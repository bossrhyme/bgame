## GameAudioBridge — Gameplay → Ses Köprüsü
##
## Gameplay olaylarını (ekmek pişme, müşteri hizmet, tarif açılımı)
## AudioManager.play_sfx() çağrılarına dönüştürür.
##
## AudioStream kaynakları sahne inspector'ından @export ile atanır.
## null stream → push_warning + atla; gameplay etkilenmez.
##
## GDD: design/gdd/sound-animation-system.md
class_name GameAudioBridge
extends Node

@export var sfx_bake_complete: AudioStream
@export var sfx_bread_harvest: AudioStream
@export var sfx_order_delivered: AudioStream
@export var sfx_customer_escaped: AudioStream
@export var sfx_recipe_unlocked: AudioStream
@export var sfx_dough_loaded: AudioStream

## Dependency injection (test izolasyonu).
var _audio_ref: AudioManager = null
var _oven_ref: OvenManager = null
var _customer_ref: CustomerOrderSystem = null
var _recipe_ref: RecipeManager = null
var _anim_ref: AnimationManager = null


func _ready() -> void:
	_wire_signals()


# ── Signal Wiring ─────────────────────────────────────────────────────────────

func _wire_signals() -> void:
	var audio := _get_audio()
	if not audio:
		push_warning("GameAudioBridge: AudioManager bağlanamadı")
		return

	var oven := _get_oven()
	if oven:
		oven.bake_completed.connect(_on_bake_completed)
		oven.bread_harvested.connect(_on_bread_harvested)
	else:
		push_warning("GameAudioBridge: OvenManager bağlanamadı")

	var customer := _get_customer()
	if customer:
		customer.order_delivered.connect(_on_order_delivered)
		customer.customer_escaped.connect(_on_customer_escaped)
	else:
		push_warning("GameAudioBridge: CustomerOrderSystem bağlanamadı")

	var recipe := _get_recipe()
	if recipe:
		recipe.recipe_unlocked.connect(_on_recipe_unlocked)
	else:
		push_warning("GameAudioBridge: RecipeManager bağlanamadı")

	var anim := _get_anim()
	if anim:
		anim.dough_loaded.connect(_on_dough_loaded)


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_bake_completed(_slot_id: int, _recipe_id: StringName) -> void:
	_play(sfx_bake_complete, AudioManager.SFX_PRIORITY_LOW)


func _on_bread_harvested(_slot_id: int, _recipe_id: StringName, _gold: int) -> void:
	_play(sfx_bread_harvest, AudioManager.SFX_PRIORITY_MEDIUM)


func _on_order_delivered(_order: OrderEntry, _gold: int) -> void:
	_play(sfx_order_delivered, AudioManager.SFX_PRIORITY_MEDIUM)


func _on_customer_escaped(_order: OrderEntry) -> void:
	_play(sfx_customer_escaped, AudioManager.SFX_PRIORITY_LOW)


func _on_recipe_unlocked(_recipe_id: StringName) -> void:
	_play(sfx_recipe_unlocked, AudioManager.SFX_PRIORITY_HIGH)


func _on_dough_loaded(_slot_id: int) -> void:
	_play(sfx_dough_loaded, AudioManager.SFX_PRIORITY_LOW)


# ── Internal ──────────────────────────────────────────────────────────────────

func _play(stream: AudioStream, priority: int) -> void:
	if stream == null:
		push_warning("GameAudioBridge: AudioStream atanmamış — ses atlandı")
		return
	var audio := _get_audio()
	if audio == null:
		return
	audio.play_sfx(stream, priority)


func _get_audio() -> AudioManager:
	if _audio_ref:
		return _audio_ref
	return get_node_or_null("/root/AudioManager") as AudioManager


func _get_oven() -> OvenManager:
	if _oven_ref:
		return _oven_ref
	return get_node_or_null("/root/OvenManager") as OvenManager


func _get_customer() -> CustomerOrderSystem:
	if _customer_ref:
		return _customer_ref
	return get_node_or_null("/root/CustomerOrderSystem") as CustomerOrderSystem


func _get_recipe() -> RecipeManager:
	if _recipe_ref:
		return _recipe_ref
	return get_node_or_null("/root/RecipeManager") as RecipeManager


func _get_anim() -> AnimationManager:
	if _anim_ref:
		return _anim_ref
	return get_node_or_null("/root/AnimationManager") as AnimationManager
