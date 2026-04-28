## LocationSystem — Lokasyon Açma ve Prestij Servisi
##
## Beş lokasyonu (start → inner_anatolia → istanbul → paris → rome) sırayla
## açar; her lokasyonun koşullarını dahili olarak değerlendirir.
## Prestij: gold sıfırlama, upgrade sıfırlama, tarif kilitleme, Rozet bonusu.
##
## GDD: design/gdd/location-prestige-system.md
class_name LocationSystem
extends Node

## Lokasyon açıldığında yayılır.
signal location_unlocked(location_id: StringName)
## Prestij tamamlandığında yayılır.
signal prestige_completed(new_prestige_count: int, rozet_bonus: int)

## Lokasyon açılma sırası.
const LOCATION_ORDER: Array[StringName] = [
	&"start",
	&"inner_anatolia",
	&"istanbul",
	&"paris",
	&"rome",
]

## Lokasyon → bağlı tarif kategorisi.
const LOCATION_CATEGORY: Dictionary = {
	&"start":          &"basic",
	&"inner_anatolia": &"wheat",
	&"istanbul":       &"sweet",
	&"paris":          &"french",
	&"rome":           &"italian",
}

## Prestij Rozet bonusu çarpanı (F-2: bonus = PRESTIGE_ROZET_MULTIPLIER × n).
const PRESTIGE_ROZET_MULTIPLIER: int = 10

## Lokasyon unlock için minimum satış sayıları (GDD F-1).
const SALE_REQ: Dictionary = {
	&"inner_anatolia": 50,
	&"istanbul":       100,
	&"paris":          150,
	&"rome":           200,
}

var _unlocked: Dictionary = {}        # StringName → bool
var _category_sales: Dictionary = {}  # StringName (category) → int
var _prestige_count: int = 0

## Dependency injection (test izolasyonu).
var _economy_ref: EconomySystem = null
var _upgrade_ref: UpgradeTree = null
var _recipe_ref: RecipeManager = null
var _resolver_ref: UnlockConditionResolver = null


func _ready() -> void:
	_unlocked[&"start"] = true


# ── Public API — Sorgulama ────────────────────────────────────────────────────

## Mevcut prestij sayısını döner.
var prestige_count: int:
	get: return _prestige_count


## Lokasyonun açık olup olmadığını döner.
func is_location_unlocked(location_id: StringName) -> bool:
	return _unlocked.get(location_id, false)


## Bir kategori için kayıtlı satış sayısını döner.
func get_category_sale_count(category_id: StringName) -> int:
	return _category_sales.get(category_id, 0)


## Sıradaki kilitli lokasyonu döner. Tümü açıksa &"" döner.
func get_next_locked_location() -> StringName:
	for loc: StringName in LOCATION_ORDER:
		if not _unlocked.get(loc, false):
			return loc
	return &""


## Prestij yapılabilir mi? Roma açıksa true.
func can_prestige() -> bool:
	return is_location_unlocked(&"rome")


# ── Public API — Aksiyon ─────────────────────────────────────────────────────

## Lokasyon açmayı dener. Sıra koşulu ve kendi koşulları karşılanmalıdır.
## Returns: true → başarılı; false → koşul eksik veya zaten açık.
func try_unlock_location(location_id: StringName) -> bool:
	if _unlocked.get(location_id, false):
		return false
	if not _is_next_in_sequence(location_id):
		push_warning("LocationSystem: '%s' sıradaki lokasyon değil" % location_id)
		return false
	if not _check_conditions(location_id):
		return false

	_unlocked[location_id] = true
	location_unlocked.emit(location_id)

	var resolver := _get_resolver()
	if resolver:
		resolver.unlock_location(location_id)

	return true


## Kategori satışını kaydeder; koşullar otomatik yeniden değerlendirilmez.
## (Unlock denemeleri oyuncu UI aksiyonuyla tetiklenir, otomatik değil.)
func record_category_sale(category_id: StringName) -> void:
	_category_sales[category_id] = _category_sales.get(category_id, 0) + 1


