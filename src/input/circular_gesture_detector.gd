## CircularGestureDetector
##
## Hamur yoğurma için dairesel sürükleme (G1) gesture'ını algılar.
## 3 tam tur tamamlandığında circular_completed sinyali emit edilir.
##
## Mimari kuralları (GDD Touch/Gesture Input):
##   - _unhandled_input() üzerinden InputEventScreenTouch + InputEventScreenDrag işlenir
##   - _touch_id yalnızca parmak ekrandan kalkınca sıfırlanır (Core Rule 4)
##   - circular_completed sonrası COMPLETED durumuna geçer; parmak kalkana kadar yeni gesture yok
##   - Tüm eşik değerleri GestureConfig resource'undan okunur (hardcode yasak)
class_name CircularGestureDetector
extends Node

## 3 tam tur tamamlandığında yayılır.
signal circular_completed
## Her drag event'te tamamlanma oranı [0.0, 1.0] ile yayılır (F-1).
signal circular_progress(fraction: float)
## MAX_RADIUS aşıldığında veya parmak TRACKING sırasında kalkınca yayılır.
signal circular_cancelled
## Her tam tur geçişinde yayılır. Ses ve haptic tick için kullanılır (F-1b).
signal knead_tick(circle_count: int)

@export var config: GestureConfig

enum State { IDLE, TOUCH_DOWN, TRACKING, COMPLETED }

var _state: State = State.IDLE
var _touch_id: int = -1
var _center_pos: Vector2 = Vector2.ZERO
var _last_angle: float = 0.0
var _cumulative_angle: float = 0.0
var _prev_fraction: float = 0.0

## Dependency injection (test izolasyonu). null ise autoload'dan alınır.
var _settings_ref: SettingsManager = null


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
			return  # Başka parmak aktif — yok say (Core Rule 5)
		_touch_id = event.index
		_center_pos = event.position
		_state = State.TOUCH_DOWN
		_cumulative_angle = 0.0
		_prev_fraction = 0.0
	else:
		if event.index != _touch_id:
			return
		if _state == State.TRACKING:
			circular_cancelled.emit()
		_full_reset()  # Core Rule 4: _touch_id yalnızca parmak kalkınca sıfırlanır


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_id:
		return
	match _state:
		State.TOUCH_DOWN:
			var dist: float = (event.position - _center_pos).length()
			if dist >= config.min_radius:
				_state = State.TRACKING
				_last_angle = atan2(
					event.position.y - _center_pos.y,
					event.position.x - _center_pos.x
				)
		State.TRACKING:
			_process_circular(event.position)
		State.COMPLETED:
			pass  # Parmak kalkana kadar tüm drag event'leri yoksay


func _process_circular(pos: Vector2) -> void:
	var dist: float = (pos - _center_pos).length()
	if dist > config.max_radius:
		circular_cancelled.emit()
		_full_reset()
		return

	# F-2: ±π wrap-around normalizasyonu
	var new_angle: float = atan2(pos.y - _center_pos.y, pos.x - _center_pos.x)
	var delta: float = new_angle - _last_angle
	if delta > PI:
		delta -= TAU
	elif delta < -PI:
		delta += TAU
	_cumulative_angle += delta
	_last_angle = new_angle

	# F-1: tamamlanma fraksiyonu
	var circles_f: float = float(config.circles_required)
	var fraction: float = clampf(absf(_cumulative_angle) / (circles_f * TAU), 0.0, 1.0)
	circular_progress.emit(fraction)

	# F-1b: tam tur geçişi — haptic tick + knead_tick sinyali
	var prev_circles: int = int(_prev_fraction * circles_f)
	var curr_circles: int = int(fraction * circles_f)
	if curr_circles > prev_circles and fraction < 1.0:
		knead_tick.emit(curr_circles)
		_vibrate(config.haptic_tick_ms)

	_prev_fraction = fraction

	if fraction >= 1.0:
		_vibrate(config.haptic_complete_ms)
		circular_completed.emit()
		# Core Rule 4: _touch_id korunur; COMPLETED durumuna geç
		_state = State.COMPLETED
		_cumulative_angle = 0.0
		_prev_fraction = 0.0


func _vibrate(duration_ms: int) -> void:
	var settings := _get_settings()
	if settings and settings.get_haptic_enabled():
		Input.vibrate_handheld(duration_ms)


func _full_reset() -> void:
	_state = State.IDLE
	_touch_id = -1
	_center_pos = Vector2.ZERO
	_last_angle = 0.0
	_cumulative_angle = 0.0
	_prev_fraction = 0.0


func _get_settings() -> SettingsManager:
	if _settings_ref:
		return _settings_ref
	return get_node_or_null("/root/Settings") as SettingsManager
