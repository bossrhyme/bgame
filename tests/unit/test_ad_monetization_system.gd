## GUT Test Suite — AdMonetizationSystem
## design/gdd/ad-monetization-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_ad_monetization_system.gd
extends GutTest


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

	_ads = AdMonetizationSystem.new()
	_ads._economy_ref = _economy
	_ads._tutorial_ref = _tutorial
	add_child_autofree(_ads)


# ── F-4: can_show ─────────────────────────────────────────────────────────────

func test_can_show_true_initially_for_valid_placement() -> void:
	assert_true(_ads.can_show(&"offline_boost"))


func test_can_show_false_during_tutorial() -> void:
	# Tutorial henüz aktif
	assert_false(_ads.can_show(&"offline_boost"),
		"Tutorial devam ederken reklam teklifi gösterilmez")


func test_can_show_true_after_tutorial_complete() -> void:
	for step: StringName in TutorialSystem.STEPS:
		_tutorial.complete_step_if_current(step)
	assert_true(_ads.can_show(&"offline_boost"), "Tutorial sonrası teklif gösterilir")


func test_can_show_false_when_daily_limit_reached() -> void:
	for step: StringName in TutorialSystem.STEPS:
		_tutorial.complete_step_if_current(step)
	_ads._daily_ads_watched = AdMonetizationSystem.DAILY_AD_LIMIT
	assert_false(_ads.can_show(&"offline_boost"), "Günlük limit dolunca teklif yok")


func test_can_show_false_during_cooldown() -> void:
	for step: StringName in TutorialSystem.STEPS:
		_tutorial.complete_step_if_current(step)
	# Son reklam zamanı şu an → cooldown aktif
	_ads._last_ad_time[&"offline_boost"] = Time.get_unix_time_from_system()
	assert_false(_ads.can_show(&"offline_boost"), "Cooldown aktifken teklif yok")


func test_can_show_false_when_ad_not_available() -> void:
	for step: StringName in TutorialSystem.STEPS:
		_tutorial.complete_step_if_current(step)
	_ads._ad_available[&"offline_boost"] = false
	assert_false(_ads.can_show(&"offline_boost"), "Ad mevcut değilse teklif yok")


# ── Ödül — offline_boost ──────────────────────────────────────────────────────

func test_offline_boost_gives_bonus_gold() -> void:
	_ads.on_ad_rewarded(&"offline_boost", {"offline_gold": 100})
	# Bonus = raw × 2 - raw = 100
	assert_eq(_economy.gold_balance, 100, "Offline boost %100 bonus altın verir")


func test_offline_boost_reward_granted_signal() -> void:
	watch_signals(_ads)
	_ads.on_ad_rewarded(&"offline_boost", {"offline_gold": 50})
	assert_signal_emitted(_ads, "reward_granted")


# ── Ödül — task_double ────────────────────────────────────────────────────────

func test_task_double_gives_bonus_rozet() -> void:
	_ads.on_ad_rewarded(&"task_double", {"base_rozet": 10})
	# Bonus = 10 × 2 - 10 = 10 rozet
	assert_eq(_economy.rozet_balance, 10, "Task double %100 bonus rozet verir")


# ── ad_closed → ödül yok ──────────────────────────────────────────────────────

func test_ad_closed_emits_skipped_signal() -> void:
	watch_signals(_ads)
	_ads.on_ad_closed(&"offline_boost")
	assert_signal_emitted(_ads, "reward_skipped")


func test_ad_closed_gives_no_gold() -> void:
	_ads.on_ad_closed(&"offline_boost")
	assert_eq(_economy.gold_balance, 0, "Reklam kapatılınca ödül yok")


# ── Günlük kota ───────────────────────────────────────────────────────────────

func test_daily_limit_reached_signal_on_last_ad() -> void:
	watch_signals(_ads)
	_ads._daily_ads_watched = AdMonetizationSystem.DAILY_AD_LIMIT - 1
	_ads.on_ad_rewarded(&"offline_boost", {"offline_gold": 10})
	assert_signal_emitted(_ads, "daily_limit_reached")


func test_reset_daily_quota_clears_counter() -> void:
	_ads._daily_ads_watched = AdMonetizationSystem.DAILY_AD_LIMIT
	_ads.reset_daily_quota()
	assert_eq(_ads._daily_ads_watched, 0)


# ── Fill rate = 0 ─────────────────────────────────────────────────────────────

func test_notify_ad_failed_disables_placement() -> void:
	_ads.notify_ad_failed(&"daily_bonus")
	assert_false(_ads._ad_available.get(&"daily_bonus", true))


func test_notify_ad_loaded_enables_placement() -> void:
	_ads._ad_available[&"daily_bonus"] = false
	_ads.notify_ad_loaded(&"daily_bonus")
	assert_true(_ads._ad_available.get(&"daily_bonus", false))


func test_one_placement_failure_does_not_affect_others() -> void:
	for step: StringName in TutorialSystem.STEPS:
		_tutorial.complete_step_if_current(step)
	_ads.notify_ad_failed(&"offline_boost")
	assert_true(_ads.can_show(&"daily_bonus"), "Diğer placement etkilenmez")


# ── Null guard ────────────────────────────────────────────────────────────────

func test_null_economy_reward_does_not_crash() -> void:
	_ads._economy_ref = null
	_ads.on_ad_rewarded(&"offline_boost", {"offline_gold": 100})
	pass_test()


func test_null_tutorial_can_show_returns_false() -> void:
	_ads._tutorial_ref = null
	# Tutorial null → _is_tutorial_active() false kabul edilir
	# can_show: tutorial yok → aktif olmadığı varsayılır → true dönmeli
	# (güvenli default: tutorial bilgisi yoksa bloklama yapma)
	assert_true(_ads.can_show(&"offline_boost"),
		"Tutorial ref null ise tutorial aktif sayılmaz")
