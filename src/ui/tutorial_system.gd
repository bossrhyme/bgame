## TutorialSystem — Contextual Tutorial & Hint Manager
##
## Yeni oyuncuyu ilk 5 adımda temel döngüyü keşfettirip bağımsız oynamaya hazırlar.
## Adımlar sıralı kilitlidir; her adım tamamlanınca sonraki açılır.
## Skip akışı: confirm dialog → flag yazılır → ödül verilmez.
## Prestige tutorial'ı sıfırlamaz.
##
## ADR-0003: _process() kullanılmaz; sinyal tabanlı tetikleme.
## GDD: design/gdd/tutorial-onboarding-system.md
class_name TutorialSystem
extends Node

## Tutorial adımı tamamlandığında (ödül öncesi).
signal step_completed(step_id: StringName, reward_gold: int)
## Tüm 5 adım tamamlanıp tutorial kapandığında.
signal tutorial_finished
## Tutorial atlandığında (ödülsüz).
signal tutorial_skipped
## Bir hint gösterilmeye hazır olduğunda (UI overlay için).
signal hint_ready(hint_id: StringName)
## Tooltip göstermek için — step_id, hedef UI yolu.
signal show_tooltip(step_id: StringName, target_node_path: String, message: String)
## Tooltip gizlenecek.
signal hide_tooltip

# ── Adım tanımları ────────────────────────────────────────────────────────────

const STEPS: Array[StringName] = [
	&"tut_knead", &"tut_bake", &"tut_harvest", &"tut_sell", &"tut_upgrade"
]

const STEP_REWARDS: Dictionary = {
	&"tut_knead":   10,
	&"tut_bake":    15,
	&"tut_harvest": 15,
	&"tut_sell":    20,
	&"tut_upgrade": 25,
}

const STEP_MESSAGES: Dictionary = {
	&"tut_knead":   "Hamuru yoğurmak için döngüsel hareket yap",
	&"tut_bake":    "Hazır hamuru fırına sürükle",
	&"tut_harvest": "Pişen ekmeği fırından al",
	&"tut_sell":    "Müşteriye ekmeği sat",
	&"tut_upgrade": "İlk upgrade'ini satın al",
}

const STEP_UI_PATHS: Dictionary = {
	&"tut_knead":   "KneadArea",
	&"tut_bake":    "OvenSlot",
	&"tut_harvest": "OvenSlot",
	&"tut_sell":    "CustomerArea",
	&"tut_upgrade": "UpgradeButton",
}

const HINTS: Array[StringName] = [
	&"hint_offline_return",
	&"hint_new_upgrade",
	&"hint_daily_task",
]

const STARTING_GOLD: int = 30
const SKIP_BUTTON_DELAY_SEC: float = 5.0

# ── State ──────────────────────────────────────────────────────────────────────

var _tutorial_completed: bool = false
var _current_step_index: int = 0
var _reward_given: Dictionary = {}     # StringName → bool; idempotency
var _hint_shown: Dictionary = {}       # StringName → bool

## Tutorial aktifken reklam teklifleri baskılanır (AdMonetizationSystem kontrol eder).
var tut_active: bool:
	get: return not _tutorial_completed

# ── Dependency injection ──────────────────────────────────────────────────────

var _economy_ref: EconomySystem = null
var _oven_ref: OvenManager = null
var _upgrade_ref: UpgradeTree = null
var _recipe_ref: RecipeManager = null
var _customer_ref: CustomerOrderSystem = null
var _gesture_ref: CircularGestureDetector = null


func _ready() -> void:
	_wire_signals()
	if not _tutorial_completed:
		_show_current_step_tooltip()
		_start_skip_timer()


# ── Public API ────────────────────────────────────────────────────────────────

## SaveLoadManager tarafından yüklenir.
func deserialize(data: Dictionary) -> void:
	_tutorial_completed = data.get("tutorial_completed", false)
	_current_step_index = data.get("current_step_index", 0)
	_reward_given = data.get("reward_given", {})
	_hint_shown   = data.get("hint_shown", {})


## SaveLoadManager tarafından kaydedilir.
func serialize() -> Dictionary:
	return {
		"tutorial_completed":  _tutorial_completed,
		"current_step_index":  _current_step_index,
		"reward_given":        _reward_given,
		"hint_shown":          _hint_shown,
	}


