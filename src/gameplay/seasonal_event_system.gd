## SeasonalEventSystem — Takvime Bağlı Sınırlı Süreli Etkinlikler
##
## Gerçek UTC tarihlere bağlı etkinlikler gold multiplier, görev ve tarif bonusu sağlar.
## Anti-FOMO: etkinlik bonusları ana ilerlemeyi engellemez; offline üretim bonusu almaz.
##
## apply_gold_bonus(raw) → final_gold hesabı bu sistem tarafından yapılır;
## diğer sistemler Economy.earn_gold() yerine bu metodu çağırır.
##
## GDD: design/gdd/seasonal-events-system.md
class_name SeasonalEventSystem
extends Node

## Yeni bir etkinlik başladı.
signal event_started(event_id: StringName)
## Bir etkinlik sona erdi.
signal event_ended(event_id: StringName)
## Etkinlik tamamlama rozeti kazanıldı.
signal event_rozet_earned(event_id: StringName, rozet: int)

# ── Etkinlik Verisi ───────────────────────────────────────────────────────────

class EventEntry:
	extends RefCounted
	var event_id: StringName = &""
	var start_unix: int = 0
	var end_unix: int = 0
	var gold_bonus_multiplier: float = 1.0
	var event_recipe_id: StringName = &""
	var rozet_reward: int = 0
	var rozet_claimed: bool = false

## 2026-2027 Türkiye/global etkinlik takvimi (UTC unix timestamp).
## 1970-01-01 00:00:00 UTC + günler × 86400
## Ramazan 2026: ~26 Feb – 27 Mar (29 gün)
## Kurban Bayramı 2026: ~5-9 Jun
## Yeni Yıl 2026/2027: 31 Dec – 2 Jan
## Cumhuriyet Bayramı: 29 Oct
const _EVENT_DEFINITIONS: Array = [
	# [event_id, start_unix, end_unix, multiplier, recipe_id, rozet_reward]
	[&"ramazan_2026",    1740528000, 1743033600, 1.5, &"",              5],   # 26 Feb – 23 Mar 2026
	[&"eid_al_fitr_2026",1743033600, 1743292800, 2.0, &"seker_bayram_pogacasi", 10],  # 27-29 Mar 2026
	[&"eid_al_adha_2026",1749081600, 1749427200, 2.0, &"bayram_corbasi", 10],  # 5-9 Jun 2026
	[&"republic_day_2026",1761696000,1761782400, 1.25,&"baget",         3],   # 29 Oct 2026
	[&"new_year_2027",   1767225600, 1767484800, 1.5, &"galeta",        5],   # 31 Dec 2026 – 2 Jan 2027
]

# ── State ──────────────────────────────────────────────────────────────────────

var _events: Array[EventEntry] = []
## Aktif olduğu tespit edilen ve sinyali gönderilmiş etkinlikler.
var _signaled_start: Dictionary = {}   # StringName → bool
## Son kontrol zamanı — bitiş tespiti için.
var _last_check_unix: int = 0
## Etkinlik tarifleri açıldı mı (kalıcı).
var _unlocked_recipes: Dictionary = {}  # StringName → bool

# ── Dependency injection ──────────────────────────────────────────────────────

var _economy_ref: EconomySystem = null
var _recipe_ref: RecipeManager = null
var _notif_ref: NotificationManager = null


func _ready() -> void:
	_build_events()
	_check_events()
	_schedule_check()


# ── Public API ────────────────────────────────────────────────────────────────

## F-2: Etkinlik aktif mi?
func is_active(event_id: StringName) -> bool:
	var now: int = Time.get_unix_time_from_system()
	for e: EventEntry in _events:
		if e.event_id == event_id:
			return now >= e.start_unix and now < e.end_unix
	return false


## F-1: Aktif tüm etkinliklerin gold çarpanlarının çarpımı.
func get_active_multiplier() -> float:
	var now: int = Time.get_unix_time_from_system()
	var combined: float = 1.0
	for e: EventEntry in _events:
		if now >= e.start_unix and now < e.end_unix:
			combined *= e.gold_bonus_multiplier
	return combined


## Etkinlik bonusuyla gold kazandır. Economy.earn_gold() yerine bu çağrılır.
## Offline üretim hesabı bu fonksiyondan geçMEZ (kasıtlı — GDD §Edge Cases).
func earn_gold_with_bonus(raw_gold: int) -> void:
	if raw_gold <= 0:
		return
	var econ := _get_economy()
	if not econ:
		push_error("SeasonalEventSystem: Economy bulunamadı")
		return
	var multiplier: float = get_active_multiplier()
	var final_gold: int = int(float(raw_gold) * multiplier)
	econ.earn_gold(final_gold)