## Prestij yapar. Yalnızca Roma açıksa çalışır.
## Returns: true → başarılı; false → koşul karşılanmadı.
func do_prestige() -> bool:
	if not can_prestige():
		push_warning("LocationSystem: Prestij için Roma açık olmalıdır")
		return false

	# 1. Economy sıfırla
	var economy := _get_economy()
	if economy:
		economy.reset_for_prestige()

	# 2. Upgrade seviyeleri sıfırla
	var upgrade := _get_upgrade()
	if upgrade:
		upgrade.reset_levels()

	# 3. Tarifleri kilitle
	var recipe := _get_recipe()
	if recipe:
		recipe.reset_all_to_locked()

	# 4. Lokasyonları sıfırla (sadece start açık)
	_unlocked.clear()
	_unlocked[&"start"] = true

	# 5. Prestige sayacı + Rozet bonusu (F-2)
	_prestige_count += 1
	var bonus: int = PRESTIGE_ROZET_MULTIPLIER * _prestige_count
	if economy:
		economy.earn_rozet(bonus)

	# 6. Resolver'ı sıfırla ve start lokasyonunu bildir
	var resolver := _get_resolver()
	if resolver:
		resolver.reset()
		resolver.unlock_location(&"start")

	prestige_completed.emit(_prestige_count, bonus)
	return true


# ── Serialize / Deserialize ────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"unlocked_locations": _unlocked.duplicate(),
		"category_sales":     _category_sales.duplicate(),
		"prestige_count":     _prestige_count,
	}


func deserialize(data: Dictionary) -> void:
	_unlocked = data.get("unlocked_locations", {&"start": true}).duplicate()
	_unlocked[&"start"] = true  # start her zaman açık
	_category_sales = data.get("category_sales", {}).duplicate()
	_prestige_count = maxi(data.get("prestige_count", 0), 0)


# ── Internal ──────────────────────────────────────────────────────────────────

func _is_next_in_sequence(location_id: StringName) -> bool:
	var idx: int = LOCATION_ORDER.find(location_id)
	if idx <= 0:
		return false  # start zaten açık veya bilinmiyor
	var prev: StringName = LOCATION_ORDER[idx - 1]
	return _unlocked.get(prev, false)


func _check_conditions(location_id: StringName) -> bool:
	var upgrade := _get_upgrade()
	match location_id:
		&"inner_anatolia":
			return _category_sales.get(&"basic", 0) >= SALE_REQ[&"inner_anatolia"]

		&"istanbul":
			var oc_level: int = upgrade.get_current_level(&"oven_capacity") if upgrade else 0
			return (_category_sales.get(&"wheat", 0) >= SALE_REQ[&"istanbul"]
				and oc_level >= 2)

		&"paris":
			var sw_level: int = upgrade.get_current_level(&"showcase_width") if upgrade else 0
			return (_category_sales.get(&"sweet", 0) >= SALE_REQ[&"paris"]
				and sw_level >= 1)

		&"rome":
			return (_category_sales.get(&"french", 0) >= SALE_REQ[&"rome"]
				and _prestige_count >= 1)

	push_warning("LocationSystem: Bilinmeyen lokasyon '%s'" % location_id)
	return false


func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem


func _get_upgrade() -> UpgradeTree:
	if _upgrade_ref:
		return _upgrade_ref
	return get_node_or_null("/root/UpgradeTree") as UpgradeTree


func _get_recipe() -> RecipeManager:
	if _recipe_ref:
		return _recipe_ref
	return get_node_or_null("/root/RecipeManager") as RecipeManager


func _get_resolver() -> UnlockConditionResolver:
	if _resolver_ref:
		return _resolver_ref
	return get_node_or_null("/root/UnlockConditionResolver") as UnlockConditionResolver
