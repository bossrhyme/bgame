## CustomerOrderSystem
##
## Sipariş panosunu (max 4 slot), müşteri memnuniyetini ve spawn döngüsünü yönetir.
## Unix timestamp tabanlı sabır/grace sayacı uygulamayı arka plana alınca da çalışır.
##
## Mimari kuralları (GDD Customer/Order System):
##   - _process() yasak (ADR-0003); zamanlama create_timer + unix timestamp ile
##   - Sabır/grace geçişleri hem timer (in-game) hem update_order_states() (resume) ile
##   - EconomySystem bağımlılığı enjeksiyon ile (test izolasyonu)
##   - customer_types ve available_recipe_ids boşsa spawn yapılmaz (güvenli default)
class_name CustomerOrderSystem
extends Node

## Sipariş eklendi.
signal order_added(order: OrderEntry)
## Sipariş başarıyla teslim edildi; kazanılan altın bildirilir.
signal order_delivered(order: OrderEntry, gold_earned: int)
## Sabır süresi doldu; grace penceresi başladı.
signal order_grace_started(order: OrderEntry)
## Müşteri kaçtı (grace doldu).
signal customer_escaped(order: OrderEntry)
## Memnuniyet değişti.
signal satisfaction_changed(new_satisfaction: int)

# ── Sabitler ─────────────────────────────────────────────────────────────────

const GRACE_DURATION: float               = 10.0
const SATISFACTION_MIN: int               = 0
const SATISFACTION_MAX: int               = 10
const SATISFACTION_INITIAL: int           = 10
const SATISFACTION_SLOW_THRESHOLD: int    = 5
const SATISFACTION_SLOW_MULTIPLIER: float = 1.25
const DELIVERY_STREAK_RECOVERY: int       = 5
const BASE_SPAWN_INTERVAL: float          = 30.0

const SATISFACTION_BONUS_HIGH: float   = 1.1  ## satisfaction 8–10
const SATISFACTION_BONUS_MEDIUM: float = 1.0  ## satisfaction 5–7
const SATISFACTION_BONUS_LOW: float    = 0.9  ## satisfaction 0–4

const DELIVERY_MODIFIER_FULL: float  = 1.0  ## WAITING → tam altın
const DELIVERY_MODIFIER_GRACE: float = 0.5  ## GRACE → %50 altın

# ── Dışarıdan enjekte edilen veriler ─────────────────────────────────────────

## Spawn havuzu için müşteri tipleri. Boşsa spawn yapılmaz.
var customer_types: Array[CustomerTypeData] = []

## Spawn sırasında rastgele seçilecek tarif ID'leri. Boşsa spawn yapılmaz.
var available_recipe_ids: Array[StringName] = []

## Upgrade Tree provisional arayüzü. null ise varsayılan değerler kullanılır.
var config: CustomerConfig = null

## EconomySystem bağımlılık enjeksiyonu (test izolasyonu).
var _economy_ref: EconomySystem = null

# ── Runtime durumu ────────────────────────────────────────────────────────────

var _active_orders: Array[OrderEntry] = []
var _satisfaction: int = SATISFACTION_INITIAL
var _delivery_streak: int = 0
var _order_id_counter: int = 0
var _spawn_timer: SceneTreeTimer = null


func _ready() -> void:
	_schedule_spawn()


# ── Public API — Sipariş Yönetimi ─────────────────────────────────────────────

## Aktif sipariş sayısını döner.
func get_active_order_count() -> int:
	return _active_orders.size()


## Aktif siparişlerin kopyasını döner (salt okunur erişim için).
func get_active_orders() -> Array[OrderEntry]:
	return _active_orders.duplicate()


## Mevcut memnuniyet değerini döner.
func get_satisfaction() -> int:
	return _satisfaction


## Siparişi teslim eder. Kazanılan altını döner (0 = teslim edilemedi).
##
## Durum geçişleri teslim anında unix timestamp ile yeniden değerlendirilir;
## bu sayede grace süresi tam dolmuşsa oyuncu 0 altın alır.
func deliver_order(order_id: int) -> int:
	var order: OrderEntry = _find_order(order_id)
	if order == null:
		return 0

	# Teslim anında durumu güncelle (edge case: grace tam dolduysa)
	_update_single_order_state(order)

	if order.status == OrderEntry.OrderStatus.ESCAPED or \
	   order.status == OrderEntry.OrderStatus.DELIVERED:
		return 0

	var modifier: float = DELIVERY_MODIFIER_FULL \
		if order.status == OrderEntry.OrderStatus.WAITING \
		else DELIVERY_MODIFIER_GRACE
	var gold: int = int(order.base_gold * modifier * _get_satisfaction_bonus())

	order.status = OrderEntry.OrderStatus.DELIVERED
	_active_orders.erase(order)
	_delivery_streak += 1

	if _delivery_streak >= DELIVERY_STREAK_RECOVERY:
		_delivery_streak = 0
		_set_satisfaction(mini(_satisfaction + 1, SATISFACTION_MAX))

	var economy := _get_economy()
	if economy:
		economy.earn_gold(gold)

	order_delivered.emit(order, gold)
	_schedule_spawn()
	return gold


