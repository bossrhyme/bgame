## GUT Test Suite — SettingsManager
## GDD #6 Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_settings_manager.gd
extends GutTest

const TEST_SETTINGS_PATH: String = "user://settings_test.cfg"

var settings: SettingsManager
var _original_max_fps: int = 0


func before_each() -> void:
	_original_max_fps = Engine.max_fps
	settings = SettingsManager.new()
	settings._set_save_path(TEST_SETTINGS_PATH)
	add_child(settings)


func after_each() -> void:
	settings.queue_free()
	Engine.max_fps = _original_max_fps
	_cleanup_test_file()


func _cleanup_test_file() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("settings_test.cfg"):
		dir.remove("settings_test.cfg")


func _make_settings_with_file(cfg: ConfigFile) -> SettingsManager:
	cfg.save(TEST_SETTINGS_PATH)
	var s := SettingsManager.new()
	s._set_save_path(TEST_SETTINGS_PATH)
	add_child(s)
	return s


# ── F-1: slider_to_db formülü ────────────────────────────────────────────────

func test_slider_to_db_at_100_returns_zero_db() -> void:
	var db := settings.slider_to_db(100)
	assert_almost_eq(db, 0.0, 0.01, "slider=100 → 0.0 dB")


func test_slider_to_db_at_80_returns_approx_minus_2_db() -> void:
	var db := settings.slider_to_db(80)
	# linear_to_db(0.8) ≈ -1.94 dB
	assert_almost_eq(db, -1.94, 0.1, "slider=80 → ≈-1.9 dB (±0.1)")


func test_slider_to_db_at_50_returns_approx_minus_6_db() -> void:
	var db := settings.slider_to_db(50)
	# linear_to_db(0.5) ≈ -6.02 dB
	assert_almost_eq(db, -6.02, 0.1, "slider=50 → ≈-6.0 dB (±0.1)")


func test_slider_to_db_at_0_returns_silence_db() -> void:
	var db := settings.slider_to_db(0)
	assert_eq(db, SettingsManager.SILENCE_DB, "slider=0 → -80.0 dB")


# ── Varsayılan değerler ───────────────────────────────────────────────────────

func test_default_music_volume_is_80() -> void:
	assert_eq(settings.music_volume, 80, "music_volume varsayılanı 80")


func test_default_sfx_volume_is_80() -> void:
	assert_eq(settings.sfx_volume, 80, "sfx_volume varsayılanı 80")


func test_default_ambient_volume_is_70() -> void:
	assert_eq(settings.ambient_volume, 70, "ambient_volume varsayılanı 70")


func test_default_haptic_enabled_is_true() -> void:
	assert_true(settings.haptic_enabled, "haptic_enabled varsayılanı true")


func test_default_battery_saver_is_false() -> void:
	assert_false(settings.battery_saver, "battery_saver varsayılanı false")


func test_default_language_is_tr() -> void:
	assert_eq(settings.language, "tr", "language varsayılanı 'tr'")


# ── Setter'lar — ses ──────────────────────────────────────────────────────────

func test_set_music_volume_updates_value() -> void:
	settings.set_music_volume(55)
	assert_eq(settings.music_volume, 55, "music_volume 55 oldu")


func test_set_music_volume_clamps_to_range() -> void:
	settings.set_music_volume(200)
	assert_eq(settings.music_volume, 100, "200 → klamplanarak 100")
	settings.set_music_volume(-10)
	assert_eq(settings.music_volume, 0, "-10 → klamplanarak 0")


func test_set_sfx_volume_independent_of_music() -> void:
	settings.set_music_volume(70)
	settings.set_sfx_volume(30)
	assert_eq(settings.music_volume, 70, "music_volume değişmedi")
	assert_eq(settings.sfx_volume, 30, "sfx_volume 30 oldu")


func test_set_ambient_volume_independent() -> void:
	settings.set_ambient_volume(45)
	assert_eq(settings.ambient_volume, 45, "ambient_volume 45 oldu")
	assert_eq(settings.music_volume, SettingsManager.DEFAULT_MUSIC_VOLUME, "music_volume değişmedi")


# ── Master mute ───────────────────────────────────────────────────────────────

func test_master_mute_true_preserves_slider_values() -> void:
	settings.set_music_volume(60)
	settings.set_sfx_volume(40)
	settings.set_master_mute(true)
	# Slider değerleri değişmemiş olmalı (mute yalnızca AudioServer'ı etkiler)
	assert_eq(settings.music_volume, 60, "music_volume mute sonrası korundu")
	assert_eq(settings.sfx_volume, 40, "sfx_volume mute sonrası korundu")
	assert_true(settings.master_mute, "master_mute = true")


func test_master_mute_false_restores_sliders() -> void:
	settings.set_music_volume(75)
	settings.set_master_mute(true)
	settings.set_master_mute(false)
	assert_eq(settings.music_volume, 75, "Mute açılınca slider değeri korunuyor")
	assert_false(settings.master_mute, "master_mute = false")


# ── Performans ────────────────────────────────────────────────────────────────

func test_battery_saver_true_sets_engine_fps_30() -> void:
	settings.set_battery_saver(true)
	assert_eq(Engine.max_fps, 30, "battery_saver=true → Engine.max_fps=30")


func test_battery_saver_false_sets_engine_fps_60() -> void:
	settings.set_battery_saver(true)   # önce true
	settings.set_battery_saver(false)  # sonra false
	assert_eq(Engine.max_fps, 60, "battery_saver=false → Engine.max_fps=60")


func test_haptic_enabled_get_returns_current_value() -> void:
	settings.set_haptic_enabled(false)
	assert_false(settings.get_haptic_enabled(), "haptic_enabled=false → get döner false")
	settings.set_haptic_enabled(true)
	assert_true(settings.get_haptic_enabled(), "haptic_enabled=true → get döner true")


# ── Dil ───────────────────────────────────────────────────────────────────────

func test_set_language_valid_locale_accepted() -> void:
	settings.set_language("en")
	assert_eq(settings.language, "en", "Geçerli locale 'en' kabul edildi")


func test_set_language_invalid_locale_rejected() -> void:
	settings.set_language("fr")  # desteklenmiyor
	assert_eq(settings.language, "tr", "Geçersiz locale reddedildi; 'tr' korundu")


# ── Kalıcılık: kayıt ve yükleme ───────────────────────────────────────────────

func test_settings_persist_to_file() -> void:
	settings.set_music_volume(42)
	settings.set_battery_saver(true)
	settings.set_haptic_enabled(false)

	# Yeni instance ile yükle
	var s2 := SettingsManager.new()
	s2._set_save_path(TEST_SETTINGS_PATH)
	add_child(s2)
	assert_eq(s2.music_volume, 42, "music_volume dosyadan geri yüklendi")
	assert_true(s2.battery_saver, "battery_saver dosyadan geri yüklendi")
	assert_false(s2.haptic_enabled, "haptic_enabled dosyadan geri yüklendi")
	s2.queue_free()


func test_notif_settings_persist() -> void:
	settings.set_notif_promo(true)
	settings.set_notif_order(false)

	var s2 := SettingsManager.new()
	s2._set_save_path(TEST_SETTINGS_PATH)
	add_child(s2)
	assert_true(s2.notif_promo, "notif_promo dosyadan geri yüklendi")
	assert_false(s2.notif_order, "notif_order dosyadan geri yüklendi")
	s2.queue_free()


func test_corrupt_settings_file_loads_defaults() -> void:
	var file := FileAccess.open(TEST_SETTINGS_PATH, FileAccess.WRITE)
	file.store_string("bu gecerli bir cfg degil!!!")
	file.close()

	var s2 := SettingsManager.new()
	s2._set_save_path(TEST_SETTINGS_PATH)
	add_child(s2)
	assert_eq(s2.music_volume, SettingsManager.DEFAULT_MUSIC_VOLUME, "Bozuk dosya → varsayılan music_volume")
	assert_false(s2.battery_saver, "Bozuk dosya → varsayılan battery_saver")
	s2.queue_free()


func test_missing_settings_file_loads_defaults() -> void:
	# Hiçbir dosya yazılmadı — varsayılanlar bekleniyor
	assert_eq(settings.music_volume, SettingsManager.DEFAULT_MUSIC_VOLUME, "Dosya yok → varsayılan")
	assert_eq(settings.language, SettingsManager.DEFAULT_LANGUAGE, "Dosya yok → varsayılan dil")


func test_unsupported_language_in_file_falls_back_to_default() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("locale", "language", "ja")  # desteklenmiyor
	cfg.save(TEST_SETTINGS_PATH)

	var s2 := SettingsManager.new()
	s2._set_save_path(TEST_SETTINGS_PATH)
	add_child(s2)
	assert_eq(s2.language, SettingsManager.DEFAULT_LANGUAGE, "Desteklenmeyen locale → 'tr'")
	s2.queue_free()


# ── clear_settings ────────────────────────────────────────────────────────────

func test_clear_settings_removes_file() -> void:
	settings.set_music_volume(50)  # dosya oluştur
	assert_true(FileAccess.file_exists(TEST_SETTINGS_PATH), "Dosya oluşturuldu")
	settings.clear_settings()
	assert_false(FileAccess.file_exists(TEST_SETTINGS_PATH), "Dosya silindi")
