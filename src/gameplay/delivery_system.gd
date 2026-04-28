## DeliverySystem — Toplu Teslimat Pasif Gelir Kanalı
##
## Oyuncu toplu ekmek gönderir; timer dolunca ödülü talep eder.
## Üç teslimat türü: local (2 dk), city (10 dk), intercity (1 saat).
## Upgrade entegrasyonu: delivery_speed (süre azaltma), delivery_slots (slot sayısı).
##
## Mimari kuralları (ADR-0003):
##   - _process() yasak; SceneTreeTimer bazlı tick (60s aralık)
##   - Timer: unix timestamp; offline süre geçse bile doğru hesaplanır
##   - Expire: 4 saatlik talep penceresi; DELIVERY_UNCLAIMED_CAP_HOURS
##
## GDD: design/gdd/delivery-system.md
class_name DeliverySystem
extends Node

## Teslimat tamamlandığında (talep bekleniyor).
signal delivery_ready(slot_idx: int, reward_gold: int)
## Teslimat expire olduğunda.
signal delivery_expired(slot_idx: int)
## Teslimat başlatıldığında.
signal delivery_started(slot_idx: int, delivery_type: StringName, duration_sec: float)
## Ödül talep edildiğinde.
signal delivery_claimed(slot_idx: int, gold_earned: int)

# ── Sabitler ──────────────────────────────────────────────────────────────────

const BASE_SLOTS: int = 1
const DELIVERY_UNCLAIMED_CAP_HOURS: float = 4.0
const TICK_INTERVAL_SEC: float = 60.0
const SPEED_REDUCTION_PER_LEVEL: float = 0.1

const BASE_DURATION: Dictionary = {
	&"local":      120.0,
	&"city":       600.0,
	&"intercity": 3600.0,
}

const TYPE_MULTIPLIER: Dictionary = {
	&"local":     1.0,
	&"city":      2.5,
	&"intercity": 8.0,
}

const BREAD_REQ: Dictionary = {
	&"local":      5,
	&"city":      15,
	&"intercity": 50,
}

## Upgrade ID'leri — UpgradeTree'deki tanımla eşleşmeli.
const UPGRADE_SPEED: StringName  = &"delivery_speed"
const UPGRADE_SLOTS: StringName  = &"delivery_slots"

## Ekmek pişirme başına kazanılan ortalama altın değeri (F-1 hesabı için).
const BASE_BREAD_VALUE: int = 5

# ── Slot ──────────────────────────────────────────────────────────────────────

class DeliverySlot:
	extends RefCounted
	var delivery_type: StringName = &""
	var start_unix: int = 0
	var duration_sec: float = 0.0
	var bread_count: int = 0
	var reward_gold: int = 0
	var is_active: bool = false
	var is_ready: bool = false      # süre doldu, talep bekleniyor
	var is_expired: bool = false
	var reward_claimed: bool = false

# ── State ──────────────────────────────────────────────────────────────────────

var _slots: Array[DeliverySlot] = []
var _available_bread: int = 0
var _tick_timer: SceneTreeTimer = null

# ── Dependency injection ──────────────────────────────────────────────────────

var _economy_ref: EconomySystem = null
var _upgrade_ref: UpgradeTree = null
var _oven_ref: OvenManager = null


func _ready() -> void:
	_init_slots()
	_wire_signals()
	_schedule_tick()


# ── Public API ────────────────────────────────────────────────────────────────

## Teslimat başlat. Başarılıysa true.
func start_delivery(delivery_type: StringName) -> bool:
	if not BASE_DURATION.has(delivery_type):
		push_warning("DeliverySystem: Bilinmeyen teslimat türü '%s'" % delivery_type)
		return false

	var slot_idx: int = _find_free_slot()
	if slot_idx == -1:
		return false  # Tüm slotlar dolu

	var required: int = BREAD_REQ.get(delivery_type, 0)
	if _available_bread < required:
		return false  # Yetersiz ekmek

	_available_bread -= required

	var slot: DeliverySlot = _slots[slot_idx]
	slot.delivery_type = delivery_type
	slot.start_unix = Time.get_unix_time_from_system()
	slot.bread_count = required
	slot.duration_sec = _compute_duration(delivery_type)
	slot.reward_gold = _compute_reward(delivery_type)
	slot.is_active = true
	slot.is_ready = false
	slot.is_expired = false
	slot.reward_claimed = false

	delivery_started.emit(slot_idx, delivery_type, slot.duration_sec)
	return true


