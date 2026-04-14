## test_customer_order_system.gd
##
## GUT testleri — CustomerOrderSystem (S2-04)
## Kapsanan AC'ler: sipariş teslim, grace, escape, memnuniyet,
##   spawn engelleme, offline 8 saat, altın formülü
extends GutTest

var _system: CustomerOrderSystem


func before_each() -> void:
	_system = CustomerOrderSystem.new()
	add_child_autofree(_system)
	# EconomySystem mock — testlerde sinyal yeterliyse null bırak
	_system._economy_ref = null


# ── Yardımcılar ───────────────────────────────────────────────────────────────

func _make_customer(patience_secs: float, gold_mult: float,
		weight: float = 10.0, id: StringName = &"normal") -> CustomerTypeData:
	var ct := CustomerTypeData.new()
	ct.id = id
	ct.display_name = str(id)
	ct.patience_seconds = patience_secs
	ct.gold_multiplier = gold_mult
	ct.spawn_weight = weight
	return ct


func _add_order_now(base_gold: int = 100, patience_secs: float = 300.0,
		gold_mult: float = 1.0) -> OrderEntry:
	var ct := _make_customer(patience_secs, gold_mult)
	return _system._add_order(&"white_bread", ct, base_gold)


func _add_order_past(seconds_ago: int, patience_secs: float = 300.0,
		base_gold: int = 100) -> OrderEntry:
	var ct := _make_customer(patience_secs, 1.0)
	var past_unix := Time.get_unix_time_from_system() - seconds_ago
	return _system._add_order(&"white_bread", ct, base_gold, past_unix)


# ── AC: Başlangıç durumu ──────────────────────────────────────────────────────

func test_initial_satisfaction_is_10() -> void:
	assert_eq(_system.get_satisfaction(), 10, "Başlangıç memnuniyeti 10 olmalı")


func test_initial_active_orders_empty() -> void:
	assert_eq(_system.get_active_order_count(), 0, "Başlangıçta aktif sipariş olmamalı")


# ── AC: Sipariş ekleme ────────────────────────────────────────────────────────

func test_add_order_increases_count() -> void:
	_add_order_now()
	assert_eq(_system.get_active_order_count(), 1)


func test_add_order_emits_signal() -> void:
	watch_signals(_system)
	_add_order_now()
	assert_signal_emitted(_system, "order_added")


func test_add_order_status_is_waiting() -> void:
	var order := _add_order_now()
	assert_eq(order.status, OrderEntry.OrderStatus.WAITING)


# ── AC: Teslim — tam altın (WAITING) ─────────────────────────────────────────

func test_deliver_waiting_order_returns_full_gold() -> void:
	# satisfaction=10 → bonus=1.1x; modifier=1.0
	# 100 * 1.0 * 1.1 = 110
	var order := _add_order_now(100)
	var gold := _system.deliver_order(order.order_id)
	assert_eq(gold, 110, "WAITING teslimde tam altın (satisfaction 1.1x bonus) = 110")


func test_deliver_order_emits_signal() -> void:
	var order := _add_order_now()
	watch_signals(_system)
	_system.deliver_order(order.order_id)
	assert_signal_emitted(_system, "order_delivered")


func test_deliver_order_removes_from_active() -> void:
	var order := _add_order_now()
	_system.deliver_order(order.order_id)
	assert_eq(_system.get_active_order_count(), 0, "Teslim sonrası sipariş aktif listeden çıkmalı")


func test_deliver_unknown_order_returns_zero() -> void:
	var gold := _system.deliver_order(9999)
	assert_eq(gold, 0, "Bilinmeyen sipariş ID'si 0 döndürmeli")


# ── AC: Teslim — grace altın (%50) ───────────────────────────────────────────

func test_deliver_grace_order_returns_half_gold() -> void:
	# patience=1sn, created 2sn önce → patience expired, grace active (10sn)
	var order := _add_order_past(2, 1.0, 100)
	_system.update_order_states()
	assert_eq(order.status, OrderEntry.OrderStatus.GRACE, "Sipariş GRACE durumuna geçmeli")
	# 100 * 0.5 * 1.1 = 55
	var gold := _system.deliver_order(order.order_id)
	assert_eq(gold, 55, "GRACE teslimde %50 altın (1.1x satisfaction bonus) = 55")


func test_grace_order_emits_grace_started_signal() -> void:
	var order := _add_order_past(2, 1.0)
	watch_signals(_system)
	_system.update_order_states()
	assert_signal_emitted_with_parameters(_system, "order_grace_started", [order])


# ── AC: Kaçış (grace doldu) ───────────────────────────────────────────────────

