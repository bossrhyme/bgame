## CustomerConfig — Upgrade Tree'den gelen müşteri parametreleri.
##
## PROVISIONAL — Upgrade Tree (Sistem #12) yazılınca bu arayüz güncellenir.
## Upgrade Tree bu Resource'u yükler ve değerlerini ayarlar.
## CustomerOrderSystem bu Resource'u okur; Upgrade Tree iç yapısını bilmez.
##
## GDD: design/gdd/customer-order-system.md — Appendix A
class_name CustomerConfig
extends Resource

## Eş zamanlı sipariş slot sayısı (base: 4).
@export var max_active_orders: int = 4

## Sabır süresi çarpanı — tüm müşteri tipleri için (base: 1.0).
@export var patience_multiplier: float = 1.0

## VIP spawn oranı (base: 0.05 = %5). Spawn ağırlığını override eder.
@export var vip_spawn_rate: float = 0.05

## Tekrar müşteri altın bonusu (base: 0.0 = bonus yok).
@export var repeat_customer_gold_bonus: float = 0.0
