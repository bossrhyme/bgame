## GUT Test Suite — LocationSystem
## design/gdd/location-prestige-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_location_system.gd
extends GutTest


var _loc: LocationSystem
var _economy: EconomySystem
var _upgrade: UpgradeTree
var _recipe: RecipeManager
var _resolver: UnlockConditionResolver


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(99999, 9999)

	_upgrade = UpgradeTree.new()
	_upgrade._economy_ref = _economy
	_upgrade._registry_ref = null
	add_child_autofree(_upgrade)

	_recipe = RecipeManager.new()
	_recipe._registry_ref = null
	add_child_autofree(_recipe)

	_resolver = UnlockConditionResolver.new()
	add_child_autofree(_resolver)

	_loc = LocationSystem.new()
	_loc._economy_ref = _economy
	_loc._upgrade_ref = _upgrade
	_loc._recipe_ref = _recipe
	_loc._resolver_ref = _resolver
	add_child_autofree(_loc)


# ── Başlangıç durumu ──────────────────────────────────────────────────────────

func test_start_location_always_unlocked() -> void:
	assert_true(_loc.is_location_unlocked(&"start"))


func test_other_locations_locked_initially() -> void:
	assert_false(_loc.is_location_unlocked(&"inner_anatolia"))
	assert_false(_loc.is_location_unlocked(&"istanbul"))
	assert_false(_loc.is_location_unlocked(&"paris"))
	assert_false(_loc.is_location_unlocked(&"rome"))


func test_initial_prestige_count_is_zero() -> void:
	assert_eq(_loc.prestige_count, 0)


func test_can_prestige_false_initially() -> void:
	assert_false(_loc.can_prestige())


# ── İç Anadolu açma koşulu ────────────────────────────────────────────────────

func test_inner_anatolia_unlocks_with_50_basic_sales() -> void:
	for i: int in range(50):
		_loc.record_category_sale(&"basic")

	var ok: bool = _loc.try_unlock_location(&"inner_anatolia")
	assert_true(ok, "50 basic satış → inner_anatolia açılır")
	assert_true(_loc.is_location_unlocked(&"inner_anatolia"))


func test_inner_anatolia_fails_with_49_basic_sales() -> void:
	for i: int in range(49):
		_loc.record_category_sale(&"basic")

	var ok: bool = _loc.try_unlock_location(&"inner_anatolia")
	assert_false(ok, "49 basic satış → yetersiz")
	assert_false(_loc.is_location_unlocked(&"inner_anatolia"))


# ── Sıralı açılma ────────────────────────────────────────────────────────────

func test_istanbul_cannot_unlock_before_inner_anatolia() -> void:
	for i: int in range(100):
		_loc.record_category_sale(&"wheat")
	_upgrade._levels[&"oven_capacity"] = 2

	var ok: bool = _loc.try_unlock_location(&"istanbul")
	assert_false(ok, "İç Anadolu açılmadan İstanbul açılamaz")


func test_locations_unlock_in_order() -> void:
	# inner_anatolia
	for i: int in range(50):
		_loc.record_category_sale(&"basic")
	_loc.try_unlock_location(&"inner_anatolia")

	# istanbul: wheat sales + oven_capacity >= 2
	for i: int in range(100):
		_loc.record_category_sale(&"wheat")
	_upgrade._levels[&"oven_capacity"] = 2
	_loc.try_unlock_location(&"istanbul")

	assert_true(_loc.is_location_unlocked(&"inner_anatolia"))
	assert_true(_loc.is_location_unlocked(&"istanbul"))
	assert_false(_loc.is_location_unlocked(&"paris"))


# ── İstanbul açma koşulları (AND) ────────────────────────────────────────────

func test_istanbul_requires_wheat_sales_and_oven_capacity() -> void:
	for i: int in range(50):
		_loc.record_category_sale(&"basic")
	_loc.try_unlock_location(&"inner_anatolia")

	# Sadece satış yeterli değil
	for i: int in range(100):
		_loc.record_category_sale(&"wheat")
	var ok_no_upgrade: bool = _loc.try_unlock_location(&"istanbul")
	assert_false(ok_no_upgrade, "Upgrade olmadan İstanbul açılamaz")

	# Upgrade eklendi → açılır
	_upgrade._levels[&"oven_capacity"] = 2
	var ok_with_upgrade: bool = _loc.try_unlock_location(&"istanbul")
	assert_true(ok_with_upgrade, "Hem satış hem upgrade → İstanbul açılır")


# ── Paris açma koşulları ──────────────────────────────────────────────────────

func test_paris_requires_sweet_sales_and_showcase_width() -> void:
	_loc._unlocked[&"inner_anatolia"] = true
	_loc._unlocked[&"istanbul"] = true
	_loc._category_sales[&"sweet"] = 150
	# Showcase_width eksik → başarısız
	var ok1: bool = _loc.try_unlock_location(&"paris")
	assert_false(ok1)

	_upgrade._levels[&"showcase_width"] = 1
	var ok2: bool = _loc.try_unlock_location(&"paris")
	assert_true(ok2)


# ── Roma açma koşulları ───────────────────────────────────────────────────────

