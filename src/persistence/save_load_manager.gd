## SaveLoadManager — Autoload
##
## Tüm kalıcı oyun verisinin tek güvenilir depolama noktası.
## ConfigFile API'si ile user://save_game.cfg dosyasına yazar ve okur.
##
## Mimari kuralları (GDD #8):
##   - Autoload listesinin en üstünde yer alır — tüm sistemlerden önce yüklenir
##   - Tek okuma (startup), çoklu yazma (olay-tetiklemeli)
##   - _process() içinde dosya I/O yasaktır (ADR-0003)
##   - Atomik yazma: .tmp → rename, başarısızlıkta .cfg bozulmaz
##   - Debounce: SAVE_DEBOUNCE_MS içinde tek fiziksel yazma
##   - Bozuk kayıt → push_warning + varsayılanlar; oyun asla çökmez
class_name SaveLoadManager
extends Node

const CURRENT_SAVE_VERSION: int = 2
const SAVE_DEBOUNCE_MS: int = 500

enum State { UNINITIALIZED, LOADING, READY, SAVING }

var _state: State = State.UNINITIALIZED
var _debounce_active: bool = false

## Son kapanış Unix timestamp (UTC). Downstream sistemler pull eder.
var last_seen_unix: int = 0

## Kayıt dosyası yolu. Test izolasyonu için _set_save_path() ile override edilir.
var _save_path: String = "user://save_game.cfg"
var _save_tmp_path: String = "user://save_game.cfg.tmp"

## Dependency injection (test izolasyonu). null ise autoload'dan alınır.
var _economy_ref: EconomySystem = null
var _oven_ref: OvenManager = null
var _upgrade_ref: UpgradeTree = null
var _recipe_ref: RecipeManager = null
var _customer_ref: CustomerOrderSystem = null
var _employee_ref: EmployeeManager = null
var _registry_ref: ContentRegistry = null

## Salt okunur state erişimi.
var state: State:
	get: return _state


func _ready() -> void:
	_state = State.LOADING
	_clean_stale_tmp()
	_load_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_trigger_save()


# ── Public API ────────────────────────────────────────────────────────────────

## Kayıt tetikleyicisi. Upgrade satın alma, lokasyon açma vb. sinyaller buraya bağlanır.
func save_game() -> void:
	_trigger_save()


## Test izolasyonu için kayıt yolunu değiştirir.
## Yalnızca test ortamında kullanılır; production'da çağrılmaz.
func _set_save_path(path: String) -> void:
	_save_path = path
	_save_tmp_path = path + ".tmp"


# ── Internal ──────────────────────────────────────────────────────────────────

func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem


func _get_oven() -> OvenManager:
	if _oven_ref:
		return _oven_ref
	return get_node_or_null("/root/OvenManager") as OvenManager


func _get_upgrade_tree() -> UpgradeTree:
	if _upgrade_ref:
		return _upgrade_ref
	return get_node_or_null("/root/UpgradeTree") as UpgradeTree


func _get_recipe_manager() -> RecipeManager:
	if _recipe_ref:
		return _recipe_ref
	return get_node_or_null("/root/RecipeManager") as RecipeManager


func _get_customer_system() -> CustomerOrderSystem:
	if _customer_ref:
		return _customer_ref
	return get_node_or_null("/root/CustomerOrderSystem") as CustomerOrderSystem


func _get_employee_manager() -> EmployeeManager:
	if _employee_ref:
		return _employee_ref
	return get_node_or_null("/root/EmployeeManager") as EmployeeManager


func _get_registry() -> ContentRegistry:
	if _registry_ref:
		return _registry_ref
	return get_node_or_null("/root/ContentRegistry") as ContentRegistry


func _clean_stale_tmp() -> void:
	if FileAccess.file_exists(_save_tmp_path):
		var dir := DirAccess.open(_save_tmp_path.get_base_dir())
		if dir:
			dir.remove(_save_tmp_path.get_file())
		push_warning("SaveLoadManager: Stale .tmp removed")


