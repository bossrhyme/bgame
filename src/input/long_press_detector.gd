## LongPressDetector
##
## Uzun basış + sürükleme (G4) gesture'ını algılar. Hamur şekil verme için kullanılır.
## LONG_PRESS_DURATION_MS hareketsiz basılırsa long_drag_started emit edilir.
##
## Mimari kuralları (GDD Touch/Gesture Input):
##   - F-4: elapsed >= LONG_PRESS_DURATION_MS AND moved < MIN_RADIUS → long-press intent
##   - Hareket MIN_RADIUS'u geçerse circular/drag intent devralır; long-press iptal
##   - Zamanlama Time.get_ticks_msec() ile her drag event'te kontrol edilir (ADR-0003 uyumlu)
class_name LongPressDetector
extends Node

## Long-press intent onaylandı; sürükleme başladı.
signal long_drag_started
## Parmak ekrandan kalkınca bırakış pozisyonuyla yayılır.
signal long_drag_ended(end_position: Vector2)

@export var config: GestureConfig

enum State { IDLE, PENDING, LONG_PRESSING }

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
		if _state == State.LONG_PRESSING:
			long_drag_ended.emit(event.position)
		_reset()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_id:
		return
	var moved: float = (event.position - _touch_start_pos).length()
	match _state:
		State.PENDING:
			if moved >= config.min_radius:
				# Circular/drag intent devralıyor — long-press iptal
				_reset()
				return
			# Hareket < MIN_RADIUS: zamanlama kontrolü (F-4)
			var elapsed: int = Time.get_ticks_msec() - _touch_start_time_ms
			if elapsed >= config.long_press_duration_ms:
				_state = State.LONG_PRESSING
				long_drag_started.emit()
		State.LONG_PRESSING:
			pass  # Sürükleme pozisyonu takip edilir; bırakınca long_drag_ended


func _reset() -> void:
	_state = State.IDLE
	_touch_id = -1
	_touch_start_pos = Vector2.ZERO
	_touch_start_time_ms = 0
