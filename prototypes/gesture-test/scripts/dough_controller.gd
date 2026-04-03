extends Node2D

## Visual + state controller for the dough node.
## Connects to GestureDetector signals and shows ASMR-style feedback.
## State machine: IDLE -> KNEADING -> READY -> BAKING

enum State { IDLE, KNEADING, READY, BAKING }

var state: State = State.IDLE

@onready var dough_rect: ColorRect = $DoughRect
@onready var haptic: Node = $HapticHelper
@onready var status_label: Label = $StatusLabel

# Prototype colors (placeholder art)
const COLOR_IDLE    := Color(0.75, 0.65, 0.50)  # dry beige
const COLOR_KNEADING := Color(0.85, 0.72, 0.55) # warmer mid-knead
const COLOR_READY   := Color(0.95, 0.82, 0.62)  # warm golden beige — ready

signal dough_ready
signal dough_to_oven  # emitted when player taps ready dough to send to oven


func _ready() -> void:
	dough_rect.color = COLOR_IDLE
	status_label.text = "Knead the dough\n(draw 3 circles)"


func on_gesture_progress(fraction: float) -> void:
	if state != State.IDLE and state != State.KNEADING:
		return
	state = State.KNEADING

	# Pulse scale: grows slightly with each circle
	var scale_val: float = 1.0 + fraction * 0.3
	var tween := create_tween()
	tween.tween_property(dough_rect, "scale", Vector2(scale_val, scale_val), 0.1)

	# Interpolate color toward ready
	dough_rect.color = COLOR_IDLE.lerp(COLOR_KNEADING, fraction)

	# Haptic tick on each 33% progress (one circle)
	var prev_circles := int((fraction - 0.01) * 3)
	var curr_circles := int(fraction * 3)
	if curr_circles > prev_circles:
		haptic.pulse()

	status_label.text = "Kneading... %d / 3" % curr_circles


func on_gesture_completed() -> void:
	if state == State.BAKING:
		return
	state = State.READY
	haptic.complete()

	# Pop animation: scale up then settle
	var tween := create_tween()
	tween.tween_property(dough_rect, "scale", Vector2(1.4, 1.4), 0.15)
	tween.tween_property(dough_rect, "scale", Vector2(1.25, 1.25), 0.1)

	dough_rect.color = COLOR_READY
	status_label.text = "Dough ready!\nTap to send to oven"

	dough_ready.emit()


func on_gesture_cancelled() -> void:
	if state != State.KNEADING:
		return
	state = State.IDLE
	var tween := create_tween()
	tween.tween_property(dough_rect, "scale", Vector2(1.0, 1.0), 0.2)
	dough_rect.color = COLOR_IDLE
	status_label.text = "Knead the dough\n(draw 3 circles)"


func _unhandled_input(event: InputEvent) -> void:
	if state != State.READY:
		return
	if event is InputEventScreenTouch and event.pressed:
		# Tap on ready dough — send to oven
		state = State.BAKING
		var tween := create_tween()
		tween.tween_property(dough_rect, "modulate:a", 0.0, 0.25)
		status_label.text = "Baking..."
		dough_to_oven.emit()