## Oyuncu "Atla" butonuna bastı.
func skip_tutorial() -> void:
	if _tutorial_completed:
		return
	_tutorial_completed = true
	hide_tooltip.emit()
	var econ := _get_economy()
	if econ and econ.gold_balance == 0:
		econ.earn_gold(STARTING_GOLD)
	tutorial_skipped.emit()


## Hint tetikleyicisi: hint_id zaten gösterildiyse no-op.
func trigger_hint(hint_id: StringName) -> void:
	if not _tutorial_completed:
		return
	if _hint_shown.get(hint_id, false):
		return
	_hint_shown[hint_id] = true
	hint_ready.emit(hint_id)


## Bir adımı doğrudan tamamla (test / özel tetikleyici için).
func complete_step_if_current(step_id: StringName) -> void:
	if _tutorial_completed:
		return
	if _current_step_index >= STEPS.size():
		return
	if STEPS[_current_step_index] != step_id:
		return
	_on_step_triggered(step_id)


# ── Signal Wiring ─────────────────────────────────────────────────────────────

func _wire_signals() -> void:
	var gesture := _get_gesture()
	if gesture:
		gesture.circular_completed.connect(_on_knead_completed)

	var oven := _get_oven()
	if oven:
		oven.bake_started.connect(_on_bake_started)
		oven.bread_harvested.connect(_on_bread_harvested)

	var customer := _get_customer()
	if customer:
		customer.order_delivered.connect(_on_order_delivered)

	var upgrade := _get_upgrade()
	if upgrade:
		upgrade.upgrade_purchased.connect(_on_upgrade_purchased)


# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_knead_completed() -> void:
	_on_step_triggered(&"tut_knead")


func _on_bake_started(_slot_id: int, _recipe_id: StringName) -> void:
	_on_step_triggered(&"tut_bake")


func _on_bread_harvested(_slot_id: int, _recipe_id: StringName, _gold: int) -> void:
	_on_step_triggered(&"tut_harvest")


func _on_order_delivered(_order: OrderEntry, _gold: int) -> void:
	_on_step_triggered(&"tut_sell")


func _on_upgrade_purchased(_upgrade_id: StringName, _new_level: int) -> void:
	_on_step_triggered(&"tut_upgrade")


# ── Step Logic ────────────────────────────────────────────────────────────────

func _on_step_triggered(step_id: StringName) -> void:
	if _tutorial_completed:
		return
	if _current_step_index >= STEPS.size():
		return
	if STEPS[_current_step_index] != step_id:
		return

	hide_tooltip.emit()

	# Ödül — idempotency flag ile korunur
	if not _reward_given.get(step_id, false):
		_reward_given[step_id] = true
		var reward: int = STEP_REWARDS.get(step_id, 0)
		var econ := _get_economy()
		if econ and reward > 0:
			econ.earn_gold(reward)
		step_completed.emit(step_id, reward)

	_current_step_index += 1

	if _current_step_index >= STEPS.size():
		_tutorial_completed = true
		tutorial_finished.emit()
	else:
		_show_current_step_tooltip()


func _show_current_step_tooltip() -> void:
	if _current_step_index >= STEPS.size():
		return
	var step_id: StringName = STEPS[_current_step_index]
	show_tooltip.emit(
		step_id,
		STEP_UI_PATHS.get(step_id, ""),
		STEP_MESSAGES.get(step_id, "")
	)


func _start_skip_timer() -> void:
	var tree := get_tree()
	if not tree:
		return
	tree.create_timer(SKIP_BUTTON_DELAY_SEC).timeout.connect(
		func() -> void:
			if not _tutorial_completed:
				# UI katmanına skip butonunu göstermesi için sinyal yayılabilir.
				# Bu iskelet; UI bağlantısı HUDManager tarafından yapılır.
				pass
	, CONNECT_ONE_SHOT)


# ── Dependency Getters ────────────────────────────────────────────────────────

func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem


func _get_oven() -> OvenManager:
	if _oven_ref:
		return _oven_ref
	return get_node_or_null("/root/OvenManager") as OvenManager


func _get_upgrade() -> UpgradeTree:
	if _upgrade_ref:
		return _upgrade_ref
	return get_node_or_null("/root/UpgradeTree") as UpgradeTree


func _get_customer() -> CustomerOrderSystem:
	if _customer_ref:
		return _customer_ref
	return get_node_or_null("/root/CustomerOrderSystem") as CustomerOrderSystem


func _get_gesture() -> CircularGestureDetector:
	if _gesture_ref:
		return _gesture_ref
	return get_node_or_null("/root/CircularGestureDetector") as CircularGestureDetector
