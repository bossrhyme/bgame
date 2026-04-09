## LocationData — Tek bir lokasyonun tüm statik verisi.
## GDD: design/gdd/content-database.md
class_name LocationData
extends Resource

## Benzersiz tanımlayıcı. Dosya adıyla eşleşmeli.
@export var id: StringName

## Oyuncuya gösterilen lokasyon adı.
@export var display_name: String

## Gelir çarpanı (1.0 = köy, 1.5 = Paris).
@export var income_multiplier: float = 1.0

## Bu lokasyona özgü tarif ID'leri.
@export var exclusive_recipe_ids: Array[StringName] = []

## Visual Progression sistemi için tema anahtarı.
@export var theme_key: StringName = &""
