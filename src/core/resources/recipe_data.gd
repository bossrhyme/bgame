## RecipeData — Tek bir ekmek tarifinin tüm statik verisi.
## ContentRegistry tarafından assets/data/recipes/*.tres'ten yüklenir.
## GDD: design/gdd/content-database.md, design/gdd/recipe-system.md
class_name RecipeData
extends Resource

## Benzersiz tanımlayıcı. Dosya adıyla eşleşmeli (white_bread.tres → &"white_bread").
@export var id: StringName

## Oyuncuya gösterilen tarif adı.
@export var display_name: String

## Tarif kategorisi (GameEnums.RecipeCategory).
@export var category: GameEnums.RecipeCategory = GameEnums.RecipeCategory.BASIC

## Temel altın değeri (adet başına). gold_value formülü Economy/Recipe sistemine ait.
@export var base_value: int = 10

## Pişirme süresi (saniye). Fırın Sıcaklığı upgrade'i bu değeri çarpar.
@export var bake_time_seconds: float = 60.0

## Bu tarifte sadece bu lokasyon açıksa kullanılabilir. "" → her yerde.
@export var location_id: StringName = &""

## AnimationStateMachine'e iletilen anahtar.
@export var animation_key: StringName = &""

## Pişirme ses efekti anahtarı (AudioBus).
@export var sfx_bake_key: StringName = &""

## Hasat ses efekti anahtarı (AudioBus).
@export var sfx_harvest_key: StringName = &""
