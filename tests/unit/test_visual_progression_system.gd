## GUT Test Suite — VisualProgressionSystem
## design/gdd/visual-progression-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_visual_progression_system.gd
extends GutTest


var _vps: VisualProgressionSystem
var _tree: UpgradeTree
var _economy: EconomySystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(99999, 9999)

	_tree = UpgradeTree.new()
	add_child_autofree(_tree)
	_tree._economy_ref = _economy
	_tree._registry_ref = null

	_vps = VisualProgressionSystem.new()
	add_child_autofree(_vps)
	_vps._upgrade_ref = _tree
	# Manuel sinyal bağlantısı (DI sonrası _ready çağrılmadı)
	_tree.upgrade_purchased.connect(_vps._on_upgrade_purchased)


# ── Yardımcı ──────────────────────────────────────────────────────────────────

func _inject_upgrade(id: StringName, max_level: int = 5) -> void:
	var u := UpgradeData.new()
	u.id = id
	u.display_name = str(id)
	u.base_cost = 10
	u.max_level = max_level
	u.effect_per_level.resize(max_level)
	u.effect_per_level.fill(0.1)
	_tree._upgrades[id] = u
	_tree._levels[id] = 0


# ── Başlangıç durumu ──────────────────────────────────────────────────────────

func test_initial_tiers_are_zero() -> void:
	assert_eq(_vps.oven_tier, 0)
	assert_eq(_vps.showcase_tier, 0)
	assert_eq(_vps.decor_tier, 0)


# ── OVEN upgrade → oven_visual_changed ───────────────────────────────────────

func test_oven_temperature_purchase_emits_oven_signal() -> void:
	_inject_upgrade(&"oven_temperature")

	watch_signals(_vps)
	_tree.upgrade_purchased.emit(&"oven_temperature", 1)
	_tree._levels[&"oven_temperature"] = 1

	# Signal'i doğrudan tetikledik; tier hesabı _tree'ye sorulur
	# Önce seviyeyi ayarla sonra emit tekrarla (gerçek satın alma sırası)
	_tree._levels[&"oven_temperature"] = 0
	_tree._levels[&"oven_temperature"] = 1
	_vps._on_upgrade_purchased(&"oven_temperature", 1)

	assert_signal_emitted(_vps, "oven_visual_changed")


func test_oven_tier_equals_sum_of_oven_upgrade_levels() -> void:
	for id: StringName in VisualProgressionSystem.OVEN_UPGRADES:
		_inject_upgrade(id, 5)

	_tree._levels[&"oven_temperature"] = 2
	_tree._levels[&"dough_quality"] = 1
	_vps._on_upgrade_purchased(&"oven_temperature", 2)

	assert_eq(_vps.oven_tier, 3, "oven_tier = 2+1 = 3")


func test_oven_tier_accumulates_across_multiple_upgrades() -> void:
	for id: StringName in VisualProgressionSystem.OVEN_UPGRADES:
		_inject_upgrade(id, 5)

	_tree._levels[&"oven_temperature"] = 1
	_vps._on_upgrade_purchased(&"oven_temperature", 1)
	assert_eq(_vps.oven_tier, 1)

	_tree._levels[&"oven_capacity"] = 2
	_vps._on_upgrade_purchased(&"oven_capacity", 2)
	assert_eq(_vps.oven_tier, 3)

	_tree._levels[&"auto_dough"] = 1
	_vps._on_upgrade_purchased(&"auto_dough", 1)
	assert_eq(_vps.oven_tier, 4)


func test_oven_signal_not_emitted_when_tier_unchanged() -> void:
	for id: StringName in VisualProgressionSystem.OVEN_UPGRADES:
		_inject_upgrade(id, 5)

	# Tier'ı önce 1'e getir
	_tree._levels[&"oven_temperature"] = 1
	_vps._on_upgrade_purchased(&"oven_temperature", 1)

	watch_signals(_vps)
	# Aynı tier ile tekrar tetikle — sinyal yayılmamalı
	_vps._on_upgrade_purchased(&"oven_temperature", 1)

	assert_signal_not_emitted(_vps, "oven_visual_changed")


# ── SHOWCASE upgrade → showcase_visual_changed ────────────────────────────────

func test_showcase_width_purchase_emits_showcase_signal() -> void:
	_inject_upgrade(&"showcase_width", 3)

	watch_signals(_vps)
	_tree._levels[&"showcase_width"] = 1
	_vps._on_upgrade_purchased(&"showcase_width", 1)

	assert_signal_emitted(_vps, "showcase_visual_changed")
	assert_eq(_vps.showcase_tier, 1)


func test_showcase_tier_reaches_max_at_level_3() -> void:
	_inject_upgrade(&"showcase_width", 3)

	_tree._levels[&"showcase_width"] = 3
	_vps._on_upgrade_purchased(&"showcase_width", 3)

	assert_eq(_vps.showcase_tier, 3)


# ── DECOR upgrade → decor_visual_changed ─────────────────────────────────────

