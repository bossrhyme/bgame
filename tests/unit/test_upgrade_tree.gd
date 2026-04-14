## test_upgrade_tree.gd
##
## GUT testleri — UpgradeTree (S2-05)
## Kapsanan AC'ler: maliyet formülü, efekt hesabı, satın alma akışı,
##   çift tap kilidi, sınır değerleri, Config Resource güncellemeleri,
##   serialize/deserialize, bozuk kayıt koruması
extends GutTest

var _tree: UpgradeTree
var _economy: EconomySystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(10000, 5000)  # Bol bakiye

	_tree = UpgradeTree.new()
	add_child_autofree(_tree)
	_tree._economy_ref = _economy
	_tree._registry_ref = null  # ContentRegistry yok; test enjeksiyonu


# ── Yardımcılar ───────────────────────────────────────────────────────────────

func _make_upgrade(id: StringName, base_cost: int, max_level: int,
		effects: Array[float], costs_badge: bool = false,
		category: GameEnums.UpgradeCategory = GameEnums.UpgradeCategory.PRODUCTION,
		effect_type: GameEnums.UpgradeEffectType = GameEnums.UpgradeEffectType.BAKE_SPEED
		) -> UpgradeData:
	var u := UpgradeData.new()
	u.id = id
	u.display_name = str(id)
	u.base_cost = base_cost
	u.max_level = max_level
	u.effect_per_level = effects
	u.costs_badge = costs_badge
	u.category = category
	u.effect_type = effect_type
	return u


func _inject(upgrade: UpgradeData) -> void:
	_tree._upgrades[upgrade.id] = upgrade
	_tree._levels[upgrade.id] = 0


# ── AC: Maliyet formülü (F-1) ─────────────────────────────────────────────────

func test_cost_formula_level_1() -> void:
	# base_cost × 3^0 = base_cost
	assert_eq(UpgradeTree.compute_cost(50, 1), 50, "Sev.1: base_cost × 1 = 50")


func test_cost_formula_level_2() -> void:
	# 50 × 3^1 = 150
	assert_eq(UpgradeTree.compute_cost(50, 2), 150, "Sev.2: base_cost × 3 = 150")


func test_cost_formula_level_3() -> void:
	# 50 × 3^2 = 450
	assert_eq(UpgradeTree.compute_cost(50, 3), 450, "Sev.3: base_cost × 9 = 450")


func test_cost_formula_level_4() -> void:
	# 50 × 3^3 = 1350
	assert_eq(UpgradeTree.compute_cost(50, 4), 1350, "Sev.4: base_cost × 27 = 1350")


func test_cost_formula_level_5() -> void:
	# 50 × 3^4 = 4050
	assert_eq(UpgradeTree.compute_cost(50, 5), 4050, "Sev.5: base_cost × 81 = 4050")


func test_get_next_cost_level_1() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	assert_eq(_tree.get_next_cost(&"oven_temperature"), 50,
		"Seviye 0'dan 1'e geçiş maliyeti base_cost olmalı")


func test_get_next_cost_after_one_purchase() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	_tree._levels[&"oven_temperature"] = 1
	assert_eq(_tree.get_next_cost(&"oven_temperature"), 150,
		"Sev.1'den 2'ye geçiş maliyeti 150 olmalı")


func test_get_next_cost_maxed_returns_zero() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 3,
		[0.10, 0.25, 0.50] as Array[float])
	_inject(upgrade)
	_tree._levels[&"oven_temperature"] = 3
	assert_eq(_tree.get_next_cost(&"oven_temperature"), 0,
		"Maxed upgrade için maliyet 0 döndürmeli")


# ── AC: Satın alma akışı ──────────────────────────────────────────────────────

func test_purchase_increments_level() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	_tree.purchase(&"oven_temperature")
	assert_eq(_tree.get_current_level(&"oven_temperature"), 1)


func test_purchase_deducts_gold() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	var gold_before: int = _economy.gold_balance
	_tree.purchase(&"oven_temperature")
	assert_eq(_economy.gold_balance, gold_before - 50, "Satın alma altın düşmeli")


func test_purchase_emits_signal() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	watch_signals(_tree)
	_tree.purchase(&"oven_temperature")
	assert_signal_emitted_with_parameters(_tree, "upgrade_purchased",
		[&"oven_temperature", 1])


func test_purchase_returns_true_on_success() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	assert_true(_tree.purchase(&"oven_temperature"))


func test_purchase_blocked_insufficient_gold() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50000, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	var result := _tree.purchase(&"oven_temperature")
	assert_false(result, "Yetersiz altın ile satın alma reddedilmeli")


