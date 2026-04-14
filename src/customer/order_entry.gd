## OrderEntry — Tek bir aktif siparişin runtime durumu.
##
## Immutable kimlik verisi (recipe_id, customer_type_id, base_gold) ve
## unix timestamp tabanlı sabır/grace zamanlaması taşır.
## CustomerOrderSystem bu nesneyi oluşturur ve durum geçişlerini yönetir.
##
## GDD: design/gdd/customer-order-system.md
class_name OrderEntry
extends RefCounted

## Sipariş durumu.
enum OrderStatus {
	WAITING,    ## Sabır süresi dolmadı; tam altın
	GRACE,      ## Sabır doldu, 10 sn grace aktif; %50 altın
	DELIVERED,  ## Başarıyla teslim edildi
	ESCAPED,    ## Grace süresi de doldu; müşteri kaçtı
}

## Oturum içi benzersiz sipariş numarası.
var order_id: int = 0

## İstenen tarifin ID'si.
var recipe_id: StringName = &""

## Müşteri tipi ID'si.
var customer_type_id: StringName = &""

## base_gold = recipe.base_value × customer.gold_multiplier
## CustomerOrderSystem tarafından spawn sırasında hesaplanır.
var base_gold: int = 0

## Sabır süresinin dolacağı Unix timestamp (saniye).
var patience_end_unix: int = 0

## Grace süresinin dolacağı Unix timestamp (patience_end + grace_duration).
var grace_end_unix: int = 0

## Mevcut durum.
var status: OrderStatus = OrderStatus.WAITING
