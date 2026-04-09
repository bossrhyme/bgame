## GUT Test Suite — AnimationManager
## GDD #7 Acceptance Criteria: sinyal tabanlı state geçişleri, coin formülleri
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_animation_manager.gd
extends GutTest

var manager: AnimationManager
var economy: EconomySystem
var settings: SettingsManager


func before_each() -> void:
	# Economy — READY durumunda (gold=0)
	economy = EconomySystem.new()
	add_child(economy)
	economy.initialize(0, 0)

	# SettingsManager — test dosyasına yönlendir
	settings = SettingsManager.new()
	settings._set_save_path("user://settings_anim_test.cfg")
	add_child(settings)

	# AnimationManager — dependency injection
	manager = AnimationManager.new()
	manager._economy_ref = economy
	manager._settings_ref = settings
	add_child(manager)


func after_each() -> void:
	manager.queue_free()
	settings.queue_free()
	economy.queue_free()
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("settings_anim_test.cfg"):
		dir.remove("settings_anim_test.cfg")


# ── F-2: coin_count_for_delta formülü ────────────────────────────────────────

func test_coin_count_delta_zero_returns_zero() -> void:
	assert_eq(manager.coin_count_for_delta(0), 0, "delta=0 → 0 coin")


func test_coin_count_delta_negative_returns_zero() -> void:
	assert_eq(manager.coin_count_for_delta(-100), 0, "delta<0 → 0 coin")


func test_coin_count_delta_1() -> void:
	assert_eq(manager.coin_count_for_delta(1), 1, "delta=1 → 1 coin")


func test_coin_count_delta_at_threshold_1() -> void:
	assert_eq(manager.coin_count_for_delta(50), 1, "delta=50 → 1 coin (eşik)")


func test_coin_count_delta_just_above_threshold_1() -> void:
	assert_eq(manager.coin_count_for_delta(51), 3, "delta=51 → 3 coin")


func test_coin_count_delta_at_threshold_2() -> void:
	assert_eq(manager.coin_count_for_delta(500), 3, "delta=500 → 3 coin (eşik)")


func test_coin_count_delta_just_above_threshold_2() -> void:
	assert_eq(manager.coin_count_for_delta(501), 5, "delta=501 → 5 coin")


func test_coin_count_delta_at_threshold_3() -> void:
	assert_eq(manager.coin_count_for_delta(2000), 5, "delta=2000 → 5 coin (eşik)")


func test_coin_count_delta_above_threshold_3() -> void:
	assert_eq(manager.coin_count_for_delta(2001), 8, "delta=2001 → 8 coin (max)")


func test_coin_count_delta_very_large() -> void:
	assert_eq(manager.coin_count_for_delta(999_999), 8, "delta çok büyük → 8 coin (cap)")


# ── gold_changed → coin_spawn_requested ──────────────────────────────────────

func test_earn_gold_triggers_coin_spawn() -> void:
	var signals: Array = []
	manager.coin_spawn_requested.connect(func(c, d): signals.append([c, d]))

	economy.earn_gold(25)  # delta=25, eşik 1 altı → 1 coin
	assert_eq(signals.size(), 1, "coin_spawn_requested emit edildi")
	assert_eq(signals[0][0], 1, "count = 1")
	assert_eq(signals[0][1], 25, "delta = 25")


func test_earn_gold_large_delta_5_coins() -> void:
	var signals: Array = []
	manager.coin_spawn_requested.connect(func(c, d): signals.append([c, d]))

	economy.earn_gold(800)  # delta=800, 501–2000 → 5 coin
	assert_eq(signals[0][0], 5, "count = 5 (delta=800)")


func test_spend_gold_no_coin_spawn() -> void:
	economy.earn_gold(200)  # balance=200, bu signal sayılır
	var signals: Array = []
	manager.coin_spawn_requested.connect(func(c, d): signals.append([c, d]))

	economy.spend_gold(50)  # delta negatif → sinyal yok
	assert_eq(signals.size(), 0, "spend_gold → coin_spawn yok")


