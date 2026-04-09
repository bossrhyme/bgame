## SettingsManager
##
## Oyuncu tercihlerinin tek depolama ve uygulama noktası.
## ConfigFile ile user://settings.cfg dosyasına yazar/okur.
## Oyun kaydından (user://save_game.cfg) tamamen bağımsızdır (GDD #8 Core Rule 11).
##
## Mimari kuralları (GDD #6):
##   - Her setter anında kaydeder (_save_settings) ve uygular (_apply_*)
##   - _process() yasaktır (ADR-0003)
##   - Bozuk settings.cfg → varsayılanlar; oyun asla çökmez
##   - AudioServer, Engine, TranslationServer entegrasyonu _apply_all() üzerinden
class_name SettingsManager
extends Node

# ── Sabitler ─────────────────────────────────────────────────────────────────

const DEFAULT_MUSIC_VOLUME: int   = 80
const DEFAULT_SFX_VOLUME: int     = 80
const DEFAULT_AMBIENT_VOLUME: int = 70
const SILENCE_DB: float           = -80.0

const DEFAULT_BATTERY_SAVER: bool    = false
const DEFAULT_HAPTIC_ENABLED: bool   = true

const DEFAULT_LANGUAGE: String         = "tr"
const SUPPORTED_LANGUAGES: Array[String] = ["tr", "en"]

const DEFAULT_NOTIF_PRODUCTION: bool = true
const DEFAULT_NOTIF_ORDER: bool      = true
const DEFAULT_NOTIF_PROMO: bool      = false

# AudioServer bus adları (proje ayarlarında tanımlı olmalı)
const BUS_MUSIC: String   = "Music"
const BUS_SFX: String     = "SFX"
const BUS_AMBIENT: String = "Ambient"

# ── Durum ─────────────────────────────────────────────────────────────────────

## Ses ayarları
var music_volume: int   = DEFAULT_MUSIC_VOLUME
var sfx_volume: int     = DEFAULT_SFX_VOLUME
var ambient_volume: int = DEFAULT_AMBIENT_VOLUME
var master_mute: bool   = false

## Bildirim tercihleri
var notif_production: bool = DEFAULT_NOTIF_PRODUCTION
var notif_order: bool      = DEFAULT_NOTIF_ORDER
var notif_promo: bool      = DEFAULT_NOTIF_PROMO

## Performans
var battery_saver: bool  = DEFAULT_BATTERY_SAVER
var haptic_enabled: bool = DEFAULT_HAPTIC_ENABLED

## Dil
var language: String = DEFAULT_LANGUAGE

## Kayıt yolu (test izolasyonu için _set_save_path ile override edilir)
var _save_path: String = "user://settings.cfg"


func _ready() -> void:
	_load_settings()
	_apply_all()


# ── Public API — Ses ──────────────────────────────────────────────────────────

## Müzik slider değerini ayarlar (0–100). Anında AudioServer'a ve dosyaya yazar.
func set_music_volume(value: int) -> void:
	music_volume = clampi(value, 0, 100)
	_apply_audio()
	_save_settings()


## SFX slider değerini ayarlar (0–100).
func set_sfx_volume(value: int) -> void:
	sfx_volume = clampi(value, 0, 100)
	_apply_audio()
	_save_settings()


## Ambient slider değerini ayarlar (0–100).
func set_ambient_volume(value: int) -> void:
	ambient_volume = clampi(value, 0, 100)
	_apply_audio()
	_save_settings()


## Master mute açar/kapatır. Slider değerleri korunur.
func set_master_mute(value: bool) -> void:
	master_mute = value
	_apply_audio()
	_save_settings()


# ── Public API — Bildirimler ──────────────────────────────────────────────────

func set_notif_production(value: bool) -> void:
	notif_production = value
	_save_settings()


func set_notif_order(value: bool) -> void:
	notif_order = value
	_save_settings()


func set_notif_promo(value: bool) -> void:
	notif_promo = value
	_save_settings()


# ── Public API — Performans ───────────────────────────────────────────────────

## Pil tasarrufu modu değiştiğinde yayılır. AnimationManager dinler.
signal battery_saver_changed(enabled: bool)

## Pil tasarrufu modunu açar/kapatır. Engine.max_fps anında değişir.
func set_battery_saver(value: bool) -> void:
	battery_saver = value
	_apply_performance()
	_save_settings()
	battery_saver_changed.emit(value)


## Dokunsal geri bildirimi açar/kapatır.
func set_haptic_enabled(value: bool) -> void:
	haptic_enabled = value
	_save_settings()


## Dokunsal geri bildirim aktif mi? (Touch/Gesture Input sistemi bu API'yi kullanır)
func get_haptic_enabled() -> bool:
	return haptic_enabled


# ── Public API — Dil ──────────────────────────────────────────────────────────

