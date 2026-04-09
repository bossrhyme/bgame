## UpgradeData — Tek bir upgrade'in tüm statik verisi.
## GDD: design/gdd/content-database.md, design/gdd/upgrade-tree-system.md
class_name UpgradeData
extends Resource

## Benzersiz tanımlayıcı. Dosya adıyla eşleşmeli.
@export var id: StringName

## Oyuncuya gösterilen upgrade adı.
@export var display_name: String

## Upgrade kategorisi (GameEnums.UpgradeCategory).
@export var category: GameEnums.UpgradeCategory = GameEnums.UpgradeCategory.PRODUCTION

## Upgrade'in etkilediği değişken tipi (GameEnums.UpgradeEffectType).
@export var effect_type: GameEnums.UpgradeEffectType = GameEnums.UpgradeEffectType.BAKE_SPEED

## Her seviyenin etkisi. 0-indexed: [0] = seviye 1, [2] = seviye 3.
## GDD kuralı: effect_per_level.size() == max_level olmalı.
@export var effect_per_level: Array[float] = []

## Seviye 1 maliyeti. cost(level) = base_cost × 3^(level-1).
@export var base_cost: int = 50

## Maksimum seviye. effect_per_level.size() ile eşleşmeli.
@export var max_level: int = 1

## Rozet ile mi alınır? false = altın, true = Rozet.
@export var costs_badge: bool = false