func test_escaped_order_not_in_active_list() -> void:
	# patience=1sn, created 20sn önce → hem patience hem grace doldu
	_add_order_past(20, 1.0)
	_system.update_order_states()
	assert_eq(_system.get_active_order_count(), 0, "Kaçmış sipariş aktif listede olmamalı")


func test_escaped_order_emits_signal() -> void:
	_add_order_past(20, 1.0)
	watch_signals(_system)
	_system.update_order_states()
	assert_signal_emitted(_system, "customer_escaped")


func test_deliver_escaped_order_returns_zero() -> void:
	var order := _add_order_past(20, 1.0, 100)
	_system.update_order_states()
	var gold := _system.deliver_order(order.order_id)
	assert_eq(gold, 0, "Kaçmış siparişi teslim etmek 0 döndürmeli")


# ── AC: Memnuniyet — kaçış cezası ─────────────────────────────────────────────

func test_escape_decrements_satisfaction() -> void:
	_add_order_past(20, 1.0)
	_system.update_order_states()
	assert_eq(_system.get_satisfaction(), 9, "Müşteri kaçışı memnuniyeti 1 düşürmeli")


func test_escape_emits_satisfaction_changed_signal() -> void:
	_add_order_past(20, 1.0)
	watch_signals(_system)
	_system.update_order_states()
	assert_signal_emitted(_system, "satisfaction_changed")


func test_satisfaction_cannot_go_below_zero() -> void:
	_system._satisfaction = 0
	# Direkt _escape_order çağır
	var order := _add_order_now()
	_system._escape_order(order)
	assert_eq(_system.get_satisfaction(), 0, "Memnuniyet 0'ın altına düşemez")


func test_satisfaction_capped_at_zero() -> void:
	# 11 kaçış ile 0 altına çek; 0'ın altına düşmemeli
	_system._satisfaction = 2
	for i in range(3):
		_add_order_past(20, 1.0)
	_system.update_order_states()
	assert_eq(_system.get_satisfaction(), 0, "Memnuniyet minimum 0'da sabitlenmeli")


# ── AC: Memnuniyet — teslimat streak'i ───────────────────────────────────────

func test_delivery_streak_increments_satisfaction() -> void:
	_system._satisfaction = 7  # Başlangıç memnuniyeti
	# 5 arka arkaya başarılı teslim → +1 memnuniyet
	for i in range(5):
		var order := _add_order_now()
		_system.deliver_order(order.order_id)
	assert_eq(_system.get_satisfaction(), 8, "5 başarılı teslim sonrası memnuniyet +1 artmalı")


func test_delivery_streak_resets_on_escape() -> void:
	# 4 başarılı teslim, 1 kaçış → streak sıfırlanır
	for i in range(4):
		var order := _add_order_now()
		_system.deliver_order(order.order_id)
	_add_order_past(20, 1.0)  # Bu kaçacak
	_system.update_order_states()
	# Şimdi 1 teslim daha → streak=1, memnuniyet değişmemeli
	var next := _add_order_now()
	_system.deliver_order(next.order_id)
	# Streak 1'de; +1 için 4 tane daha gerekli
	# Satisfaction 10-1=9 (escape'den) sonra hâlâ 9 olmalı (yalnızca 1 teslim)
	assert_eq(_system.get_satisfaction(), 9, "Kaçış sonrası streak sıfırlanmalı")


func test_satisfaction_max_is_ten() -> void:
	_system._satisfaction = 10
	_system._delivery_streak = 4
	var order := _add_order_now()
	_system.deliver_order(order.order_id)
	assert_eq(_system.get_satisfaction(), 10, "Memnuniyet 10'un üstüne çıkmamalı")


# ── AC: Spawn engelleme ───────────────────────────────────────────────────────

func test_spawn_blocked_when_satisfaction_zero() -> void:
	_system._satisfaction = 0
	_system.customer_types = [_make_customer(300.0, 1.0)]
	_system.available_recipe_ids = [&"white_bread"]
	_system._schedule_spawn()
	assert_null(_system._spawn_timer, "Memnuniyet=0 iken spawn planlanmamalı")


func test_spawn_blocked_when_slots_full() -> void:
	# max_active_orders = 4; 4 sipariş ekle
	var ct := _make_customer(300.0, 1.0)
	for i in range(4):
		_system._add_order(&"white_bread", ct, 10)
	assert_eq(_system.get_active_order_count(), 4)
	_system.customer_types = [ct]
	_system.available_recipe_ids = [&"white_bread"]
	_system._schedule_spawn()
	assert_null(_system._spawn_timer, "Slotlar dolu iken spawn planlanmamalı")


