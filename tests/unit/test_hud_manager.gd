## GUT Test Suite — HUDManager
## src/ui/hud/hud_manager.gd — HUD kök denetleyicisi, toast bildirimleri
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_hud_manager.gd
extends GutTest


var _hud: HUDManager
var _economy: EconomySystem
var _customer: CustomerOrderSystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(0, 0)

	_customer = CustomerOrderSystem.new()
	add_child_autofree(_customer)

	_hud = HUDManager.new()
	_hud._economy_ref = _economy
	_hud._customer_ref = _customer
	add_child_autofree(_hud)


# ── Başlangıç durumu ──────────────────────────────────────────────────────────

func test_toast_queue_empty_initially() -> void:
	assert_true(_hud._toast_queue.is_empty())


func test_toast_not_active_initially() -> void:
	assert_false(_hud._toast_active)


# ── show_notification ─────────────────────────────────────────────────────────

func test_show_notification_adds_to_queue() -> void:
	# İlk çağrı kuyruğa ekler ve hemen işler (_toast_active = true)
	_hud.show_notification("Test mesajı")
	# Aktif işleme başladıysa kuyruk boş olabilir (pop edildi)
	assert_true(_hud._toast_active)


func test_show_notification_multiple_queues_up() -> void:
	# İlk mesaj işlenirken ikincisi kuyruğa girer
	_hud.show_notification("Birinci")
	_hud.show_notification("İkinci")
	# İkinci mesaj kuyruğa eklenmiş olmalı
	assert_eq(_hud._toast_queue.size(), 1)


func test_show_notification_empty_string_no_crash() -> void:
	_hud.show_notification("")
	assert_true(true)


func test_show_notification_long_message_no_crash() -> void:
	_hud.show_notification("X".repeat(500))
	assert_true(true)


# ── Toast kuyruğu ─────────────────────────────────────────────────────────────

func test_show_next_toast_empty_queue_deactivates() -> void:
	_hud._toast_active = true
	_hud._toast_queue.clear()
	_hud._show_next_toast()
	assert_false(_hud._toast_active)


func test_show_next_toast_pops_first_entry() -> void:
	_hud._toast_queue.append({"message": "A"})
	_hud._toast_queue.append({"message": "B"})
	_hud._show_next_toast()
	# "A" işlendi, "B" kuyrukta
	assert_eq(_hud._toast_queue.size(), 1)
	assert_eq(_hud._toast_queue[0]["message"], "B")


# ── Sinyal sinyalleri ─────────────────────────────────────────────────────────

func test_upgrade_menu_requested_signal_exists() -> void:
	assert_true(_hud.has_signal("upgrade_menu_requested"))


func test_employee_menu_requested_signal_exists() -> void:
	assert_true(_hud.has_signal("employee_menu_requested"))


func test_recipe_menu_requested_signal_exists() -> void:
	assert_true(_hud.has_signal("recipe_menu_requested"))


# ── Satisfaction düşük bildirimi ──────────────────────────────────────────────

func test_low_satisfaction_triggers_notification() -> void:
	# satisfaction_changed → 3 veya altında → show_notification çağrılmalı
	_hud._on_satisfaction_changed(3)
	assert_true(_hud._toast_active)


func test_low_satisfaction_value_1_triggers_notification() -> void:
	_hud._on_satisfaction_changed(1)
	assert_true(_hud._toast_active)


func test_high_satisfaction_no_notification() -> void:
	_hud._on_satisfaction_changed(8)
	assert_false(_hud._toast_active)


func test_satisfaction_exactly_3_triggers_notification() -> void:
	_hud._on_satisfaction_changed(3)
	assert_true(_hud._toast_active)


func test_satisfaction_4_no_notification() -> void:
	_hud._on_satisfaction_changed(4)
	assert_false(_hud._toast_active)


# ── NotificationPriority enum ────────────────────────────────────────────────

func test_priority_info_is_lowest() -> void:
	assert_lt(HUDManager.NotificationPriority.INFO, HUDManager.NotificationPriority.HIGH)


func test_priority_high_is_highest() -> void:
	assert_gt(HUDManager.NotificationPriority.HIGH, HUDManager.NotificationPriority.LOW)


# ── Lazy-init getter'lar ──────────────────────────────────────────────────────

func test_get_economy_returns_injected() -> void:
	assert_eq(_hud._get_economy(), _economy)


func test_get_customer_returns_injected() -> void:
	assert_eq(_hud._get_customer(), _customer)


func test_get_economy_null_when_not_wired() -> void:
	var h := HUDManager.new()
	add_child_autofree(h)
	assert_null(h._get_economy())


# ── Wire bağlantıları ─────────────────────────────────────────────────────────

func test_wire_customer_no_crash_without_customer() -> void:
	_hud._customer_ref = null
	_hud._wire_customer()
	assert_true(true)


func test_wire_economy_no_crash_without_economy() -> void:
	_hud._economy_ref = null
	_hud._wire_economy()
	assert_true(true)
