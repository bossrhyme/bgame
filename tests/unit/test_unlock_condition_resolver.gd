## GUT Test Suite — UnlockConditionResolver
## design/gdd/recipe-system.md — Unlock Conditions
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_unlock_condition_resolver.gd
extends GutTest


var resolver: UnlockConditionResolver
var recipe_mgr: RecipeManager


func before_each() -> void:
	resolver = UnlockConditionResolver.new()
	add_child(resolver)


func after_each() -> void:
	if is_instance_valid(resolver):
		resolver.queue_free()
	if is_instance_valid(recipe_mgr):
		recipe_mgr.queue_free()


# ── Yardımcı ─────────────────────────────────────────────────────────────────

func _make_condition(type: UnlockCondition.ConditionType) -> UnlockCondition:
	var cond := UnlockCondition.new()
	cond.condition_type = type
	return cond


# ── evaluate: SALE_COUNT ─────────────────────────────────────────────────────

func test_sale_count_returns_false_before_threshold() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond.required_count = 5
	cond.target_category = &""

	# Act: 4 satış → eşik altında
	for _i in range(4):
		resolver.record_sale(&"ekmek")

	# Assert
	assert_false(resolver.evaluate(cond), "4 satış / eşik 5 → false")


func test_sale_count_returns_true_at_threshold() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond.required_count = 5
	cond.target_category = &""

	# Act: tam 5 satış
	for _i in range(5):
		resolver.record_sale(&"ekmek")

	# Assert
	assert_true(resolver.evaluate(cond), "5 satış / eşik 5 → true")


func test_sale_count_returns_true_above_threshold() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond.required_count = 3
	cond.target_category = &""

	# Act: 10 satış >> eşik 3
	for _i in range(10):
		resolver.record_sale(&"simit")

	# Assert
	assert_true(resolver.evaluate(cond), "10 satış / eşik 3 → true")


func test_sale_count_specific_category_ignores_other_recipes() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond.required_count = 3
	cond.target_category = &"pogaca"  # yalnızca poğaça satışı

	# Act: 10 ekmek, 0 poğaça
	for _i in range(10):
		resolver.record_sale(&"ekmek")

	# Assert
	assert_false(resolver.evaluate(cond), "Ekmek satışları poğaça sayılmaz → false")


func test_sale_count_specific_category_counts_correctly() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond.required_count = 3
	cond.target_category = &"pogaca"

	# Act: 3 poğaça
	for _i in range(3):
		resolver.record_sale(&"pogaca")

	# Assert
	assert_true(resolver.evaluate(cond), "3 poğaça / eşik 3 → true")


func test_sale_count_empty_category_sums_all_recipes() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond.required_count = 5
	cond.target_category = &""  # toplam

	# Act: 3 ekmek + 2 simit = 5 toplam
	for _i in range(3):
		resolver.record_sale(&"ekmek")
	for _i in range(2):
		resolver.record_sale(&"simit")

	# Assert
	assert_true(resolver.evaluate(cond), "3+2=5 toplam / eşik 5 → true")


# ── evaluate: LOCATION_UNLOCKED ───────────────────────────────────────────────

func test_location_unlocked_returns_false_if_not_unlocked() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.LOCATION_UNLOCKED)
	cond.required_location_id = &"pazar"

	# Assert: açılmamış lokasyon → false
	assert_false(resolver.evaluate(cond), "Açılmamış lokasyon → false")


func test_location_unlocked_returns_true_after_unlock() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.LOCATION_UNLOCKED)
	cond.required_location_id = &"pazar"

	# Act
	resolver.unlock_location(&"pazar")

	# Assert
	assert_true(resolver.evaluate(cond), "Açılmış lokasyon → true")


func test_location_unlocked_wrong_location_returns_false() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.LOCATION_UNLOCKED)
	cond.required_location_id = &"carsi"

	# Act: farklı lokasyon açıldı
	resolver.unlock_location(&"pazar")

	# Assert
	assert_false(resolver.evaluate(cond), "Farklı lokasyon açıldı → false")


# ── evaluate: INGREDIENT_OWNED ───────────────────────────────────────────────

func test_ingredient_owned_returns_false_without_recipe_manager() -> void:
	# Arrange: recipe_ref yok
	var cond := _make_condition(UnlockCondition.ConditionType.INGREDIENT_OWNED)
	cond.required_ingredient_id = &"ozel_un"

	# Assert: RecipeManager yoksa false (güvenli varsayılan)
	assert_false(resolver.evaluate(cond), "RecipeManager yok → false")


func test_ingredient_owned_returns_false_when_stock_is_zero() -> void:
	# Arrange
	recipe_mgr = RecipeManager.new()
	add_child(recipe_mgr)
	resolver._recipe_ref = recipe_mgr
	var cond := _make_condition(UnlockCondition.ConditionType.INGREDIENT_OWNED)
	cond.required_ingredient_id = &"ozel_un"

	# Assert: stok 0 → false
	assert_false(resolver.evaluate(cond), "Stok 0 → INGREDIENT_OWNED false")


func test_ingredient_owned_returns_true_when_stock_positive() -> void:
	# Arrange
	recipe_mgr = RecipeManager.new()
	add_child(recipe_mgr)
	resolver._recipe_ref = recipe_mgr
	recipe_mgr.add_ingredient(&"ozel_un", 1)
	var cond := _make_condition(UnlockCondition.ConditionType.INGREDIENT_OWNED)
	cond.required_ingredient_id = &"ozel_un"

	# Assert: stok > 0 → true
	assert_true(resolver.evaluate(cond), "Stok > 0 → INGREDIENT_OWNED true")


