## PerformanceMonitor — Geliştirici Metrik İzleyici
##
## FPS, draw call ve bellek metriklerini periyodik örnekler; eşik aşılınca sinyal yayar.
## Yalnızca DEBUG build'de aktiftir; production'da _MONITORING_ENABLED = false.
##
## ADR-0003 uyumu: _process() kullanılmaz; SceneTreeTimer bazlı örnekleme.
## GDD: design/gdd/performance-monitoring.md
class_name PerformanceMonitor
extends Node

signal fps_dropped(fps: float)
signal draw_calls_exceeded(count: int)
signal memory_warning(mb: float)
signal bake_latency_warning(ms: float)

const SAMPLE_INTERVAL_SEC: float = 5.0
const WINDOW_SIZE: int = 3
const FPS_WARN_THRESHOLD: float = 30.0
const DRAW_CALL_LIMIT: int = 100
const MEMORY_WARN_MB: float = 512.0
const BAKE_LATENCY_WARN_MS: float = 33.0

## Production build'de tüm sampling devre dışı.
var _monitoring_enabled: bool = OS.is_debug_build()

var _fps_samples: Array[float] = []
var _draw_samples: Array[int] = []
var _memory_samples: Array[float] = []

var _bake_start_ms: int = -1

var _oven_ref: OvenManager = null


func _ready() -> void:
	if not _monitoring_enabled:
		return
	_wire_oven()
	_schedule_sample()


# ── Public API ────────────────────────────────────────────────────────────────

## Anlık metrik snapshot (debug HUD için).
func get_report() -> Dictionary:
	return {
		"fps":        _moving_avg(_fps_samples),
		"draw_calls": _moving_avg_int(_draw_samples),
		"memory_mb":  _moving_avg(_memory_samples),
		"enabled":    _monitoring_enabled,
	}


## Test ortamında örneklemeyi manuel tetikle.
func sample_now() -> void:
	_do_sample()


# ── Internal ──────────────────────────────────────────────────────────────────

func _wire_oven() -> void:
	var oven := _get_oven()
	if not oven:
		return
	if oven.has_signal("bake_started"):
		oven.bake_started.connect(_on_bake_started)
	if oven.has_signal("bake_completed"):
		oven.bake_completed.connect(_on_bake_completed)


func _on_bake_started(_slot_id: int, _recipe_id: StringName) -> void:
	_bake_start_ms = Time.get_ticks_msec()


func _on_bake_completed(_slot_id: int, _recipe_id: StringName) -> void:
	if _bake_start_ms < 0:
		return
	var elapsed_ms: float = float(Time.get_ticks_msec() - _bake_start_ms)
	_bake_start_ms = -1
	if elapsed_ms > BAKE_LATENCY_WARN_MS:
		bake_latency_warning.emit(elapsed_ms)


func _schedule_sample() -> void:
	var tree := get_tree()
	if not tree:
		push_warning("PerformanceMonitor: SceneTree yok — sampling başlatılamadı")
		return
	tree.create_timer(SAMPLE_INTERVAL_SEC).timeout.connect(_on_sample_timeout, CONNECT_ONE_SHOT)


func _on_sample_timeout() -> void:
	_do_sample()
	_schedule_sample()


func _do_sample() -> void:
	var fps: float  = Performance.get_monitor(Performance.TIME_FPS)
	var draws: int  = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var mem_bytes: float = Performance.get_monitor(Performance.STATIC_MEMORY_USAGE_BY_TYPE)
	var mem_mb: float = mem_bytes / (1024.0 * 1024.0)

	_push_sample(_fps_samples, fps)
	_push_sample_int(_draw_samples, draws)
	_push_sample(_memory_samples, mem_mb)

	var avg_fps: float  = _moving_avg(_fps_samples)
	var avg_draws: int  = _moving_avg_int(_draw_samples)
	var avg_mem: float  = _moving_avg(_memory_samples)

	if avg_fps > 0.0 and avg_fps < FPS_WARN_THRESHOLD:
		fps_dropped.emit(avg_fps)

	if avg_draws > DRAW_CALL_LIMIT:
		draw_calls_exceeded.emit(avg_draws)

	if avg_mem > 0.0 and avg_mem > MEMORY_WARN_MB:
		memory_warning.emit(avg_mem)


func _push_sample(arr: Array[float], value: float) -> void:
	arr.append(value)
	while arr.size() > WINDOW_SIZE:
		arr.pop_front()


func _push_sample_int(arr: Array[int], value: int) -> void:
	arr.append(value)
	while arr.size() > WINDOW_SIZE:
		arr.pop_front()


func _moving_avg(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in arr:
		total += v
	return total / float(arr.size())


func _moving_avg_int(arr: Array[int]) -> int:
	if arr.is_empty():
		return 0
	var total: int = 0
	for v: int in arr:
		total += v
	return total / arr.size()


func _get_oven() -> OvenManager:
	if _oven_ref:
		return _oven_ref
	return get_node_or_null("/root/OvenManager") as OvenManager
