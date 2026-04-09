## GUT Test Suite — OvenManager + BakingSlot
## GDD #9 Acceptance Criteria: AC-01 – AC-09
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_oven_manager.gd
extends GutTest

const FAST_BAKE_TIME: float = 0.05   ## Async testler için kısa süre (50ms)
const ASYNC_WAIT: float    = 0.15    ## Timer bitişi için bekleme tamponu

var oven: OvenManager
var economy: EconomySystem
var content: ContentRegistry
var _test_recipe: RecipeData


func before_each() -> void:
	# Economy — READY durumunda başlaması için initialize
	economy = EconomySystem.new()
	add_child(economy)
	economy.initialize(0, 0)

	# ContentRegistry — mock veri enjeksiyonu
	content = ContentRegistry.new()
	add_child(content)
	_test_recipe = RecipeData.new()
	_test_recipe.id = &"test_bread"
	_test_recipe.display_name = "Test Ekmek"
	_test_recipe.bake_time_seconds = FAST_BAKE_TIME
	_test_recipe.base_value = 10
	content._recipes[&"test_bread"] = _test_recipe

	# OvenManager — dependency injection
	oven = OvenManager.new()
	oven._economy_ref = economy
	oven._content_ref = content
	add_child(oven)


func after_each() -> void:
	oven.queue_free()
	economy.queue_free()
	content.queue_free()


# ── Yardımcılar ───────────────────────────────────────────────────────────────

func _slot(index: int) -> BakingSlot:
	return oven._slots[index]


func _make_slot_ready(slot_index: int, gold: int = 10) -> void:
	var slot: BakingSlot = _slot(slot_index)
	slot.recipe_id = &"test_bread"
	slot.bake_time_seconds = FAST_BAKE_TIME
	slot.gold_reward = gold
	slot.state = BakingSlot.State.READY


func _make_slot_baking(slot_index: int) -> void:
	var slot: BakingSlot = _slot(slot_index)
	slot.recipe_id = &"test_bread"
	slot.bake_time_seconds = 60.0
	slot.gold_reward = 10
	slot.bake_start_timestamp = Time.get_unix_time_from_system()
	slot.state = BakingSlot.State.BAKING


# ── AC-01: receive_dough → bake_completed (async) ─────────────────────────────

func test_bake_completed_signal_emitted_after_timer() -> void:
	var signals_received: Array = []
	oven.bake_completed.connect(func(sid, rid): signals_received.append([sid, rid]))

	var result := oven.receive_dough(&"test_bread")
	assert_true(result, "receive_dough EMPTY slotta true döner")
	assert_eq(_slot(0).state, BakingSlot.State.BAKING, "Slot BAKING durumuna geçti")

	await get_tree().create_timer(ASYNC_WAIT).timeout

	assert_eq(signals_received.size(), 1, "bake_completed tam 1 kez emit edildi")
	assert_eq(signals_received[0][1], &"test_bread", "Doğru recipe_id")
	assert_eq(_slot(0).state, BakingSlot.State.READY, "Slot READY durumuna geçti")


# ── receive_dough temel davranışı ─────────────────────────────────────────────

func test_receive_dough_returns_true_for_empty_slot() -> void:
	var result := oven.receive_dough(&"test_bread")
	assert_true(result, "Boş slot → true")


func test_receive_dough_returns_false_when_slot_full() -> void:
	_make_slot_baking(0)
	var result := oven.receive_dough(&"test_bread")
	assert_false(result, "Dolu slot → false")


func test_receive_dough_unknown_recipe_returns_false() -> void:
	var result := oven.receive_dough(&"unknown_bread")
	assert_false(result, "Bilinmeyen tarif → false")
	assert_eq(_slot(0).state, BakingSlot.State.EMPTY, "Slot EMPTY kaldı")


func test_receive_dough_emits_bake_started_signal() -> void:
	var signals: Array = []
	oven.bake_started.connect(func(sid, rid): signals.append([sid, rid]))

	oven.receive_dough(&"test_bread")
	assert_eq(signals.size(), 1, "bake_started emit edildi")
	assert_eq(signals[0][0], 0, "slot_id = 0")
	assert_eq(signals[0][1], &"test_bread", "recipe_id doğru")


# ── AC-02: harvest ────────────────────────────────────────────────────────────

func test_harvest_success_returns_true() -> void:
	_make_slot_ready(0, 15)
	var result := oven.harvest(0)
	assert_true(result, "READY slottan harvest → true")


func test_harvest_calls_earn_gold() -> void:
	_make_slot_ready(0, 25)
	oven.harvest(0)
	assert_eq(economy.gold_balance, 25, "earn_gold doğru miktarla çağrıldı")


func test_harvest_emits_bread_harvested_signal() -> void:
	_make_slot_ready(0, 10)
	var signals: Array = []
	oven.bread_harvested.connect(func(sid, rid, gold): signals.append([sid, rid, gold]))

	oven.harvest(0)
	assert_eq(signals.size(), 1, "bread_harvested emit edildi")
	assert_eq(signals[0][0], 0, "slot_id = 0")
	assert_eq(signals[0][2], 10, "gold_earned = 10")


