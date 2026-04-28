## GUT Test Suite — VFXSystem
## design/gdd/vfx-particle-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_vfx_system.gd
extends GutTest


var _vfx: VFXSystem
var _anim: AnimationManager
var _economy: EconomySystem
var _settings: SettingsManager
var _recipe: RecipeManager


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(0, 0)

	_settings = SettingsManager.new()
	_settings._set_save_path("user://settings_vfx_test.cfg")
	add_child_autofree(_settings)

	_anim = AnimationManager.new()
	_anim._economy_ref = _economy
	_anim._settings_ref = _settings
	add_child_autofree(_anim)

	_recipe = RecipeManager.new()
	_recipe._economy_ref = _economy
	add_child_autofree(_recipe)

	_vfx = VFXSystem.new()
	_vfx._animation_ref = _anim
	_vfx._recipe_ref = _recipe
	_vfx._settings_ref = _settings
	add_child_autofree(_vfx)

	# Manuel sinyal bağlantısı (DI sonrası _ready çağrılmadı)
	_anim.coin_spawn_requested.connect(_vfx._on_coin_spawn_requested)
	_recipe.recipe_unlocked.connect(_vfx._on_recipe_unlocked)
	_settings.battery_saver_changed.connect(_vfx._on_battery_saver_changed)


func after_each() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("settings_vfx_test.cfg"):
		dir.remove("settings_vfx_test.cfg")


# ── Başlangıç durumu ──────────────────────────────────────────────────────────

func test_initial_battery_saver_is_false() -> void:
	assert_false(_vfx.battery_saver)


# ── Coin VFX ─────────────────────────────────────────────────────────────────

func test_coin_spawn_requested_forwards_as_coin_vfx_requested() -> void:
	watch_signals(_vfx)
	_vfx._on_coin_spawn_requested(3, 120)

	assert_signal_emitted(_vfx, "coin_vfx_requested")


func test_coin_vfx_requested_passes_count_and_delta() -> void:
	var received_count: int = -1
	var received_delta: int = -1
	_vfx.coin_vfx_requested.connect(
		func(c: int, d: int) -> void:
			received_count = c
			received_delta = d
	)

	_vfx._on_coin_spawn_requested(5, 350)

	assert_eq(received_count, 5, "count iletildi")
	assert_eq(received_delta, 350, "delta iletildi")


func test_coin_vfx_always_forwarded_regardless_of_battery_saver() -> void:
	# AnimationManager zaten battery_saver'da coin_spawn_requested yayımlamaz;
	# VFXSystem'e ulaşan sinyal her zaman iletilmeli.
	_vfx._battery_saver = true
	watch_signals(_vfx)
	_vfx._on_coin_spawn_requested(1, 10)

	assert_signal_emitted(_vfx, "coin_vfx_requested")


# ── Unlock VFX ───────────────────────────────────────────────────────────────

func test_recipe_unlocked_emits_unlock_vfx_requested() -> void:
	watch_signals(_vfx)
	_vfx._on_recipe_unlocked(&"simit")

	assert_signal_emitted(_vfx, "unlock_vfx_requested")


func test_unlock_vfx_requested_passes_recipe_id() -> void:
	var received_id: StringName = &""
	_vfx.unlock_vfx_requested.connect(
		func(id: StringName) -> void: received_id = id
	)

	_vfx._on_recipe_unlocked(&"pogaca")

	assert_eq(received_id, &"pogaca", "recipe_id iletildi")


func test_unlock_vfx_suppressed_when_battery_saver_true() -> void:
	_vfx._battery_saver = true
	watch_signals(_vfx)
	_vfx._on_recipe_unlocked(&"simit")

	assert_signal_not_emitted(_vfx, "unlock_vfx_requested")


func test_unlock_vfx_emitted_when_battery_saver_false() -> void:
	_vfx._battery_saver = false
	watch_signals(_vfx)
	_vfx._on_recipe_unlocked(&"simit")

	assert_signal_emitted(_vfx, "unlock_vfx_requested")


# ── Battery Saver Toggle ──────────────────────────────────────────────────────

func test_battery_saver_true_emits_vfx_disabled() -> void:
	watch_signals(_vfx)
	_vfx._on_battery_saver_changed(true)

	assert_signal_emitted(_vfx, "vfx_disabled")
	assert_true(_vfx.battery_saver)


func test_battery_saver_false_emits_vfx_enabled() -> void:
	_vfx._battery_saver = true
	watch_signals(_vfx)
	_vfx._on_battery_saver_changed(false)

	assert_signal_emitted(_vfx, "vfx_enabled")
	assert_false(_vfx.battery_saver)


func test_battery_saver_enabled_then_disabled_unlock_works() -> void:
	_vfx._on_battery_saver_changed(true)
	_vfx._on_battery_saver_changed(false)

	watch_signals(_vfx)
	_vfx._on_recipe_unlocked(&"simit")

	assert_signal_emitted(_vfx, "unlock_vfx_requested")


func test_battery_saver_false_no_spurious_vfx_disabled() -> void:
	# battery_saver zaten false iken false set edilirse vfx_disabled yayılmamalı
	_vfx._battery_saver = false
	watch_signals(_vfx)
	_vfx._on_battery_saver_changed(false)

	assert_signal_not_emitted(_vfx, "vfx_disabled")
	assert_signal_emitted(_vfx, "vfx_enabled")


# ── Null dependency koruması ──────────────────────────────────────────────────

func test_null_animation_manager_does_not_crash() -> void:
	var vfx2 := VFXSystem.new()
	vfx2._animation_ref = null
	vfx2._recipe_ref = null
	vfx2._settings_ref = null
	add_child(vfx2)
	# _ready() push_warning yayar ama çökmez
	vfx2.queue_free()
	pass_test()
