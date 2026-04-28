## AdMonetizationSystem — Rewarded Reklam Yönetimi (SDK Bağımsız İskelet)
##
## 5 placement tanımlı; cooldown ve günlük kota yönetimi.
## AdMob SDK yokken stub/mock ile test edilebilir.
## Gerçek SDK entegrasyonu Alpha aşamasında yapılacak.
##
## Mimari kuralları:
##   - Ödül yalnızca ad_rewarded callback'ten gelir (ad_closed → ödül yok)
##   - Economy public API ile çalışır; doğrudan gold/rozet yazmaz
##   - tutorial_active iken teklif gösterilmez
##
## GDD: design/gdd/ad-monetization-system.md
class_name AdMonetizationSystem
extends Node

## Ödül kazanıldı (placement_id, ödül başarıyla verildi).
signal reward_granted(placement_id: StringName, reward_amount: int)
## Reklam atlandı/kapatıldı — ödül verilmedi.
signal reward_skipped(placement_id: StringName)
## Günlük limit doldu.
signal daily_limit_reached

const DAILY_AD_LIMIT: int = 10
const PLACEMENT_COOLDOWN_SEC: float = 300.0
const OFFLINE_BOOST_MULTIPLIER: float = 2.0
const DAILY_BONUS_MULTIPLIER: float = 3.0
const TASK_REWARD_MULTIPLIER: float = 2.0

## Desteklenen placement ID'leri.
const PLACEMENTS: Array[StringName] = [
	&"offline_boost",
	&"daily_bonus",
	&"instant_bake",
	&"vip_extend",
	&"task_double",
]

# ── State ──────────────────────────────────────────────────────────────────────

var _daily_ads_watched: int = 0
var _last_ad_time: Dictionary = {}        # StringName → int (unix)
var _ad_available: Dictionary = {}        # StringName → bool
var _last_reset_unix: int = 0

# ── Dependency injection ──────────────────────────────────────────────────────

var _economy_ref: EconomySystem = null
var _tutorial_ref: TutorialSystem = null


func _ready() -> void:
	_reset_availability()


# ── Public API ────────────────────────────────────────────────────────────────

## Belirtilen placement'ın teklif gösterilip gösterilmeyeceğini döner (F-4).
func can_show(placement_id: StringName) -> bool:
	if _is_tutorial_active():
		return false
	if _daily_ads_watched >= DAILY_AD_LIMIT:
		return false
	var now: int = Time.get_unix_time_from_system()
	var last: int = _last_ad_time.get(placement_id, 0)
	if float(now - last) < PLACEMENT_COOLDOWN_SEC:
		return false
	return _ad_available.get(placement_id, false)


## SDK'dan "yükleme başarısız" callback'i.
func notify_ad_failed(placement_id: StringName) -> void:
	_ad_available[placement_id] = false


## SDK'dan "reklam yüklendi" callback'i.
func notify_ad_loaded(placement_id: StringName) -> void:
	_ad_available[placement_id] = true


## Oyuncu reklamı izledi ve ödülü hak etti.
## Gerçek SDK entegrasyonunda bu, AdMob'un on_user_earned_reward callback'inden çağrılır.
func on_ad_rewarded(placement_id: StringName, context: Dictionary = {}) -> void:
	if not PLACEMENTS.has(placement_id):
		push_warning("AdMonetizationSystem: Bilinmeyen placement '%s'" % placement_id)
		return

	_daily_ads_watched += 1
	_last_ad_time[placement_id] = Time.get_unix_time_from_system()
	_ad_available[placement_id] = false  # Gösterim sonrası yeniden yüklenmeli

	if _daily_ads_watched >= DAILY_AD_LIMIT:
		daily_limit_reached.emit()

	var reward: int = _apply_reward(placement_id, context)
	reward_granted.emit(placement_id, reward)


## Oyuncu reklamı kapattı / atladı — ödül yok.
func on_ad_closed(placement_id: StringName) -> void:
	reward_skipped.emit(placement_id)


## Günlük sıfırlama (midnight UTC — SaveLoadManager veya TimeTracking tarafından çağrılır).
func reset_daily_quota() -> void:
	_daily_ads_watched = 0
	_last_reset_unix = Time.get_unix_time_from_system()
	_reset_availability()


# ── Reward Logic ──────────────────────────────────────────────────────────────

func _apply_reward(placement_id: StringName, context: Dictionary) -> int:
	var econ := _get_economy()
	if not econ:
		push_error("AdMonetizationSystem: Economy bulunamadı — ödül verilemedi")
		return 0

	match placement_id:
		&"offline_boost":
			var raw: int = context.get("offline_gold", 0)
			var bonus: int = int(float(raw) * OFFLINE_BOOST_MULTIPLIER) - raw
			if bonus > 0:
				econ.earn_gold(bonus)
			return bonus

		&"daily_bonus":
			var raw: int = context.get("daily_bonus_gold", 0)
			var total: int = int(float(raw) * DAILY_BONUS_MULTIPLIER)
			var bonus: int = total - raw
			if bonus > 0:
				econ.earn_gold(bonus)
			return bonus

		&"instant_bake":
			# OvenManager entegrasyonu Alpha'da; şimdilik no-op.
			return 0

		&"vip_extend":
			# CustomerOrderSystem entegrasyonu Alpha'da; şimdilik no-op.
			return 0

		&"task_double":
			var base_rozet: int = context.get("base_rozet", 0)
			var bonus: int = int(float(base_rozet) * TASK_REWARD_MULTIPLIER) - base_rozet
			if bonus > 0:
				econ.earn_rozet(bonus)
			return bonus

	return 0


func _reset_availability() -> void:
	for p: StringName in PLACEMENTS:
		if not _ad_available.has(p):
			_ad_available[p] = true  # Varsayılan: stub'da her zaman mevcut


func _is_tutorial_active() -> bool:
	var tut := _get_tutorial()
	if tut:
		return tut.tut_active
	return false


# ── Dependency Getters ────────────────────────────────────────────────────────

func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem


func _get_tutorial() -> TutorialSystem:
	if _tutorial_ref:
		return _tutorial_ref
	return get_node_or_null("/root/TutorialSystem") as TutorialSystem