## Dili değiştirir. Desteklenmeyen locale → hata logu, değişiklik yapılmaz.
func set_language(value: String) -> void:
	if value not in SUPPORTED_LANGUAGES:
		push_error("SettingsManager: Desteklenmeyen dil: '%s' — varsayılan '%s' kullanılıyor" \
			% [value, DEFAULT_LANGUAGE])
		return
	language = value
	_apply_language()
	_save_settings()


# ── Public API — Veri ─────────────────────────────────────────────────────────

## settings.cfg'yi siler. Bir sonraki _ready()'de varsayılanlar yüklenir.
## Kayıt Sil onay dialog'u [Sil] basıldığında UI bu metodu çağırır.
func clear_settings() -> void:
	var dir := DirAccess.open(_save_path.get_base_dir())
	if dir and dir.file_exists(_save_path.get_file()):
		dir.remove(_save_path.get_file())


# ── Formül — Ses Volume Dönüşümü (F-1) ───────────────────────────────────────

## Slider değerini (0–100 int) AudioServer dB değerine dönüştürür.
## slider=0 → SILENCE_DB (-80.0), slider=100 → 0.0 dB
func slider_to_db(value: int) -> float:
	if value <= 0:
		return SILENCE_DB
	return linear_to_db(clampf(value / 100.0, 0.0, 1.0))


## Test izolasyonu için kayıt yolunu değiştirir.
func _set_save_path(path: String) -> void:
	_save_path = path


# ── Internal ──────────────────────────────────────────────────────────────────

func _load_settings() -> void:
	if not FileAccess.file_exists(_save_path):
		return  # Dosya yok → varsayılanlar kalır

	var config := ConfigFile.new()
	var err: Error = config.load(_save_path)
	if err != OK:
		push_warning("SettingsManager: settings.cfg bozuk (%s) — varsayılanlar kullanılıyor" \
			% error_string(err))
		return

	# Ses
	music_volume   = clampi(config.get_value("audio", "music_volume",   DEFAULT_MUSIC_VOLUME),   0, 100)
	sfx_volume     = clampi(config.get_value("audio", "sfx_volume",     DEFAULT_SFX_VOLUME),     0, 100)
	ambient_volume = clampi(config.get_value("audio", "ambient_volume", DEFAULT_AMBIENT_VOLUME), 0, 100)
	master_mute    = config.get_value("audio", "master_mute", false)

	# Bildirimler
	notif_production = config.get_value("notifications", "production", DEFAULT_NOTIF_PRODUCTION)
	notif_order      = config.get_value("notifications", "order",      DEFAULT_NOTIF_ORDER)
	notif_promo      = config.get_value("notifications", "promo",      DEFAULT_NOTIF_PROMO)

	# Performans
	battery_saver  = config.get_value("performance", "battery_saver",  DEFAULT_BATTERY_SAVER)
	haptic_enabled = config.get_value("performance", "haptic_enabled", DEFAULT_HAPTIC_ENABLED)

	# Dil
	var saved_lang: String = config.get_value("locale", "language", DEFAULT_LANGUAGE)
	if saved_lang in SUPPORTED_LANGUAGES:
		language = saved_lang
	else:
		push_error("SettingsManager: settings.cfg'de desteklenmeyen dil '%s' — '%s' kullanılıyor" \
			% [saved_lang, DEFAULT_LANGUAGE])
		language = DEFAULT_LANGUAGE


func _save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("audio", "music_volume",   music_volume)
	config.set_value("audio", "sfx_volume",     sfx_volume)
	config.set_value("audio", "ambient_volume", ambient_volume)
	config.set_value("audio", "master_mute",    master_mute)

	config.set_value("notifications", "production", notif_production)
	config.set_value("notifications", "order",      notif_order)
	config.set_value("notifications", "promo",      notif_promo)

	config.set_value("performance", "battery_saver",  battery_saver)
	config.set_value("performance", "haptic_enabled", haptic_enabled)

	config.set_value("locale", "language", language)

	var err: Error = config.save(_save_path)
	if err != OK:
		push_error("SettingsManager: Kayıt başarısız (%s)" % error_string(err))


func _apply_all() -> void:
	_apply_audio()
	_apply_performance()
	_apply_language()


func _apply_audio() -> void:
	_set_bus_volume(BUS_MUSIC,   music_volume)
	_set_bus_volume(BUS_SFX,     sfx_volume)
	_set_bus_volume(BUS_AMBIENT, ambient_volume)


func _set_bus_volume(bus_name: String, slider_value: int) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return  # Bus proje ayarlarında tanımlı değil; sessiz geç
	var db: float = SILENCE_DB if master_mute else slider_to_db(slider_value)
	AudioServer.set_bus_volume_db(bus_idx, db)


func _apply_performance() -> void:
	Engine.max_fps = 30 if battery_saver else 60


func _apply_language() -> void:
	TranslationServer.set_locale(language)
