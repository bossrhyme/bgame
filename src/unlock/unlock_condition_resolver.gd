## UnlockConditionResolver — Autoload / Service
##
## UnlockCondition nesnelerini mevcut oyun durumuna göre değerlendirir.
## RecipeManager.mark_available() çağrısından önce recipe'nin tüm koşullarını
## kontrol etmek için kullanılır.
##
## Mimari kuralları:
##   - _process() içinde değerlendirme yasaktır (ADR-0003)
##   - Koşul sorguları olay-tetiklemeli (satış, lokasyon açma vb.) çağrılır
##   - Dependency injection: _recipe_ref, _economy_ref — test izolasyonu için
##
## Referans: design/gdd/recipe-system.md — Unlock Conditions
class_name UnlockConditionResolver
extends Node

## Tüm koşullar karşılandığında yayılır. RecipeManager.mark_available() bağlanır.
signal conditions_met(recipe_id: StringName)

## Dependency injection. null ise autoload'dan alınır.
var _recipe_ref: RecipeManager = null
var _location_ref: LocationSystem = null

## Satış sayaçları: recipe_id → toplam satış adedi.
## record_sale() çağrısıyla güncellenir.
var _sale_counts: Dictionary = {}  # StringName → int

## Açık lokasyonlar seti.
## unlock_location() çağrısıyla güncellenir.
var _unlocked_locations: Dictionary = {}  # StringName → bool

## Takip edilen recipe koşulları: recipe_id → Array[UnlockCondition].
## watch() ile eklenir; koşullar karşılandığında otomatik olarak kaldırılır.
var _watched: Dictionary = {}  # StringName → Array[UnlockCondition]


# ── Public API ────────────────────────────────────────────────────────────────

## Tek bir UnlockCondition'ı mevcut duruma göre değerlendirir.
## true → koşul karşılandı; false → karşılanmadı.
func evaluate(cond: UnlockCondition) -> bool:
	match cond.condition_type:
		UnlockCondition.ConditionType.SALE_COUNT:
			var count: int = _get_sale_count(cond.target_category)
			return count >= cond.required_count

		UnlockCondition.ConditionType.LOCATION_UNLOCKED:
			return _unlocked_locations.get(cond.required_location_id, false)

		UnlockCondition.ConditionType.INGREDIENT_OWNED:
			var recipe_mgr := _get_recipe_manager()
			if not recipe_mgr:
				push_warning("UnlockConditionResolver: RecipeManager bulunamadı — " \
					+ "INGREDIENT_OWNED koşulu false döndü")
				return false
			return recipe_mgr.get_ingredient_count(cond.required_ingredient_id) > 0

		UnlockCondition.ConditionType.PRESTIGE_COUNT:
			var loc := _get_location_system()
			if not loc:
				push_warning("UnlockConditionResolver: LocationSystem bulunamadı — " \
					+ "PRESTIGE_COUNT koşulu false döndü")
				return false
			return loc.prestige_count >= cond.required_prestige_count

	push_warning("UnlockConditionResolver: Bilinmeyen koşul tipi: %d" \
		% cond.condition_type)
	return false


## Bir recipe'nin tüm UnlockCondition'larını değerlendirir.
## Tüm koşullar karşılandıysa true; herhangi biri karşılanmadıysa false.
## Boş dizi → true (koşulsuz, her zaman açık).
func evaluate_all(conditions: Array[UnlockCondition]) -> bool:
	for cond: UnlockCondition in conditions:
		if not evaluate(cond):
			return false
	return true


## Bir recipe için koşul izlemeye başlar.
## Her olay sonrası evaluate_all() çağrılır; koşullar karşılandığında
## conditions_met(recipe_id) sinyali yayılır ve izleme durur.
func watch(recipe_id: StringName, conditions: Array[UnlockCondition]) -> void:
	if conditions.is_empty():
		conditions_met.emit(recipe_id)
		return
	_watched[recipe_id] = conditions


## Satış kaydeder. SALE_COUNT koşullarını tetikler.
## recipe_id: hangi tariften satış yapıldı.
func record_sale(recipe_id: StringName) -> void:
	var current: int = _sale_counts.get(recipe_id, 0)
	_sale_counts[recipe_id] = current + 1
	_check_watched()


## Lokasyon açılışını kaydeder. LOCATION_UNLOCKED koşullarını tetikler.
func unlock_location(location_id: StringName) -> void:
	_unlocked_locations[location_id] = true
	_check_watched()


## Malzeme edinimi bildirir. INGREDIENT_OWNED koşullarını tetikler.
## (RecipeManager.ingredient_stock_changed sinyaline bağlanır.)
func notify_ingredient_changed(_ingredient_id: StringName, _new_count: int) -> void:
	_check_watched()


## Test izolasyonu için sayaçları ve durumu sıfırlar.
func reset() -> void:
	_sale_counts.clear()
	_unlocked_locations.clear()
	_watched.clear()


# ── Internal ──────────────────────────────────────────────────────────────────

func _get_recipe_manager() -> RecipeManager:
	if _recipe_ref:
		return _recipe_ref
	return get_node_or_null("/root/RecipeManager") as RecipeManager


func _get_location_system() -> LocationSystem:
	if _location_ref:
		return _location_ref
	return get_node_or_null("/root/LocationSystem") as LocationSystem


## Tüm izlenen recipe'leri kontrol eder; karşılananları sinyalle bildirir.
func _check_watched() -> void:
	var to_remove: Array[StringName] = []
	for recipe_id: StringName in _watched:
		var conditions: Array[UnlockCondition] = _watched[recipe_id]
		if evaluate_all(conditions):
			to_remove.append(recipe_id)
	for recipe_id: StringName in to_remove:
		_watched.erase(recipe_id)
		conditions_met.emit(recipe_id)


## Belirli bir kategorideki toplam satış sayısını döner.
## target_category = &"" → tüm recipe'lerin toplam satışı.
## target_category = <recipe_id> → yalnızca o recipe'nin satışı.
func _get_sale_count(target_category: StringName) -> int:
	if target_category == &"":
		var total: int = 0
		for count: int in _sale_counts.values():
			total += count
		return total
	return _sale_counts.get(target_category, 0)
