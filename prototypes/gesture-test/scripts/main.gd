extends Node2D

## Main scene controller — wires all prototype signals together.
## The complete loop:
##   1. Circular drag x3  → dough_ready
##   2. Tap ready dough   → bake_timer.start()
##   3. 8s timer fires    → bread_ready
##   4. Tap bread         → bread_harvested → coin_counter += 10
##   5. Dough resets      → loop repeats

@onready var gesture_detector: Node = $GestureDetector
@onready var dough_node: Node2D = $DoughNode
@onready var bake_station: Node2D = $BakeStation
@onready var coin_counter: Node2D = $CoinCounter

# Debug labels
@onready var circle_count_label: Label = $DebugPanel/CircleCountLabel
@onready var fraction_label: Label = $DebugPanel/FractionLabel
@onready var radius_label: Label = $DebugPanel/RadiusLabel


func _ready() -> void:
	# Gesture → Dough
	gesture_detector.gesture_progress.connect(dough_node.on_gesture_progress)
	gesture_detector.gesture_completed.connect(dough_node.on_gesture_completed)
	gesture_detector.gesture_cancelled.connect(dough_node.on_gesture_cancelled)

	# Gesture → Debug display
	gesture_detector.gesture_progress.connect(_update_debug_display)
	gesture_detector.gesture_completed.connect(_on_gesture_completed_debug)

	# Dough → Bake
	dough_node.dough_to_oven.connect(_on_dough_to_oven)

	# Bake → Harvest
	bake_station.bread_harvested.connect(coin_counter.on_bread_harvested)
	bake_station.bread_harvested.connect(_reset_dough)


func _on_dough_to_oven() -> void:
	bake_station.start_bake()


func _reset_dough() -> void:
	# Reset dough state for next knead cycle
	dough_node.state = dough_node.State.IDLE
	var tween := create_tween()
	tween.tween_property(dough_node.get_node("DoughRect"), "scale", Vector2(1.0, 1.0), 0.3)
	tween.parallel().tween_property(dough_node.get_node("DoughRect"), "modulate:a", 1.0, 0.3)
	dough_node.get_node("DoughRect").color = dough_node.COLOR_IDLE
	dough_node.get_node("StatusLabel").text = "Knead the dough\n(draw 3 circles)"


func _update_debug_display(fraction: float) -> void:
	circle_count_label.text = "Circles: %d / 3" % gesture_detector.debug_circle_count
	fraction_label.text = "Progress: %d%%" % int(fraction * 100)
	radius_label.text = "Radius: %.0fpx" % gesture_detector.debug_last_radius


func _on_gesture_completed_debug() -> void:
	circle_count_label.text = "Circles: 3 / 3 ✓"
	fraction_label.text = "Progress: 100%"


func _process(_delta: float) -> void:
	# Only for debug display refresh — no gameplay logic here
	if gesture_detector.debug_last_radius > 0:
		radius_label.text = "Radius: %.0fpx" % gesture_detector.debug_last_radius
