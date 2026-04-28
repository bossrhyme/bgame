## CollectionDexSystem — Tarif Koleksiyon Takibi
##
## RecipeManager.recipe_unlocked sinyalini dinleyerek açılan tarifleri
## kaydeder; kategori ve genel tamamlanma yüzdesini hesaplar.
## Koleksiyon prestijden etkilenmez (tarihsel kayıt).
##
## GDD: design/gdd/collection-dex-system.md
class_name CollectionDexSystem
extends Node

## Koleksiyona yeni tarif eklenince yayılır.
signal collection_updated(recipe_id: StringName)
## Kategorinin tüm tarifleri toplandığında yayılır (bir kez).
signal category_completed(category: GameEnums.RecipeCategory)
## Tüm tarifler toplandığında yayılır (bir kez).
signal all_recipes_collected

var _collected: Dictionary = {}           # StringName → bool
var _completed_categories: Dictionary = {}  # int (RecipeCategory) → bool

## Dependency injection (test izolasyonu).
var _recipe_ref: RecipeManager = null
var _registry_ref: ContentRegistry = null
var _notif_ref: NotificationManager = null


func _ready() -> void:
	var recipe := _get_recipe()
	if recipe:
		recipe.recipe_unlocked.connect(_on_recipe_unlocked)
	else:
		push_warning("CollectionDexSystem: RecipeManager bağlanamadı")


# ── Public API ────────────────────────────────────────────────────────────────

## Tarif koleksiyona eklendi mi?
func is_collected(recipe_id: StringName) -> bool:
	return _collected.get(recipe_id, false)


## Toplam kaç tarif toplandı.
var collected_count: int:
	get: return _collected.size()


## Kategori tamamlanma yüzdesi [0.0, 1.0].
func get_category_completion(category: GameEnums.RecipeCategory) -> float:
	var all := _get_recipes_in_category(category)
	if all.is_empty():
		return 0.0
	var count: int = 0
	for r: RecipeData in all:
		if _collected.get(r.id, false):
			count += 1
	return float(count) / float(all.size())


## Genel tamamlanma yüzdesi [0.0, 1.0].
func get_total_completion() -> float:
	var registry := _get_registry()
	if not registry:
		return 0.0
	var total: int = registry.get_all_recipes().size()
	if total == 0:
		return 0.0
	return float(_collected.size()) / float(total)


# ── Signal Handler ────────────────────────────────────────────────────────────

func _on_recipe_unlocked(recipe_id: StringName) -> void:
	if _collected.get(recipe_id, false):
		return  # Zaten koleksiyonda

	_collected[recipe_id] = true
	collection_updated.emit(recipe_id)

	var recipe_data: RecipeData = _get_recipe_data(recipe_id)
	if recipe_data:
		_check_category_completion(recipe_data.category)

	_check_all_collected()


# ── Internal ──────────────────────────────────────────────────────────────────

func _check_category_completion(category: GameEnums.RecipeCategory) -> void:
	if _completed_categories.get(int(category), false):
		return  # Zaten tamamlandı olarak işaretlendi
	var completion: float = get_category_completion(category)
	if completion < 1.0:
		return
	_completed_categories[int(category)] = true
	category_completed.emit(category)

	var notif := _get_notif()
	if notif:
		var cat_name: String = GameEnums.RecipeCategory.keys()[category]
		notif.queue_notification("Tüm %s tarifleri toplandı!" % cat_name,
			NotificationManager.Priority.INFO)


func _check_all_collected() -> void:
	var registry := _get_registry()
	if not registry:
		return
	if _collected.size() >= registry.get_all_recipes().size() \
			and not registry.get_all_recipes().is_empty():
		all_recipes_collected.emit()


func _get_recipes_in_category(category: GameEnums.RecipeCategory) -> Array[RecipeData]:
	var registry := _get_registry()
	if not registry:
		push_warning("CollectionDexSystem: ContentRegistry bulunamadı")
		return []
	var result: Array[RecipeData] = []
	for r: RecipeData in registry.get_all_recipes():
		if r.category == category:
			result.append(r)
	return result


func _get_recipe_data(recipe_id: StringName) -> RecipeData:
	var registry := _get_registry()
	if not registry:
		return null
	return registry.get_recipe(recipe_id)


# ── Serialize / Deserialize ────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"collected": _collected.keys(),
		"completed_categories": _completed_categories.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	_collected.clear()
	for id in data.get("collected", []):
		_collected[id] = true
	_completed_categories = data.get("completed_categories", {}).duplicate()


# ── Dependency Getters ────────────────────────────────────────────────────────

func _get_recipe() -> RecipeManager:
	if _recipe_ref:
		return _recipe_ref
	return get_node_or_null("/root/RecipeManager") as RecipeManager


func _get_registry() -> ContentRegistry:
	if _registry_ref:
		return _registry_ref
	return get_node_or_null("/root/ContentRegistry") as ContentRegistry


func _get_notif() -> NotificationManager:
	if _notif_ref:
		return _notif_ref
	return get_node_or_null("/root/NotificationManager") as NotificationManager
