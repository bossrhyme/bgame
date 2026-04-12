## TapDetector
##
## Kısa dokunuş (G3) gesture'ını algılar. Her tappable node'un child'ı olarak eklenir.
## Hasat, müşteri satışı, çalışan ataması gibi context-resolution alıcı tarafında çözülür.
##
## Mimari kuralları (GDD Touch/Gesture Input):
##   - F-3: elapsed < TAP_MAX_MS AND moved < MIN_RADIUS → tapped(node) emit edilir
##   - Context-resolution alıcı tarafında: hangi aksiyonun tetikleneceğine alıcı karar verir
##   - target_node atanmazsa get_parent() kullanılır
class_name TapDetector
extends Node

## Dokunuş tap olarak tanındığında yayılır. node: tapped olan hedef.
signal tapped(node: Node)

@export var config: GestureConfig
## Tapped sinyaliyle emit edilecek node. Atanmazsa get_parent() kullanılır.
@export var target_node: Node

enum State { IDLE, PENDING }

var _state: State = State.IDLE
var _touch_id: int = -1
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time_ms: int = 0


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
		_touch_start_time_ms = Time.get_ticks_msec()
		_state = State.PENDING
	else:
		if event.index != _touch_id:
			return
		if _state == State.PENDING:
			# F-3: tap detection
			var elapsed: int = Time.get_ticks_msec() - _touch_start_time_ms
			var moved: float = (event.position - _touch_start_pos).length()
			if elapsed < config.tap_max_ms and moved < config.min_radius:
				var target: Node = target_node if target_node else get_parent()
				tapped.emit(target)
		_reset()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_id:
		return
	if _state == State.PENDING:
		var moved: float = (event.position - _touch_start_pos).length()
		if moved >= config.min_radius:
			_reset()  # Drag intent → tap iptal


func _reset() -> void:
	_state = State.IDLE
	_touch_id = -1
	_touch_start_pos = Vector2.ZERO
	_touch_start_time_ms = 0