func test_customer_satisfaction_purchase_emits_decor_signal() -> void:
	_inject_upgrade(&"customer_satisfaction", 3)

	watch_signals(_vps)
	_tree._levels[&"customer_satisfaction"] = 1
	_vps._on_upgrade_purchased(&"customer_satisfaction", 1)

	assert_signal_emitted(_vps, "decor_visual_changed")


func test_decor_tier_sums_all_decor_upgrades() -> void:
	for id: StringName in VisualProgressionSystem.DECOR_UPGRADES:
		var max_lv: int = 3 if id == &"customer_satisfaction" else 1
		_inject_upgrade(id, max_lv)

	_tree._levels[&"customer_satisfaction"] = 2
	_tree._levels[&"loyalty_card"] = 1
	_vps._on_upgrade_purchased(&"loyalty_card", 1)

	assert_eq(_vps.decor_tier, 3, "decor_tier = 2+1 = 3")


func test_vip_lounge_contributes_to_decor_tier() -> void:
	_inject_upgrade(&"vip_lounge", 1)
	_inject_upgrade(&"customer_satisfaction", 3)

	_tree._levels[&"vip_lounge"] = 1
	_vps._on_upgrade_purchased(&"vip_lounge", 1)

	assert_eq(_vps.decor_tier, 1)


# ── Bilinmeyen upgrade_id ─────────────────────────────────────────────────────

func test_unknown_upgrade_id_does_not_emit_any_signal() -> void:
	watch_signals(_vps)
	_vps._on_upgrade_purchased(&"completely_unknown_upgrade", 1)

	assert_signal_not_emitted(_vps, "oven_visual_changed")
	assert_signal_not_emitted(_vps, "showcase_visual_changed")
	assert_signal_not_emitted(_vps, "decor_visual_changed")


func test_unknown_upgrade_id_does_not_crash() -> void:
	# Çökmediğini doğrula
	_vps._on_upgrade_purchased(&"nonexistent", 99)
	pass_test()


# ── refresh() ────────────────────────────────────────────────────────────────

func test_refresh_emits_oven_signal_on_nonzero_tier() -> void:
	for id: StringName in VisualProgressionSystem.OVEN_UPGRADES:
		_inject_upgrade(id, 5)

	_tree._levels[&"oven_temperature"] = 3

	watch_signals(_vps)
	_vps.refresh(_tree)

	assert_signal_emitted(_vps, "oven_visual_changed")
	assert_eq(_vps.oven_tier, 3)


func test_refresh_does_not_emit_when_tier_unchanged() -> void:
	for id: StringName in VisualProgressionSystem.OVEN_UPGRADES:
		_inject_upgrade(id, 5)

	# İlk refresh — tier 0, başlangıç da 0 → sinyal yok
	watch_signals(_vps)
	_vps.refresh(_tree)

	assert_signal_not_emitted(_vps, "oven_visual_changed")
	assert_signal_not_emitted(_vps, "showcase_visual_changed")
	assert_signal_not_emitted(_vps, "decor_visual_changed")


func test_refresh_with_null_tree_does_not_crash() -> void:
	_vps.refresh(null)
	pass_test()


func test_refresh_updates_all_three_categories() -> void:
	_inject_upgrade(&"oven_temperature", 5)
	_inject_upgrade(&"showcase_width", 3)
	_inject_upgrade(&"customer_satisfaction", 3)

	_tree._levels[&"oven_temperature"] = 2
	_tree._levels[&"showcase_width"] = 1
	_tree._levels[&"customer_satisfaction"] = 3

	_vps.refresh(_tree)

	assert_eq(_vps.oven_tier, 2)
	assert_eq(_vps.showcase_tier, 1)
	assert_eq(_vps.decor_tier, 3)


# ── Kategori listesi tutarlılığı ──────────────────────────────────────────────

func test_oven_upgrades_list_contains_expected_ids() -> void:
	assert_true(&"oven_temperature" in VisualProgressionSystem.OVEN_UPGRADES)
	assert_true(&"dough_quality" in VisualProgressionSystem.OVEN_UPGRADES)
	assert_true(&"oven_capacity" in VisualProgressionSystem.OVEN_UPGRADES)
	assert_true(&"auto_dough" in VisualProgressionSystem.OVEN_UPGRADES)
	assert_true(&"ingredient_storage" in VisualProgressionSystem.OVEN_UPGRADES)


func test_showcase_upgrades_list_contains_showcase_width() -> void:
	assert_true(&"showcase_width" in VisualProgressionSystem.SHOWCASE_UPGRADES)


func test_decor_upgrades_list_contains_expected_ids() -> void:
	assert_true(&"customer_satisfaction" in VisualProgressionSystem.DECOR_UPGRADES)
	assert_true(&"loyalty_card" in VisualProgressionSystem.DECOR_UPGRADES)
	assert_true(&"vip_lounge" in VisualProgressionSystem.DECOR_UPGRADES)
