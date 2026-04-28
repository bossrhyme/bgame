## TutorialOverlay — Tutorial Tooltip Görsel Katmanı
##
## TutorialSystem'in show_tooltip / hide_tooltip sinyallerini dinler;
## hedef UI elementinin üzerinde animasyonlu ok + metin gösterir.
## Hedef UI elementini BLOKE ETMEZ — yalnızca görsel overlay.
##
## GDD: design/gdd/tutorial-onboarding-system.md §3.2
class_name TutorialOverlay
extends CanvasLayer

const FADE_SEC: float = 0.3
const MAX_CHARS: int = 60
const ARROW_BLINK_SEC: float = 0.6

## Skip butonunu göster sinyali — TutorialSystem skip_timer callback'inden tetiklenir.
signal skip_requested

var _tween: Tween = null
var _visible_flag: bool = false

# UI node referansları (scene'den set_root_node ile bağlanır)
var _label: Label = null
var _arrow: Control = null
var _skip_button: Button = null
var _container: Control = null

var _tut_ref: TutorialSystem = null


func _ready() -> void:
	layer = 10  # HUD'un üzerinde, diğer overlay'lerin altında
	_build_ui()
	_wire_tutorial()
	_set_visible_immediate(false)


# ── Public API ────────────────────────────────────────────────────────────────

func show_skip_button() -> void:
	if _skip_button:
		_skip_button.visible = true


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_show_tooltip(step_id: StringName, _target_path: String, message: String) -> void:
	var text: String = message
	if text.length() > MAX_CHARS:
		text = text.substr(0, MAX_CHARS - 3) + "..."
	if _label:
		_label.text = text
	_fade_in()
	_start_arrow_blink()
	# step_id rezerv — ileriki sürümde konumlandırma için kullanılacak
	@warning_ignore("return_value_discarded")
	step_id


func _on_hide_tooltip() -> void:
	_fade_out()


func _on_tutorial_finished() -> void:
	_fade_out()
	if _skip_button:
		_skip_button.visible = false


func _on_skip_pressed() -> void:
	skip_requested.emit()
	var tut := _get_tutorial()
	if tut:
		tut.skip_tutorial()


# ── Internal ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_container = Control.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(240, 0)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.position = Vector2(-120, -120)
	_container.add_child(_label)

	_arrow = Control.new()
	_arrow.custom_minimum_size = Vector2(32, 32)
	_arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_arrow.position = Vector2(-16, -80)
	_container.add_child(_arrow)

	_skip_button = Button.new()
	_skip_button.text = "Atla"
	_skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skip_button.position = Vector2(-100, 20)
	_skip_button.visible = false
	_skip_button.pressed.connect(_on_skip_pressed)
	_container.add_child(_skip_button)


func _wire_tutorial() -> void:
	var tut := _get_tutorial()
	if not tut:
		return
	tut.show_tooltip.connect(_on_show_tooltip)
	tut.hide_tooltip.connect(_on_hide_tooltip)
	tut.tutorial_finished.connect(_on_tutorial_finished)


func _fade_in() -> void:
	if _tween:
		_tween.kill()
	_set_visible_immediate(true)
	_visible_flag = true
	_tween = create_tween()
	_tween.tween_property(_container, "modulate:a", 1.0, FADE_SEC).from(0.0)


func _fade_out() -> void:
	if not _visible_flag:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_container, "modulate:a", 0.0, FADE_SEC).from(1.0)
	_tween.tween_callback(func() -> void: _set_visible_immediate(false))
	_visible_flag = false


func _set_visible_immediate(v: bool) -> void:
	if _container:
		_container.visible = v
		_container.modulate.a = 1.0 if v else 0.0


func _start_arrow_blink() -> void:
	if not _arrow:
		return
	var t := create_tween().set_loops()
	t.tween_property(_arrow, "modulate:a", 0.2, ARROW_BLINK_SEC)
	t.tween_property(_arrow, "modulate:a", 1.0, ARROW_BLINK_SEC)


func _get_tutorial() -> TutorialSystem:
	if _tut_ref:
		return _tut_ref
	return get_node_or_null("/root/TutorialSystem") as TutorialSystem
