## EmployeeData — Tek bir çalışan tipinin tüm statik verisi.
## GDD: design/gdd/content-database.md, design/gdd/employee-system.md
class_name EmployeeData
extends Resource

## Benzersiz tanımlayıcı. Dosya adıyla eşleşmeli.
@export var id: StringName

## Oyuncuya gösterilen çalışan adı.
@export var display_name: String

## Çalışan rolü (GameEnums.EmployeeRole).
@export var role: GameEnums.EmployeeRole = GameEnums.EmployeeRole.DOUGH_MAKER

## Günlük altın ücreti.
@export var daily_wage: int = 50

## Etki tipi (GameEnums.UpgradeEffectType ile paylaşımlı enum).
@export var effect_type: GameEnums.UpgradeEffectType = GameEnums.UpgradeEffectType.BAKE_SPEED

## Her seviyenin etkisi. 0-indexed.
@export var effect_per_level: Array[float] = []

## Maksimum seviye.
@export var max_level: int = 3
