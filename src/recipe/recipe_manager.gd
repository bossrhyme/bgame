## RecipeManager
##
## Tarif kilit durumlarını (LOCKED/AVAILABLE/UNLOCKED) ve özel malzeme stoğunu
## yönetir. Tüm statik tarif verisi ContentRegistry'den gelir; bu sistem yalnızca
## runtime durumunu tutar.
##
## Mimari kuralları (GDD Recipe System):
##   - Koşul değerlendirmesi bu sistemin sorumluluğunda DEĞİLDİR (D-14 yapar)
##   - mark_available(): D-14 tarafından koşul karşılandığında çağrılır
##   - unlock(): UI onay ekranından oyuncu onayıyla çağrılır; malzeme harcar
##   - Bir tarif UNLOCKED olduktan sonra kilitlenemez (kalıcı progression)
##   - Bağımlılık enjeksiyonu: _registry_ref test izolasyonu için
class_name RecipeManager
extends Node

## Tarif AVAILABLE durumuna geçince yayılır (badge, bildirim için).
signal recipe_available(recipe_id: StringName)
## Tarif UNLOCKED durumuna geçince yayılır (unlock animasyonu/ses için).
signal recipe_unlocked(recipe_id: StringName)
## Malzeme stoğu değişince yayılır (UI güncelleme için).
signal ingredient_stock_changed(ingredient_id: StringName, new_count: int)

## Malzeme yığın sınırı (GDD Tuning Knobs).
const MAX_INGREDIENT_STACK: int = 10

## Tarif kilit durumu.
enum RecipeStatus { LOCKED = 0, AVAILABLE = 1, UNLOCKED = 2 }

## StringName → RecipeStatus
var _unlock_state: Dictionary = {}
## StringName → int (stok adedi)
var _ingredient_stock: Dictionary = {}
## StringName → RecipeData (test enjeksiyonu veya Registry'den doldurulur)
var _recipes: Dictionary = {}

## ContentRegistry bağımlılık enjeksiyonu (test izolasyonu).
var _registry_ref: ContentRegistry = null


func _ready() -> void:
	var registry := _get_registry()
	if registry:
		_load_from_registry(registry)


## ContentRegistry'den tüm tarifleri yükler; başlangıç durumu LOCKED.
func _load_from_registry(registry: ContentRegistry) -> void:
	for recipe: RecipeData in registry.get_all_recipes():
		_recipes[recipe.id] = recipe
		if not _unlock_state.has(recipe.id):
			_unlock_state[recipe.id] = RecipeStatus.LOCKED


# ── Public API — Durum ────────────────────────────────────────────────────────

## D-14 tarafından çağrılır: koşullar sağlandığında LOCKED → AVAILABLE.
func mark_available(recipe_id: StringName) -> void:
	if not _recipes.has(recipe_id):
		push_error("RecipeManager: bilinmeyen tarif '%s'" % recipe_id)
		return
	if _unlock_state.get(recipe_id, RecipeStatus.LOCKED) == RecipeStatus.LOCKED:
		_unlock_state[recipe_id] = RecipeStatus.AVAILABLE
		recipe_available.emit(recipe_id)


## UI onay ekranından oyuncu onayıyla çağrılır: AVAILABLE → UNLOCKED.
## Malzeme gerektiriyorsa harcar; yetersizse false döner.
## Returns: true → başarılı, false → reddedildi (durum uygun değil veya malzeme yetersiz)
func unlock(recipe_id: StringName) -> bool:
	if _unlock_state.get(recipe_id, RecipeStatus.LOCKED) != RecipeStatus.AVAILABLE:
		return false
	var recipe: RecipeData = _recipes.get(recipe_id)
	if recipe == null:
		return false
	# Malzeme maliyeti kontrolü
	if recipe.required_ingredient != &"" and recipe.ingredient_cost > 0:
		if not consume_ingredient(recipe.required_ingredient, recipe.ingredient_cost):
			return false
	_unlock_state[recipe_id] = RecipeStatus.UNLOCKED
	recipe_unlocked.emit(recipe_id)
	return true


