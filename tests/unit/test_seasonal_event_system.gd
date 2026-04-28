## GUT Test Suite — SeasonalEventSystem
## design/gdd/seasonal-events-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_seasonal_event_system.gd
extends GutTest


var _seasonal: SeasonalEventSystem
var _economy: EconomySystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(0, 0)

	_seasonal = SeasonalEventSystem.new()
	_seasonal._economy_ref = _economy
	_seasonal._recipe_ref = null
	_seasonal._notif_ref = null
	add_child_autofree(_seasonal)


# ── Yardımcı ──────────────────────────────────────────────────────────────────

func _inject_event(id: StringName, start_offset_sec: int, end_offset_sec: int,
		multiplier: float = 1.5, rozet: int = 5) -> void:
	var now: int = Time.get_unix_time_from_system()
	var e := SeasonalEventSystem.EventEntry.new()
	e.event_id              = id
	e.start_unix            = now + start_offset_sec
	e.end_unix              = now + end_offset_sec
	e.gold_bonus_multiplier = multiplier
	e.event_recipe_id       = &""
	e.rozet_reward          = rozet
	_seasonal._events.append(e)


# ── F-2: is_active ────────────────────────────────────────────────────────────

func test_is_active_true_when_within_window() -> void:
	_inject_event(&"test_active", -100, 3600)
	assert_true(_seasonal.is_active(&"test_active"))


func test_is_active_false_before_start() -> void:
	_inject_event(&"test_future", 3600, 7200)
	assert_false(_seasonal.is_active(&"test_future"))


func test_is_active_false_after_end() -> void:
	_inject_event(&"test_past", -7200, -100)
	assert_false(_seasonal.is_active(&"test_past"))


func test_is_active_false_for_unknown_event() -> void:
	assert_false(_seasonal.is_active(&"nonexistent"))


func test_is_active_false_at_exact_end_boundary() -> void:
	# end_unix = now → aktif DEĞİL (strict less than)
	var now: int = Time.get_unix_time_from_system()
	var e := SeasonalEventSystem.EventEntry.new()
	e.event_id = &"boundary"
	e.start_unix = now - 100
	e.end_unix = now  # tam şu an bitiyor
	e.gold_bonus_multiplier = 1.5
	_seasonal._events.append(e)
	# now >= end_unix → false (now < end_unix şartı sağlanmaz)
	assert_false(_seasonal.is_active(&"boundary"), "Bitiş anında aktif değil")


# ── F-1: get_active_multiplier ────────────────────────────────────────────────

func test_multiplier_is_1_when_no_active_event() -> void:
	assert_almost_eq(_seasonal.get_active_multiplier(), 1.0, 0.001)


func test_multiplier_matches_single_active_event() -> void:
	_inject_event(&"ev1", -100, 3600, 1.5)
	assert_almost_eq(_seasonal.get_active_multiplier(), 1.5, 0.001)


func test_multiplier_is_product_of_two_active_events() -> void:
	_inject_event(&"ev1", -100, 3600, 1.5)
	_inject_event(&"ev2", -100, 3600, 1.25)
	assert_almost_eq(_seasonal.get_active_multiplier(), 1.5 * 1.25, 0.001)


func test_inactive_event_does_not_affect_multiplier() -> void:
	_inject_event(&"ev_active", -100, 3600, 2.0)
	_inject_event(&"ev_future", 3600, 7200, 3.0)
	assert_almost_eq(_seasonal.get_active_multiplier(), 2.0, 0.001)


# ── earn_gold_with_bonus ──────────────────────────────────────────────────────

func test_earn_gold_no_event_gives_raw_gold() -> void:
	_seasonal.earn_gold_with_bonus(100)
	assert_eq(_economy.gold_balance, 100)


func test_earn_gold_with_active_event_applies_multiplier() -> void:
	_inject_event(&"ev", -100, 3600, 2.0)
	_seasonal.earn_gold_with_bonus(100)
	assert_eq(_economy.gold_balance, 200, "2× multiplier → 200 altın")


func test_earn_gold_zero_is_noop() -> void:
	_seasonal.earn_gold_with_bonus(0)
	assert_eq(_economy.gold_balance, 0)


