extends Node

## Coin counter + harvest feedback.
## Validates GPUParticles2D performance during coin burst on mobile renderer.

const COINS_PER_BREAD: int = 10

var total_coins: int = 0

@onready var coin_label: Label = $"/root/GestureTestMain/HUD/CoinLabel"
@onready var particles: GPUParticles2D = $CoinParticles
@onready var popup_label: Label = $PopupLabel


func _ready() -> void:
	popup_label.visible = false
	_update_display()


func on_bread_harvested() -> void:
	total_coins += COINS_PER_BREAD
	_update_display()
	_show_popup()
	_burst_particles()


func _update_display() -> void:
	if coin_label:
		coin_label.text = "Coins: %d" % total_coins


func _show_popup() -> void:
	popup_label.text = "+%d" % COINS_PER_BREAD
	popup_label.visible = true
	popup_label.modulate.a = 1.0
	popup_label.position.y = 0.0

	var tween := create_tween()
	tween.tween_property(popup_label, "position:y", -60.0, 0.6)
	tween.parallel().tween_property(popup_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): popup_label.visible = false)


func _burst_particles() -> void:
	if not particles:
		return
	particles.restart()
	particles.emitting = true
