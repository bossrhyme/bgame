## GUT Test Suite — Offline Production System
## design/gdd/offline-production-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_offline_production.gd
extends GutTest


# ── apply_offline (BakingSlot) ────────────────────────────────────────────────

var slot: BakingSlot


func before_each() -> void:
	slot = BakingSlot.new()
	slot.slot_id = 0
	add_child(slot)


func after_each() -> void:
	if is_instance_valid(slot):
		slot.queue_free()


func _set_baking(bake_time: float, gold: int = 100) -> void:
	slot.recipe_id = &"ekmek"
	slot.bake_time_seconds = bake_time
	slot.gold_reward = gold
	slot.bake_start_timestamp = Time.get_unix_time_from_system()
	slot.state = BakingSlot.State.BAKING


# ── AC: 8h offline → READY ───────────────────────────────────────────────────

func test_apply_offline_8h_completes_60s_recipe() -> void:
	# Arrange
	_set_baking(60.0)

	# Act: 8 saat (28800s) geçti
	slot.apply_offline(28800.0, 28800.0, 1.0)

	# Assert
	assert_eq(slot.state, BakingSlot.State.READY, "8h offline → 60s tarif tamamlandı")


func test_apply_offline_exact_bake_time_completes() -> void:
	# Arrange
	_set_baking(300.0)

	# Act: tam süre geçti
	slot.apply_offline(300.0, 28800.0, 1.0)

	# Assert
	assert_eq(slot.state, BakingSlot.State.READY, "Tam süre = tamamlandı")


func test_apply_offline_insufficient_time_stays_baking() -> void:
	# Arrange: 300s tarif, 200s geçti
	_set_baking(300.0)

	# Act
	slot.apply_offline(200.0, 28800.0, 1.0)

	# Assert
	assert_eq(slot.state, BakingSlot.State.BAKING, "Yetersiz süre → hâlâ BAKING")


# ── AC: elapsed=0 → değişiklik yok ──────────────────────────────────────────

func test_apply_offline_zero_elapsed_no_change() -> void:
	# Arrange
	_set_baking(300.0)

	# Act
	slot.apply_offline(0.0, 28800.0, 1.0)

	# Assert
	assert_eq(slot.state, BakingSlot.State.BAKING, "Elapsed=0 → slot değişmez")


# ── AC: Negatif elapsed → güvenli (anti-cheat) ───────────────────────────────

func test_apply_offline_negative_elapsed_clamped_to_zero() -> void:
	# Arrange
	_set_baking(300.0)

	# Act: negatif değer (saat geri alındı)
	slot.apply_offline(-3600.0, 28800.0, 1.0)

	# Assert: clamp ile 0 → slot ilerlemiyor
	assert_eq(slot.state, BakingSlot.State.BAKING, "Negatif elapsed → BAKING devam")


# ── AC: Fırın Ustası speed_multiplier ────────────────────────────────────────

func test_apply_offline_speed_multiplier_shortens_effective_time() -> void:
	# Arrange: 300s tarif, speed=1.4 → effective=214.3s
	# elapsed=215s → effective_bake > elapsed → READY
	_set_baking(300.0)

	# Act
	slot.apply_offline(215.0, 28800.0, 1.4)

	# Assert: 300/1.4 ≈ 214.3 < 215 → READY
	assert_eq(slot.state, BakingSlot.State.READY,
		"speed=1.4: 300s tarif, 215s ile tamamlandı")


func test_apply_offline_speed_multiplier_1_unchanged() -> void:
	# speed=1.0 → effective_time == bake_time_seconds (referans)
	_set_baking(300.0)
	slot.apply_offline(299.0, 28800.0, 1.0)
	assert_eq(slot.state, BakingSlot.State.BAKING,
		"speed=1.0, elapsed=299s < 300s → hâlâ BAKING")


func test_apply_offline_employee_bonus_below_threshold_still_baking() -> void:
	# speed=1.4: effective = 300/1.4 ≈ 214.3s; elapsed=213s → BAKING
	_set_baking(300.0)
	slot.apply_offline(213.0, 28800.0, 1.4)
	assert_eq(slot.state, BakingSlot.State.BAKING,
		"speed=1.4, elapsed=213s < 214.3 → hâlâ BAKING")


# ── AC: EMPTY ve READY slotlar apply_offline'dan etkilenmez ──────────────────

func test_apply_offline_empty_slot_no_op() -> void:
	# EMPTY slot
	slot.apply_offline(28800.0, 28800.0, 1.0)
	assert_eq(slot.state, BakingSlot.State.EMPTY, "EMPTY slot → değişmez")


func test_apply_offline_ready_slot_no_op() -> void:
	# READY slot
	_set_baking(60.0)
	slot.state = BakingSlot.State.READY
	slot.apply_offline(28800.0, 28800.0, 1.0)
	assert_eq(slot.state, BakingSlot.State.READY, "READY slot → değişmez")


# ── AC: Cap zorunluluğu ───────────────────────────────────────────────────────

func test_apply_offline_cap_limits_elapsed() -> void:
	# 300s tarif; elapsed=999999 ama cap=28800
	# clamped=28800 > 300 → READY
	_set_baking(300.0)
	slot.apply_offline(999999.0, 28800.0, 1.0)
	assert_eq(slot.state, BakingSlot.State.READY, "Cap sonrası elapsed > bake_time → READY")


func test_apply_offline_beyond_cap_does_not_crash() -> void:
	# Büyük değer → crash yok
	_set_baking(100.0)
	slot.apply_offline(1000000.0, 28800.0, 1.0)
	pass  # assert_no_crash yok; test tamamlanması yeterli


# ── OvenManager entegrasyonu ─────────────────────────────────────────────────

func test_oven_manager_passes_speed_multiplier_to_apply_offline() -> void:
	# Arrange: OvenManager'a BAKING slot verisi ver; speed_multiplier ile başlat
	var oven := OvenManager.new()
	add_child(oven)

	var now_unix: int = Time.get_unix_time_from_system()
	var start_ts: int = now_unix - 215  # 215s önce başladı

	var slot_data: Array[Dictionary] = [{
		"slot_id": 0,
		"state": "BAKING",
		"recipe_id": &"ekmek",
		"bake_start_timestamp": start_ts,
		"bake_time_seconds": 300.0,  # 300/1.4 ≈ 214.3 < 215 → READY
		"gold_reward": 100,
	}]

	# Act: Fırın Ustası Sev.2 efekti (speed=1.4)
	oven.initialize_from_save(slot_data, 1.4)

	# Assert
	assert_eq(oven._slots[0].state, BakingSlot.State.READY,
		"OvenManager speed_multiplier=1.4 ile 215s → READY")
	oven.queue_free()


func test_oven_manager_default_speed_multiplier_1() -> void:
	# speed_multiplier varsayılanı 1.0 — mevcut testlerle geriye dönük uyumlu
	var oven := OvenManager.new()
	add_child(oven)

	var now_unix: int = Time.get_unix_time_from_system()
	var start_ts: int = now_unix - 299  # 299s önce; 300s tarif → hâlâ BAKING

	var slot_data: Array[Dictionary] = [{
		"slot_id": 0,
		"state": "BAKING",
		"recipe_id": &"ekmek",
		"bake_start_timestamp": start_ts,
		"bake_time_seconds": 300.0,
		"gold_reward": 100,
	}]

	oven.initialize_from_save(slot_data)  # speed_multiplier varsayılan 1.0

	assert_eq(oven._slots[0].state, BakingSlot.State.BAKING,
		"Varsayılan speed=1.0, elapsed=299s < 300s → BAKING")
	oven.queue_free()
