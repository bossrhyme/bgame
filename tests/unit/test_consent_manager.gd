## GUT Test Suite — ConsentManager
## src/ui/consent_manager.gd — GDPR rıza yönetimi
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_consent_manager.gd
extends GutTest


var _consent: ConsentManager
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
	_tutorial._tutorial_completed = true
	add_child_autofree(_tutorial)

	_ads = AdMonetizationSystem.new()
	_ads._economy_ref = _economy
	_ads._tutorial_ref = _tutorial
	add_child_autofree(_ads)

	_stub = AdMobStub.new()
	_stub.load_delay_sec = 0.0
	add_child_autofree(_stub)

	_bridge = AdMobBridge.new()
	_bridge._admob = _stub
	_bridge._ad_system = _ads
	add_child_autofree(_bridge)
	_bridge._load_ad_unit_ids()
	_bridge._build_reverse_map()

	_consent = ConsentManager.new()
	_consent._ad_bridge = _bridge
	add_child_autofree(_consent)


# ── Başlangıç durumu ──────────────────────────────────────────────────────────

func test_initial_state_is_unknown() -> void:
	var fresh := ConsentManager.new()
	add_child_autofree(fresh)
	# _load_persisted_state çağrılmadan önce UNKNOWN
	assert_eq(fresh._state, ConsentManager.ConsentState.UNKNOWN)


func test_ready_sets_not_required_in_stub_mode() -> void:
	# Stub modda (UMP yok) → NOT_REQUIRED
	assert_eq(_consent.get_state(), ConsentManager.ConsentState.NOT_REQUIRED)


# ── can_show_ads ──────────────────────────────────────────────────────────────

func test_can_show_ads_true_when_not_required() -> void:
	assert_true(_consent.can_show_ads())


func test_can_show_ads_true_when_obtained() -> void:
	_consent._state = ConsentManager.ConsentState.OBTAINED
	assert_true(_consent.can_show_ads())


func test_can_show_ads_false_when_required() -> void:
	_consent._state = ConsentManager.ConsentState.REQUIRED
	assert_false(_consent.can_show_ads())


func test_can_show_ads_false_when_denied() -> void:
	_consent._state = ConsentManager.ConsentState.DENIED
	assert_false(_consent.can_show_ads())


func test_can_show_ads_false_when_unknown() -> void:
	_consent._state = ConsentManager.ConsentState.UNKNOWN
	assert_false(_consent.can_show_ads())


# ── consent_updated sinyali ───────────────────────────────────────────────────

func test_consent_updated_emitted_on_state_change() -> void:
	watch_signals(_consent)
	_consent._set_state(ConsentManager.ConsentState.OBTAINED)
	assert_signal_emitted(_consent, "consent_updated")


func test_consent_updated_carries_correct_state() -> void:
	watch_signals(_consent)
	_consent._set_state(ConsentManager.ConsentState.DENIED)
	assert_signal_emitted_with_parameters(
		_consent, "consent_updated", [ConsentManager.ConsentState.DENIED]
	)


# ── request_consent_form (stub) ───────────────────────────────────────────────

func test_request_consent_form_no_op_when_not_required() -> void:
	# NOT_REQUIRED → form gösterilmez, durum değişmez
	var before: ConsentManager.ConsentState = _consent.get_state()
	_consent.request_consent_form()
	assert_eq(_consent.get_state(), before)


func test_request_consent_form_sets_obtained_in_stub() -> void:
	_consent._state = ConsentManager.ConsentState.REQUIRED
	_consent.request_consent_form()
	assert_eq(_consent.get_state(), ConsentManager.ConsentState.OBTAINED)


# ── AdMobBridge bağlantısı ────────────────────────────────────────────────────

func test_notify_ad_bridge_sets_consent_ok_true_when_not_required() -> void:
	_consent._set_state(ConsentManager.ConsentState.NOT_REQUIRED)
	assert_true(_bridge._consent_ok)


func test_notify_ad_bridge_sets_consent_ok_false_when_denied() -> void:
	_consent._set_state(ConsentManager.ConsentState.DENIED)
	assert_false(_bridge._consent_ok)


func test_notify_ad_bridge_sets_consent_ok_true_when_obtained() -> void:
	_consent._set_state(ConsentManager.ConsentState.OBTAINED)
	assert_true(_bridge._consent_ok)


func test_notify_ad_bridge_no_crash_without_bridge() -> void:
	_consent._ad_bridge = null
	_consent._set_state(ConsentManager.ConsentState.REQUIRED)
	assert_true(true)  # çökme yok


# ── get_state ─────────────────────────────────────────────────────────────────

func test_get_state_returns_current_state() -> void:
	_consent._state = ConsentManager.ConsentState.OBTAINED
	assert_eq(_consent.get_state(), ConsentManager.ConsentState.OBTAINED)


# ── _persist ve _load (round-trip) ───────────────────────────────────────────

func test_persist_and_load_round_trip() -> void:
	_consent._state = ConsentManager.ConsentState.OBTAINED
	_consent._persist_state()

	var fresh := ConsentManager.new()
	add_child_autofree(fresh)
	fresh._load_persisted_state()
	assert_eq(fresh._state, ConsentManager.ConsentState.OBTAINED)