## Etkinlik rozet ödülünü talep et. Başarılıysa true.
func claim_event_rozet(event_id: StringName) -> bool:
	for e: EventEntry in _events:
		if e.event_id != event_id:
			continue
		if e.rozet_claimed or e.rozet_reward <= 0:
			return false
		var econ := _get_economy()
		if not econ:
			push_error("SeasonalEventSystem: Economy bulunamadı — rozet verilemedi")
			return false
		econ.earn_rozet(e.rozet_reward)
		e.rozet_claimed = true
		event_rozet_earned.emit(event_id, e.rozet_reward)
		return true
	return false


## Aktif etkinlik listesi (UI için).
func get_active_events() -> Array[EventEntry]:
	var now: int = Time.get_unix_time_from_system()
	var result: Array[EventEntry] = []
	for e: EventEntry in _events:
		if now >= e.start_unix and now < e.end_unix:
			result.append(e)
	return result


func serialize() -> Dictionary:
	var claimed: Dictionary = {}
	for e: EventEntry in _events:
		if e.rozet_claimed:
			claimed[e.event_id] = true
	return {
		"rozet_claimed":    claimed,
		"unlocked_recipes": _unlocked_recipes.duplicate(),
		"signaled_start":   _signaled_start.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	var claimed: Dictionary = data.get("rozet_claimed", {})
	for e: EventEntry in _events:
		e.rozet_claimed = claimed.get(e.event_id, false)
	_unlocked_recipes = data.get("unlocked_recipes", {})
	_signaled_start = data.get("signaled_start", {})


# ── Internal ──────────────────────────────────────────────────────────────────

func _build_events() -> void:
	_events.clear()
	for def: Array in _EVENT_DEFINITIONS:
		var e := EventEntry.new()
		e.event_id             = def[0]
		e.start_unix           = def[1]
		e.end_unix             = def[2]
		e.gold_bonus_multiplier = def[3]
		e.event_recipe_id      = def[4]
		e.rozet_reward         = def[5]
		_events.append(e)


func _check_events() -> void:
	var now: int = Time.get_unix_time_from_system()
	for e: EventEntry in _events:
		var active: bool = now >= e.start_unix and now < e.end_unix

		# Yeni başladı
		if active and not _signaled_start.get(e.event_id, false):
			_signaled_start[e.event_id] = true
			event_started.emit(e.event_id)
			_notify("Etkinlik başladı: %s! Bonus altın kazanıyorsun." % e.event_id,
				NotificationManager.Priority.INFO)
			_try_unlock_recipe(e)

		# Bitti (önceden aktifti)
		if not active and _signaled_start.get(e.event_id, false) and _last_check_unix > 0:
			if _last_check_unix >= e.start_unix and _last_check_unix < e.end_unix:
				event_ended.emit(e.event_id)

	_last_check_unix = now


func _try_unlock_recipe(e: EventEntry) -> void:
	if e.event_recipe_id == &"":
		return
	if _unlocked_recipes.get(e.event_recipe_id, false):
		return
	var recipe_mgr := _get_recipe()
	if recipe_mgr:
		recipe_mgr.unlock(e.event_recipe_id)
		_unlocked_recipes[e.event_recipe_id] = true


func _schedule_check() -> void:
	var tree := get_tree()
	if not tree:
		return
	# 60 dakikada bir kontrol (ADR-0003: _process yasak)
	tree.create_timer(3600.0).timeout.connect(_on_check_timeout, CONNECT_ONE_SHOT)


func _on_check_timeout() -> void:
	_check_events()
	_schedule_check()


func _notify(msg: String, priority: NotificationManager.Priority) -> void:
	var notif := _get_notif()
	if notif:
		notif.queue_notification(msg, priority)


# ── Dependency Getters ────────────────────────────────────────────────────────

func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem


func _get_recipe() -> RecipeManager:
	if _recipe_ref:
		return _recipe_ref
	return get_node_or_null("/root/RecipeManager") as RecipeManager


func _get_notif() -> NotificationManager:
	if _notif_ref:
		return _notif_ref
	return get_node_or_null("/root/NotificationManager") as NotificationManager
