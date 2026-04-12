## GUT Test Suite — Gesture Detectors
## GDD Touch/Gesture Input Acceptance Criteria: AC-01 – AC-16
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_gesture_detectors.gd
extends GutTest

var detector_circ: CircularGestureDetector
var detector_tap: TapDetector
var detector_dtd: DragToDropDetector
var detector_lp: LongPressDetector
var _cfg: GestureConfig


func before_each() -> void:
	_cfg = GestureConfig.new()
	_cfg.circles_required = 3
	_cfg.min_radius = 40.0
	_cfg.max_radius = 200.0
	_cfg.tap_max_ms = 300.0
	_cfg.long_press_duration_ms = 250.0
	_cfg.haptic_tick_ms = 20
	_cfg.haptic_complete_ms = 80
	_cfg.drag_drop_snap_radius = 60.0

	detector_circ = CircularGestureDetector.new()
	detector_circ.config = _cfg
	add_child(detector_circ)

	detector_tap = TapDetector.new()
	detector_tap.config = _cfg
	add_child(detector_tap)

	detector_dtd = DragToDropDetector.new()
	detector_dtd.config = _cfg
	add_child(detector_dtd)

	detector_lp = LongPressDetector.new()
	detector_lp.config = _cfg
	add_child(detector_lp)


func after_each() -> void:
	detector_circ.queue_free()
	detector_tap.queue_free()
	detector_dtd.queue_free()
	detector_lp.queue_free()


# ── Yardımcılar ───────────────────────────────────────────────────────────────

func _touch_down(pos: Vector2, index: int = 0) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = true
	e.position = pos
	e.index = index
	return e


func _touch_up(pos: Vector2, index: int = 0) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = false
	e.position = pos
	e.index = index
	return e


func _drag(pos: Vector2, index: int = 0) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.position = pos
	e.index = index
	return e


## center etrafında radius'ta circles tam tur simüle eder (steps: tur başına adım sayısı).
func _do_circle(det: CircularGestureDetector, center: Vector2, radius: float,
		circles: float, steps: int = 60) -> void:
	var total_steps: int = int(circles * steps)
	for i: int in range(total_steps + 1):
		var angle: float = float(i) / float(steps) * TAU
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		det._unhandled_input(_drag(pos))


# ── AC-01: 3 tam tur → circular_completed tam 1 kez ─────────────────────────

func test_circular_completed_emitted_once_after_3_circles() -> void:
	var center := Vector2(200.0, 400.0)
	var radius := 100.0
	var count := 0
	detector_circ.circular_completed.connect(func(): count += 1)

	detector_circ._unhandled_input(_touch_down(center))
	detector_circ._unhandled_input(_drag(center + Vector2(radius, 0.0)))
	_do_circle(detector_circ, center, radius, 3.0)

	assert_eq(count, 1, "circular_completed tam 1 kez emit edildi")


# ── AC-02: Fraction 0.33 ve 0.67 değerlerini geçiyor ────────────────────────

func test_circular_progress_fraction_hits_third_marks() -> void:
	var center := Vector2(200.0, 400.0)
	var radius := 100.0
	var fractions: Array = []
	detector_circ.circular_progress.connect(func(f: float): fractions.append(f))

	detector_circ._unhandled_input(_touch_down(center))
	detector_circ._unhandled_input(_drag(center + Vector2(radius, 0.0)))
	_do_circle(detector_circ, center, radius, 3.0)

	var found_third: bool = false
	var found_two_thirds: bool = false
	for f: float in fractions:
		if absf(f - 0.333) < 0.05:
			found_third = true
		if absf(f - 0.667) < 0.05:
			found_two_thirds = true

	assert_true(found_third, "fraction ≈ 0.33 değerini geçti")
	assert_true(found_two_thirds, "fraction ≈ 0.67 değerini geçti")


# ── AC-03: Düz sürükleme → circular_completed yok ────────────────────────────

