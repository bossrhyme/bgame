## UnlockCondition — Tek bir tarif kilit koşulunu tanımlar.
##
## RecipeData.unlock_conditions dizisine eklenir.
## Koşul değerlendirmesi UnlockConditionResolver (D-14) tarafından yapılır;
## bu resource yalnızca veri taşır.
##
## GDD: design/gdd/recipe-system.md — Unlock Conditions
class_name UnlockCondition
extends Resource

## Koşul tipleri (GDD § Unlock Conditions).
enum ConditionType {
	SALE_COUNT,          ## Belirli sayıda ekmek satılınca
	LOCATION_UNLOCKED,   ## Belirli bir lokasyon açılınca
	INGREDIENT_OWNED,    ## Belirli bir özel malzeme edinilince
}

@export var condition_type: ConditionType = ConditionType.SALE_COUNT

# ── SALE_COUNT alanları ───────────────────────────────────────────────────────

## Gerekli satış adedi.
@export var required_count: int = 0

## Hangi kategoriden sayılır. &"" ise tüm satışlar.
@export var target_category: StringName = &""

# ── LOCATION_UNLOCKED alanları ────────────────────────────────────────────────

## Açılması gereken lokasyon ID'si.
@export var required_location_id: StringName = &""

# ── INGREDIENT_OWNED alanları ─────────────────────────────────────────────────

## Sahip olunması gereken özel malzeme ID'si.
@export var required_ingredient_id: StringName = &""