func test_purchase_blocked_gold_unchanged_on_failure() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50000, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	var gold_before: int = _economy.gold_balance
	_tree.purchase(&"oven_temperature")
	assert_eq(_economy.gold_balance, gold_before, "Başarısız satın almada altın değişmemeli")


func test_purchase_blocked_when_maxed() -> void:
	var upgrade := _make_upgrade(&"simple_upgrade", 50, 1,
		[0.10] as Array[float])
	_inject(upgrade)
	_tree.purchase(&"simple_upgrade")  # Level 0 → 1 (max)
	var result := _tree.purchase(&"simple_upgrade")  # Maxed → reddedilmeli
	assert_false(result, "Max seviyedeki upgrade satın alınamaz")


func test_is_maxed_false_at_level_zero() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	assert_false(_tree.is_maxed(&"oven_temperature"))


func test_is_maxed_true_after_max_purchases() -> void:
	var upgrade := _make_upgrade(&"simple_upgrade", 10, 2,
		[0.10, 0.20] as Array[float])
	_inject(upgrade)
	_tree.purchase(&"simple_upgrade")  # → level 1
	_tree._is_purchasing = false       # Kilidi manuel sıfırla (timer test'te çalışmaz)
	_tree.purchase(&"simple_upgrade")  # → level 2 (max)
	assert_true(_tree.is_maxed(&"simple_upgrade"), "Max seviyede is_maxed true olmalı")


# ── AC: Çift tap kilidi (GDD EC-2) ───────────────────────────────────────────

func test_double_tap_lock_second_purchase_rejected() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	_tree.purchase(&"oven_temperature")  # İlk satın alma → kilitler
	var result := _tree.purchase(&"oven_temperature")  # İkinci → kilitli
	assert_false(result, "Çift tap kilidi ikinci satın almayı engellemeli")


func test_double_tap_lock_level_not_incremented_twice() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	_tree.purchase(&"oven_temperature")
	_tree.purchase(&"oven_temperature")  # Kilitli; yoksayılmalı
	assert_eq(_tree.get_current_level(&"oven_temperature"), 1,
		"Çift tap sonrası seviye sadece 1 artmış olmalı")


# ── AC: Efekt hesabı ──────────────────────────────────────────────────────────

func test_get_current_effect_level_zero() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	assert_almost_eq(_tree.get_current_effect(&"oven_temperature"), 0.0, 0.001,
		"Seviye 0'da efekt 0.0 olmalı")


func test_get_current_effect_after_purchase() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	_tree.purchase(&"oven_temperature")
	assert_almost_eq(_tree.get_current_effect(&"oven_temperature"), 0.10, 0.001,
		"Sev.1 efekti 0.10 olmalı")


func test_get_next_effect_at_level_zero() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	assert_almost_eq(_tree.get_next_effect(&"oven_temperature"), 0.10, 0.001,
		"Sonraki seviye efekti 0.10 olmalı")


# ── AC: Rozet ile alınan upgrade ──────────────────────────────────────────────

func test_rozet_upgrade_deducts_rozet() -> void:
	var upgrade := _make_upgrade(&"vip_lounge", 1000, 1,
		[0.50] as Array[float], true,
		GameEnums.UpgradeCategory.CUSTOMER, GameEnums.UpgradeEffectType.VIP_RATE)
	_inject(upgrade)
	var rozet_before: int = _economy.rozet_balance
	_tree.purchase(&"vip_lounge")
	assert_eq(_economy.rozet_balance, rozet_before - 1000, "VIP Lounge Rozet düşmeli")


func test_rozet_upgrade_does_not_deduct_gold() -> void:
	var upgrade := _make_upgrade(&"vip_lounge", 1000, 1,
		[0.50] as Array[float], true,
		GameEnums.UpgradeCategory.CUSTOMER, GameEnums.UpgradeEffectType.VIP_RATE)
	_inject(upgrade)
	var gold_before: int = _economy.gold_balance
	_tree.purchase(&"vip_lounge")
	assert_eq(_economy.gold_balance, gold_before, "VIP Lounge altın düşmemeli")


# ── AC: CustomerConfig güncellemeleri ────────────────────────────────────────

func test_showcase_width_updates_max_active_orders() -> void:
	var sw := _make_upgrade(&"showcase_width", 200, 3,
		[2.0, 2.0, 2.0] as Array[float],
		false, GameEnums.UpgradeCategory.CUSTOMER,
		GameEnums.UpgradeEffectType.CUSTOMER_CAPACITY)
	_inject(sw)
	_tree.purchase(&"showcase_width")  # +2 slot
	assert_eq(_tree.customer_config.max_active_orders, 6,
		"showcase_width Sev.1 sonrası max_active_orders = 4+2 = 6")


