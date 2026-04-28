## MotivationHooksSystem — Oyuncu Tutma Kancaları
##
## Economy, OvenManager, DailyTaskSystem sinyallerini izleyerek "az kaldı"
## ve "hasat zamanı" türü bildirimler üretir.
## session_idle (iskelet): platform push notif için yer tutucu.
##
## GDD: design/gdd/motivation-hooks-system.md
class_name MotivationHooksSystem
extends Node

## En ucuz upgrade'e NEAR_UPGRADE_THRESHOLD altın kaldığında.
signal near_upgrade(upgrade_id: StringName, gold_needed: int)
## Fırın doluluk oranı OVEN_FULL_RATIO'yu aştığında.
signal oven_nearly_full(used_slots: int, total_slots: int)
## Günlük görevde yalnızca 1 görev kalmışken bir görev tamamlandığında.
signal daily_task_near_completion(remaining: int)
## IDLE_TIMEOUT_SEC boyunca altın kazanılmadığında (platform push iskelet).
signal session_idle

const NEAR_UPGRADE_THRESHOLD: int = 50
const OVEN_FULL_RATIO: float = 0.8
const IDLE_TIMEOUT_SEC: float = 1200.0

## Dependency injection (test izolasyonu).
var _economy_ref: EconomySystem = null
var _upgrade_ref: UpgradeTree = null
var _oven_ref: OvenManager = null
var _task_ref: DailyTaskSystem = null
var _notif_ref: NotificationManager = null

var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	_wire_signals()
	_reset_idle_timer()


# ── Signal Wiring ─────────────────────────────────────────────────────────────

func _wire_signals() -> void:
	var economy := _get_economy()
	if economy:
		economy.gold_changed.connect(_on_gold_changed)
	else:
		push_warning("MotivationHooksSystem: EconomySystem bağlanamadı")

	var oven := _get_oven()
	if oven:
		oven.bake_started.connect(_on_bake_started)
	else:
		push_warning("MotivationHooksSystem: OvenManager bağlanamadı")

	var task := _get_task()
	if task:
		task.task_completed.connect(_on_task_completed)
	else:
		push_warning("MotivationHooksSystem: DailyTaskSystem bağlanamadı")


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_gold_changed(new_balance: int) -> void:
	_reset_idle_timer()
	_check_near_upgrade(new_balance)


func _on_bake_started(_slot_id: int, _recipe_id: StringName) -> void:
	_check_oven_capacity()


func _on_task_completed(_task_id: int) -> void:
	_check_daily_task_progress()


# ── Hook Logic ────────────────────────────────────────────────────────────────

func _check_near_upgrade(gold: int) -> void:
	var upgrade := _get_upgrade()
	if not upgrade:
		return

	var cheapest_id: StringName = &""
	var cheapest_cost: int = INT_MAX
	for id: StringName in upgrade._upgrades:
		if upgrade.is_maxed(id):
			continue
		var cost: int = upgrade.get_next_cost(id)
		if cost > 0 and cost < cheapest_cost:
			cheapest_cost = cost
			cheapest_id = id

	if cheapest_id == &"":
		return  # Tüm upgrade'ler maxlenmiş

	var needed: int = cheapest_cost - gold
	if needed > 0 and needed <= NEAR_UPGRADE_THRESHOLD:
		near_upgrade.emit(cheapest_id, needed)
		_notify("Bir sonraki upgrade'e %d altın kaldı!" % needed,
			NotificationManager.Priority.LOW)


func _check_oven_capacity() -> void:
	var oven := _get_oven()
	if not oven:
		return
	var total: int = oven.active_slot_count
	if total <= 0:
		return

	var busy: int = 0
	for i: int in range(total):
		var slot: BakingSlot = oven._slots[i] if i < oven._slots.size() else null
		if slot and slot.state == BakingSlot.State.BAKING:
			busy += 1

	var ratio: float = float(busy) / float(total)
	if ratio >= OVEN_FULL_RATIO:
		oven_nearly_full.emit(busy, total)
		_notify("Fırın neredeyse dolu! Hasat zamanı.",
			NotificationManager.Priority.LOW)


func _check_daily_task_progress() -> void:
	var task := _get_task()
	if not task:
		return
	var remaining: int = task.get_incomplete_count()
	if remaining == 1:
		daily_task_near_completion.emit(remaining)
		_notify("Son göreve kaldı!", NotificationManager.Priority.INFO)


func _reset_idle_timer() -> void:
	var tree := get_tree()
	if not tree:
		return
	_idle_timer = tree.create_timer(IDLE_TIMEOUT_SEC)
	_idle_timer.timeout.connect(_on_idle_timeout, CONNECT_ONE_SHOT)


func _on_idle_timeout() -> void:
	session_idle.emit()


func _notify(message: String, priority: NotificationManager.Priority) -> void:
	var notif := _get_notif()
	if notif:
		notif.queue_notification(message, priority)


# ── Dependency Getters ────────────────────────────────────────────────────────

func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem


func _get_upgrade() -> UpgradeTree:
	if _upgrade_ref:
		return _upgrade_ref
	return get_node_or_null("/root/UpgradeTree") as UpgradeTree


func _get_oven() -> OvenManager:
	if _oven_ref:
		return _oven_ref
	return get_node_or_null("/root/OvenManager") as OvenManager


func _get_task() -> DailyTaskSystem:
	if _task_ref:
		return _task_ref
	return get_node_or_null("/root/DailyTaskSystem") as DailyTaskSystem


func _get_notif() -> NotificationManager:
	if _notif_ref:
		return _notif_ref
	return get_node_or_null("/root/NotificationManager") as NotificationManager
