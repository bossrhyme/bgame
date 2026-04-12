## DragToDropDetector
##
## Sürükle-bırak (G2) gesture'ını algılar. Hamur fırına atma için kullanılır.
## drop_zones listesindeki Node2D'lerden biri snap_radius içindeyse drag_dropped emit edilir.
##
## Mimari kuralları (GDD Touch/Gesture Input):
##   - INTENT_PENDING: hareket < MIN_RADIUS iken tap/drag belirsiz; MIN_RADIUS geçince DRAGGING
##   - DropZone dışına bırakılınca drag_cancelled emit edilir
##   - Tap intent: TapDetector'a bırakılır (DragToDropDetector pasif kalır)
class_name DragToDropDetector
extends Node

## DropZone içine bırakılınca yayılır. target_node: hangi zone'a bırakıldı.
signal drag_dropped(target_node: Node)
## DropZone dışına bırakılınca yayılır.
signal drag_cancelled

@export var config: GestureConfig
## Geçerli DropZone node'ları. global_position ile snap kontrolü yapılır.
@export var drop_zones: Array[Node2D] = []

enum State { IDLE, INTENT_PENDING, DRAGGING }

var _state: State = State.IDLE
var _touch_id: int = -1
var _touch_start_pos: Vector2 = Vector2.ZERO
var _current_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	if not config:
		config = GestureConfig.new()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


# ── Internal ──────────────────────────────────────────────────────────────────

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_id != -1:
			return
		_touch_id = event.index
		_touch_start_pos = event.position
		_current_pos = event.position
		_state = State.INTENT_PENDING
	else:
		if event.index != _touch_id:
			return
		_current_pos = event.position
		if _state == State.DRAGGING:
			var target: Node2D = _find_drop_target(_current_pos)
			if target:
				drag_dropped.emit(target)
			else:
				drag_cancelled.emit()
		# INTENT_PENDING'de bırakma: tap intent — TapDetector yakalar, sinyal yok
		_reset()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_id:
		return
	_current_pos = event.position
	if _state == State.INTENT_PENDING:
		var moved: float = (event.position - _touch_start_pos).length()
		if moved >= config.min_radius:
			_state = State.DRAGGING


func _find_drop_target(pos: Vector2) -> Node2D:
	for zone: Node2D in drop_zones:
		if not is_instance_valid(zone):
			continue
		var dist: float = (pos - zone.global_position).length()
		if dist <= config.drag_drop_snap_radius:
			return zone
	return null


func _reset() -> void:
	_state = State.IDLE
	_touch_id = -1
	_touch_start_pos = Vector2.ZERO
	_current_pos = Vector2.ZERO