## Tarifin kilidi açık mı?
func is_unlocked(recipe_id: StringName) -> bool:
	return _unlock_state.get(recipe_id, RecipeStatus.LOCKED) == RecipeStatus.UNLOCKED


## Tarif kilit durumunu döner.
func get_status(recipe_id: StringName) -> RecipeStatus:
	return _unlock_state.get(recipe_id, RecipeStatus.LOCKED) as RecipeStatus


# ── Public API — Tarif Verisi ─────────────────────────────────────────────────

## Tarifin altın değerini hesaplar (F-1: base_value * (1 + tier * 0.5)).
## Bilinmeyen id → 0.0 + push_error().
func get_gold_value(recipe_id: StringName) -> float:
	var recipe: RecipeData = _recipes.get(recipe_id)
	if recipe == null:
		push_error("RecipeManager: bilinmeyen tarif '%s'" % recipe_id)
		return 0.0
	return recipe.base_value * (1.0 + recipe.tier * 0.5)


## Tarifin pişirme süresini döner (saniye).
## Bilinmeyen id → 0.0 + push_error().
func get_bake_time(recipe_id: StringName) -> float:
	var recipe: RecipeData = _recipes.get(recipe_id)
	if recipe == null:
		push_error("RecipeManager: bilinmeyen tarif '%s'" % recipe_id)
		return 0.0
	return recipe.bake_time_seconds


## Tarif verisini döner. Test enjeksiyonu için kullanılır.
func get_recipe(recipe_id: StringName) -> RecipeData:
	return _recipes.get(recipe_id) as RecipeData


# ── Public API — Malzeme Stoğu ────────────────────────────────────────────────

## Malzeme stoğuna ekler. MAX_INGREDIENT_STACK (10) aşılmaz.
## Returns: yeni stok miktarı.
func add_ingredient(ingredient_id: StringName, count: int) -> int:
	var current: int = _ingredient_stock.get(ingredient_id, 0)
	var new_count: int = mini(current + count, MAX_INGREDIENT_STACK)
	_ingredient_stock[ingredient_id] = new_count
	ingredient_stock_changed.emit(ingredient_id, new_count)
	return new_count


## Malzeme stoğundan harcar. Yetersizse false döner; stok değişmez.
func consume_ingredient(ingredient_id: StringName, count: int) -> bool:
	var current: int = _ingredient_stock.get(ingredient_id, 0)
	if current < count:
		return false
	_ingredient_stock[ingredient_id] = current - count
	ingredient_stock_changed.emit(ingredient_id, current - count)
	return true


## Mevcut malzeme stok miktarını döner (sahip değilse 0).
func get_ingredient_count(ingredient_id: StringName) -> int:
	return _ingredient_stock.get(ingredient_id, 0)


# ── Kayıt/Yükleme ─────────────────────────────────────────────────────────────

## SaveLoadManager tarafından çağrılır: runtime durumunu Dictionary olarak döner.
func serialize() -> Dictionary:
	return {
		"unlock_state": _unlock_state.duplicate(),
		"ingredient_stock": _ingredient_stock.duplicate(),
	}


## SaveLoadManager tarafından çağrılır: kayıtlı durumu geri yükler.
func deserialize(data: Dictionary) -> void:
	var unlock_data: Dictionary = data.get("unlock_state", {})
	for key in unlock_data:
		if _recipes.has(key):
			_unlock_state[key] = unlock_data[key]
	_ingredient_stock = data.get("ingredient_stock", {}).duplicate()


# ── Bağımlılık enjeksiyonu ────────────────────────────────────────────────────

func _get_registry() -> ContentRegistry:
	if _registry_ref:
		return _registry_ref
	return get_node_or_null("/root/ContentRegistry") as ContentRegistry