func test_earn_gold_two_events_multiplied() -> void:
	_inject_event(&"ev1", -100, 3600, 1.5)
	_inject_event(&"ev2", -100, 3600, 2.0)
	_seasonal.earn_gold_with_bonus(100)
	assert_eq(_economy.gold_balance, 300, "1.5 × 2.0 = 3.0× → 300 altın")


# ── Rozet talep ───────────────────────────────────────────────────────────────

func test_claim_rozet_active_event_gives_rozet() -> void:
	_inject_event(&"ev", -100, 3600, 1.0, 10)
	var result: bool = _seasonal.claim_event_rozet(&"ev")
	assert_true(result)
	assert_eq(_economy.rozet_balance, 10)


func test_claim_rozet_emits_signal() -> void:
	_inject_event(&"ev", -100, 3600, 1.0, 5)
	watch_signals(_seasonal)
	_seasonal.claim_event_rozet(&"ev")
	assert_signal_emitted(_seasonal, "event_rozet_earned")


func test_claim_rozet_idempotent() -> void:
	_inject_event(&"ev", -100, 3600, 1.0, 10)
	_seasonal.claim_event_rozet(&"ev")
	var result: bool = _seasonal.claim_event_rozet(&"ev")
	assert_false(result, "Zaten talep edilmiş rozet tekrar verilemez")
	assert_eq(_economy.rozet_balance, 10, "Rozet iki kez verilmedi")


func test_claim_rozet_zero_reward_returns_false() -> void:
	_inject_event(&"ev_no_rozet", -100, 3600, 1.0, 0)
	var result: bool = _seasonal.claim_event_rozet(&"ev_no_rozet")
	assert_false(result, "0 rozet talep edilemez")


# ── event_started sinyali ──────────────────────────────────────────────────────

func test_event_started_signal_emitted_for_active_event() -> void:
	_inject_event(&"ev_signal", -100, 3600)
	watch_signals(_seasonal)
	_seasonal._check_events()
	assert_signal_emitted(_seasonal, "event_started")


func test_event_started_signal_not_emitted_twice() -> void:
	_inject_event(&"ev_once", -100, 3600)
	_seasonal._check_events()  # İlk kontrol: sinyal gönderilir
	watch_signals(_seasonal)
	_seasonal._check_events()  # İkinci kontrol: sinyal tekrar gönderilmez
	assert_signal_not_emitted(_seasonal, "event_started", "Aynı etkinlik için sinyal tekrarlanmaz")


# ── get_active_events ─────────────────────────────────────────────────────────

func test_get_active_events_empty_when_no_active() -> void:
	_inject_event(&"future", 3600, 7200)
	assert_eq(_seasonal.get_active_events().size(), 0)


func test_get_active_events_contains_active_only() -> void:
	_inject_event(&"active", -100, 3600)
	_inject_event(&"future", 3600, 7200)
	var active := _seasonal.get_active_events()
	assert_eq(active.size(), 1)
	assert_eq(active[0].event_id, &"active")


# ── Serialize / Deserialize ───────────────────────────────────────────────────

func test_serialize_preserves_rozet_claimed() -> void:
	_inject_event(&"ev", -100, 3600, 1.0, 5)
	_seasonal.claim_event_rozet(&"ev")
	var data: Dictionary = _seasonal.serialize()
	assert_true(data["rozet_claimed"].get(&"ev", false))


func test_deserialize_restores_rozet_claimed() -> void:
	_inject_event(&"ev", -100, 3600, 1.0, 5)
	_seasonal.deserialize({"rozet_claimed": {&"ev": true}, "unlocked_recipes": {}, "signaled_start": {}})
	# Talep edilmiş rozet tekrar verilemez
	var result: bool = _seasonal.claim_event_rozet(&"ev")
	assert_false(result, "Deserialize sonrası zaten talep edilmiş")


# ── Null guard ────────────────────────────────────────────────────────────────

func test_null_economy_earn_gold_does_not_crash() -> void:
	_seasonal._economy_ref = null
	_inject_event(&"ev", -100, 3600, 2.0)
	_seasonal.earn_gold_with_bonus(100)
	pass_test()


func test_null_economy_claim_rozet_does_not_crash() -> void:
	_seasonal._economy_ref = null
	_inject_event(&"ev", -100, 3600, 1.0, 5)
	_seasonal.claim_event_rozet(&"ev")
	pass_test()