func test_harvest_resets_slot_to_empty() -> void:
	_make_slot_ready(0)
	oven.harvest(0)
	assert_eq(_slot(0).state, BakingSlot.State.EMPTY, "Slot EMPTY'e döndü")
	assert_eq(_slot(0).recipe_id, &"", "recipe_id sıfırlandı")


# ── AC-03: Dolu slota receive_dough no-op ─────────────────────────────────────

func test_receive_dough_on_baking_slot_is_noop() -> void:
	_make_slot_baking(0)
	var result := oven.receive_dough(&"test_bread")
	assert_false(result, "BAKING slotta receive_dough → false")
	assert_eq(_slot(0).state, BakingSlot.State.BAKING, "Slot state değişmedi")


# ── E-3, E-11: Geçersiz state'te harvest ──────────────────────────────────────

func test_harvest_empty_slot_returns_false() -> void:
	var result := oven.harvest(0)
	assert_false(result, "EMPTY slottan harvest → false")
	assert_eq(economy.gold_balance, 0, "earn_gold çağrılmadı")


func test_harvest_baking_slot_returns_false() -> void:
	_make_slot_baking(0)
	var result := oven.harvest(0)
	assert_false(result, "BAKING slottan harvest → false")
	assert_eq(_slot(0).state, BakingSlot.State.BAKING, "Slot BAKING kaldı")


# ── AC-04: 4 slot bağımsız (async) ───────────────────────────────────────────

func test_four_slots_independent() -> void:
	# Slot 1–3'ü aç
	oven.unlock_slot(1)
	oven.unlock_slot(2)
	oven.unlock_slot(3)
	assert_eq(oven.active_slot_count, 4, "4 slot aktif")

	# 2. recipe (daha uzun bake time)
	var slow_recipe := RecipeData.new()
	slow_recipe.id = &"slow_bread"
	slow_recipe.bake_time_seconds = FAST_BAKE_TIME * 3.0  # 150ms
	slow_recipe.base_value = 20
	content._recipes[&"slow_bread"] = slow_recipe

	var completed: Array = []
	oven.bake_completed.connect(func(sid, rid): completed.append(sid))

	oven.receive_dough(&"test_bread", 0)   # 50ms
	oven.receive_dough(&"slow_bread", 1)   # 150ms
	oven.receive_dough(&"test_bread", 2)   # 50ms
	oven.receive_dough(&"slow_bread", 3)   # 150ms

	# 50ms + buffer → slot 0 ve 2 tamamlanmış olmalı
	await get_tree().create_timer(ASYNC_WAIT).timeout
	assert_true(0 in completed, "Slot 0 tamamlandı")
	assert_true(2 in completed, "Slot 2 tamamlandı")
	assert_false(1 in completed, "Slot 1 henüz tamamlanmadı (150ms)")
	assert_false(3 in completed, "Slot 3 henüz tamamlanmadı (150ms)")

	# 150ms daha bekle → slot 1 ve 3 de tamamlanmalı
	await get_tree().create_timer(ASYNC_WAIT).timeout
	assert_true(1 in completed, "Slot 1 tamamlandı")
	assert_true(3 in completed, "Slot 3 tamamlandı")


# ── AC-05: Offline → slot READY ───────────────────────────────────────────────

func test_offline_elapsed_greater_than_bake_time_sets_ready() -> void:
	var slot := _slot(0)
	slot.recipe_id = &"test_bread"
	slot.bake_time_seconds = 30.0
	slot.gold_reward = 10
	slot.bake_start_timestamp = 1_000_000
	slot.state = BakingSlot.State.BAKING

	slot.apply_offline(45.0, OvenManager.OFFLINE_CAP_SECONDS)

	assert_eq(slot.state, BakingSlot.State.READY, "Elapsed > bake_time → READY")


func test_offline_bake_completed_signal_emitted_when_slot_ready() -> void:
	var slot := _slot(0)
	slot.recipe_id = &"test_bread"
	slot.bake_time_seconds = 30.0
	slot.gold_reward = 10
	slot.state = BakingSlot.State.BAKING

	var signals: Array = []
	oven.bake_completed.connect(func(sid, rid): signals.append(sid))
	slot.apply_offline(45.0, OvenManager.OFFLINE_CAP_SECONDS)

	assert_eq(signals.size(), 1, "bake_completed emit edildi (offline)")


# ── AC-06: Offline → slot BAKING, Timer kalan süreyle yeniden başlar ──────────

func test_offline_elapsed_less_than_bake_time_keeps_baking() -> void:
	var slot := _slot(0)
	slot.recipe_id = &"test_bread"
	slot.bake_time_seconds = 30.0
	slot.gold_reward = 10
	slot.state = BakingSlot.State.BAKING

	slot.apply_offline(15.0, OvenManager.OFFLINE_CAP_SECONDS)

	assert_eq(slot.state, BakingSlot.State.BAKING, "Elapsed < bake_time → hâlâ BAKING")
	assert_true(slot._timer.time_left > 0.0, "Timer çalışıyor")


