## GUT Test Suite — ContentRegistry
## GDD #2 Acceptance Criteria: AC-1 – AC-10
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_content_registry.gd
extends GutTest

# ContentRegistry'yi doğrudan test etmek yerine iç mantığı mock verilerle test ederiz.
# Godot editörü olmadan .tres dosyaları yüklenemeyeceğinden entegrasyon testleri
# ayrı bir test koşumunda çalıştırılır (integration/test_content_registry_integration.gd).

var registry: ContentRegistry


func before_each() -> void:
	registry = ContentRegistry.new()
	add_child(registry)


func after_each() -> void:
	registry.free()


# ── Bilinmeyen ID testleri (AC-3) ─────────────────────────────────────────────

# AC-3: get_recipe bilinmeyen id → null, çökme yok
func test_get_recipe_unknown_id_returns_null() -> void:
	var result = registry.get_recipe(&"nonexistent_recipe")
	assert_null(result, "Bilinmeyen tarif id → null")


# AC-3: get_upgrade bilinmeyen id → null
func test_get_upgrade_unknown_id_returns_null() -> void:
	var result = registry.get_upgrade(&"nonexistent_upgrade")
	assert_null(result, "Bilinmeyen upgrade id → null")


# AC-3: get_employee bilinmeyen id → null
func test_get_employee_unknown_id_returns_null() -> void:
	var result = registry.get_employee(&"nonexistent_employee")
	assert_null(result, "Bilinmeyen çalışan id → null")


# AC-3: get_location bilinmeyen id → null
func test_get_location_unknown_id_returns_null() -> void:
	var result = registry.get_location(&"nonexistent_location")
	assert_null(result, "Bilinmeyen lokasyon id → null")


# AC-3: get_customer_type bilinmeyen id → null
func test_get_customer_type_unknown_id_returns_null() -> void:
	var result = registry.get_customer_type(&"nonexistent_type")
	assert_null(result, "Bilinmeyen müşteri tipi id → null")


# ── Boş kayıt listeleri (AC-8 — boş başlangıç) ───────────────────────────────

func test_get_all_recipes_empty_registry_returns_empty_array() -> void:
	var result: Array = registry.get_all_recipes()
	assert_not_null(result, "get_all_recipes() null dönemez")
	# Boş registry'de 0 kayıt — çökme yok
	assert_true(result is Array, "Array dönmeli")


func test_get_all_upgrades_empty_returns_array() -> void:
	assert_true(registry.get_all_upgrades() is Array)


func test_get_all_employees_empty_returns_array() -> void:
	assert_true(registry.get_all_employees() is Array)


# ── Manuel kayıt enjeksiyonu ile veri doğrulama ───────────────────────────────

# AC-2: white_bread benzeri mock RecipeData → doğru değerleri döner
func test_injected_recipe_data_accessible() -> void:
	var recipe := RecipeData.new()
	recipe.id = &"white_bread"
	recipe.display_name = "Beyaz Ekmek"
	recipe.category = GameEnums.RecipeCategory.BASIC
	recipe.base_value = 10
	recipe.bake_time_seconds = 60.0
	registry._recipes[&"white_bread"] = recipe

	var result: RecipeData = registry.get_recipe(&"white_bread")
	assert_not_null(result, "white_bread kaydı mevcut")
	assert_eq(result.base_value, 10, "base_value = 10")
	assert_almost_eq(result.bake_time_seconds, 60.0, 0.001, "bake_time_seconds = 60.0")
	assert_eq(result.category, GameEnums.RecipeCategory.BASIC, "category = BASIC")


# AC-5: effect_per_level boş UpgradeData → _validate_all sonrası null döner
func test_upgrade_with_empty_effect_per_level_removed() -> void:
	var upgrade := UpgradeData.new()
	upgrade.id = &"bad_upgrade"
	upgrade.effect_per_level = []
	registry._upgrades[&"bad_upgrade"] = upgrade

	registry._validate_all()

	var result = registry.get_upgrade(&"bad_upgrade")
	assert_null(result, "Boş effect_per_level → kayıt kaldırılmalı, null döner")


# AC-4: max_level ≠ effect_per_level.size() → max_level otomatik düzeltilir
func test_upgrade_max_level_mismatch_autocorrected() -> void:
	var upgrade := UpgradeData.new()
	upgrade.id = &"mismatched_upgrade"
	upgrade.effect_per_level = [0.1, 0.2, 0.3]
	upgrade.max_level = 5  # yanlış
	registry._upgrades[&"mismatched_upgrade"] = upgrade

	registry._validate_all()

	var result: UpgradeData = registry.get_upgrade(&"mismatched_upgrade")
	assert_not_null(result)
	assert_eq(result.max_level, 3, "max_level effect_per_level.size() ile eşleşmeli")


# AC-6: Tüm spawn_weight = 0 → sıfıra bölme yok, tümü 1'e sıfırlanır
func test_all_zero_spawn_weights_reset_to_one() -> void:
	var ct1 := CustomerTypeData.new()
	ct1.id = &"type_a"
	ct1.spawn_weight = 0.0
	var ct2 := CustomerTypeData.new()
	ct2.id = &"type_b"
	ct2.spawn_weight = 0.0
	registry._customer_types[&"type_a"] = ct1
	registry._customer_types[&"type_b"] = ct2

	registry._validate_all()

	var a: CustomerTypeData = registry.get_customer_type(&"type_a")
	var b: CustomerTypeData = registry.get_customer_type(&"type_b")
	assert_eq(a.spawn_weight, 1.0, "type_a spawn_weight 1'e sıfırlandı")
	assert_eq(b.spawn_weight, 1.0, "type_b spawn_weight 1'e sıfırlandı")


# ── Enum değer doğrulama ───────────────────────────────────────────────────────

func test_recipe_category_basic_equals_zero() -> void:
	assert_eq(int(GameEnums.RecipeCategory.BASIC), 0, "BASIC = 0")


func test_upgrade_effect_type_count() -> void:
	# 10 adet UpgradeEffectType tanımlı olmalı
	assert_eq(GameEnums.UpgradeEffectType.keys().size(), 10, "10 UpgradeEffectType")