func test_customer_satisfaction_updates_patience_multiplier() -> void:
	var cs := _make_upgrade(&"customer_satisfaction", 300, 3,
		[0.20, 0.20, 0.20] as Array[float],
		false, GameEnums.UpgradeCategory.CUSTOMER,
		GameEnums.UpgradeEffectType.PATIENCE)
	_inject(cs)
	_tree.purchase(&"customer_satisfaction")
	assert_almost_eq(_tree.customer_config.patience_multiplier, 1.20, 0.001,
		"customer_satisfaction Sev.1 sonrası patience_multiplier = 1.20")


func test_customer_config_changed_signal_emitted() -> void:
	var sw := _make_upgrade(&"showcase_width", 200, 3,
		[2.0, 2.0, 2.0] as Array[float],
		false, GameEnums.UpgradeCategory.CUSTOMER,
		GameEnums.UpgradeEffectType.CUSTOMER_CAPACITY)
	_inject(sw)
	watch_signals(_tree)
	_tree.purchase(&"showcase_width")
	assert_signal_emitted(_tree, "customer_config_changed")


# ── AC: ProductionConfig güncellemeleri ──────────────────────────────────────

func test_oven_temperature_updates_bake_speed() -> void:
	var ot := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(ot)
	_tree.purchase(&"oven_temperature")
	assert_almost_eq(_tree.production_config.bake_speed_multiplier, 1.10, 0.001,
		"oven_temperature Sev.1 sonrası bake_speed_multiplier = 1.10")


func test_oven_capacity_cumulative_effect() -> void:
	var oc := _make_upgrade(&"oven_capacity", 75, 3,
		[1.0, 2.0, 4.0] as Array[float])
	_inject(oc)
	_tree.purchase(&"oven_capacity")  # +1 → toplam 2
	assert_eq(_tree.production_config.oven_capacity, 2,
		"oven_capacity Sev.1 sonrası kapasite = 1+1 = 2")


func test_production_config_changed_signal_emitted() -> void:
	var ot := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(ot)
	watch_signals(_tree)
	_tree.purchase(&"oven_temperature")
	assert_signal_emitted(_tree, "production_config_changed")


# ── AC: Serialize / Deserialize ──────────────────────────────────────────────

func test_serialize_includes_levels() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	_tree.purchase(&"oven_temperature")
	var data := _tree.serialize()
	assert_eq((data.get("levels") as Dictionary).get(&"oven_temperature"), 1,
		"Serialize seviye bilgisini içermeli")


func test_deserialize_restores_level() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	_tree.deserialize({"levels": {&"oven_temperature": 3}})
	assert_eq(_tree.get_current_level(&"oven_temperature"), 3,
		"Deserialize sonrası seviye 3 olmalı")


func test_deserialize_restores_effects() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 5,
		[0.10, 0.25, 0.50, 0.80, 1.20] as Array[float])
	_inject(upgrade)
	_tree.deserialize({"levels": {&"oven_temperature": 2}})
	assert_almost_eq(_tree.production_config.bake_speed_multiplier, 1.25, 0.001,
		"Deserialize sonrası Sev.2 efekti = 1.25 uygulanmalı")


func test_deserialize_corrupt_level_clamped_to_max() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 3,
		[0.10, 0.25, 0.50] as Array[float])
	_inject(upgrade)
	_tree.deserialize({"levels": {&"oven_temperature": 99}})
	assert_eq(_tree.get_current_level(&"oven_temperature"), 3,
		"Bozuk kayıt (level>max) max_level'a sabitlenmeli")


func test_deserialize_unknown_upgrade_skipped() -> void:
	# Bilinmeyen upgrade → hata loglanır ama oyun çökmez
	_tree.deserialize({"levels": {&"ghost_upgrade": 2}})
	pass_test("Bilinmeyen upgrade ile deserialize crash vermedi")


func test_deserialize_negative_level_clamped_to_zero() -> void:
	var upgrade := _make_upgrade(&"oven_temperature", 50, 3,
		[0.10, 0.25, 0.50] as Array[float])
	_inject(upgrade)
	_tree.deserialize({"levels": {&"oven_temperature": -5}})
	assert_eq(_tree.get_current_level(&"oven_temperature"), 0,
		"Negatif kayıt 0'a sabitlenmeli")