func test_spawn_blocked_when_no_customer_types() -> void:
	_system.customer_types = []
	_system.available_recipe_ids = [&"white_bread"]
	_system._schedule_spawn()
	assert_null(_system._spawn_timer, "Müşteri tipi yokken spawn planlanmamalı")


# ── AC: Offline 8 saat → tüm siparişler kaçmış ───────────────────────────────

func test_offline_8_hours_all_orders_escaped() -> void:
	# 8 saat = 28800 saniye; patience=300sn + grace=10sn = 310sn << 28800sn
	var order1 := _add_order_past(28800, 300.0, 50)
	var order2 := _add_order_past(28800, 300.0, 80)
	assert_eq(_system.get_active_order_count(), 2)
	watch_signals(_system)
	_system.update_order_states()
	assert_eq(_system.get_active_order_count(), 0,
		"8 saatlik offline sonrası tüm siparişler kaçmış olmalı")
	assert_signal_emit_count(_system, "customer_escaped", 2,
		"2 sipariş için customer_escaped sinyali yayılmalı")


func test_offline_8_hours_satisfaction_decremented() -> void:
	_add_order_past(28800, 300.0)
	_add_order_past(28800, 300.0)
	_system.update_order_states()
	assert_eq(_system.get_satisfaction(), 8,
		"8 saatlik offline 2 kaçıştan sonra memnuniyet 10-2=8 olmalı")


# ── AC: VIP altın formülü ─────────────────────────────────────────────────────

func test_vip_gold_multiplier() -> void:
	# VIP: gold_multiplier=3.0; base_gold=100 → 100*3.0 = 300 base
	# satisfaction=10 → bonus=1.1; modifier=1.0 (WAITING)
	# final = 300 * 1.0 * 1.1 = 330
	var vip := _make_customer(180.0, 3.0, 5.0, &"vip")
	var order := _system._add_order(&"white_bread", vip, int(100.0 * 3.0))
	var gold := _system.deliver_order(order.order_id)
	assert_eq(gold, 330, "VIP teslimde base_gold=300, satisfaction 1.1x bonus = 330")


# ── AC: Satisfaction bonus seviyeleri ────────────────────────────────────────

func test_satisfaction_bonus_high() -> void:
	# satisfaction=8 → 1.1x
	_system._satisfaction = 8
	var order := _system._add_order(&"white_bread", _make_customer(300.0, 1.0), 100)
	var gold := _system.deliver_order(order.order_id)
	assert_eq(gold, 110, "Memnuniyet 8-10 → 1.1x bonus")


func test_satisfaction_bonus_medium() -> void:
	# satisfaction=7 → 1.0x; 100 * 1.0 * 1.0 = 100
	_system._satisfaction = 7
	var order := _system._add_order(&"white_bread", _make_customer(300.0, 1.0), 100)
	var gold := _system.deliver_order(order.order_id)
	assert_eq(gold, 100, "Memnuniyet 5-7 → 1.0x bonus")


func test_satisfaction_bonus_low() -> void:
	# satisfaction=3 → 0.9x; 100 * 1.0 * 0.9 = 90
	_system._satisfaction = 3
	var order := _system._add_order(&"white_bread", _make_customer(300.0, 1.0), 100)
	var gold := _system.deliver_order(order.order_id)
	assert_eq(gold, 90, "Memnuniyet 0-4 → 0.9x bonus")


# ── AC: CustomerConfig max_active_orders ────────────────────────────────────

func test_max_active_orders_from_config() -> void:
	var cfg := CustomerConfig.new()
	cfg.max_active_orders = 2
	_system.config = cfg
	var ct := _make_customer(300.0, 1.0)
	_system.customer_types = [ct]
	_system.available_recipe_ids = [&"white_bread"]
	# 2 sipariş ekle
	_system._add_order(&"white_bread", ct, 10)
	_system._add_order(&"white_bread", ct, 10)
	# 3. spawn planlanamaz
	_system._schedule_spawn()
	assert_null(_system._spawn_timer,
		"CustomerConfig.max_active_orders=2 ile 2 sipariş sonrası spawn bloklanmalı")


# ── AC: Serialize/Deserialize ────────────────────────────────────────────────

func test_serialize_includes_satisfaction() -> void:
	_system._satisfaction = 7
	var data := _system.serialize()
	assert_eq(data.get("satisfaction"), 7, "Serialize satisfaction içermeli")


func test_serialize_includes_orders() -> void:
	_add_order_now()
	var data := _system.serialize()
	assert_eq((data.get("orders") as Array).size(), 1, "Serialize aktif siparişleri içermeli")
