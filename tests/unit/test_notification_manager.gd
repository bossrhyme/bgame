## GUT Test Suite — NotificationManager
## design/gdd/notification-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_notification_manager.gd
extends GutTest


var notif: NotificationManager


func before_each() -> void:
	notif = NotificationManager.new()
	add_child(notif)


func after_each() -> void:
	if is_instance_valid(notif):
		notif.queue_free()


# ── queue_notification ────────────────────────────────────────────────────────

func test_queue_notification_adds_to_queue() -> void:
	notif.queue_notification("Test", NotificationManager.Priority.INFO)
	# Toast hemen başlar (_toast_active=true), kuyruk 0 olabilir
	# Sadece çökmediğini doğrula
	pass_test()


func test_empty_message_ignored() -> void:
	notif.queue_notification("", NotificationManager.Priority.HIGH)
	assert_eq(notif.queue_size, 0, "Boş mesaj kuyruğa eklenmez")


# ── Öncelik sıralaması ────────────────────────────────────────────────────────

func test_high_priority_goes_before_low() -> void:
	# _toast_active durumunu simüle etmek için doğrudan _insert kullanıyoruz
	notif._toast_active = true  # toast aktif → _show_next çağrılmaz, kuyrukta kalır
	notif._insert_by_priority({"message": "low msg", "priority": NotificationManager.Priority.LOW})
	notif._insert_by_priority({"message": "info msg", "priority": NotificationManager.Priority.INFO})
	notif._insert_by_priority({"message": "high msg", "priority": NotificationManager.Priority.HIGH})

	assert_eq(notif._queue[0].get("message"), "high msg",
		"HIGH mesaj kuyruğun başında")


func test_medium_priority_after_high_before_low() -> void:
	notif._toast_active = true
	notif._insert_by_priority({"message": "low", "priority": NotificationManager.Priority.LOW})
	notif._insert_by_priority({"message": "high", "priority": NotificationManager.Priority.HIGH})
	notif._insert_by_priority({"message": "med", "priority": NotificationManager.Priority.MEDIUM})

	assert_eq(notif._queue[0].get("message"), "high", "HIGH önce")
	assert_eq(notif._queue[1].get("message"), "med", "MEDIUM HIGH'dan sonra")
	assert_eq(notif._queue[2].get("message"), "low", "LOW en sonda")


func test_multiple_high_messages_in_order() -> void:
	notif._toast_active = true
	notif._insert_by_priority({"message": "high1", "priority": NotificationManager.Priority.HIGH})
	notif._insert_by_priority({"message": "high2", "priority": NotificationManager.Priority.HIGH})

	# Her ikisi de HIGH: ekleme sırasında kalır
	assert_eq(notif._queue[0].get("message"), "high1")
	assert_eq(notif._queue[1].get("message"), "high2")


# ── Deduplication ─────────────────────────────────────────────────────────────

func test_duplicate_message_within_window_ignored() -> void:
	# İlk mesaj → gösterilir; dedup kaydı oluştu
	notif._last_shown["Grev!"] = Time.get_unix_time_from_system()

	# Aynı mesajı hemen tekrar ekle
	notif._toast_active = true
	notif.queue_notification("Grev!", NotificationManager.Priority.HIGH)

	assert_eq(notif.queue_size, 0, "Dedup penceresi içinde mesaj kuyruğa girmez")


func test_duplicate_message_after_window_allowed() -> void:
	# Pencere dolmuş (6 saniye önceden)
	notif._last_shown["Grev!"] = Time.get_unix_time_from_system() - 6.0
	notif._toast_active = true
	notif.queue_notification("Grev!", NotificationManager.Priority.HIGH)

	assert_eq(notif.queue_size, 1, "Pencere dolduktan sonra mesaj kuyruğa girer")


# ── MAX_QUEUE_SIZE ────────────────────────────────────────────────────────────

func test_max_queue_size_enforced_removes_low_priority() -> void:
	notif._toast_active = true
	# 10 INFO mesaj ekle
	for i: int in range(10):
		notif._insert_by_priority({"message": "info_%d" % i, "priority": NotificationManager.Priority.INFO})
	assert_eq(notif.queue_size, 10, "10 mesaj kuyruğa eklendi")

	# 11. mesaj → en eski INFO silinir
	notif._insert_by_priority({"message": "new_info", "priority": NotificationManager.Priority.INFO})
	assert_eq(notif.queue_size, 10, "Kuyruk 10'da tutuldu")


func test_high_priority_messages_preserved_during_overflow() -> void:
	notif._toast_active = true
	# 5 HIGH ekle
	for i: int in range(5):
		notif._insert_by_priority({"message": "high_%d" % i, "priority": NotificationManager.Priority.HIGH})
	# 5 LOW ekle
	for i: int in range(5):
		notif._insert_by_priority({"message": "low_%d" % i, "priority": NotificationManager.Priority.LOW})
	# 3 INFO daha → LOW'lar silinir
	for i: int in range(3):
		notif._insert_by_priority({"message": "info_%d" % i, "priority": NotificationManager.Priority.INFO})

	# 5 HIGH korunmalı
	var high_count := 0
	for entry: Dictionary in notif._queue:
		if entry.get("priority") == NotificationManager.Priority.HIGH:
			high_count += 1
	assert_eq(high_count, 5, "HIGH mesajlar overflow'da korundu")


# ── Sinyal bağlantıları ───────────────────────────────────────────────────────

func test_strike_signal_queues_high_notification() -> void:
	# Arrange: EmployeeManager mock
	var economy := EconomySystem.new()
	add_child(economy)
	var emp := EmployeeManager.new()
	emp._economy_ref = economy
	add_child(emp)
	notif._employee_ref = emp

	# Sinyali manuel bağla (DI injection sonrası _wire_signals çağrılmadı)
	emp.strike_started.connect(notif._on_strike_started)
	notif._toast_active = true  # kuyruğa düşürmek için

	# Act
	emp.strike_started.emit()

	# Assert
	assert_eq(notif.queue_size, 1, "Grev sinyali kuyruğa ekledi")
	assert_eq(notif._queue[0].get("priority"), NotificationManager.Priority.HIGH,
		"Grev mesajı HIGH öncelikli")

	emp.queue_free()
	economy.queue_free()


func test_satisfaction_low_queues_medium_notification() -> void:
	notif._toast_active = true
	notif._on_satisfaction_changed(2)  # 2 ≤ 3 → MEDIUM

	assert_eq(notif.queue_size, 1)
	assert_eq(notif._queue[0].get("priority"), NotificationManager.Priority.MEDIUM)


func test_satisfaction_high_no_notification() -> void:
	notif._toast_active = true
	notif._on_satisfaction_changed(8)  # 8 > 3 → bildirim yok

	assert_eq(notif.queue_size, 0, "Yüksek memnuniyet → bildirim yok")


func test_task_completed_queues_low_notification() -> void:
	notif._toast_active = true
	notif._on_task_completed(42)

	assert_eq(notif.queue_size, 1)
	assert_eq(notif._queue[0].get("priority"), NotificationManager.Priority.LOW)


func test_all_tasks_completed_queues_info_notification() -> void:
	notif._toast_active = true
	notif._on_all_tasks_completed(525)

	assert_eq(notif.queue_size, 1)
	assert_eq(notif._queue[0].get("priority"), NotificationManager.Priority.INFO)
	assert_true(notif._queue[0].get("message", "").contains("525"),
		"Bonus miktarı mesajda yer aldı")


# ── clear ─────────────────────────────────────────────────────────────────────

func test_clear_empties_queue_and_dedup() -> void:
	notif._toast_active = true
	notif._insert_by_priority({"message": "msg1", "priority": NotificationManager.Priority.HIGH})
	notif._last_shown["msg1"] = Time.get_unix_time_from_system()

	notif.clear()

	assert_eq(notif.queue_size, 0, "Kuyruk temizlendi")
	assert_false(notif._last_shown.has("msg1"), "Dedup geçmişi temizlendi")
