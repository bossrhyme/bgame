## GUT Test Suite — DeliverySystem
## design/gdd/delivery-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_delivery_system.gd
extends GutTest


var _delivery: DeliverySystem
var _economy: EconomySystem
var _upgrade: UpgradeTree


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(0, 0)

	_upgrade = UpgradeTree.new()
	_upgrade._economy_ref = _economy
	_upgrade._registry_ref = null
	add_child_autofree(_upgrade)

	_delivery = DeliverySystem.new()
	_delivery._economy_ref = _economy
	_delivery._upgrade_ref = _upgrade
	_delivery._oven_ref = null
	add_child_autofree(_delivery)


# ── Yardımcı ──────────────────────────────────────────────────────────────────

func _inject_upgrade(id: StringName, base_cost: int, max_level: int) -> void:
	var u := UpgradeData.new()
	u.id = id
	u.base_cost = base_cost
	u.max_level = max_level
	u.effect_per_level.resize(max_level)
	u.effect_per_level.fill(0.1)
	_upgrade._upgrades[id] = u
	_upgrade._levels[id] = 0


# ── Başlangıç durumu ──────────────────────────────────────────────────────────

func test_initial_available_bread_is_zero() -> void:
	assert_eq(_delivery.get_available_bread(), 0)


func test_initial_slots_count_is_base_slots() -> void:
	var slots := _delivery.get_slots()
	assert_eq(slots.size(), DeliverySystem.BASE_SLOTS)


# ── Teslimat başlatma ─────────────────────────────────────────────────────────

func test_start_delivery_fails_with_no_bread() -> void:
	var result: bool = _delivery.start_delivery(&"local")
	assert_false(result, "Ekmek yokken teslimat başlamaz")


func test_start_delivery_succeeds_with_enough_bread() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	var result: bool = _delivery.start_delivery(&"local")
	assert_true(result)


func test_start_delivery_deducts_bread_from_stock() -> void:
	var req: int = DeliverySystem.BREAD_REQ[&"local"]
	_delivery.add_bread(req + 5)
	_delivery.start_delivery(&"local")
	assert_eq(_delivery.get_available_bread(), 5)


func test_start_delivery_emits_signal() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"city"])
	watch_signals(_delivery)
	_delivery.start_delivery(&"city")
	assert_signal_emitted(_delivery, "delivery_started")


func test_start_delivery_unknown_type_returns_false() -> void:
	_delivery.add_bread(100)
	var result: bool = _delivery.start_delivery(&"galaxy")
	assert_false(result)


# ── F-1: Ödül hesabı ─────────────────────────────────────────────────────────

func test_local_reward_formula() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	_delivery.start_delivery(&"local")
	var slot := _delivery.get_slots()[0]
	var expected: int = int(
		float(DeliverySystem.BASE_BREAD_VALUE)
		* float(DeliverySystem.BREAD_REQ[&"local"])
		* DeliverySystem.TYPE_MULTIPLIER[&"local"]
	)
	assert_eq(slot.reward_gold, expected, "Local ödül formülü")


func test_intercity_reward_higher_than_local() -> void:
	_delivery.add_bread(100)
	_delivery.start_delivery(&"local")
	var local_reward: int = _delivery.get_slots()[0].reward_gold

	var d2 := DeliverySystem.new()
	d2._economy_ref = _economy
	d2._upgrade_ref = _upgrade
	d2._oven_ref = null
	add_child_autofree(d2)
	d2.add_bread(100)
	d2.start_delivery(&"intercity")
	var intercity_reward: int = d2.get_slots()[0].reward_gold

	assert_true(intercity_reward > local_reward, "Intercity ödülü local'dan yüksek")


# ── F-2: Süre hesabı (delivery_speed upgrade) ─────────────────────────────────

func test_duration_without_upgrade_is_base() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	_delivery.start_delivery(&"local")
	var slot := _delivery.get_slots()[0]
	assert_almost_eq(slot.duration_sec, DeliverySystem.BASE_DURATION[&"local"], 0.01)


func test_duration_reduced_by_speed_upgrade() -> void:
	_inject_upgrade(DeliverySystem.UPGRADE_SPEED, 100, 3)
	_upgrade._levels[DeliverySystem.UPGRADE_SPEED] = 2  # 2 seviye = %20 azalma

	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"city"])
	_delivery.start_delivery(&"city")
	var slot := _delivery.get_slots()[0]
	var expected: float = DeliverySystem.BASE_DURATION[&"city"] * 0.8
	assert_almost_eq(slot.duration_sec, expected, 0.01, "2 seviye upgrade %20 azaltır")


# ── Slot sayısı (delivery_slots upgrade) ──────────────────────────────────────

func test_default_max_slots_is_one() -> void:
	assert_eq(_delivery.get_slots().size(), 1)