# ── battery_saver modu ────────────────────────────────────────────────────────

func test_battery_saver_true_suppresses_coin_spawn() -> void:
	settings.set_battery_saver(true)
	var signals: Array = []
	manager.coin_spawn_requested.connect(func(c, d): signals.append([c, d]))

	economy.earn_gold(100)
	assert_eq(signals.size(), 0, "battery_saver=true → coin_spawn atlandı")


func test_battery_saver_false_allows_coin_spawn() -> void:
	settings.set_battery_saver(true)
	settings.set_battery_saver(false)
	var signals: Array = []
	manager.coin_spawn_requested.connect(func(c, d): signals.append([c, d]))

	economy.earn_gold(100)
	assert_eq(signals.size(), 1, "battery_saver=false → coin_spawn tetiklendi")


func test_battery_saver_change_updates_manager_state() -> void:
	assert_false(manager.battery_saver, "Başlangıçta battery_saver=false")
	settings.set_battery_saver(true)
	assert_true(manager.battery_saver, "battery_saver_changed sinyali alındı → true")
	settings.set_battery_saver(false)
	assert_false(manager.battery_saver, "battery_saver tekrar false")


# ── get_blend_time ────────────────────────────────────────────────────────────

func test_get_blend_time_normal_returns_requested_value() -> void:
	var blend := manager.get_blend_time(AnimationManager.BLEND_STANDARD)
	assert_almost_eq(blend, AnimationManager.BLEND_STANDARD, 0.001, "Normal modda BLEND_STANDARD")


func test_get_blend_time_battery_saver_returns_instant() -> void:
	settings.set_battery_saver(true)
	var blend := manager.get_blend_time(AnimationManager.BLEND_STANDARD)
	assert_almost_eq(blend, AnimationManager.BLEND_INSTANT, 0.001, "battery_saver → BLEND_INSTANT")


# ── Max coin grup limiti (Edge Case 4) ────────────────────────────────────────

func test_coin_group_limit_max_3_active() -> void:
	# Manuel olarak 3 aktif grubu simüle et
	manager._active_coin_groups = AnimationManager.MAX_COIN_GROUPS
	var signals: Array = []
	manager.coin_spawn_requested.connect(func(c, d): signals.append([c, d]))

	manager._on_gold_changed(100)  # _prev_gold_balance = 0 → delta=100
	assert_eq(signals.size(), 0, "3 aktif grup varken yeni coin_spawn atlandı")


# ── Sinyal API'leri ───────────────────────────────────────────────────────────

func test_notify_harvest_blocked_emits_signal() -> void:
	var signals: Array = []
	manager.harvest_blocked.connect(func(sid): signals.append(sid))
	manager.notify_harvest_blocked(2)
	assert_eq(signals.size(), 1, "harvest_blocked emit edildi")
	assert_eq(signals[0], 2, "slot_id = 2")


func test_notify_dough_loaded_emits_signal() -> void:
	var signals: Array = []
	manager.dough_loaded.connect(func(sid): signals.append(sid))
	manager.notify_dough_loaded(0)
	assert_eq(signals.size(), 1, "dough_loaded emit edildi")
	assert_eq(signals[0], 0, "slot_id = 0")


# ── Prev balance delta hesabı ─────────────────────────────────────────────────

func test_prev_balance_tracks_correctly() -> void:
	economy.earn_gold(100)  # balance=100, delta=100 → coin spawn + prev güncellendi
	var signals: Array = []
	manager.coin_spawn_requested.connect(func(c, d): signals.append([c, d]))

	economy.earn_gold(30)   # balance=130, delta=30 → 1 coin
	assert_eq(signals.size(), 1, "İkinci earn_gold delta=30 → 1 coin")
	assert_eq(signals[0][1], 30, "delta=30 (100→130)")