## Hazır teslimatı talep et. Başarılıysa ödül eklenir ve true döner.
func claim_reward(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= _slots.size():
		return false
	var slot: DeliverySlot = _slots[slot_idx]
	if not slot.is_ready or slot.is_expired or slot.reward_claimed:
		return false

	var econ := _get_economy()
	if not econ:
		push_error("DeliverySystem: Economy bulunamadı — ödül verilemedi")
		return false

	econ.earn_gold(slot.reward_gold)
	slot.reward_claimed = true
	slot.is_active = false
	slot.is_ready = false
	delivery_claimed.emit(slot_idx, slot.reward_gold)
	return true


## Mevcut slot durumlarını döner (UI için).
func get_slots() -> Array[DeliverySlot]:
	return _slots.duplicate()


## Kullanılabilir ekmek stoku (test / UI için).
func get_available_bread() -> int:
	return _available_bread


## Stok manuel ekleme (OvenManager bağlantısı yoksa test için).
func add_bread(count: int) -> void:
	_available_bread += count


## Tüm slotlarda expire/ready durumu kontrol edilir.
func tick() -> void:
	var now: int = Time.get_unix_time_from_system()
	var unclaimed_cap_sec: float = DELIVERY_UNCLAIMED_CAP_HOURS * 3600.0

	for i: int in range(_slots.size()):
		var slot: DeliverySlot = _slots[i]
		if not slot.is_active:
			continue
		if slot.reward_claimed:
			continue

		var elapsed: float = maxf(float(now - slot.start_unix), 0.0)

		if not slot.is_ready:
			if elapsed >= slot.duration_sec:
				slot.is_ready = true
				delivery_ready.emit(i, slot.reward_gold)
		else:
			# Teslim hazır ama talep edilmedi — expire kontrolü
			var ready_elapsed: float = elapsed - slot.duration_sec
			if ready_elapsed >= unclaimed_cap_sec:
				slot.is_expired = true
				slot.is_active = false
				delivery_expired.emit(i)


## Serialize / Deserialize ──────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var slots_data: Array = []
	for slot: DeliverySlot in _slots:
		slots_data.append({
			"delivery_type":   slot.delivery_type,
			"start_unix":      slot.start_unix,
			"duration_sec":    slot.duration_sec,
			"bread_count":     slot.bread_count,
			"reward_gold":     slot.reward_gold,
			"is_active":       slot.is_active,
			"is_ready":        slot.is_ready,
			"is_expired":      slot.is_expired,
			"reward_claimed":  slot.reward_claimed,
		})
	return {
		"slots":           slots_data,
		"available_bread": _available_bread,
	}


func deserialize(data: Dictionary) -> void:
	_available_bread = data.get("available_bread", 0)
	var slots_data: Array = data.get("slots", [])
	_slots.clear()
	_init_slots()  # max_slots sayısına göre yeniden oluştur
	for i: int in range(mini(slots_data.size(), _slots.size())):
		var entry: Dictionary = slots_data[i]
		var slot: DeliverySlot = _slots[i]
		slot.delivery_type  = entry.get("delivery_type", &"")
		slot.start_unix     = entry.get("start_unix", 0)
		slot.duration_sec   = entry.get("duration_sec", 0.0)
		slot.bread_count    = entry.get("bread_count", 0)
		slot.reward_gold    = entry.get("reward_gold", 0)
		slot.is_active      = entry.get("is_active", false)
		slot.is_ready       = entry.get("is_ready", false)
		slot.is_expired     = entry.get("is_expired", false)
		slot.reward_claimed = entry.get("reward_claimed", false)
	# Yüklenmiş slotlar için expired/ready durumunu hemen kontrol et
	tick()


# ── Internal ──────────────────────────────────────────────────────────────────

func _init_slots() -> void:
	_slots.clear()
	for _i: int in range(_max_slots()):
		_slots.append(DeliverySlot.new())


func _wire_signals() -> void:
	var oven := _get_oven()
	if oven:
		oven.bread_harvested.connect(_on_bread_harvested)
	else:
		push_warning("DeliverySystem: OvenManager bağlanamadı — ekmek stoku otomatik güncellenemez")


func _on_bread_harvested(_slot_id: int, _recipe_id: StringName, _gold: int) -> void:
	_available_bread += 1


func _schedule_tick() -> void:
	var tree := get_tree()
	if not tree:
		return
	_tick_timer = tree.create_timer(TICK_INTERVAL_SEC)
	_tick_timer.timeout.connect(_on_tick_timeout, CONNECT_ONE_SHOT)


func _on_tick_timeout() -> void:
	tick()
	_schedule_tick()


func _find_free_slot() -> int:
	for i: int in range(_slots.size()):
		if not _slots[i].is_active:
			return i
	return -1


func _max_slots() -> int:
	var upgrade := _get_upgrade()
	if not upgrade:
		return BASE_SLOTS
	return BASE_SLOTS + upgrade.get_current_level(UPGRADE_SLOTS)


func _compute_duration(delivery_type: StringName) -> float:
	var base: float = BASE_DURATION.get(delivery_type, 120.0)
	var speed_level: int = 0
	var upgrade := _get_upgrade()
	if upgrade:
		speed_level = upgrade.get_current_level(UPGRADE_SPEED)
	var reduction: float = float(speed_level) * SPEED_REDUCTION_PER_LEVEL
	return base * maxf(1.0 - reduction, 0.0)


func _compute_reward(delivery_type: StringName) -> int:
	var bread_count: int = BREAD_REQ.get(delivery_type, 0)
	var multiplier: float = TYPE_MULTIPLIER.get(delivery_type, 1.0)
	var speed_level: int = 0
	var upgrade := _get_upgrade()
	if upgrade:
		speed_level = upgrade.get_current_level(UPGRADE_SPEED)
	# delivery_speed_bonus iskelet — şu an 1.0 (gelecek upgrade efekti)
	@warning_ignore("unused_variable")
	var speed_bonus: float = 1.0
	return int(float(BASE_BREAD_VALUE) * float(bread_count) * multiplier)


# ── Dependency Getters ────────────────────────────────────────────────────────

func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem


func _get_upgrade() -> UpgradeTree:
	if _upgrade_ref:
		return _upgrade_ref
	return get_node_or_null("/root/UpgradeTree") as UpgradeTree


func _get_oven() -> OvenManager:
	if _oven_ref:
		return _oven_ref
	return get_node_or_null("/root/OvenManager") as OvenManager