# ── AC-07: Offline cap kırpma ─────────────────────────────────────────────────

func test_offline_elapsed_clamped_to_cap() -> void:
	var slot := _slot(0)
	slot.recipe_id = &"test_bread"
	slot.bake_time_seconds = 86400.0  # 24h tarif — cap'i aşıyor
	slot.gold_reward = 50
	slot.state = BakingSlot.State.BAKING

	# 100000s inject et → cap = 28800s → remaining = 86400 - 28800 = 57600 > 0 → BAKING kalır
	slot.apply_offline(100000.0, OvenManager.OFFLINE_CAP_SECONDS)

	assert_eq(slot.state, BakingSlot.State.BAKING, "100000s kırpıldı → 28800s → BAKING devam ediyor")
	assert_almost_eq(slot._timer.time_left, 57600.0, 1.0, "Timer kalan süre: 86400 - 28800 = 57600s")


# ── AC-08: unlock_slot → active_slot_count artar ──────────────────────────────

func test_unlock_slot_increases_active_count() -> void:
	assert_eq(oven.active_slot_count, 1, "Başlangıçta 1 slot")
	oven.unlock_slot(1)
	assert_eq(oven.active_slot_count, 2, "unlock_slot(1) → 2 slot")


func test_unlocked_slot_is_usable() -> void:
	oven.unlock_slot(1)
	var result := oven.receive_dough(&"test_bread", 1)
	assert_true(result, "Açılan slot 1 kullanılabilir")


# ── AC-09: unlock_slot üst sınır ──────────────────────────────────────────────

func test_unlock_slot_above_max_is_noop() -> void:
	oven.unlock_slot(1)
	oven.unlock_slot(2)
	oven.unlock_slot(3)
	assert_eq(oven.active_slot_count, 4, "4 slot aktif")
	oven.unlock_slot(4)  # 5. slot — geçersiz
	assert_eq(oven.active_slot_count, 4, "5. slot → no-op; count 4'ü geçmedi")


func test_unlock_slot_at_max_count_is_noop() -> void:
	oven.unlock_slot(1)
	oven.unlock_slot(2)
	oven.unlock_slot(3)
	oven.unlock_slot(3)  # tekrar → no-op
	assert_eq(oven.active_slot_count, 4, "Tekrar unlock → count değişmedi")


# ── AC-10: 4 slot ardışık harvest ────────────────────────────────────────────

func test_four_simultaneous_ready_slots_harvest_correctly() -> void:
	oven.unlock_slot(1)
	oven.unlock_slot(2)
	oven.unlock_slot(3)
	for i in range(4):
		_make_slot_ready(i, 10)

	var total_gold := 0
	var harvested_count := 0
	oven.bread_harvested.connect(func(_sid, _rid, gold): total_gold += gold; harvested_count += 1)

	for i in range(4):
		oven.harvest(i)

	assert_eq(harvested_count, 4, "4 hasat sinyali emit edildi")
	assert_eq(total_gold, 40, "Toplam altın = 4 × 10 = 40")
	assert_eq(economy.gold_balance, 40, "Economy doğru bakiyeye ulaştı")


# ── get_save_data / initialize_from_save ────────────────────────────────────────

func test_get_save_data_captures_slot_state() -> void:
	_make_slot_baking(0)
	_slot(0).bake_start_timestamp = 1234567890
	_slot(0).bake_time_seconds = 60.0
	_slot(0).gold_reward = 10

	var data: Array[Dictionary] = oven.get_save_data()
	assert_eq(data.size(), 1, "1 aktif slot")
	assert_eq(data[0]["slot_id"], 0)
	assert_eq(data[0]["state"], "BAKING")
	assert_eq(data[0]["recipe_id"], &"test_bread")


func test_initialize_from_save_restores_ready_slot() -> void:
	var slot_data: Array[Dictionary] = [{
		"slot_id": 0,
		"state": "READY",
		"recipe_id": &"test_bread",
		"bake_start_timestamp": 1_000_000,
		"bake_time_seconds": 30.0,
		"gold_reward": 15,
	}]
	oven.initialize_from_save(slot_data)
	assert_eq(_slot(0).state, BakingSlot.State.READY, "READY state restore edildi")
	assert_eq(_slot(0).gold_reward, 15, "gold_reward restore edildi")


func test_initialize_from_save_baking_slot_already_done_becomes_ready() -> void:
	var old_timestamp: int = Time.get_unix_time_from_system() - 60  # 60s önce başladı
	var slot_data: Array[Dictionary] = [{
		"slot_id": 0,
		"state": "BAKING",
		"recipe_id": &"test_bread",
		"bake_start_timestamp": old_timestamp,
		"bake_time_seconds": 30.0,  # 30s < 60s elapsed → tamamlanmış
		"gold_reward": 10,
	}]
	oven.initialize_from_save(slot_data)
	assert_eq(_slot(0).state, BakingSlot.State.READY, "Offline tamamlanan slot READY'ye geçti")