func _load_game() -> void:
	var gold: int = 0
	var rozet: int = 0

	if not FileAccess.file_exists(_save_path):
		push_warning("SaveLoadManager: Kayıt dosyası yok — yeni oyun başlatılıyor")
		_finish_load({"gold": gold, "rozet": rozet})
		return

	var config := ConfigFile.new()
	var err: Error = config.load(_save_path)
	if err != OK:
		push_error("SaveLoadManager: Kayıt bozuk (%s) — varsayılanlar yükleniyor" % error_string(err))
		_finish_load({"gold": gold, "rozet": rozet})
		return

	# Versiyon kontrolü ve migration
	var saved_version: int = config.get_value("meta", "save_version", 0)
	if saved_version < CURRENT_SAVE_VERSION:
		push_warning("SaveLoadManager: Eski versiyon (%d → %d) — migration çalıştırılıyor" \
			% [saved_version, CURRENT_SAVE_VERSION])
	elif saved_version > CURRENT_SAVE_VERSION:
		push_warning("SaveLoadManager: Yeni versiyon (%d) — bilinmeyen anahtarlar yoksayılıyor" \
			% saved_version)

	# Economy — negatif değerler 0'a sabitlenir (GDD EC-4)
	gold = maxi(config.get_value("economy", "gold", 0), 0)
	rozet = maxi(config.get_value("economy", "rozet", 0), 0)

	# Time
	last_seen_unix = config.get_value("time", "last_seen_unix", 0)

	# Sistem verileri
	var save_data := {
		"gold": gold,
		"rozet": rozet,
		"oven_slots": config.get_value("gameplay", "oven_slots", []),
		"upgrade_levels": config.get_value("progression", "upgrade_levels", {}),
		"recipe_unlock_state": config.get_value("progression", "recipe_unlock_state", {}),
		"ingredient_stock": config.get_value("progression", "ingredient_stock", {}),
		"customer_state": config.get_value("gameplay", "customer_state", {}),
		"employee_state": config.get_value("gameplay", "employee_state", {}),
	}
	_finish_load(save_data)


func _finish_load(data: Dictionary) -> void:
	# 1. Economy (önce yüklenmeli — diğer sistemler bakiyeye bağımlı olabilir)
	var econ := _get_economy()
	if econ:
		econ.initialize(data.get("gold", 0), data.get("rozet", 0))
	else:
		push_error("SaveLoadManager: Economy sistemi bulunamadı!")

	# 2. EmployeeManager — Offline pişirme hız bonusu için ücret kesiminden ÖNCE yüklenmeli
	#    (GDD Offline Production #16: speed_multiplier hesabı ücret kesiminden önce yapılır)
	var employee_mgr := _get_employee_manager()
	if employee_mgr:
		var registry := _get_registry()
		if registry:
			var all_emp: Array[EmployeeData] = registry.get_all_employees()
			var data_map: Dictionary = {}
			for emp: EmployeeData in all_emp:
				data_map[emp.id] = emp
			employee_mgr.deserialize(data.get("employee_state", {}), data_map)
		elif not data.get("employee_state", {}).is_empty():
			push_warning("SaveLoadManager: ContentRegistry yok — employee_state yoksayıldı")

	# 3. OvenManager — speed_multiplier Fırın Ustası efektinden alınır; ücret kesiminden önce
	var oven := _get_oven()
	if oven:
		var speed_mult: float = 1.0
		if employee_mgr:
			speed_mult = 1.0 + employee_mgr.get_effect(GameEnums.EmployeeRole.OVEN_MASTER)
		var raw: Array = data.get("oven_slots", [])
		var typed: Array[Dictionary] = []
		for entry in raw:
			typed.append(entry)
		oven.initialize_from_save(typed, speed_mult)

	# 4. Employee günlük ücret kesimi — offline üretim hesabından SONRA (GDD §3)
	if employee_mgr:
		var elapsed_days: int = 0
		if last_seen_unix > 0:
			elapsed_days = int(float(Time.get_unix_time_from_system() - last_seen_unix) / 86400.0)
		employee_mgr.process_daily_wages(elapsed_days)

	# 5. UpgradeTree — Config Resource'ları anında günceller
	var upgrade_tree := _get_upgrade_tree()
	if upgrade_tree:
		upgrade_tree.deserialize({"levels": data.get("upgrade_levels", {})})

	# 6. RecipeManager — kilit durumu ve malzeme stoğu
	var recipe_mgr := _get_recipe_manager()
	if recipe_mgr:
		recipe_mgr.deserialize({
			"unlock_state": data.get("recipe_unlock_state", {}),
			"ingredient_stock": data.get("ingredient_stock", {}),
		})

	# 7. CustomerOrderSystem — aktif siparişler ve memnuniyet
	var customer_sys := _get_customer_system()
	if customer_sys:
		customer_sys.deserialize(data.get("customer_state", {}))
		customer_sys.update_order_states()  # Offline süre dolmuş siparişleri temizle

	_state = State.READY