func test_straight_drag_does_not_trigger_circular_completed() -> void:
	var center := Vector2(200.0, 400.0)
	var completed := false
	detector_circ.circular_completed.connect(func(): completed = true)

	detector_circ._unhandled_input(_touch_down(center))
	for i: int in range(10):
		detector_circ._unhandled_input(_drag(center + Vector2(50.0 + i * 5.0, 0.0)))

	assert_false(completed, "Düz sürükleme → circular_completed yok")


# ── AC-04: Tamamlama sonrası parmak yerde → yeni gesture başlamaz ────────────

func test_no_new_gesture_while_finger_down_after_completion() -> void:
	var center := Vector2(200.0, 400.0)
	var radius := 100.0
	var count := 0
	detector_circ.circular_completed.connect(func(): count += 1)

	detector_circ._unhandled_input(_touch_down(center))
	detector_circ._unhandled_input(_drag(center + Vector2(radius, 0.0)))
	_do_circle(detector_circ, center, radius, 3.0)
	assert_eq(count, 1, "İlk gesture tamamlandı")

	# Parmak hâlâ ekranda — 3 tur daha simüle et
	_do_circle(detector_circ, center, radius, 3.0)
	assert_eq(count, 1, "Parmak yerdeyken yeni gesture başlamadı")


# ── AC-05: MAX_RADIUS aşılınca circular_cancelled ─────────────────────────────

func test_circular_cancelled_when_max_radius_exceeded() -> void:
	var center := Vector2(200.0, 400.0)
	var cancelled := false
	detector_circ.circular_cancelled.connect(func(): cancelled = true)

	detector_circ._unhandled_input(_touch_down(center))
	detector_circ._unhandled_input(_drag(center + Vector2(60.0, 0.0)))  # TRACKING'e gir
	detector_circ._unhandled_input(_drag(center + Vector2(250.0, 0.0)))  # MAX_RADIUS (200) aşıldı

	assert_true(cancelled, "circular_cancelled emit edildi")


# ── AC-05b: İptal sonrası yeni drag yeni gesture başlatmaz ───────────────────

func test_after_cancel_new_drag_does_not_restart() -> void:
	var center := Vector2(200.0, 400.0)
	var cancel_count := 0
	detector_circ.circular_cancelled.connect(func(): cancel_count += 1)

	detector_circ._unhandled_input(_touch_down(center))
	detector_circ._unhandled_input(_drag(center + Vector2(60.0, 0.0)))
	detector_circ._unhandled_input(_drag(center + Vector2(250.0, 0.0)))  # iptal
	# Parmak hâlâ yerde — daha fazla drag
	detector_circ._unhandled_input(_drag(center + Vector2(80.0, 0.0)))

	assert_eq(cancel_count, 1, "İptal sonrası drag yeni gesture başlatmadı")


# ── AC-06: drag_dropped doğru target_node ile ─────────────────────────────────

func test_drag_dropped_emits_correct_target() -> void:
	var drop_zone := Node2D.new()
	add_child(drop_zone)
	drop_zone.global_position = Vector2(500.0, 300.0)
	detector_dtd.drop_zones = [drop_zone]

	var dropped_target: Node = null
	detector_dtd.drag_dropped.connect(func(t: Node): dropped_target = t)

	detector_dtd._unhandled_input(_touch_down(Vector2(100.0, 300.0)))
	detector_dtd._unhandled_input(_drag(Vector2(200.0, 300.0)))  # MIN_RADIUS geçildi → DRAGGING
	detector_dtd._unhandled_input(_touch_up(Vector2(510.0, 305.0)))  # snap_radius=60 içinde

	assert_eq(dropped_target, drop_zone, "drag_dropped doğru target ile emit edildi")
	drop_zone.queue_free()


# ── AC-07: DropZone dışına bırakınca drag_cancelled ──────────────────────────

func test_drag_cancelled_when_released_outside_drop_zone() -> void:
	var drop_zone := Node2D.new()
	add_child(drop_zone)
	drop_zone.global_position = Vector2(500.0, 300.0)
	detector_dtd.drop_zones = [drop_zone]

	var cancelled := false
	detector_dtd.drag_cancelled.connect(func(): cancelled = true)

	detector_dtd._unhandled_input(_touch_down(Vector2(100.0, 300.0)))
	detector_dtd._unhandled_input(_drag(Vector2(200.0, 300.0)))
	detector_dtd._unhandled_input(_touch_up(Vector2(100.0, 100.0)))  # DropZone uzağında

	assert_true(cancelled, "drag_cancelled emit edildi")
	drop_zone.queue_free()


# ── AC-08: Kısa tap → tapped emit edilir ─────────────────────────────────────

func test_short_tap_emits_tapped_signal() -> void:
	var target := Node.new()
	detector_tap.target_node = target
	add_child(target)

	var tapped_node: Node = null
	detector_tap.tapped.connect(func(n: Node): tapped_node = n)

	detector_tap._unhandled_input(_touch_down(Vector2(100.0, 100.0)))
	detector_tap._unhandled_input(_touch_up(Vector2(100.0, 100.0)))

	assert_eq(tapped_node, target, "tapped(node) doğru hedefle emit edildi")
	target.queue_free()


# ── AC-09: tap_max_ms geçince tap sinyali yok ────────────────────────────────

func test_tap_not_emitted_after_timeout() -> void:
	var tapped_called := false
	detector_tap.tapped.connect(func(_n): tapped_called = true)

	detector_tap._unhandled_input(_touch_down(Vector2(100.0, 100.0)))
	# Zaman aşımı simülasyonu: başlangıç zamanını 400ms geri al
	detector_tap._touch_start_time_ms -= 400
	detector_tap._unhandled_input(_touch_up(Vector2(100.0, 100.0)))

	assert_false(tapped_called, "Zaman aşımı → tap sinyali yok")


# ── AC-10: MIN_RADIUS dışına hareket → tap yok ───────────────────────────────

func test_tap_not_emitted_when_finger_moves_beyond_min_radius() -> void:
	var tapped_called := false
	detector_tap.tapped.connect(func(_n): tapped_called = true)

	detector_tap._unhandled_input(_touch_down(Vector2(100.0, 100.0)))
	detector_tap._unhandled_input(_drag(Vector2(145.0, 100.0)))  # 45px > MIN_RADIUS(40)
	detector_tap._unhandled_input(_touch_up(Vector2(145.0, 100.0)))

	assert_false(tapped_called, "Hareket > MIN_RADIUS → tap sinyali yok")


# ── AC-11: Long press + drag → sinyaller ─────────────────────────────────────

func test_long_press_drag_emits_started_and_ended() -> void:
	var started := false
	var ended_pos := Vector2.ZERO
	detector_lp.long_drag_started.connect(func(): started = true)
	detector_lp.long_drag_ended.connect(func(p: Vector2): ended_pos = p)

	detector_lp._unhandled_input(_touch_down(Vector2(200.0, 400.0)))
	# Zamanlama simülasyonu: 300ms geçmiş gibi
	detector_lp._touch_start_time_ms -= 300
	# Hareket < MIN_RADIUS iken drag (parmak yerinde sayılır)
	detector_lp._unhandled_input(_drag(Vector2(205.0, 400.0)))
	assert_true(started, "long_drag_started emit edildi")

	detector_lp._unhandled_input(_touch_up(Vector2(300.0, 450.0)))
	assert_eq(ended_pos, Vector2(300.0, 450.0), "long_drag_ended doğru pozisyon")


# ── AC-12: 250ms önce sürükleme → long_drag_started yok ─────────────────────

func test_early_drag_cancels_long_press_intent() -> void:
	var started := false
	detector_lp.long_drag_started.connect(func(): started = true)

	detector_lp._unhandled_input(_touch_down(Vector2(200.0, 400.0)))
	# Zaman geçmeden MIN_RADIUS dışına sürükle
	detector_lp._unhandled_input(_drag(Vector2(250.0, 400.0)))  # 50px > MIN_RADIUS

	assert_false(started, "Erken sürükleme → long_drag_started yok")


# ── knead_tick: her tam turda 1 sinyal ───────────────────────────────────────

