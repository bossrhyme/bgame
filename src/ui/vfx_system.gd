## VFXSystem — VFX/Partikül Koordinasyon Servisi
##
## Oyun olaylarını görsel efekt isteklerine dönüştürür.
## AnimationManager.coin_spawn_requested → coin_vfx_requested
## RecipeManager.recipe_unlocked → unlock_vfx_requested (battery_saver'da engellenir)
## battery_saver değişince vfx_disabled / vfx_enabled sinyalleri yayılır.
##
## GDD: design/gdd/vfx-particle-system.md
class_name VFXSystem
extends Node

## Coin VFX spawn isteği. Sahne node'ları bu sinyale bağlanarak GPUParticles2D tetikler.
signal coin_vfx_requested(count: int, delta: int)
## Tarif açılımı VFX isteği. Sahne node'ları patlama efekti için bağlanır.
signal unlock_vfx_requested(recipe_id: StringName)
## battery_saver aktif olduğunda; sahne node'ları process_mode=DISABLED ayarlar.
signal vfx_disabled
## battery_saver devre dışı olduğunda; sahne node'ları process_mode=INHERIT ayarlar.
signal vfx_enabled

var _battery_saver: bool = false

## Dependency injection (test izolasyonu).
var _animation_ref: AnimationManager = null
var _recipe_ref: RecipeManager = null
var _settings_ref: SettingsManager = null


func _ready() -> void:
	_wire_signals()


# ── Public API ────────────────────────────────────────────────────────────────

## Mevcut battery_saver durumunu döner.
var battery_saver: bool:
	get: return _battery_saver


# ── Signal Wiring ─────────────────────────────────────────────────────────────

func _wire_signals() -> void:
	var anim := _get_animation()
	if anim:
		anim.coin_spawn_requested.connect(_on_coin_spawn_requested)
	else:
		push_warning("VFXSystem: AnimationManager bağlanamadı")

	var recipe := _get_recipe()
	if recipe:
		recipe.recipe_unlocked.connect(_on_recipe_unlocked)
	else:
		push_warning("VFXSystem: RecipeManager bağlanamadı")

	var settings := _get_settings()
	if settings:
		_battery_saver = settings.battery_saver
		settings.battery_saver_changed.connect(_on_battery_saver_changed)


func _on_coin_spawn_requested(count: int, delta: int) -> void:
	# AnimationManager battery_saver kontrolünü zaten yapar; bu noktaya
	# ulaşmışsa emit güvenlidir.
	coin_vfx_requested.emit(count, delta)


func _on_recipe_unlocked(recipe_id: StringName) -> void:
	if _battery_saver:
		return
	unlock_vfx_requested.emit(recipe_id)


func _on_battery_saver_changed(enabled: bool) -> void:
	_battery_saver = enabled
	if enabled:
		vfx_disabled.emit()
	else:
		vfx_enabled.emit()


# ── Dependency Getters ────────────────────────────────────────────────────────

func _get_animation() -> AnimationManager:
	if _animation_ref:
		return _animation_ref
	return get_node_or_null("/root/AnimationManager") as AnimationManager


func _get_recipe() -> RecipeManager:
	if _recipe_ref:
		return _recipe_ref
	return get_node_or_null("/root/RecipeManager") as RecipeManager


func _get_settings() -> SettingsManager:
	if _settings_ref:
		return _settings_ref
	return get_node_or_null("/root/Settings") as SettingsManager