# ── evaluate_all ─────────────────────────────────────────────────────────────

func test_evaluate_all_empty_conditions_returns_true() -> void:
	# Boş koşul dizisi → her zaman açık
	var conditions: Array[UnlockCondition] = []
	assert_true(resolver.evaluate_all(conditions), "Boş dizi → true")


func test_evaluate_all_all_met_returns_true() -> void:
	# Arrange: 2 koşul, ikisi de karşılanmış
	var cond1 := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond1.required_count = 2
	cond1.target_category = &""
	var cond2 := _make_condition(UnlockCondition.ConditionType.LOCATION_UNLOCKED)
	cond2.required_location_id = &"pazar"

	resolver.record_sale(&"ekmek")
	resolver.record_sale(&"ekmek")
	resolver.unlock_location(&"pazar")

	var conditions: Array[UnlockCondition] = [cond1, cond2]

	# Assert
	assert_true(resolver.evaluate_all(conditions), "Her iki koşul karşılandı → true")


func test_evaluate_all_one_unmet_returns_false() -> void:
	# Arrange: cond1 karşılandı, cond2 karşılanmadı
	var cond1 := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond1.required_count = 1
	cond1.target_category = &""
	var cond2 := _make_condition(UnlockCondition.ConditionType.LOCATION_UNLOCKED)
	cond2.required_location_id = &"carsi"  # açılmamış

	resolver.record_sale(&"ekmek")

	var conditions: Array[UnlockCondition] = [cond1, cond2]

	# Assert
	assert_false(resolver.evaluate_all(conditions), "Bir koşul karşılanmadı → false")


# ── watch / conditions_met sinyali ───────────────────────────────────────────

func test_watch_empty_conditions_emits_immediately() -> void:
	# Arrange
	var emitted := false
	resolver.conditions_met.connect(func(_id: StringName) -> void: emitted = true)

	# Act
	resolver.watch(&"kolay_tarif", [])

	# Assert
	assert_true(emitted, "Boş koşul → conditions_met anında yayıldı")


func test_watch_emits_conditions_met_when_sale_threshold_reached() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond.required_count = 3
	cond.target_category = &""
	var conditions: Array[UnlockCondition] = [cond]

	var met_id: StringName = &""
	resolver.conditions_met.connect(func(id: StringName) -> void: met_id = id)
	resolver.watch(&"yeni_tarif", conditions)

	# Act: 2 satış → henüz karşılanmadı
	resolver.record_sale(&"ekmek")
	resolver.record_sale(&"ekmek")
	assert_eq(met_id, &"", "2 satışta sinyal yok")

	# Act: 3. satış → koşul karşılandı
	resolver.record_sale(&"ekmek")

	# Assert
	assert_eq(met_id, &"yeni_tarif", "conditions_met → recipe_id doğru")


func test_watch_stops_after_conditions_met() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond.required_count = 1
	cond.target_category = &""
	var conditions: Array[UnlockCondition] = [cond]

	var emit_count: int = 0
	resolver.conditions_met.connect(func(_id: StringName) -> void: emit_count += 1)
	resolver.watch(&"tarif_a", conditions)

	# Act: 3 satış (koşul 1. satışta karşılandı, sonraki satışlar tekrar sinyal vermemeli)
	resolver.record_sale(&"ekmek")
	resolver.record_sale(&"ekmek")
	resolver.record_sale(&"ekmek")

	# Assert: sinyal yalnızca bir kez yayıldı
	assert_eq(emit_count, 1, "watch karşılandıktan sonra sinyal tekrarlanmaz")


func test_watch_location_unlock_triggers_conditions_met() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.LOCATION_UNLOCKED)
	cond.required_location_id = &"pazar"
	var conditions: Array[UnlockCondition] = [cond]

	var met_id: StringName = &""
	resolver.conditions_met.connect(func(id: StringName) -> void: met_id = id)
	resolver.watch(&"pazar_tarifi", conditions)

	# Act
	resolver.unlock_location(&"pazar")

	# Assert
	assert_eq(met_id, &"pazar_tarifi", "Lokasyon açılınca conditions_met yayıldı")


# ── reset ─────────────────────────────────────────────────────────────────────

func test_reset_clears_sale_counts() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.SALE_COUNT)
	cond.required_count = 2
	cond.target_category = &""
	for _i in range(5):
		resolver.record_sale(&"ekmek")
	assert_true(resolver.evaluate(cond), "Reset öncesi koşul karşılanmış")

	# Act
	resolver.reset()

	# Assert
	assert_false(resolver.evaluate(cond), "Reset sonrası sayaç sıfırlandı → false")


func test_reset_clears_unlocked_locations() -> void:
	# Arrange
	var cond := _make_condition(UnlockCondition.ConditionType.LOCATION_UNLOCKED)
	cond.required_location_id = &"pazar"
	resolver.unlock_location(&"pazar")
	assert_true(resolver.evaluate(cond), "Reset öncesi lokasyon açık")

	# Act
	resolver.reset()

	# Assert
	assert_false(resolver.evaluate(cond), "Reset sonrası lokasyon temizlendi → false")
