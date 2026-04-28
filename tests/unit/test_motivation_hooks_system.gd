## GUT Test Suite — MotivationHooksSystem
## design/gdd/motivation-hooks-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_motivation_hooks_system.gd
extends GutTest


var _hooks: MotivationHooksSystem
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

	_hooks = MotivationHooksSystem.new()
	_hooks._economy_ref = _economy
	_hooks._upgrade_ref = _upgrade
	_hooks._oven_ref = null
	_hooks._task_ref = null
	_hooks._notif_ref = null
	add_child_autofree(_hooks)


# ── Yardımcı ──────────────────────────────────────────────────────────────────

func _inject_upgrade(id: StringName, base_cost: int, max_level: int = 3) -> void:
	var u := UpgradeData.new()
	u.id = id
	u.base_cost = base_cost
	u.max_level = max_level
	u.effect_per_level.resize(max_level)
	u.effect_per_level.fill(0.1)
	_upgrade._upgrades[id] = u
	_upgrade._levels[id] = 0


# ── Near Upgrade ──────────────────────────────────────────────────────────────

func test_near_upgrade_signal_when_within_threshold() -> void:
	_inject_upgrade(&"oven_temp", 100)  # cost=100, gold=60 → needed=40 ≤ 50
	_economy.initialize(60, 0)

	watch_signals(_hooks)
	_hooks._check_near_upgrade(60)

	assert_signal_emitted(_hooks, "near_upgrade")


func test_near_upgrade_not_emitted_when_far_from_cost() -> void:
	_inject_upgrade(&"oven_temp", 200)  # cost=200, gold=100 → needed=100 > 50
	_economy.initialize(100, 0)

	watch_signals(_hooks)
	_hooks._check_near_upgrade(100)

	assert_signal_not_emitted(_hooks, "near_upgrade")


func test_near_upgrade_not_emitted_when_gold_exceeds_cost() -> void:
	_inject_upgrade(&"oven_temp", 50)  # cost=50, gold=60 → needed=−10 ≤ 0
	_economy.initialize(60, 0)

	watch_signals(_hooks)
	_hooks._check_near_upgrade(60)

	assert_signal_not_emitted(_hooks, "near_upgrade",
		"Gold ≥ cost → satın alabilir; motivasyon kancası tetiklenmez")


func test_near_upgrade_not_emitted_when_all_maxed() -> void:
	_inject_upgrade(&"oven_temp", 50, 1)
	_upgrade._levels[&"oven_temp"] = 1  # maxed

	watch_signals(_hooks)
	_hooks._check_near_upgrade(10)

	assert_signal_not_emitted(_hooks, "near_upgrade")


func test_near_upgrade_picks_cheapest_non_maxed() -> void:
	_inject_upgrade(&"cheap", 80)   # cost=80, needed=80-30=50 ≤ 50
	_inject_upgrade(&"expensive", 500)  # cost=500, needed=470 > 50

	var received_id: StringName = &""
	_hooks.near_upgrade.connect(func(id: StringName, _n: int) -> void: received_id = id)
	_hooks._check_near_upgrade(30)

	assert_eq(received_id, &"cheap", "En ucuz upgrade seçilir")


func test_near_upgrade_threshold_boundary_exactly_50() -> void:
	_inject_upgrade(&"oven_temp", 100)  # gold=50 → needed=50 == threshold
	watch_signals(_hooks)
	_hooks._check_near_upgrade(50)

	assert_signal_emitted(_hooks, "near_upgrade", "Eşik değeri dahil")


# ── Oven Nearly Full ──────────────────────────────────────────────────────────

func test_oven_nearly_full_not_emitted_when_no_oven() -> void:
	# _oven_ref = null → push_warning, sinyal yok
	watch_signals(_hooks)
	_hooks._check_oven_capacity()
	assert_signal_not_emitted(_hooks, "oven_nearly_full")


# ── Daily Task Near Completion ────────────────────────────────────────────────

func test_daily_task_not_emitted_when_no_task_system() -> void:
	watch_signals(_hooks)
	_hooks._check_daily_task_progress()
	assert_signal_not_emitted(_hooks, "daily_task_near_completion")


# ── Session Idle (iskelet) ────────────────────────────────────────────────────

func test_session_idle_signal_exists() -> void:
	# Sinyalin tanımlı olduğunu doğrula (GUT watch destekli)
	assert_true(_hooks.has_signal("session_idle"))


# ── Null guard ────────────────────────────────────────────────────────────────

func test_null_upgrade_does_not_crash() -> void:
	_hooks._upgrade_ref = null
	_hooks._check_near_upgrade(100)
	pass_test()


func test_null_economy_wiring_does_not_crash() -> void:
	var h := MotivationHooksSystem.new()
	h._economy_ref = null
	h._upgrade_ref = null
	h._oven_ref = null
	h._task_ref = null
	h._notif_ref = null
	add_child(h)
	h.queue_free()
	pass_test()
