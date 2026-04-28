## BakingSlot — Tek fırın yuvası state machine
##
## EMPTY → BAKING (start_baking) → READY (timer.timeout) → EMPTY (do_harvest)
## Offline açılış: apply_offline(elapsed) ile kalan süre hesaplanır veya READY'ye geçilir.
##
## Mimari kuralları (GDD #9):
##   - _process() yasaktır; zamanlama yalnızca Timer.timeout üzerinden (ADR-0003)
##   - Her slot bağımsız; OvenManager tarafından sinyal üzerinden izlenir
class_name BakingSlot
extends Node

## Pişirme tamamlandığında yayılır. OvenManager dinler.
signal bake_completed(slot_id: int, recipe_id: StringName)

enum State { EMPTY, BAKING, READY }

## Yuva indeksi (0–3)
var slot_id: int = 0
## Mevcut durum
var state: State = State.EMPTY
## Pişirilmekte olan tarif ID'si (EMPTY'de &"")
var recipe_id: StringName = &""
## Pişirme başlangıç Unix timestamp'i (offline hesap için)
var bake_start_timestamp: int = 0
## Tariften okunan toplam pişirme süresi (saniye)
var bake_time_seconds: float = 0.0
## Tariften okunan hasat altın miktarı
var gold_reward: int = 0

var _timer: Timer = null


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)


# ── Public API ────────────────────────────────────────────────────────────────

## Pişirmeyi başlatır. Slot EMPTY değilse false döner.
func start_baking(p_recipe_id: StringName, p_bake_time: float, p_gold: int) -> bool:
	if state != State.EMPTY:
		return false
	recipe_id = p_recipe_id
	bake_time_seconds = p_bake_time
	gold_reward = p_gold
	bake_start_timestamp = Time.get_unix_time_from_system()
	state = State.BAKING
	_timer.start(bake_time_seconds)
	return true


## Hasat yapar. Başarıysa gold_reward döner; READY değilse -1.
func do_harvest() -> int:
	if state != State.READY:
		push_error("BakingSlot %d: do_harvest READY olmayan durumda çağrıldı (%s)" \
			% [slot_id, State.keys()[state]])
		return -1
	var reward := gold_reward
	_reset()
	return reward


## Offline geçen süreyi uygular. initialize_from_save sırasında OvenManager çağırır.
## elapsed_seconds: şimdiki unix - bake_start_timestamp
## speed_multiplier: 1.0 + Fırın Ustası efekti (GDD Offline Production F-1/F-2)
func apply_offline(elapsed_seconds: float, offline_cap: float,
		speed_multiplier: float = 1.0) -> void:
	if state != State.BAKING:
		return
	var clamped: float = clampf(elapsed_seconds, 0.0, offline_cap)
	var safe_mult: float = maxf(speed_multiplier, 0.01)
	var effective_bake_time: float = bake_time_seconds / safe_mult
	var remaining: float = effective_bake_time - clamped
	if remaining <= 0.0:
		_timer.stop()
		state = State.READY
		bake_completed.emit(slot_id, recipe_id)
	else:
		_timer.start(remaining)


## İlerleme fraksiyonu [0.0, 1.0] — UI progress bar için (F-1).
var bake_progress: float:
	get:
		if state != State.BAKING or bake_time_seconds <= 0.0:
			return 0.0
		return clampf(1.0 - (_timer.time_left / bake_time_seconds), 0.0, 1.0)


# ── Internal ──────────────────────────────────────────────────────────────────

func _on_timer_timeout() -> void:
	if state == State.BAKING:
		state = State.READY
		bake_completed.emit(slot_id, recipe_id)


func _reset() -> void:
	state = State.EMPTY
	recipe_id = &""
	bake_start_timestamp = 0
	bake_time_seconds = 0.0
	gold_reward = 0