func test_rome_requires_french_sales_and_prestige_count_1() -> void:
	_loc._unlocked[&"inner_anatolia"] = true
	_loc._unlocked[&"istanbul"] = true
	_loc._unlocked[&"paris"] = true
	_loc._category_sales[&"french"] = 200
	# prestige_count = 0 → başarısız
	var ok1: bool = _loc.try_unlock_location(&"rome")
	assert_false(ok1, "Prestij yokken Roma açılamaz")

	_loc._prestige_count = 1
	var ok2: bool = _loc.try_unlock_location(&"rome")
	assert_true(ok2)


# ── Sinyal yayımı ─────────────────────────────────────────────────────────────

func test_try_unlock_emits_location_unlocked_signal() -> void:
	for i: int in range(50):
		_loc.record_category_sale(&"basic")

	watch_signals(_loc)
	_loc.try_unlock_location(&"inner_anatolia")

	assert_signal_emitted(_loc, "location_unlocked")


func test_try_unlock_already_open_returns_false() -> void:
	_loc._unlocked[&"inner_anatolia"] = true
	var ok: bool = _loc.try_unlock_location(&"inner_anatolia")
	assert_false(ok, "Zaten açık lokasyon tekrar açılamaz")


# ── get_next_locked_location ──────────────────────────────────────────────────

func test_get_next_locked_returns_inner_anatolia_initially() -> void:
	assert_eq(_loc.get_next_locked_location(), &"inner_anatolia")


func test_get_next_locked_returns_empty_when_all_unlocked() -> void:
	for loc: StringName in LocationSystem.LOCATION_ORDER:
		_loc._unlocked[loc] = true
	assert_eq(_loc.get_next_locked_location(), &"")


# ── Prestij ───────────────────────────────────────────────────────────────────

func test_prestige_fails_without_rome() -> void:
	var ok: bool = _loc.do_prestige()
	assert_false(ok)


func test_prestige_succeeds_when_rome_unlocked() -> void:
	for loc: StringName in LocationSystem.LOCATION_ORDER:
		_loc._unlocked[loc] = true

	var ok: bool = _loc.do_prestige()
	assert_true(ok)


func test_prestige_resets_gold_to_zero() -> void:
	for loc: StringName in LocationSystem.LOCATION_ORDER:
		_loc._unlocked[loc] = true

	_loc.do_prestige()
	assert_eq(_economy.gold_balance, 0)


func test_prestige_preserves_rozet() -> void:
	for loc: StringName in LocationSystem.LOCATION_ORDER:
		_loc._unlocked[loc] = true

	_loc.do_prestige()
	# Rozet: 9999 başlangıç + 10 × 1 (prestige bonus) = 10009
	assert_eq(_economy.rozet_balance, 9999 + 10)


func test_prestige_increments_count() -> void:
	for loc: StringName in LocationSystem.LOCATION_ORDER:
		_loc._unlocked[loc] = true

	_loc.do_prestige()
	assert_eq(_loc.prestige_count, 1)


func test_prestige_rozet_bonus_formula() -> void:
	for loc: StringName in LocationSystem.LOCATION_ORDER:
		_loc._unlocked[loc] = true

	_economy.initialize(0, 0)

	_loc.do_prestige()  # n=1 → bonus=10
	assert_eq(_economy.rozet_balance, 10)

	# Tekrar prestige (Roma tekrar açık yapılmalı)
	for loc: StringName in LocationSystem.LOCATION_ORDER:
		_loc._unlocked[loc] = true
	_loc.do_prestige()  # n=2 → bonus=20
	assert_eq(_economy.rozet_balance, 30, "n=1 (10) + n=2 (20) = 30")


func test_prestige_resets_locations_to_start_only() -> void:
	for loc: StringName in LocationSystem.LOCATION_ORDER:
		_loc._unlocked[loc] = true

	_loc.do_prestige()

	assert_true(_loc.is_location_unlocked(&"start"))
	assert_false(_loc.is_location_unlocked(&"inner_anatolia"))
	assert_false(_loc.is_location_unlocked(&"rome"))


func test_prestige_emits_signal() -> void:
	for loc: StringName in LocationSystem.LOCATION_ORDER:
		_loc._unlocked[loc] = true

	watch_signals(_loc)
	_loc.do_prestige()

	assert_signal_emitted(_loc, "prestige_completed")


# ── Serialize / Deserialize ────────────────────────────────────────────────────

func test_serialize_preserves_state() -> void:
	_loc._unlocked[&"inner_anatolia"] = true
	_loc._category_sales[&"basic"] = 75
	_loc._prestige_count = 2

	var data: Dictionary = _loc.serialize()
	assert_eq(data["prestige_count"], 2)
	assert_true(data["unlocked_locations"].get(&"inner_anatolia", false))
	assert_eq(data["category_sales"].get(&"basic", 0), 75)


func test_deserialize_restores_state() -> void:
	var data: Dictionary = {
		"unlocked_locations": {&"start": true, &"inner_anatolia": true},
		"category_sales": {&"basic": 60},
		"prestige_count": 1,
	}
	_loc.deserialize(data)

	assert_eq(_loc.prestige_count, 1)
	assert_true(_loc.is_location_unlocked(&"inner_anatolia"))
	assert_eq(_loc.get_category_sale_count(&"basic"), 60)


func test_deserialize_always_keeps_start_unlocked() -> void:
	_loc.deserialize({"unlocked_locations": {}, "category_sales": {}, "prestige_count": 0})
	assert_true(_loc.is_location_unlocked(&"start"))


func test_deserialize_clamps_negative_prestige_count() -> void:
	_loc.deserialize({"prestige_count": -5})
	assert_eq(_loc.prestige_count, 0)
