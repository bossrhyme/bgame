## GUT Test Suite — SaveLoadManager
## GDD #8 Acceptance Criteria: AC-1 – AC-13
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_save_load_manager.gd
extends GutTest

const TEST_SAVE_PATH: String = "user://save_game_test.cfg"
const TEST_SAVE_TMP: String = "user://save_game_test.cfg.tmp"

var manager: SaveLoadManager
var economy: EconomySystem


func before_each() -> void:
	economy = EconomySystem.new()
	add_child(economy)
	manager = SaveLoadManager.new()
	manager._set_save_path(TEST_SAVE_PATH)
	manager._economy_ref = economy
	# NOT added to tree yet — individual tests call add_child(manager) after
	# writing any required pre-existing save files.


func after_each() -> void:
	if is_instance_valid(manager):
		if manager.is_inside_tree():
			manager.queue_free()
		else:
			manager.free()
	if is_instance_valid(economy):
		economy.queue_free()
	_cleanup_test_files()


func _cleanup_test_files() -> void:
	var dir := DirAccess.open("user://")
	if not dir:
		return
	for name: String in ["save_game_test.cfg", "save_game_test.cfg.tmp"]:
		if dir.file_exists(name):
			dir.remove(name)


## add_child(manager) tetikleri _ready() → _load_game()
func _load_with(cfg: ConfigFile = null) -> void:
	if cfg:
		cfg.save(TEST_SAVE_PATH)
	add_child(manager)


# ── AC-1: Kayıt yok → varsayılanlar ─────────────────────────────────────────

func test_no_save_file_loads_defaults_no_crash() -> void:
	_load_with()
	assert_eq(economy.gold_balance, 0, "gold varsayılanı 0")
	assert_eq(economy.rozet_balance, 0, "rozet varsayılanı 0")
	assert_eq(manager.last_seen_unix, 0, "last_seen_unix varsayılanı 0")
	assert_eq(manager.state, SaveLoadManager.State.READY, "READY durumuna geçildi")


# ── AC-2: Kayıt var → doğru değerler yüklenir ────────────────────────────────

func test_saved_gold_and_rozet_restored() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 1)
	cfg.set_value("economy", "gold", 750)
	cfg.set_value("economy", "rozet", 300)
	cfg.set_value("time", "last_seen_unix", 1_000_000)
	_load_with(cfg)
	assert_eq(economy.gold_balance, 750, "gold doğru yüklendi")
	assert_eq(economy.rozet_balance, 300, "rozet doğru yüklendi")


func test_last_seen_unix_restored() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 1)
	cfg.set_value("economy", "gold", 0)
	cfg.set_value("economy", "rozet", 0)
	cfg.set_value("time", "last_seen_unix", 1_743_750_000)
	_load_with(cfg)
	assert_eq(manager.last_seen_unix, 1_743_750_000, "last_seen_unix doğru yüklendi")


# ── AC-4: Negatif para birimi → 0'a sabitlenir ────────────────────────────────

func test_negative_gold_clamped_to_zero() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 1)
	cfg.set_value("economy", "gold", -500)
	cfg.set_value("economy", "rozet", 200)
	_load_with(cfg)
	assert_eq(economy.gold_balance, 0, "Negatif gold → 0")
	assert_eq(economy.rozet_balance, 200, "rozet değişmedi")


# ── AC-7: Bozuk kayıt → varsayılanlar ────────────────────────────────────────

func test_corrupt_save_loads_defaults_no_crash() -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("bu gecerli bir cfg degil!!! %%%###")
	file.close()
	_load_with()
	assert_eq(economy.gold_balance, 0, "Bozuk kayıt → gold=0")
	assert_eq(economy.rozet_balance, 0, "Bozuk kayıt → rozet=0")
	assert_eq(manager.state, SaveLoadManager.State.READY, "READY durumuna geçildi")


# ── AC-8: Eksik anahtar → yalnızca o anahtarın varsayılanı ───────────────────

func test_missing_gold_key_uses_default_rozet_preserved() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 1)
	# gold anahtarı yok
	cfg.set_value("economy", "rozet", 500)
	cfg.set_value("time", "last_seen_unix", 0)
	_load_with(cfg)
	assert_eq(economy.gold_balance, 0, "Eksik gold → 0")
	assert_eq(economy.rozet_balance, 500, "rozet korundu")


func test_missing_rozet_key_uses_default_gold_preserved() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 1)
	cfg.set_value("economy", "gold", 1200)
	# rozet anahtarı yok
	_load_with(cfg)
	assert_eq(economy.gold_balance, 1200, "gold korundu")
	assert_eq(economy.rozet_balance, 0, "Eksik rozet → 0")