## Arka plandan dönüşte veya uygulama başlangıcında çağrılır.
## Tüm aktif siparişlerin unix timestamp'ini şimdiki zamanla karşılaştırır;
## süre dolmuş olanları GRACE / ESCAPED durumuna geçirir.
func update_order_states() -> void:
	var now: int = Time.get_unix_time_from_system()
	var to_escape: Array[OrderEntry] = []
	var to_grace: Array[OrderEntry] = []

	for order in _active_orders:
		if order.status in [OrderEntry.OrderStatus.DELIVERED, OrderEntry.OrderStatus.ESCAPED]:
			continue
		if now >= order.grace_end_unix:
			to_escape.append(order)
		elif now >= order.patience_end_unix and order.status == OrderEntry.OrderStatus.WAITING:
			to_grace.append(order)

	for order in to_grace:
		order.status = OrderEntry.OrderStatus.GRACE
		order_grace_started.emit(order)
		var remaining_grace: float = float(order.grace_end_unix - now)
		if remaining_grace > 0.0:
			var t := get_tree().create_timer(remaining_grace)
			t.timeout.connect(_on_grace_expired.bind(order))

	for order in to_escape:
		_escape_order(order)


# ── Kayıt/Yükleme ─────────────────────────────────────────────────────────────

## SaveLoadManager tarafından çağrılır.
func serialize() -> Dictionary:
	var orders_data: Array = []
	for order in _active_orders:
		orders_data.append({
			"order_id": order.order_id,
			"recipe_id": order.recipe_id,
			"customer_type_id": order.customer_type_id,
			"base_gold": order.base_gold,
			"patience_end_unix": order.patience_end_unix,
			"grace_end_unix": order.grace_end_unix,
			"status": order.status,
		})
	return {
		"orders": orders_data,
		"satisfaction": _satisfaction,
		"delivery_streak": _delivery_streak,
		"order_id_counter": _order_id_counter,
	}


## SaveLoadManager tarafından çağrılır. Yükleme sonrası update_order_states() çağrılmalı.
func deserialize(data: Dictionary) -> void:
	_satisfaction = data.get("satisfaction", SATISFACTION_INITIAL)
	_delivery_streak = data.get("delivery_streak", 0)
	_order_id_counter = data.get("order_id_counter", 0)
	_active_orders.clear()

	var orders_data: Array = data.get("orders", [])
	for d in orders_data:
		var order := OrderEntry.new()
		order.order_id = d.get("order_id", 0)
		order.recipe_id = d.get("recipe_id", &"")
		order.customer_type_id = d.get("customer_type_id", &"")
		order.base_gold = d.get("base_gold", 0)
		order.patience_end_unix = d.get("patience_end_unix", 0)
		order.grace_end_unix = d.get("grace_end_unix", 0)
		order.status = d.get("status", OrderEntry.OrderStatus.WAITING)
		_active_orders.append(order)

	# Zamanlayıcıları yeniden başlat
	update_order_states()


# ── Internal — Sipariş Oluşturma ──────────────────────────────────────────────

## Yeni sipariş oluşturur ve panoya ekler.
## now_unix < 0 → gerçek zaman kullanılır; test için geçmiş timestamp verilebilir.
func _add_order(recipe_id: StringName, customer_type: CustomerTypeData,
		base_gold: int, now_unix: int = -1) -> OrderEntry:
	if now_unix < 0:
		now_unix = Time.get_unix_time_from_system()

	var patience_secs: float = customer_type.patience_seconds * _get_config().patience_multiplier

	var order := OrderEntry.new()
	order.order_id = _order_id_counter
	_order_id_counter += 1
	order.recipe_id = recipe_id
	order.customer_type_id = customer_type.id
	order.base_gold = base_gold
	order.patience_end_unix = now_unix + int(patience_secs)
	order.grace_end_unix = order.patience_end_unix + int(GRACE_DURATION)
	order.status = OrderEntry.OrderStatus.WAITING
	_active_orders.append(order)

	# Patience timer — yalnızca süre henüz dolmadıysa
	var patience_remaining: float = float(order.patience_end_unix) - \
		float(Time.get_unix_time_from_system())
	if patience_remaining > 0.0:
		var t := get_tree().create_timer(patience_remaining)
		t.timeout.connect(_on_patience_expired.bind(order))

	order_added.emit(order)
	return order


# ── Internal — Durum Güncellemeleri ──────────────────────────────────────────

