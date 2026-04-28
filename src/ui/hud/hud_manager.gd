## HUDManager — HUD Kök Denetleyicisi
##
## ResourceBar, sipariş panosu, hızlı erişim menüsü ve bildirim katmanını
## barındıran CanvasLayer 1 üzerindeki kök node'dur.
##
## Sinyalleri wiring: Economy, CustomerOrderSystem → HUD bileşenleri.
## Bileşenler arası doğrudan bağlantı yoktur; HUDManager aracıdır.
##
## GDD: design/gdd/ui-hud-system.md — CanvasLayer Mimarisi
class_name HUDManager
extends CanvasLayer

## Menü buton sinyalleri. UI Programmer bu sinyallere sahne root'undan bağlanır.
signal upgrade_menu_requested
signal employee_menu_requested
signal recipe_menu_requested

## Bildirim öncelik seviyeleri (GDD §3 Bildirim Katmanı).
enum NotificationPriority { INFO = 0, LOW = 1, MEDIUM = 2, HIGH = 3 }

## Toast görünürlük süresi (GDD §4: 3.0 sn).
const TOAST_VISIBLE_SEC: float = 3.0
## Toast giriş/çıkış süresi.
const TOAST_SLIDE_SEC: float = 0.2
const TOAST_FADE_SEC: float = 0.3

## ResourceBar referansı. Inspector veya test aracılığıyla atanır.
@export var resource_bar: ResourceBar

## Bildirim kuyruğu; aynı anda yalnızca bir toast gösterilir.
var _toast_queue: Array[Dictionary] = []
var _toast_active: bool = false

## Dependency injection.
var _economy_ref: EconomySystem = null
var _customer_ref: CustomerOrderSystem = null


func _ready() -> void:
	_wire_economy()
	_wire_customer()


# ── Public API ────────────────────────────────────────────────────────────────

## Toast bildirimi kuyruğa ekler. Yüksek öncelikli mesajlar düşük önceliklilerin
## önüne geçer (önce emit edilir, kuyrukta sıralanmaz — mevcut implementasyonda
## basit FIFO; öncelik sıralaması sonraki iterasyonda eklenecek).
func show_notification(message: String,
		_priority: NotificationPriority = NotificationPriority.INFO) -> void:
	_toast_queue.append({"message": message})
	if not _toast_active:
		_show_next_toast()


# ── Internal ──────────────────────────────────────────────────────────────────

func _wire_economy() -> void:
	var economy := _get_economy()
	if not economy:
		push_warning("HUDManager: Economy sistemi bulunamadı")
		return
	# ResourceBar kendi bağlantısını _ready()'de kurar;
	# HUDManager yalnızca grev uyarısı gibi üst düzey bildirimleri dinler.


func _wire_customer() -> void:
	var customer := _get_customer()
	if not customer:
		return
	if customer.has_signal("satisfaction_changed"):
		customer.satisfaction_changed.connect(_on_satisfaction_changed)


func _on_satisfaction_changed(new_value: int) -> void:
	if new_value <= 3:
		show_notification("Müşteri memnuniyeti düşük!", NotificationPriority.MEDIUM)


func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_active = false
		return
	_toast_active = true
	var entry: Dictionary = _toast_queue.pop_front()
	var msg: String = entry.get("message", "")
	# Gerçek Label/Panel animasyonu scene tasarımıyla eklenecek.
	# Şimdilik log ile göster; sahne bağlantısı S3'te yapılacak.
	push_warning("HUD Toast: %s" % msg)
	get_tree().create_timer(TOAST_VISIBLE_SEC).timeout.connect(
		func() -> void: _show_next_toast()
	)


func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem


func _get_customer() -> CustomerOrderSystem:
	if _customer_ref:
		return _customer_ref
	return get_node_or_null("/root/CustomerOrderSystem") as CustomerOrderSystem
