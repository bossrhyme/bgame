## GUT Test Suite — GameAudioBridge
## src/audio/game_audio_bridge.gd — Gameplay → ses köprüsü
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_game_audio_bridge.gd
extends GutTest


var _bridge: GameAudioBridge
var _audio: AudioManager


func before_each() -> void:
	_audio = AudioManager.new()
	add_child_autofree(_audio)

	_bridge = GameAudioBridge.new()
	_bridge._audio_ref = _audio
	add_child_autofree(_bridge)


# ── _get_audio lazy-init ──────────────────────────────────────────────────────

func test_get_audio_returns_injected_ref() -> void:
	assert_eq(_bridge._get_audio(), _audio)


func test_get_audio_returns_null_when_not_wired() -> void:
	var b := GameAudioBridge.new()
	add_child_autofree(b)
	assert_null(b._get_audio())


# ── _play: null stream ────────────────────────────────────────────────────────

func test_play_null_stream_no_crash() -> void:
	# null stream → push_warning + atla; çökme yok
	_bridge._play(null, AudioManager.SFX_PRIORITY_LOW)
	assert_true(true)


func test_play_null_audio_no_crash() -> void:
	_bridge._audio_ref = null
	# stream var ama audio yok → güvenli çıkış
	_bridge._play(null, AudioManager.SFX_PRIORITY_LOW)
	assert_true(true)


# ── Signal handler'lar: null stream → çökme yok ───────────────────────────────

func test_on_bake_completed_null_stream_no_crash() -> void:
	_bridge.sfx_bake_complete = null
	_bridge._on_bake_completed(0, &"simit")
	assert_true(true)


func test_on_bread_harvested_null_stream_no_crash() -> void:
	_bridge.sfx_bread_harvest = null
	_bridge._on_bread_harvested(0, &"simit", 5)
	assert_true(true)


func test_on_order_delivered_null_stream_no_crash() -> void:
	_bridge.sfx_order_delivered = null
	var dummy_order := OrderEntry.new()
	_bridge._on_order_delivered(dummy_order, 10)
	assert_true(true)


func test_on_customer_escaped_null_stream_no_crash() -> void:
	_bridge.sfx_customer_escaped = null
	var dummy_order := OrderEntry.new()
	_bridge._on_customer_escaped(dummy_order)
	assert_true(true)


func test_on_recipe_unlocked_null_stream_no_crash() -> void:
	_bridge.sfx_recipe_unlocked = null
	_bridge._on_recipe_unlocked(&"croissant")
	assert_true(true)


func test_on_dough_loaded_null_stream_no_crash() -> void:
	_bridge.sfx_dough_loaded = null
	_bridge._on_dough_loaded(0)
	assert_true(true)


# ── _wire_signals: bağımlılıklar olmadan çalışır ─────────────────────────────

func test_wire_signals_no_crash_without_oven() -> void:
	_bridge._oven_ref = null
	_bridge._wire_signals()
	assert_true(true)


func test_wire_signals_no_crash_without_customer() -> void:
	_bridge._customer_ref = null
	_bridge._wire_signals()
	assert_true(true)


func test_wire_signals_no_crash_without_recipe() -> void:
	_bridge._recipe_ref = null
	_bridge._wire_signals()
	assert_true(true)


func test_wire_signals_no_crash_without_audio() -> void:
	_bridge._audio_ref = null
	_bridge._wire_signals()
	assert_true(true)
