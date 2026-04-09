## AnimationManager — Autoload
##
## Oyun genelinde animasyon koordinasyon merkezi.
## Her animasyonlu nesne kendi AnimationPlayer'ını barındırır;
## AnimationManager yalnızca global kalite modunu ve coin animasyon mantığını yönetir.
##
## Mimari kuralları (GDD #7):
##   - Dağıtık sahip modeli: merkezi kontrol düğümü değil, koordinatör
##   - _process() yasaktır (ADR-0003); tüm geçişler sinyal/metod çağrısıyla
##   - battery_saver=true: tüm blend=0.0, GPUParticles2D.process_mode=DISABLED, coin atlanır
##   - Coin animasyonu: max 3 eş zamanlı grup (Edge Case 4)
##   - AnimationPlayer referansı null → push_error; gameplay devam eder (Edge Case 9)
class_name AnimationManager
extends Node

# ── Sinyaller ─────────────────────────────────────────────────────────────────

## Coin animasyonu istek sinyali. UI/VFX sistemi spawn eder.
signal coin_spawn_requested(count: int, delta: int)
## Vitrin dolu → hasat engellendi. HUD "Vitrin dolu!" uyarısı gösterir.
signal harvest_blocked(slot_id: int)
## Hamur fırına yüklendi. Oven/Baking sistemi dinler.
signal dough_loaded(slot_id: int)

# ── Tuning Knobs (GDD Tablosu) ────────────────────────────────────────────────

const COIN_FAN_INTERVAL_SEC: float   = 0.1
const COIN_FLYING_DURATION: float    = 0.8
const OVEN_DOOR_DURATION: float      = 1.0
const BREAD_SLIDE_DURATION: float    = 0.5
const CUSTOMER_ENTER_DURATION: float = 0.4
const CUSTOMER_LEAVE_DURATION: float = 0.5
const CUSTOMER_TIMEOUT_DURATION: float = 0.25
const BLEND_STANDARD: float          = 0.2
const BLEND_FAST: float              = 0.1
const BLEND_INSTANT: float           = 0.0

## Coin spawn eşikleri (F-2)
const COIN_SPAWN_THRESHOLD_1: int = 50
const COIN_SPAWN_THRESHOLD_2: int = 500
const COIN_SPAWN_THRESHOLD_3: int = 2000

## Eş zamanlı maksimum aktif coin grubu (Edge Case 4: max 3 grup = 24 coin)
const MAX_COIN_GROUPS: int = 3

# ── State ─────────────────────────────────────────────────────────────────────

var _battery_saver: bool = false
var _prev_gold_balance: int = 0
var _active_coin_groups: int = 0

## Dependency injection (test izolasyonu). null ise autoload'dan alınır.
var _settings_ref: SettingsManager = null
var _economy_ref: EconomySystem = null

## Salt okunur battery_saver durumu.
var battery_saver: bool:
	get: return _battery_saver


func _ready() -> void:
	_connect_signals()


# ── Public API ────────────────────────────────────────────────────────────────

## F-2: Altın delta değerine göre coin spawn sayısını döner.
## delta <= 0 → 0 (animasyon tetiklenmez)
func coin_count_for_delta(delta: int) -> int:
	if delta <= 0:
		return 0
	if delta <= COIN_SPAWN_THRESHOLD_1:
		return 1
	if delta <= COIN_SPAWN_THRESHOLD_2:
		return 3
	if delta <= COIN_SPAWN_THRESHOLD_3:
		return 5
	return 8


## Vitrin dolu uyarısı — OvenManager veya UI çağırır.
func notify_harvest_blocked(slot_id: int) -> void:
	harvest_blocked.emit(slot_id)


## Hamur fırına yüklendi — Dough node animasyonu tamamlanınca çağırır.
func notify_dough_loaded(slot_id: int) -> void:
	dough_loaded.emit(slot_id)


## Geçerli blend süresini döner. battery_saver=true ise daima 0.0.
func get_blend_time(standard_blend: float) -> float:
	return BLEND_INSTANT if _battery_saver else standard_blend


# ── Internal ──────────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	var settings := _get_settings()
	if settings:
		_battery_saver = settings.battery_saver
		if not settings.battery_saver_changed.is_connected(_on_battery_saver_changed):
			settings.battery_saver_changed.connect(_on_battery_saver_changed)

	var economy := _get_economy()
	if economy:
		_prev_gold_balance = economy.gold_balance
		if not economy.gold_changed.is_connected(_on_gold_changed):
			economy.gold_changed.connect(_on_gold_changed)


func _on_battery_saver_changed(enabled: bool) -> void:
	_battery_saver = enabled


func _on_gold_changed(new_balance: int) -> void:
	var delta: int = new_balance - _prev_gold_balance
	_prev_gold_balance = new_balance
	if delta <= 0:
		return
	if _battery_saver:
		return  # battery_saver: coin animasyonu tamamen atlanır (Core Rule 5)
	_trigger_coin_animation(delta)


func _trigger_coin_animation(delta: int) -> void:
	if _active_coin_groups >= MAX_COIN_GROUPS:
		# Edge Case 4: max 3 grup aktif; fazlası sessizce atlanır
		return
	var count: int = coin_count_for_delta(delta)
	_active_coin_groups += 1
	coin_spawn_requested.emit(count, delta)
	# F-3: fan süresi + coin_fly tamamlanınca grup sayacını azalt
	var total_duration: float = (count - 1) * COIN_FAN_INTERVAL_SEC + COIN_FLYING_DURATION
	get_tree().create_timer(total_duration).timeout.connect(
		func() -> void: _active_coin_groups -= 1
	)


func _get_settings() -> SettingsManager:
	if _settings_ref:
		return _settings_ref
	return get_node_or_null("/root/Settings") as SettingsManager


func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem
