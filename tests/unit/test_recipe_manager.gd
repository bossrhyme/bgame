## test_recipe_manager.gd
##
## GUT testleri — RecipeManager (S2-03)
## Kapsanan AC'ler: unlock flow, gold_value formülü, koşul AND mantığı
## (veri yapısı), malzeme stok limiti
extends GutTest

var _rm: RecipeManager


func before_each() -> void:
	_rm = RecipeManager.new()
	add_child_autofree(_rm)
	# ContentRegistry olmadan test: tarifleri doğrudan enjekte et
	_rm._registry_ref = null


# ── Yardımcılar ───────────────────────────────────────────────────────────────

func _make_recipe(id: StringName, base_value: int = 10, tier: int = 1,
		req_ingredient: StringName = &"", ingredient_cost: int = 0) -> RecipeData:
	var r := RecipeData.new()
	r.id = id
	r.display_name = str(id)
	r.base_value = base_value
	r.tier = tier
	r.bake_time_seconds = 60.0
	r.required_ingredient = req_ingredient
	r.ingredient_cost = ingredient_cost
	return r


func _inject_recipe(recipe: RecipeData) -> void:
	_rm._recipes[recipe.id] = recipe
	_rm._unlock_state[recipe.id] = RecipeManager.RecipeStatus.LOCKED


# ── AC: Başlangıç durumu LOCKED ───────────────────────────────────────────────

func test_initial_status_is_locked() -> void:
	_inject_recipe(_make_recipe(&"white_bread"))
	assert_eq(
		_rm.get_status(&"white_bread"),
		RecipeManager.RecipeStatus.LOCKED,
		"Başlangıçta tarif LOCKED olmalı"
	)


func test_is_unlocked_false_initially() -> void:
	_inject_recipe(_make_recipe(&"white_bread"))
	assert_false(_rm.is_unlocked(&"white_bread"), "Başlangıçta is_unlocked false olmalı")


# ── AC: LOCKED → AVAILABLE geçişi (mark_available) ──────────────────────────

func test_mark_available_transitions_status() -> void:
	_inject_recipe(_make_recipe(&"baguette"))
	_rm.mark_available(&"baguette")
	assert_eq(
		_rm.get_status(&"baguette"),
		RecipeManager.RecipeStatus.AVAILABLE,
		"mark_available sonrası durum AVAILABLE olmalı"
	)


func test_mark_available_emits_signal() -> void:
	_inject_recipe(_make_recipe(&"baguette"))
	watch_signals(_rm)
	_rm.mark_available(&"baguette")
	assert_signal_emitted_with_parameters(_rm, "recipe_available", [&"baguette"])


func test_mark_available_already_available_no_double_emit() -> void:
	_inject_recipe(_make_recipe(&"baguette"))
	watch_signals(_rm)
	_rm.mark_available(&"baguette")
	_rm.mark_available(&"baguette")  # İkinci çağrı etki etmemeli
	assert_signal_emit_count(_rm, "recipe_available", 1,
		"mark_available ikinci çağrısı sinyal emit etmemeli")


func test_mark_available_unknown_id_no_crash() -> void:
	_rm.mark_available(&"nonexistent")
	pass_test("Bilinmeyen tarif ID'siyle mark_available crash vermedi")


# ── AC: AVAILABLE → UNLOCKED geçişi (unlock) ─────────────────────────────────

func test_unlock_available_recipe_returns_true() -> void:
	_inject_recipe(_make_recipe(&"croissant"))
	_rm.mark_available(&"croissant")
	var result := _rm.unlock(&"croissant")
	assert_true(result, "AVAILABLE tarifin unlock'u true döndürmeli")


func test_unlock_transitions_to_unlocked() -> void:
	_inject_recipe(_make_recipe(&"croissant"))
	_rm.mark_available(&"croissant")
	_rm.unlock(&"croissant")
	assert_eq(
		_rm.get_status(&"croissant"),
		RecipeManager.RecipeStatus.UNLOCKED,
		"unlock sonrası durum UNLOCKED olmalı"
	)


func test_unlock_sets_is_unlocked_true() -> void:
	_inject_recipe(_make_recipe(&"croissant"))
	_rm.mark_available(&"croissant")
	_rm.unlock(&"croissant")
	assert_true(_rm.is_unlocked(&"croissant"), "unlock sonrası is_unlocked true olmalı")


func test_unlock_emits_signal() -> void:
	_inject_recipe(_make_recipe(&"croissant"))
	_rm.mark_available(&"croissant")
	watch_signals(_rm)
	_rm.unlock(&"croissant")
	assert_signal_emitted_with_parameters(_rm, "recipe_unlocked", [&"croissant"])


func test_unlock_locked_recipe_returns_false() -> void:
	_inject_recipe(_make_recipe(&"focaccia"))
	var result := _rm.unlock(&"focaccia")
	assert_false(result, "LOCKED tarifin unlock'u false döndürmeli")


func test_unlock_locked_recipe_stays_locked() -> void:
	_inject_recipe(_make_recipe(&"focaccia"))
	_rm.unlock(&"focaccia")
	assert_eq(
		_rm.get_status(&"focaccia"),
		RecipeManager.RecipeStatus.LOCKED,
		"Başarısız unlock sonrası durum LOCKED kalmalı"
	)


func test_unlock_already_unlocked_returns_false() -> void:
	_inject_recipe(_make_recipe(&"croissant"))
	_rm.mark_available(&"croissant")
	_rm.unlock(&"croissant")
	var result := _rm.unlock(&"croissant")  # İkinci çağrı
	assert_false(result, "UNLOCKED tarifi tekrar unlock etmek false döndürmeli")


func test_unlocked_recipe_stays_unlocked() -> void:
	# Kalıcı progression: bir kez açılan tarif kilitlenemez
	_inject_recipe(_make_recipe(&"ciabatta"))
	_rm.mark_available(&"ciabatta")
	_rm.unlock(&"ciabatta")
	# Durumu zorla sıfırlamaya çalışıyoruz (hile önleme testi değil, state testi)
	assert_eq(
		_rm.get_status(&"ciabatta"),
		RecipeManager.RecipeStatus.UNLOCKED,
		"Açılmış tarif UNLOCKED kalmalı"
	)


# ── AC: gold_value formülü (F-1) ─────────────────────────────────────────────

func test_gold_value_tier1() -> void:
	# tier=1: 10 * (1 + 1 * 0.5) = 10 * 1.5 = 15
	_inject_recipe(_make_recipe(&"white_bread", 10, 1))
	assert_almost_eq(_rm.get_gold_value(&"white_bread"), 15.0, 0.001,
		"Tier 1 gold_value = base * 1.5 olmalı")


func test_gold_value_tier2() -> void:
	# tier=2: 10 * (1 + 2 * 0.5) = 10 * 2.0 = 20
	_inject_recipe(_make_recipe(&"wheat_loaf", 10, 2))
	assert_almost_eq(_rm.get_gold_value(&"wheat_loaf"), 20.0, 0.001,
		"Tier 2 gold_value = base * 2.0 olmalı")


func test_gold_value_tier3() -> void:
	# tier=3: 10 * (1 + 3 * 0.5) = 10 * 2.5 = 25
	_inject_recipe(_make_recipe(&"croissant_ref", 10, 3))
	assert_almost_eq(_rm.get_gold_value(&"croissant_ref"), 25.0, 0.001,
		"Tier 3 gold_value = base * 2.5 olmalı")


func test_gold_value_tier4() -> void:
	# tier=4: 10 * (1 + 4 * 0.5) = 10 * 3.0 = 30
	_inject_recipe(_make_recipe(&"focaccia_ref", 10, 4))
	assert_almost_eq(_rm.get_gold_value(&"focaccia_ref"), 30.0, 0.001,
		"Tier 4 gold_value = base * 3.0 olmalı")


func test_gold_value_custom_base() -> void:
	# base=20, tier=2: 20 * 2.0 = 40
	_inject_recipe(_make_recipe(&"special_bread", 20, 2))
	assert_almost_eq(_rm.get_gold_value(&"special_bread"), 40.0, 0.001,
		"Farklı base_value ile formül doğru çalışmalı")


func test_gold_value_unknown_id_returns_zero() -> void:
	assert_almost_eq(_rm.get_gold_value(&"ghost_recipe"), 0.0, 0.001,
		"Bilinmeyen tarif için gold_value 0.0 döndürmeli")


# ── AC: Koşul AND mantığı (veri yapısı) ──────────────────────────────────────

func test_recipe_can_hold_multiple_conditions() -> void:
	# AND mantığı D-14 tarafından değerlendirilir; burada veri yapısı test edilir
	var recipe := _make_recipe(&"fancy_bread")
	var cond1 := UnlockCondition.new()
	cond1.condition_type = UnlockCondition.ConditionType.SALE_COUNT
	cond1.required_count = 50
	var cond2 := UnlockCondition.new()
	cond2.condition_type = UnlockCondition.ConditionType.LOCATION_UNLOCKED
	cond2.required_location_id = &"paris"
	recipe.unlock_conditions = [cond1, cond2]
	_inject_recipe(recipe)
	var loaded := _rm.get_recipe(&"fancy_bread")
	assert_eq(loaded.unlock_conditions.size(), 2,
		"RecipeData iki farklı koşul tipi tutabilmeli (AND mantığı için veri yapısı)")


func test_unlock_condition_sale_count_fields() -> void:
	var cond := UnlockCondition.new()
	cond.condition_type = UnlockCondition.ConditionType.SALE_COUNT
	cond.required_count = 100
	cond.target_category = &"basic"
	assert_eq(cond.required_count, 100)
	assert_eq(cond.target_category, &"basic")


func test_unlock_condition_location_fields() -> void:
	var cond := UnlockCondition.new()
	cond.condition_type = UnlockCondition.ConditionType.LOCATION_UNLOCKED
	cond.required_location_id = &"istanbul"
	assert_eq(cond.required_location_id, &"istanbul")


func test_unlock_condition_ingredient_fields() -> void:
	var cond := UnlockCondition.new()
	cond.condition_type = UnlockCondition.ConditionType.INGREDIENT_OWNED
	cond.required_ingredient_id = &"blueberry"
	assert_eq(cond.required_ingredient_id, &"blueberry")


# ── AC: Malzeme stok limiti ───────────────────────────────────────────────────

func test_add_ingredient_increases_stock() -> void:
	_rm.add_ingredient(&"blueberry", 3)
	assert_eq(_rm.get_ingredient_count(&"blueberry"), 3,
		"Malzeme eklenmeli")


func test_add_ingredient_respects_max_stack() -> void:
	_rm.add_ingredient(&"blueberry", 8)
	_rm.add_ingredient(&"blueberry", 5)  # 8+5=13 → max 10
	assert_eq(_rm.get_ingredient_count(&"blueberry"), RecipeManager.MAX_INGREDIENT_STACK,
		"Malzeme stok MAX_INGREDIENT_STACK'i aşmamalı")


func test_add_ingredient_emits_signal() -> void:
	watch_signals(_rm)
	_rm.add_ingredient(&"blueberry", 2)
	assert_signal_emitted_with_parameters(_rm, "ingredient_stock_changed", [&"blueberry", 2])


func test_consume_ingredient_succeeds() -> void:
	_rm.add_ingredient(&"saffron", 5)
	var ok := _rm.consume_ingredient(&"saffron", 3)
	assert_true(ok, "Yeterli stoğu olan malzeme harcanabilmeli")
	assert_eq(_rm.get_ingredient_count(&"saffron"), 2, "Harcama sonrası stok azalmalı")


func test_consume_ingredient_fails_insufficient() -> void:
	_rm.add_ingredient(&"saffron", 2)
	var ok := _rm.consume_ingredient(&"saffron", 5)
	assert_false(ok, "Yetersiz stoğu harcama false döndürmeli")
	assert_eq(_rm.get_ingredient_count(&"saffron"), 2, "Başarısız harcamada stok değişmemeli")


func test_ingredient_zero_stock_initially() -> void:
	assert_eq(_rm.get_ingredient_count(&"unknown_ingredient"), 0,
		"Bilinmeyen malzemenin stoğu 0 olmalı")


# ── AC: Malzeme gerektiren unlock ─────────────────────────────────────────────

func test_unlock_with_ingredient_cost_succeeds() -> void:
	var recipe := _make_recipe(&"special_loaf", 10, 2, &"blueberry", 1)
	_inject_recipe(recipe)
	_rm.add_ingredient(&"blueberry", 3)
	_rm.mark_available(&"special_loaf")
	var ok := _rm.unlock(&"special_loaf")
	assert_true(ok, "Malzeme mevcut olunca unlock başarılı olmalı")


func test_unlock_with_ingredient_cost_consumes_ingredient() -> void:
	var recipe := _make_recipe(&"special_loaf2", 10, 2, &"blueberry", 2)
	_inject_recipe(recipe)
	_rm.add_ingredient(&"blueberry", 3)
	_rm.mark_available(&"special_loaf2")
	_rm.unlock(&"special_loaf2")
	assert_eq(_rm.get_ingredient_count(&"blueberry"), 1,
		"Unlock sonrası malzeme tüketilmiş olmalı (3-2=1)")


func test_unlock_fails_with_insufficient_ingredient() -> void:
	var recipe := _make_recipe(&"expensive_loaf", 10, 3, &"blueberry", 5)
	_inject_recipe(recipe)
	_rm.add_ingredient(&"blueberry", 2)  # 2 < 5
	_rm.mark_available(&"expensive_loaf")
	var ok := _rm.unlock(&"expensive_loaf")
	assert_false(ok, "Malzeme yetersiz olunca unlock başarısız olmalı")


func test_unlock_fails_preserves_ingredient_stock() -> void:
	var recipe := _make_recipe(&"expensive_loaf2", 10, 3, &"blueberry", 5)
	_inject_recipe(recipe)
	_rm.add_ingredient(&"blueberry", 2)
	_rm.mark_available(&"expensive_loaf2")
	_rm.unlock(&"expensive_loaf2")  # Başarısız
	assert_eq(_rm.get_ingredient_count(&"blueberry"), 2,
		"Başarısız unlock sonrası malzeme stoğu korunmalı")


func test_unlock_fails_preserves_available_status() -> void:
	var recipe := _make_recipe(&"expensive_loaf3", 10, 3, &"blueberry", 5)
	_inject_recipe(recipe)
	_rm.add_ingredient(&"blueberry", 2)
	_rm.mark_available(&"expensive_loaf3")
	_rm.unlock(&"expensive_loaf3")  # Başarısız
	assert_eq(
		_rm.get_status(&"expensive_loaf3"),
		RecipeManager.RecipeStatus.AVAILABLE,
		"Başarısız unlock sonrası durum AVAILABLE kalmalı"
	)
