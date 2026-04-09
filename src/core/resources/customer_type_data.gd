## CustomerTypeData — Tek bir müşteri tipinin tüm statik verisi.
## GDD: design/gdd/content-database.md, design/gdd/customer-order-system.md
class_name CustomerTypeData
extends Resource

## Benzersiz tanımlayıcı. Dosya adıyla eşleşmeli.
@export var id: StringName

## Oyuncuya gösterilen müşteri tipi adı.
@export var display_name: String

## Sabır süresi (saniye). CustomerConfig.patience_multiplier ile çarpılır.
@export var patience_seconds: float = 300.0

## Altın çarpanı (1.0 = tam, 3.0 = VIP).
@export var gold_multiplier: float = 1.0

## Göreceli spawn ağırlığı. 0 = pasif (havuzda yok).
## Normalize: weight / Σ(all active weights).
@export var spawn_weight: float = 10.0