func test_knead_tick_emitted_for_each_full_circle() -> void:
	var center := Vector2(200.0, 400.0)
	var radius := 100.0
	var ticks: Array[int] = []
	detector_circ.knead_tick.connect(func(c: int): ticks.append(c))

	detector_circ._unhandled_input(_touch_down(center))
	detector_circ._unhandled_input(_drag(center + Vector2(radius, 0.0)))
	_do_circle(detector_circ, center, radius, 3.0)

	# 3 turda 2 tick (tur 1 ve 2'de); tur 3 circular_completed ile tamamlanır
	assert_eq(ticks.size(), 2, "3 turda 2 knead_tick emit edildi")
	assert_eq(ticks[0], 1, "İlk tick: circle_count=1")
	assert_eq(ticks[1], 2, "İkinci tick: circle_count=2")


# ── İkinci parmak yoksayılır (Core Rule 5) ───────────────────────────────────

func test_second_finger_ignored_during_active_gesture() -> void:
	var center := Vector2(200.0, 400.0)
	var count := 0
	detector_circ.circular_completed.connect(func(): count += 1)

	detector_circ._unhandled_input(_touch_down(center, 0))
	detector_circ._unhandled_input(_drag(center + Vector2(100.0, 0.0), 0))
	# İkinci parmak — farklı index
	detector_circ._unhandled_input(_touch_down(Vector2(600.0, 400.0), 1))
	detector_circ._unhandled_input(_drag(Vector2(650.0, 400.0), 1))

	_do_circle(detector_circ, center, 100.0, 3.0)
	assert_eq(count, 1, "circular_completed tam 1 kez — ikinci parmak etkilemedi")


# ── Parmak kalkınca yeni gesture başlayabilir (Core Rule 4) ─────────────────

func test_finger_lift_resets_touch_id_allows_new_gesture() -> void:
	var center := Vector2(200.0, 400.0)
	var radius := 100.0
	var count := 0
	detector_circ.circular_completed.connect(func(): count += 1)

	# İlk gesture
	detector_circ._unhandled_input(_touch_down(center, 0))
	detector_circ._unhandled_input(_drag(center + Vector2(radius, 0.0), 0))
	_do_circle(detector_circ, center, radius, 3.0)
	assert_eq(count, 1, "İlk gesture tamamlandı")

	# Parmağı kaldır
	detector_circ._unhandled_input(_touch_up(center, 0))

	# İkinci gesture
	detector_circ._unhandled_input(_touch_down(center, 0))
	detector_circ._unhandled_input(_drag(center + Vector2(radius, 0.0), 0))
	_do_circle(detector_circ, center, radius, 3.0)
	assert_eq(count, 2, "Parmak kalktıktan sonra yeni gesture başlayabildi")


# ── AC-15: haptic_enabled=false → vibrate çağrısı crash yok ─────────────────

func test_haptic_disabled_no_crash_on_circular_completed() -> void:
	var settings := SettingsManager.new()
	settings._set_save_path("user://settings_gesture_test.cfg")
	add_child(settings)
	settings.set_haptic_enabled(false)
	detector_circ._settings_ref = settings

	var center := Vector2(200.0, 400.0)
	var radius := 100.0
	var completed := false
	detector_circ.circular_completed.connect(func(): completed = true)

	detector_circ._unhandled_input(_touch_down(center))
	detector_circ._unhandled_input(_drag(center + Vector2(radius, 0.0)))
	_do_circle(detector_circ, center, radius, 3.0)

	assert_true(completed, "haptic disabled → circular_completed yine de emit edildi")

	settings.queue_free()
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("settings_gesture_test.cfg"):
		dir.remove("settings_gesture_test.cfg")


# ── DragToDropDetector: DropZone listesi boşsa drag_cancelled ────────────────

func test_drag_cancelled_when_no_drop_zones_defined() -> void:
	detector_dtd.drop_zones = []
	var cancelled := false
	detector_dtd.drag_cancelled.connect(func(): cancelled = true)

	detector_dtd._unhandled_input(_touch_down(Vector2(100.0, 300.0)))
	detector_dtd._unhandled_input(_drag(Vector2(200.0, 300.0)))
	detector_dtd._unhandled_input(_touch_up(Vector2(500.0, 300.0)))

	assert_true(cancelled, "DropZone listesi boş → drag_cancelled")