func _trigger_save() -> void:
	if _state != State.READY:
		push_warning("SaveLoadManager: Kayıt atlandı — durum READY değil (%s)" \
			% State.keys()[_state])
		return
	if _debounce_active:
		return
	_debounce_active = true
	_save_game_internal()
	# Debounce penceresi: 500ms sonra tekrar kayda izin ver
	get_tree().create_timer(SAVE_DEBOUNCE_MS / 1000.0).timeout.connect(
		func() -> void: _debounce_active = false
	)


func _save_game_internal() -> void:
	_state = State.SAVING
	var now_unix: int = Time.get_unix_time_from_system()
	last_seen_unix = now_unix

	var config := ConfigFile.new()

	# Meta
	config.set_value("meta", "save_version", CURRENT_SAVE_VERSION)

	# Economy
	var econ := _get_economy()
	if econ:
		var econ_data: Dictionary = econ.get_save_data()
		config.set_value("economy", "gold", econ_data.get("gold", 0))
		config.set_value("economy", "rozet", econ_data.get("rozet", 0))
	else:
		config.set_value("economy", "gold", 0)
		config.set_value("economy", "rozet", 0)

	# Time — her kayıtta güncellenir (GDD Core Rule 9)
	config.set_value("time", "last_seen_unix", now_unix)

	# Progression
	var upgrade_tree := _get_upgrade_tree()
	if upgrade_tree:
		var ut_data := upgrade_tree.serialize()
		config.set_value("progression", "upgrade_levels", ut_data.get("levels", {}))
	else:
		config.set_value("progression", "upgrade_levels", {})

	var recipe_mgr := _get_recipe_manager()
	if recipe_mgr:
		var rm_data := recipe_mgr.serialize()
		config.set_value("progression", "recipe_unlock_state", rm_data.get("unlock_state", {}))
		config.set_value("progression", "ingredient_stock", rm_data.get("ingredient_stock", {}))
	else:
		config.set_value("progression", "recipe_unlock_state", {})
		config.set_value("progression", "ingredient_stock", {})

	# Gameplay
	var oven := _get_oven()
	config.set_value("gameplay", "oven_slots", oven.get_save_data() if oven else [])

	var customer_sys := _get_customer_system()
	config.set_value("gameplay", "customer_state",
		customer_sys.serialize() if customer_sys else {})

	var employee_mgr := _get_employee_manager()
	config.set_value("gameplay", "employee_state",
		employee_mgr.serialize() if employee_mgr else {})

	# Atomik yazma: .tmp'ye yaz, başarıysa rename; başarısızsa .tmp sil
	var write_err: Error = config.save(_save_tmp_path)
	if write_err == OK:
		var dir := DirAccess.open(_save_tmp_path.get_base_dir())
		if dir:
			var rename_err: Error = dir.rename(_save_tmp_path.get_file(), _save_path.get_file())
			if rename_err != OK:
				push_error("SaveLoadManager: Rename başarısız (%s) — önceki kayıt korundu" \
					% error_string(rename_err))
				dir.remove(_save_tmp_path.get_file())
		else:
			push_error("SaveLoadManager: DirAccess açılamadı — önceki kayıt korundu")
	else:
		var dir := DirAccess.open(_save_tmp_path.get_base_dir())
		if dir and FileAccess.file_exists(_save_tmp_path):
			dir.remove(_save_tmp_path.get_file())
		push_error("SaveLoadManager: Kayıt başarısız (%s) — önceki kayıt korundu" \
			% error_string(write_err))

	_state = State.READY