func _update_single_order_state(order: OrderEntry) -> void:
	if order.status in [OrderEntry.OrderStatus.DELIVERED, OrderEntry.OrderStatus.ESCAPED]:
		return
	var now: int = Time.get_unix_time_from_system()
	if now >= order.grace_end_unix:
		_escape_order(order)
	elif now >= order.patience_end_unix and order.status == OrderEntry.OrderStatus.WAITING:
		order.status = OrderEntry.OrderStatus.GRACE
		order_grace_started.emit(order)


func _escape_order(order: OrderEntry) -> void:
	if order.status == OrderEntry.OrderStatus.ESCAPED:
		return  # İdempotent
	order.status = OrderEntry.OrderStatus.ESCAPED
	_active_orders.erase(order)
	_delivery_streak = 0
	_set_satisfaction(maxi(_satisfaction - 1, SATISFACTION_MIN))
	customer_escaped.emit(order)
	_schedule_spawn()


func _set_satisfaction(value: int) -> void:
	var clamped := clampi(value, SATISFACTION_MIN, SATISFACTION_MAX)
	if clamped == _satisfaction:
		return
	_satisfaction = clamped
	satisfaction_changed.emit(_satisfaction)


# ── Internal — Zamanlayıcı Callbacks ─────────────────────────────────────────

func _on_patience_expired(order: OrderEntry) -> void:
	if not _active_orders.has(order):
		return  # Zaten teslim edildi veya kaçtı
	if order.status != OrderEntry.OrderStatus.WAITING:
		return
	order.status = OrderEntry.OrderStatus.GRACE
	order_grace_started.emit(order)
	var t := get_tree().create_timer(GRACE_DURATION)
	t.timeout.connect(_on_grace_expired.bind(order))


func _on_grace_expired(order: OrderEntry) -> void:
	if not _active_orders.has(order):
		return  # Zaten teslim edildi
	if order.status != OrderEntry.OrderStatus.GRACE:
		return
	_escape_order(order)


# ── Internal — Spawn ──────────────────────────────────────────────────────────

func _schedule_spawn() -> void:
	if customer_types.is_empty() or available_recipe_ids.is_empty():
		return
	if _satisfaction == SATISFACTION_MIN:
		return
	if _active_orders.size() >= _get_config().max_active_orders:
		return
	if _spawn_timer != null:
		return  # Zaten zamanlandı
	var interval: float = BASE_SPAWN_INTERVAL
	if _satisfaction <= SATISFACTION_SLOW_THRESHOLD:
		interval *= SATISFACTION_SLOW_MULTIPLIER
	_spawn_timer = get_tree().create_timer(interval)
	_spawn_timer.timeout.connect(_on_spawn_timer_fired)


func _on_spawn_timer_fired() -> void:
	_spawn_timer = null
	_spawn_customer()


func _spawn_customer() -> void:
	if _active_orders.size() >= _get_config().max_active_orders:
		return
	if _satisfaction == SATISFACTION_MIN:
		return
	if customer_types.is_empty() or available_recipe_ids.is_empty():
		return

	var customer_type := _pick_customer_type()
	if customer_type == null:
		return

	var recipe_id: StringName = available_recipe_ids[randi() % available_recipe_ids.size()]
	var base_gold: int = int(_get_recipe_base_value(recipe_id) * customer_type.gold_multiplier)
	_add_order(recipe_id, customer_type, base_gold)
	_schedule_spawn()


func _pick_customer_type() -> CustomerTypeData:
	var total_weight: float = 0.0
	for ct: CustomerTypeData in customer_types:
		total_weight += ct.spawn_weight
	if total_weight <= 0.0:
		return null
	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for ct: CustomerTypeData in customer_types:
		cumulative += ct.spawn_weight
		if roll <= cumulative:
			return ct
	return customer_types[-1]


func _get_recipe_base_value(recipe_id: StringName) -> int:
	var registry := get_node_or_null("/root/ContentRegistry") as ContentRegistry
	if registry:
		var recipe: RecipeData = registry.get_recipe(recipe_id)
		if recipe:
			return recipe.base_value
	return 0


# ── Internal — Formüller ──────────────────────────────────────────────────────

func _get_satisfaction_bonus() -> float:
	if _satisfaction >= 8:
		return SATISFACTION_BONUS_HIGH
	elif _satisfaction >= 5:
		return SATISFACTION_BONUS_MEDIUM
	else:
		return SATISFACTION_BONUS_LOW


func _find_order(order_id: int) -> OrderEntry:
	for order: OrderEntry in _active_orders:
		if order.order_id == order_id:
			return order
	return null


# ── Bağımlılık enjeksiyonu ────────────────────────────────────────────────────

func _get_config() -> CustomerConfig:
	if config:
		return config
	var default_config := CustomerConfig.new()
	return default_config


func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem
