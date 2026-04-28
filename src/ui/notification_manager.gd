## NotificationManager — Bildirim Servisi
##
## Oyun olaylarını (grev, memnuniyet, görev) öncelik sıralamalı kuyrukta tutar ve
## HUDManager.show_notification() aracılığıyla oyuncuya iletir.
##
## Mimari kuralları (GDD Notification System #24):
##   - _process() yasaktır (ADR-0003); toast döngüsü SceneTreeTimer üzerinden
##   - Sinyal bağlantıları _ready()'de kurulur; eksik sistemler push_warning + skip
##   - Deduplication: aynı mesaj DEDUP_WINDOW_SEC içinde tekrar gösterilmez
##
## GDD: design/gdd/notification-system.md
class_name NotificationManager
extends Node

## Öncelik seviyeleri — HUDManager.NotificationPriority ile eşlenir.
enum Priority { INFO = 0, LOW = 1, MEDIUM = 2, HIGH = 3 }

const TOAST_VISIBLE_SEC: float = 3.0
const DEDUP_WINDOW_SEC: float = 5.0
const MAX_QUEUE_SIZE: int = 10

## Kuyruktaki bekleyen mesaj sayısı (test için salt okunur erişim).
var queue_size: int:
	get: return _queue.size()

var _queue: Array[Dictionary] = []  # [{message, priority}]
var _toast_active: bool = false
var _last_shown: Dictionary = {}  # message → unix timestamp (float)

## Dependency injection (test izolasyonu).
var _employee_ref: EmployeeManager = null
var _customer_ref: CustomerOrderSystem = null
var _task_ref: DailyTaskSystem = null
var _hud_ref: HUDManager = null


func _ready() -> void:
	_wire_signals()


# ── Public API ────────────────────────────────────────────────────────────────

## Mesajı öncelik sıralamalı kuyruğa ekler.
## HIGH mesajlar kuyruğun başına; INFO mesajlar sonuna eklenir.
func queue_notification(message: String, priority: Priority = Priority.INFO) -> void:
	if message.is_empty():
		push_warning("NotificationManager: Boş mesaj yoksayıldı")
		return
	if not _can_show(message):
		return
	_insert_by_priority({"message": message, "priority": priority})
	if not _toast_active:
		_show_next()


## Tüm kuyruğu ve deduplication geçmişini temizler (test izolasyonu için).
func clear() -> void:
	_queue.clear()
	_last_shown.clear()
	_toast_active = false


# ── Signal Wiring ─────────────────────────────────────────────────────────────

func _wire_signals() -> void:
	var employee := _get_employee()
	if employee:
		employee.strike_started.connect(_on_strike_started)
	else:
		push_warning("NotificationManager: EmployeeManager bağlanamadı")

	var customer := _get_customer()
	if customer:
		if customer.has_signal("satisfaction_changed"):
			customer.satisfaction_changed.connect(_on_satisfaction_changed)
	else:
		push_warning("NotificationManager: CustomerOrderSystem bağlanamadı")

	var task_sys := _get_task_system()
	if task_sys:
		task_sys.task_completed.connect(_on_task_completed)
		task_sys.all_tasks_completed.connect(_on_all_tasks_completed)
	else:
		push_warning("NotificationManager: DailyTaskSystem bağlanamadı")


func _on_strike_started() -> void:
	queue_notification("Çalışanlar greve çıktı! Maaş öde.", Priority.HIGH)


func _on_satisfaction_changed(new_value: int) -> void:
	if new_value <= 3:
		queue_notification("Müşteri memnuniyeti düşük!", Priority.MEDIUM)


func _on_task_completed(_task_id: int) -> void:
	queue_notification("Günlük görev tamamlandı!", Priority.LOW)


func _on_all_tasks_completed(bonus_gold: int) -> void:
	queue_notification("Tüm günlük görevler tamamlandı! +%d altın bonus" % bonus_gold,
		Priority.INFO)


# ── Internal ──────────────────────────────────────────────────────────────────

func _show_next() -> void:
	if _queue.is_empty():
		_toast_active = false
		return
	_toast_active = true
	var entry: Dictionary = _queue.pop_front()
	var msg: String = entry.get("message", "")
	_last_shown[msg] = Time.get_unix_time_from_system()

	var hud := _get_hud()
	if hud:
		hud.show_notification(msg, entry.get("priority", Priority.INFO) as HUDManager.NotificationPriority)

	var tree := get_tree()
	if tree:
		tree.create_timer(TOAST_VISIBLE_SEC).timeout.connect(
			func() -> void: _show_next()
		)
	else:
		push_warning("NotificationManager: SceneTree yok — timer oluşturulamadı")
		_toast_active = false


## HIGH mesajlar kuyruğun başına, LOW/INFO sona eklenir;
## MEDIUM en son HIGH'dan sonra eklenir.
func _insert_by_priority(entry: Dictionary) -> void:
	var prio: int = entry.get("priority", Priority.INFO)

	if prio == Priority.HIGH:
		# İlk HIGH olmayan girişin önüne ekle
		for i: int in range(_queue.size()):
			if _queue[i].get("priority", Priority.INFO) < Priority.HIGH:
				_queue.insert(i, entry)
				_enforce_max_size()
				return
		_queue.append(entry)
	elif prio == Priority.MEDIUM:
		# İlk MEDIUM/INFO/LOW girişinin önüne ekle (HIGH'ların arkasına)
		for i: int in range(_queue.size()):
			if _queue[i].get("priority", Priority.INFO) < Priority.MEDIUM:
				_queue.insert(i, entry)
				_enforce_max_size()
				return
		_queue.append(entry)
	else:
		_queue.append(entry)

	_enforce_max_size()


## Kuyruk MAX_QUEUE_SIZE'ı aşarsa en eski INFO/LOW mesajları siler.
func _enforce_max_size() -> void:
	while _queue.size() > MAX_QUEUE_SIZE:
		# Sondan başa tarayarak ilk INFO/LOW'u sil
		var removed: bool = false
		for i: int in range(_queue.size() - 1, -1, -1):
			var p: int = _queue[i].get("priority", Priority.INFO)
			if p <= Priority.LOW:
				_queue.remove_at(i)
				removed = true
				break
		if not removed:
			# Yalnızca HIGH/MEDIUM varsa en eskiyi sil
			_queue.remove_at(0)
			break


## Deduplication: mesaj son DEDUP_WINDOW_SEC içinde gösterildiyse false.
func _can_show(message: String) -> bool:
	if not _last_shown.has(message):
		return true
	var elapsed: float = Time.get_unix_time_from_system() - _last_shown[message]
	return elapsed >= DEDUP_WINDOW_SEC


func _get_employee() -> EmployeeManager:
	if _employee_ref:
		return _employee_ref
	return get_node_or_null("/root/EmployeeManager") as EmployeeManager


func _get_customer() -> CustomerOrderSystem:
	if _customer_ref:
		return _customer_ref
	return get_node_or_null("/root/CustomerOrderSystem") as CustomerOrderSystem


func _get_task_system() -> DailyTaskSystem:
	if _task_ref:
		return _task_ref
	return get_node_or_null("/root/DailyTaskSystem") as DailyTaskSystem


func _get_hud() -> HUDManager:
	if _hud_ref:
		return _hud_ref
	return get_node_or_null("/root/HUDManager") as HUDManager
