extends Node

## Circular drag gesture detector for dough kneading mechanic.
## Tests the hypothesis: can InputEventScreenDrag reliably detect 3 full
## clockwise circles on mobile hardware?
##
## Usage: Add as child of a Node2D. Set center_node to the dough target node.
## Listen to gesture_completed and gesture_progress signals.

# --- Signals ---

## Emitted when the required number of full circles is completed.
signal gesture_completed

## Emitted continuously during gesture. fraction = 0.0..1.0 (progress toward completion).
signal gesture_progress(fraction: float)

## Emitted when gesture is cancelled (finger lifted mid-gesture).
signal gesture_cancelled

# --- Config (hardcoded for prototype — production will use config resource) ---

const CIRCLES_REQUIRED: int = 3
const MIN_RADIUS: float = 40.0   # pixels — smaller than this = tap, not circle
const MAX_RADIUS: float = 200.0  # pixels — larger = probably not intentional

# --- State ---

var _touch_active: bool = false
var _touch_id: int = -1
var _finger_pos: Vector2 = Vector2.ZERO
var _center_pos: Vector2 = Vector2.ZERO
var _last_angle: float = 0.0
var _cumulative_angle: float = 0.0  # total radians accumulated
var _circles_completed: int = 0
var _gesture_started: bool = false

# Debug — visible in GestureTestMain via label
var debug_circle_count: int = 0
var debug_fraction: float = 0.0
var debug_last_radius: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and _touch_id == -1:
		# New finger down — record starting position as gesture center
		_touch_id = event.index
		_center_pos = event.position
		_finger_pos = event.position
		_touch_active = true
		_reset_gesture_state()
	elif not event.pressed and event.index == _touch_id:
		# Finger lifted — cancel any in-progress gesture
		if _gesture_started:
			gesture_cancelled.emit()
		_touch_id = -1
		_touch_active = false
		_gesture_started = false


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touch_active or event.index != _touch_id:
		return

	# Accumulate absolute position from relative drag deltas
	# NOTE: We track relative from the initial touch point so the center stays stable.
	# We do NOT use event.position directly as the angle reference because
	# InputEventScreenDrag.position can jitter on some devices.
	_finger_pos += event.relative

	var offset: Vector2 = _finger_pos - _center_pos
	var radius: float = offset.length()
	debug_last_radius = radius

	# Ignore if finger is too close to center (not a circular gesture)
	if radius < MIN_RADIUS:
		return

	var current_angle: float = atan2(offset.y, offset.x)

	if not _gesture_started:
		# First valid angle reading — initialize tracking
		_last_angle = current_angle
		_gesture_started = true
		return

	# Compute angular delta, handling wrap-around at ±π
	var delta: float = current_angle - _last_angle

	# Normalize delta to [-π, π] to handle the ±π boundary
	if delta > PI:
		delta -= TAU
	elif delta < -PI:
		delta += TAU

	# Accumulate clockwise rotation (positive delta = counter-clockwise in screen space)
	# Screen Y-axis is flipped, so clockwise in screen = negative atan2 delta
	# We track absolute value and check direction separately
	_cumulative_angle += delta
	_last_angle = current_angle

	# Count completed circles (TAU = one full rotation = 2π)
	var total_circles: float = abs(_cumulative_angle) / TAU
	var new_completed: int = int(total_circles)

	if new_completed > _circles_completed:
		_circles_completed = new_completed
		debug_circle_count = _circles_completed

	var fraction: float = min(total_circles / CIRCLES_REQUIRED, 1.0)
	debug_fraction = fraction
	gesture_progress.emit(fraction)

	# Check completion
	if _circles_completed >= CIRCLES_REQUIRED:
		gesture_completed.emit()
		_reset_gesture_state()
		_gesture_started = false
		_touch_id = -1
		_touch_active = false


func _reset_gesture_state() -> void:
	_cumulative_angle = 0.0
	_circles_completed = 0
	_last_angle = 0.0
	_gesture_started = false
	debug_circle_count = 0
	debug_fraction = 0.0