# ── AC-5: Atomik yazma ────────────────────────────────────────────────────────

func test_save_creates_cfg_file() -> void:
	_load_with()
	manager.save_game()
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "Kayıt dosyası oluşturuldu")


func test_atomic_write_no_tmp_after_success() -> void:
	_load_with()
	manager.save_game()
	assert_false(FileAccess.file_exists(TEST_SAVE_TMP), ".tmp dosyası kalmadı")


# ── AC-9: Debounce ────────────────────────────────────────────────────────────

func test_debounce_second_call_suppressed() -> void:
	_load_with()
	manager.save_game()
	assert_true(manager._debounce_active, "İlk çağrı sonrası debounce aktif")
	# İkinci çağrı debounce aktifken gelir → atlanır
	manager.save_game()
	# _debounce_active hâlâ true; bu çağrı no-op oldu
	assert_true(manager._debounce_active, "İkinci çağrı debounce'u bozmadı")


# ── AC-10: Eski versiyon migration ───────────────────────────────────────────

func test_old_save_version_zero_loads_without_crash() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 0)
	cfg.set_value("economy", "gold", 200)
	cfg.set_value("economy", "rozet", 100)
	_load_with(cfg)
	# Migration çalışır, mevcut anahtarlar okunur, oyun devam eder
	assert_eq(economy.gold_balance, 200, "Eski versiyon → gold okundu")
	assert_eq(manager.state, SaveLoadManager.State.READY, "READY durumuna geçildi")


func test_future_save_version_loads_known_keys() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 999)
	cfg.set_value("economy", "gold", 999)
	cfg.set_value("economy", "rozet", 0)
	_load_with(cfg)
	# Bilinmeyen anahtarlar yoksayılır, bilinen anahtarlar okunur
	assert_eq(economy.gold_balance, 999, "Bilinmeyen versiyon → bilinen gold okundu")


# ── AC-13: last_seen_unix kayıtta güncellenir ─────────────────────────────────

func test_save_updates_last_seen_unix() -> void:
	_load_with()
	assert_eq(manager.last_seen_unix, 0, "Başlangıçta 0")
	manager.save_game()
	assert_true(manager.last_seen_unix > 0, "Kayıt sonrası last_seen_unix > 0")


func test_save_writes_last_seen_unix_to_file() -> void:
	_load_with()
	manager.save_game()
	# Kaydedilen değeri dosyadan oku
	var cfg := ConfigFile.new()
	cfg.load(TEST_SAVE_PATH)
	var file_unix: int = cfg.get_value("time", "last_seen_unix", -1)
	assert_eq(file_unix, manager.last_seen_unix, "Dosyadaki last_seen_unix bellekle eşleşiyor")


# ── AC-8 (stale .tmp): Açılışta .tmp kalıntısı temizlenir ───────────────────

func test_stale_tmp_removed_on_startup() -> void:
	# Sahte .tmp bırak
	var file := FileAccess.open(TEST_SAVE_TMP, FileAccess.WRITE)
	file.store_string("[meta]\nsave_version=1\n")
	file.close()
	assert_true(FileAccess.file_exists(TEST_SAVE_TMP), "Test öncesi .tmp mevcut")
	_load_with()
	assert_false(FileAccess.file_exists(TEST_SAVE_TMP), "Startup sonrası .tmp silindi")


# ── Economy save verisi round-trip ───────────────────────────────────────────

func test_save_persists_economy_gold_to_file() -> void:
	_load_with()
	economy.earn_gold(1500)
	manager.save_game()
	var cfg := ConfigFile.new()
	cfg.load(TEST_SAVE_PATH)
	assert_eq(cfg.get_value("economy", "gold", -1), 1500, "gold dosyaya yazıldı")


func test_save_persists_economy_rozet_to_file() -> void:
	_load_with()
	economy.earn_rozet(999)
	manager.save_game()
	var cfg := ConfigFile.new()
	cfg.load(TEST_SAVE_PATH)
	assert_eq(cfg.get_value("economy", "rozet", -1), 999, "rozet dosyaya yazıldı")


# ── EconomySystem.get_save_data() ────────────────────────────────────────────

func test_economy_get_save_data_returns_balances() -> void:
	economy.initialize(400, 150)
	var data: Dictionary = economy.get_save_data()
	assert_eq(data.get("gold"), 400, "get_save_data gold = 400")
	assert_eq(data.get("rozet"), 150, "get_save_data rozet = 150")
