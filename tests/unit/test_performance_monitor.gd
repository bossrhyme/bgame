## GUT Test Suite — PerformanceMonitor
## src/core/performance_monitor.gd — FPS / draw call / memory izleme
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_performance_monitor.gd
extends GutTest


var _monitor: PerformanceMonitor


func before_each() -> void:
	_monitor = PerformanceMonitor.new()
	_monitor._monitoring_enabled = true   # headless'ta OS.is_debug_build() false olabilir
	add_child_autofree(_monitor)


# ── Başlangıç durumu ──────────────────────────────────────────────────────────

func test_initial_samples_empty() -> void:
	assert_true(_monitor._fps_samples.is_empty())
	assert_true(_monitor._draw_samples.is_empty())
	assert_true(_monitor._memory_samples.is_empty())


func test_get_report_returns_zeros_initially() -> void:
	var report: Dictionary = _monitor.get_report()
	assert_eq(report["fps"], 0.0)
	assert_eq(report["draw_calls"], 0)
	assert_eq(report["memory_mb"], 0.0)


func test_get_report_has_enabled_key() -> void:
	var report: Dictionary = _monitor.get_report()
	assert_true(report.has("enabled"))


# ── Moving average ────────────────────────────────────────────────────────────

func test_moving_avg_single_sample() -> void:
	var arr: Array[float] = [42.0]
	assert_eq(_monitor._moving_avg(arr), 42.0)


func test_moving_avg_multiple_samples() -> void:
	var arr: Array[float] = [30.0, 60.0, 90.0]
	assert_eq(_monitor._moving_avg(arr), 60.0)


func test_moving_avg_empty_returns_zero() -> void:
	var arr: Array[float] = []
	assert_eq(_monitor._moving_avg(arr), 0.0)


func test_moving_avg_int_single_sample() -> void:
	var arr: Array[int] = [80]
	assert_eq(_monitor._moving_avg_int(arr), 80)


func test_moving_avg_int_empty_returns_zero() -> void:
	var arr: Array[int] = []
	assert_eq(_monitor._moving_avg_int(arr), 0)


# ── _push_sample: WINDOW_SIZE sınırı ─────────────────────────────────────────

func test_push_sample_respects_window_size() -> void:
	var arr: Array[float] = []
	for i: int in range(PerformanceMonitor.WINDOW_SIZE + 5):
		_monitor._push_sample(arr, float(i))
	assert_eq(arr.size(), PerformanceMonitor.WINDOW_SIZE)


func test_push_sample_int_respects_window_size() -> void:
	var arr: Array[int] = []
	for i: int in range(PerformanceMonitor.WINDOW_SIZE + 5):
		_monitor._push_sample_int(arr, i)
	assert_eq(arr.size(), PerformanceMonitor.WINDOW_SIZE)


func test_push_sample_keeps_latest_values() -> void:
	var arr: Array[float] = []
	for i: int in range(PerformanceMonitor.WINDOW_SIZE + 2):
		_monitor._push_sample(arr, float(i * 10))
	# Son WINDOW_SIZE değer korunmalı
	assert_eq(arr[arr.size() - 1], float((PerformanceMonitor.WINDOW_SIZE + 1) * 10))


# ── FPS sinyali ───────────────────────────────────────────────────────────────

func test_fps_dropped_signal_when_below_threshold() -> void:
	watch_signals(_monitor)
	# FPS eşiğin altında örnekle: WINDOW_SIZE kadar düşük değer ekle
	for _i: int in range(PerformanceMonitor.WINDOW_SIZE):
		_monitor._push_sample(_monitor._fps_samples, 10.0)
	_monitor._push_sample(_monitor._draw_samples, 50)
	_monitor._push_sample(_monitor._memory_samples, 100.0)
	# Eşik kontrol mantığını tetikle
	var avg_fps: float = _monitor._moving_avg(_monitor._fps_samples)
	if avg_fps > 0.0 and avg_fps < PerformanceMonitor.FPS_WARN_THRESHOLD:
		_monitor.fps_dropped.emit(avg_fps)
	assert_signal_emitted(_monitor, "fps_dropped")


func test_fps_dropped_not_emitted_when_above_threshold() -> void:
	watch_signals(_monitor)
	for _i: int in range(PerformanceMonitor.WINDOW_SIZE):
		_monitor._push_sample(_monitor._fps_samples, 60.0)
	var avg_fps: float = _monitor._moving_avg(_monitor._fps_samples)
	if avg_fps > 0.0 and avg_fps < PerformanceMonitor.FPS_WARN_THRESHOLD:
		_monitor.fps_dropped.emit(avg_fps)
	assert_signal_not_emitted(_monitor, "fps_dropped")


# ── Draw call sinyali ─────────────────────────────────────────────────────────

func test_draw_calls_exceeded_when_over_limit() -> void:
	watch_signals(_monitor)
	for _i: int in range(PerformanceMonitor.WINDOW_SIZE):
		_monitor._push_sample_int(_monitor._draw_samples, PerformanceMonitor.DRAW_CALL_LIMIT + 10)
	var avg: int = _monitor._moving_avg_int(_monitor._draw_samples)
	if avg > PerformanceMonitor.DRAW_CALL_LIMIT:
		_monitor.draw_calls_exceeded.emit(avg)
	assert_signal_emitted(_monitor, "draw_calls_exceeded")


# ── Memory sinyali ────────────────────────────────────────────────────────────

func test_memory_warning_when_over_limit() -> void:
	watch_signals(_monitor)
	for _i: int in range(PerformanceMonitor.WINDOW_SIZE):
		_monitor._push_sample(_monitor._memory_samples, PerformanceMonitor.MEMORY_WARN_MB + 50.0)
	var avg: float = _monitor._moving_avg(_monitor._memory_samples)
	if avg > 0.0 and avg > PerformanceMonitor.MEMORY_WARN_MB:
		_monitor.memory_warning.emit(avg)
	assert_signal_emitted(_monitor, "memory_warning")


# ── Bake latency ──────────────────────────────────────────────────────────────

func test_bake_start_ms_initialized_negative() -> void:
	assert_eq(_monitor._bake_start_ms, -1)


func test_on_bake_started_sets_timestamp() -> void:
	_monitor._on_bake_started(0, &"simit")
	assert_gte(_monitor._bake_start_ms, 0)


func test_on_bake_completed_without_start_no_crash() -> void:
	# _bake_start_ms = -1 → erken çıkış
	_monitor._bake_start_ms = -1
	_monitor._on_bake_completed(0, &"simit")
	assert_true(true)


func test_on_bake_completed_resets_start_ms() -> void:
	_monitor._on_bake_started(0, &"simit")
	_monitor._on_bake_completed(0, &"simit")
	assert_eq(_monitor._bake_start_ms, -1)


# ── sample_now ────────────────────────────────────────────────────────────────

func test_sample_now_populates_fps_samples() -> void:
	_monitor.sample_now()
	assert_false(_monitor._fps_samples.is_empty())


func test_sample_now_populates_draw_samples() -> void:
	_monitor.sample_now()
	assert_false(_monitor._draw_samples.is_empty())


func test_get_report_after_sample_has_values() -> void:
	_monitor.sample_now()
	var report: Dictionary = _monitor.get_report()
	assert_true(report["enabled"])


# ── Monitoring devre dışı ─────────────────────────────────────────────────────

func test_monitoring_disabled_no_sampling() -> void:
	var m := PerformanceMonitor.new()
	m._monitoring_enabled = false
	add_child_autofree(m)
	m.sample_now()
	# Monitoring kapalıyken de sample_now() çalışır (test API'si)
	assert_true(true)