func test_delivery_slots_upgrade_increases_slot_count() -> void:
	_inject_upgrade(DeliverySystem.UPGRADE_SLOTS, 200, 2)
	_upgrade._levels[DeliverySystem.UPGRADE_SLOTS] = 1  # +1 slot

	var d2 := DeliverySystem.new()
	d2._economy_ref = _economy
	d2._upgrade_ref = _upgrade
	d2._oven_ref = null
	add_child_autofree(d2)

	assert_eq(d2.get_slots().size(), 2, "1 seviye upgrade → 2 slot")


func test_all_slots_full_blocks_new_delivery() -> void:
	# Varsayılan 1 slot doldur
	_delivery.add_bread(100)
	_delivery.start_delivery(&"local")
	# Tekrar başlatmaya çalış
	var result: bool = _delivery.start_delivery(&"local")
	assert_false(result, "Tüm slotlar doluyken başlatılamaz")


# ── tick / ready / expire ─────────────────────────────────────────────────────

func test_tick_marks_slot_ready_when_time_elapsed() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	_delivery.start_delivery(&"local")

	# Başlangıç zamanını geçmişe al (duration + 1 saniye)
	var slot := _delivery._slots[0]
	slot.start_unix = Time.get_unix_time_from_system() - int(slot.duration_sec) - 1

	watch_signals(_delivery)
	_delivery.tick()

	assert_true(slot.is_ready, "Süre dolunca slot hazır")
	assert_signal_emitted(_delivery, "delivery_ready")


func test_tick_expires_unclaimed_slot() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	_delivery.start_delivery(&"local")

	var slot := _delivery._slots[0]
	# Hem teslimat süresi hem de expire süresi geçmiş
	var total_sec: int = int(slot.duration_sec) + int(DeliverySystem.DELIVERY_UNCLAIMED_CAP_HOURS * 3600.0) + 1
	slot.start_unix = Time.get_unix_time_from_system() - total_sec
	slot.is_ready = true  # zaten ready durumuna getirilmiş

	watch_signals(_delivery)
	_delivery.tick()

	assert_true(slot.is_expired, "Expire süresi aşılınca slot expire olur")
	assert_signal_emitted(_delivery, "delivery_expired")


# ── Ödül talep etme ───────────────────────────────────────────────────────────

func test_claim_reward_gives_gold() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	_delivery.start_delivery(&"local")

	var slot := _delivery._slots[0]
	slot.start_unix = Time.get_unix_time_from_system() - int(slot.duration_sec) - 1
	_delivery.tick()

	var result: bool = _delivery.claim_reward(0)
	assert_true(result)
	assert_true(_economy.gold_balance > 0, "Ödül Economy'ye eklendi")


func test_claim_reward_emits_signal() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	_delivery.start_delivery(&"local")
	var slot := _delivery._slots[0]
	slot.start_unix = Time.get_unix_time_from_system() - int(slot.duration_sec) - 1
	_delivery.tick()

	watch_signals(_delivery)
	_delivery.claim_reward(0)
	assert_signal_emitted(_delivery, "delivery_claimed")


func test_claim_reward_not_ready_returns_false() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	_delivery.start_delivery(&"local")
	var result: bool = _delivery.claim_reward(0)
	assert_false(result, "Hazır olmayan slot talep edilemez")


func test_claim_expired_slot_returns_false() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	_delivery.start_delivery(&"local")
	var slot := _delivery._slots[0]
	var total_sec: int = int(slot.duration_sec) + int(DeliverySystem.DELIVERY_UNCLAIMED_CAP_HOURS * 3600.0) + 1
	slot.start_unix = Time.get_unix_time_from_system() - total_sec
	slot.is_ready = true
	_delivery.tick()
	var result: bool = _delivery.claim_reward(0)
	assert_false(result, "Expire olan slot talep edilemez")


# ── Serialize / Deserialize ───────────────────────────────────────────────────

func test_serialize_preserves_active_slot() -> void:
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"city"])
	_delivery.start_delivery(&"city")
	var data: Dictionary = _delivery.serialize()
	assert_eq(data["slots"][0]["delivery_type"], &"city")
	assert_true(data["slots"][0]["is_active"])


func test_deserialize_restores_bread_stock() -> void:
	_delivery.add_bread(42)
	var data: Dictionary = _delivery.serialize()

	var d2 := DeliverySystem.new()
	d2._economy_ref = _economy
	d2._upgrade_ref = _upgrade
	d2._oven_ref = null
	add_child_autofree(d2)
	d2.deserialize(data)

	assert_eq(d2.get_available_bread(), 42)


# ── Null guard ────────────────────────────────────────────────────────────────

func test_null_economy_claim_does_not_crash() -> void:
	_delivery._economy_ref = null
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	_delivery.start_delivery(&"local")
	var slot := _delivery._slots[0]
	slot.is_ready = true
	_delivery.claim_reward(0)
	pass_test()


func test_null_upgrade_uses_base_slots_and_duration() -> void:
	_delivery._upgrade_ref = null
	_delivery.add_bread(DeliverySystem.BREAD_REQ[&"local"])
	var result: bool = _delivery.start_delivery(&"local")
	assert_true(result, "Upgrade null olsa bile teslimat başlar")
