## GUT Test Suite — AdMobBridge
## src/ui/admob_bridge.gd — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_admob_bridge.gd
extends GutTest


var _bridge: AdMobBridge
var _stub: AdMobStub
var _ads: AdMonetizationSystem
var _economy: EconomySystem
var _tutorial: TutorialSystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(0, 0)

	_tutorial = TutorialSystem.new()
	_tutorial._economy_ref = _economy
	_tutorial._oven_ref = null
	_tutorial._upgrade_ref = null
	_tutorial._recipe_ref = null
	_tutorial._customer_ref = null
	_tutorial._gesture_ref = null
	add_child_autofree(_tutorial)
	# Tutorial tamamlandı olarak işaretle → can_show = true
	_tutorial._tutorial_completed = true

	_ads = AdMonetizationSystem.new()
	_ads._economy_ref = _economy
	_ads._tutorial_ref = _tutorial
	add_child_autofree(_ads)

	_stub = AdMobStub.new()
	_stub.simulate_success = true
	_stub.simulate_reward = true
	_stub.load_delay_sec = 0.0
	add_child_autofree(_stub)

	_bridge = AdMobBridge.new()
	_bridge._admob = _stub
	_bridge._ad_system = _ads
	add_child_autofree(_bridge)
	_bridge._load_ad_unit_ids()
	_bridge._build_reverse_map()
	_bridge._wire_admob()


# ── Config yükleme ────────────────────────────────────────────────────────────

func test_loads_test_ids_when_no_config() -> void:
	# Config dosyası yok → test ID'leri kullanılır
	assert_eq(_bridge._ad_unit_ids.size(), 5)
	assert_true(_bridge._ad_unit_ids.has(&"offline_boost"))


func test_reverse_map_populated() -> void:
	# Her ad_unit_id → placement_id eşlemesi var
	assert_eq(_bridge._unit_to_placement.size(), _bridge._ad_unit_ids.size())


# ── set_consent_state ─────────────────────────────────────────────────────────

func test_consent_ok_by_default() -> void:
	assert_true(_bridge._consent_ok)


func test_set_consent_state_false_blocks_ads() -> void:
	_bridge.set_consent_state(false)
	assert_false(_bridge._consent_ok)


func test_set_consent_state_true_allows_ads() -> void:
	_bridge.set_consent_state(false)
	_bridge.set_consent_state(true)
	assert_true(_bridge._consent_ok)


# ── request_rewarded_ad ───────────────────────────────────────────────────────

func test_request_rewarded_ad_triggers_load() -> void:
	watch_signals(_stub)
	_bridge.request_rewarded_ad(&"offline_boost")
	assert_signal_emitted(_stub, "ad_loaded")


func test_request_rewarded_ad_blocked_by_consent() -> void:
	_bridge.set_consent_state(false)
	watch_signals(_stub)
	_bridge.request_rewarded_ad(&"offline_boost")
	assert_signal_not_emitted(_stub, "ad_loaded")


func test_request_rewarded_ad_unknown_placement_no_crash() -> void:
	# Bilinmeyen placement → push_warning, çökme yok
	_bridge.request_rewarded_ad(&"nonexistent_placement")
	assert_true(true)


func test_request_rewarded_ad_missing_ad_system() -> void:
	_bridge._ad_system = null
	# _get_ad_system() null döner → push_error, çökme yok
	_bridge.request_rewarded_ad(&"offline_boost")
	assert_true(true)


# ── Ad signal handlers ────────────────────────────────────────────────────────

func test_on_ad_loaded_triggers_show() -> void:
	_stub.simulate_reward = true
	watch_signals(_ads)
	_bridge.request_rewarded_ad(&"offline_boost")
	# Stub: load → loaded sinyal → bridge show_rewarded_ad → reward + closed
	assert_signal_emitted(_ads, "reward_granted")


func test_on_user_earned_reward_calls_on_ad_rewarded() -> void:
	watch_signals(_ads)
	_bridge._pending_context[&"offline_boost"] = {&"offline_gold": 100}
	var unit_id: String = _bridge._ad_unit_ids.get(&"offline_boost", "")
	_bridge._on_user_earned_reward(unit_id, "gold", 1)
	assert_signal_emitted(_ads, "reward_granted")


func test_on_user_earned_reward_clears_pending_context() -> void:
	var unit_id: String = _bridge._ad_unit_ids.get(&"offline_boost", "")
	_bridge._pending_context[&"offline_boost"] = {}
	_bridge._on_user_earned_reward(unit_id, "gold", 1)
	assert_false(_bridge._pending_context.has(&"offline_boost"))


func test_on_ad_closed_without_reward_clears_context() -> void:
	var unit_id: String = _bridge._ad_unit_ids.get(&"daily_bonus", "")
	_bridge._pending_context[&"daily_bonus"] = {}
	_bridge._on_ad_closed(unit_id)
	assert_false(_bridge._pending_context.has(&"daily_bonus"))


func test_on_ad_failed_to_load_notifies_system() -> void:
	_stub.simulate_success = false
	watch_signals(_ads)
	_bridge.request_rewarded_ad(&"task_double")
	# Stub: load → failed sinyal → bridge notify_ad_failed → no reward
	assert_signal_not_emitted(_ads, "reward_granted")


func test_on_ad_failed_clears_pending_context() -> void:
	var unit_id: String = _bridge._ad_unit_ids.get(&"task_double", "")
	_bridge._pending_context[&"task_double"] = {}
	_bridge._on_ad_failed_to_load(unit_id, -1, "simulated")
	assert_false(_bridge._pending_context.has(&"task_double"))


# ── resolve_placement ─────────────────────────────────────────────────────────

func test_resolve_placement_known_unit_id() -> void:
	var unit_id: String = _bridge._ad_unit_ids.get(&"offline_boost", "")
	var resolved: StringName = _bridge._resolve_placement(unit_id)
	assert_eq(resolved, &"offline_boost")


func test_resolve_placement_unknown_unit_id() -> void:
	var resolved: StringName = _bridge._resolve_placement("ca-app-pub-UNKNOWN/000")
	assert_eq(resolved, &"")


# ── _get_ad_system lazy-init ──────────────────────────────────────────────────

func test_get_ad_system_returns_injected_ref() -> void:
	var result: AdMonetizationSystem = _bridge._get_ad_system()
	assert_eq(result, _ads)


func test_get_ad_system_returns_null_when_not_wired() -> void:
	var bridge2 := AdMobBridge.new()
	add_child_autofree(bridge2)
	# Autoload yok, _ad_system inject edilmedi → null beklenir
	var result: AdMonetizationSystem = bridge2._get_ad_system()
	assert_null(result)
