extends Node

## Timer-based bake loop — validates ADR-0003 (no _process() for idle work).
## Uses Timer.timeout signal, NOT _process() delta accumulation.
## Hardcoded 8-second bake time (prototype only — production uses config resource).

const BAKE_TIME_SECONDS: float = 8.0

@onready var timer: Timer = $Timer
@onready var status_label: Label = $BakeStatusLabel
@onready var bread_rect: ColorRect = $BreadRect

var is_baking: bool = false

signal bread_ready
signal bread_harvested


func _ready() -> void:
	timer.wait_time = BAKE_TIME_SECONDS
	timer.one_shot = true
	timer.timeout.connect(_on_bake_complete)
	bread_rect.visible = false
	status_label.text = ""


func start_bake() -> void:
	if is_baking:
		return
	is_baking = true
	bread_rect.visible = false
	bread_rect.modulate.a = 1.0
	status_label.text = "Baking... (%.0fs)" % BAKE_TIME_SECONDS
	timer.start()

	# Update label during bake using a separate display timer
	# (Still no _process() — we use a looping 1s timer for the countdown display only)
	_start_countdown_display()


func _start_countdown_display() -> void:
	var display_timer := Timer.new()
	display_timer.wait_time = 1.0
	display_timer.autostart = true
	display_timer.timeout.connect(_update_countdown_label.bind(display_timer))
	add_child(display_timer)


func _update_countdown_label(display_timer: Timer) -> void:
	var remaining: float = timer.time_left
	if remaining <= 0.0:
		display_timer.queue_free()
		return
	status_label.text = "Baking... (%.0fs)" % remaining


func _on_bake_complete() -> void:
	is_baking = false
	status_label.text = "Bread ready! Tap to harvest"
	bread_rect.visible = true

	# Flash animation to attract attention
	var tween := create_tween().set_loops(3)
	tween.tween_property(bread_rect, "modulate:a", 0.3, 0.3)
	tween.tween_property(bread_rect, "modulate:a", 1.0, 0.3)

	bread_ready.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not bread_rect.visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		_harvest()


func _harvest() -> void:
	bread_rect.visible = false
	status_label.text = ""

	var tween := create_tween()
	tween.tween_property(bread_rect, "position:y", bread_rect.position.y - 80.0, 0.3)
	tween.tween_callback(func(): bread_rect.position.y += 80.0)

	bread_harvested.emit()
