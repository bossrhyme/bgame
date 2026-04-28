## GUT Test Suite — TutorialOverlay
## src/ui/hud/tutorial_overlay.gd — Tooltip görsel katmanı
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_tutorial_overlay.gd
##
## Not: TutorialOverlay CanvasLayer'dır — görsel doğrulama headless'ta sınırlıdır.
## Bu testler sinyal bağlantıları, metin kırpma ve durum yönetimini kapsar.
extends GutTest


var _overlay: TutorialOverlay
var _tutorial: TutorialSystem
var _economy: EconomySystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(0, 0)

	_tutorial = TutorialSystem.new()
	_tutorial._economy_ref = _economy
	_tutorial._oven_ref = null
	_tutorial._upgrade_ref = null
	_tutorial._recipe_ref = null
	_tutorial._customer_ref = null
	_tutorial._gesture_ref = null
	add_child_autofree(_tutorial)

	_overlay = TutorialOverlay.new()
	_overlay._tut_ref = _tutorial
	add_child_autofree(_overlay)


# ── _build_ui sonuçları ───────────────────────────────────────────────────────

func test_label_created() -> void:
	assert_not_null(_overlay._label)


func test_arrow_created() -> void:
	assert_not_null(_overlay._arrow)


func test_skip_button_created() -> void:
	assert_not_null(_overlay._skip_button)


func test_container_created() -> void:
	assert_not_null(_overlay._container)


func test_skip_button_hidden_initially() -> void:
	assert_false(_overlay._skip_button.visible)


func test_container_hidden_initially() -> void:
	assert_false(_overlay._container.visible)


func test_layer_is_10() -> void:
	assert_eq(_overlay.layer, 10)


func test_mouse_filter_ignore_on_container() -> void:
	assert_eq(_overlay._container.mouse_filter, Control.MOUSE_FILTER_IGNORE)


# ── Metin kırpma ──────────────────────────────────────────────────────────────

func test_short_message_shown_as_is() -> void:
	var msg: String = "Kısa mesaj"
	_overlay._on_show_tooltip(&"tut_knead", "", msg)
	assert_eq(_overlay._label.text, msg)


func test_long_message_truncated_to_max_chars() -> void:
	var msg: String = "A".repeat(TutorialOverlay.MAX_CHARS + 20)
	_overlay._on_show_tooltip(&"tut_knead", "", msg)
	assert_lte(_overlay._label.text.length(), TutorialOverlay.MAX_CHARS)


func test_long_message_ends_with_ellipsis() -> void:
	var msg: String = "B".repeat(TutorialOverlay.MAX_CHARS + 10)
	_overlay._on_show_tooltip(&"tut_knead", "", msg)
	assert_true(_overlay._label.text.ends_with("..."))


func test_message_at_exactly_max_chars_not_truncated() -> void:
	var msg: String = "C".repeat(TutorialOverlay.MAX_CHARS)
	_overlay._on_show_tooltip(&"tut_knead", "", msg)
	assert_eq(_overlay._label.text, msg)
	assert_false(_overlay._label.text.ends_with("..."))


# ── show / hide ───────────────────────────────────────────────────────────────

func test_show_tooltip_makes_container_visible() -> void:
	_overlay._on_show_tooltip(&"tut_knead", "", "Test mesajı")
	assert_true(_overlay._container.visible)


func test_show_tooltip_sets_visible_flag() -> void:
	_overlay._on_show_tooltip(&"tut_bake", "", "Fırına koy")
	assert_true(_overlay._visible_flag)


func test_hide_tooltip_clears_visible_flag() -> void:
	_overlay._on_show_tooltip(&"tut_bake", "", "Fırına koy")
	_overlay._on_hide_tooltip()
	assert_false(_overlay._visible_flag)


func test_hide_tooltip_no_op_when_not_visible() -> void:
	# İkinci hide crash'e yol açmamalı
	_overlay._on_hide_tooltip()
	_overlay._on_hide_tooltip()
	assert_true(true)


func test_tutorial_finished_clears_visible_flag() -> void:
	_overlay._on_show_tooltip(&"tut_upgrade", "", "Yükselt")
	_overlay._on_tutorial_finished()
	assert_false(_overlay._visible_flag)


func test_tutorial_finished_hides_skip_button() -> void:
	_overlay._skip_button.visible = true
	_overlay._on_tutorial_finished()
	assert_false(_overlay._skip_button.visible)


# ── show_skip_button ──────────────────────────────────────────────────────────

func test_show_skip_button_makes_it_visible() -> void:
	_overlay.show_skip_button()
	assert_true(_overlay._skip_button.visible)


# ── skip_requested sinyal ─────────────────────────────────────────────────────

func test_skip_pressed_emits_skip_requested() -> void:
	watch_signals(_overlay)
	_overlay._on_skip_pressed()
	assert_signal_emitted(_overlay, "skip_requested")


func test_skip_pressed_calls_tutorial_skip() -> void:
	# Tutorial aktif; skip çağrısı sonrası tutorial tamamlanmış olmalı
	assert_true(_tutorial.tut_active)
	_overlay._on_skip_pressed()
	assert_false(_tutorial.tut_active)


# ── _wire_tutorial ────────────────────────────────────────────────────────────

func test_wire_tutorial_connects_show_tooltip() -> void:
	# show_tooltip sinyali bağlı mı?
	_overlay._wire_tutorial()
	assert_true(_tutorial.show_tooltip.is_connected(_overlay._on_show_tooltip))


func test_wire_tutorial_connects_hide_tooltip() -> void:
	_overlay._wire_tutorial()
	assert_true(_tutorial.hide_tooltip.is_connected(_overlay._on_hide_tooltip))


func test_wire_tutorial_connects_tutorial_finished() -> void:
	_overlay._wire_tutorial()
	assert_true(_tutorial.tutorial_finished.is_connected(_overlay._on_tutorial_finished))
