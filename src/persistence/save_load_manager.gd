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

const CURRENT_SAVE_VERSION: int = 1
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
		_finish_load(gold, rozet)
		return

	var config := ConfigFile.new()
	var err: Error = config.load(_save_path)
	if err != OK:
		push_error("SaveLoadManager: Kayıt bozuk (%s) — varsayılanlar yükleniyor" % error_string(err))
		_finish_load(gold, rozet)
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

	_finish_load(gold, rozet)


func _finish_load(gold: int, rozet: int) -> void:
	var econ := _get_economy()
	if econ:
		econ.initialize(gold, rozet)
	else:
		push_error("SaveLoadManager: Economy sistemi bulunamadı!")
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

	# Progression — diğer sistemler implement edilince buraya eklenir
	config.set_value("progression", "purchased_upgrades", [])
	config.set_value("progression", "unlocked_recipes", [])

	# Gameplay — diğer sistemler implement edilince buraya eklenir
	config.set_value("gameplay", "hired_employees", [])
	config.set_value("gameplay", "unlocked_locations", [])
	config.set_value("gameplay", "active_location", "bakery_1")
	config.set_value("gameplay", "oven_state", {})
	config.set_value("gameplay", "collection_progress", {})

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
