## ProductionConfig — Upgrade Tree'den gelen üretim parametreleri.
##
## UpgradeTree tarafından doldurulur; OvenManager okur.
## GDD: design/gdd/upgrade-tree-system.md — Üretim Upgrades
class_name ProductionConfig
extends Resource

## Pişirme hızı çarpanı. 1.0 = temel; oven_temperature upgrade'i ile artar.
@export var bake_speed_multiplier: float = 1.0

## Hamur kalitesi gelir bonusu. 0.0 = yok; dough_quality upgrade'i ile artar.
@export var dough_quality_bonus: float = 0.0

## Toplam fırın kapasitesi (slot sayısı). Temel=1; oven_capacity upgrade'i kümülatif ekler.
@export var oven_capacity: int = 1

## Otomatik hamur seviyesi (0 = kapalı). auto_dough upgrade seviyesiyle eşit.
@export var auto_dough_level: int = 0

## Malzeme deposu ek kapasitesi. ingredient_storage upgrade'inden gelir.
@export var storage_cap: int = 0
