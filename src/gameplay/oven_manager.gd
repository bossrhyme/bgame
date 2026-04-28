## OvenManager
##
## Fırın slot'larını yönetir: pişirme başlatma, hasat, slot kilidi açma, offline üretim.
## Upgrade Tree aracılığıyla slot sayısı STARTING_SLOT_COUNT'tan MAX_SLOT_COUNT'a çıkarılabilir.
##
## Mimari kuralları (GDD #9):
##   - _process() yasaktır (ADR-0003); tüm zamanlama BakingSlot.Timer.timeout üzerinden
##   - Her slot bağımsız; birinin tamamlanması diğerlerini etkilemez
##   - Offline: açılışta initialize_from_save() ile BAKING slotları kalan süre hesabıyla devam ettirilir
##   - efficiency_multiplier varsayılan 1.0 (Employee/Upgrade entegrasyonuna kadar)
class_name OvenManager
extends Node

const STARTING_SLOT_COUNT: int = 1
const MAX_SLOT_COUNT: int = 4
const OFFLINE_CAP_SECONDS: float = 28800.0

## Pişirme başladığında yayılır.
signal bake_started(slot_id: int, recipe_id: StringName)
## Pişirme tamamlandığında yayılır (Timer.timeout veya offline hesap).
signal bake_completed(slot_id: int, recipe_id: StringName)
## Hasat tamamlandığında yayılır.
signal bread_harvested(slot_id: int, recipe_id: StringName, gold_earned: int)

var _slots: Array[BakingSlot] = []
var _active_slot_count: int = STARTING_SLOT_COUNT

## Altın çarpanı — Employee/Upgrade entegrasyonunda inject edilir; varsayılan 1.0 (F-2)
var efficiency_multiplier: float = 1.0

## Dependency injection (test izolasyonu). null ise autoload'dan alınır.
var _economy_ref: EconomySystem = null
var _content_ref: ContentRegistry = null

## Salt okunur aktif slot sayısı.
var active_slot_count: int:
	get: return _active_slot_count


func _ready() -> void:
	_init_slots()


# ── Public API ────────────────────────────────────────────────────────────────

## Tarif ile pişirme başlatır.
## slot_id = -1: ilk boş aktif slot. slot_id >= 0: belirli slot.
## ContentRegistry'de tarif bulunamazsa veya slot doluysa false döner.
func receive_dough(recipe_id: StringName, slot_id: int = -1) -> bool:
	var target: int = slot_id
	if target < 0:
		target = _find_empty_slot()
	if target < 0 or target >= _active_slot_count:
		return false
	if _slots[target].state != BakingSlot.State.EMPTY:
		return false
	return _start_baking_in_slot(target, recipe_id)


## Hasat yapar. READY slot için Economy.earn_gold çağırır ve sinyali emit eder.
## Başarıysa true; EMPTY veya BAKING durumunda false + hata logu.
func harvest(slot_id: int) -> bool:
	if slot_id < 0 or slot_id >= MAX_SLOT_COUNT:
		push_error("OvenManager: harvest için geçersiz slot_id: %d" % slot_id)
		return false
	var slot: BakingSlot = _slots[slot_id]
	if slot.state != BakingSlot.State.READY:
		push_error("OvenManager: harvest READY olmayan slot %d üzerinde çağrıldı (%s)" \
			% [slot_id, BakingSlot.State.keys()[slot.state]])
		return false
	var recipe := slot.recipe_id
	var gold_raw: int = slot.do_harvest()
	var gold_earned: int = floori(float(gold_raw) * efficiency_multiplier)
	var economy := _get_economy()
	if economy:
		economy.earn_gold(gold_earned)
	bread_harvested.emit(slot_id, recipe, gold_earned)
	return true


## Belirtilen slot indeksini aktif eder (Upgrade Tree tarafından çağrılır).
## MAX_SLOT_COUNT sınırını aşmaz; zaten aktifse no-op.
func unlock_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MAX_SLOT_COUNT:
		push_warning("OvenManager: unlock_slot geçersiz index: %d (max %d)" \
			% [slot_index, MAX_SLOT_COUNT - 1])
		return
	if _active_slot_count >= MAX_SLOT_COUNT:
		push_warning("OvenManager: Zaten maksimum slot sayısına ulaşıldı (%d)" % MAX_SLOT_COUNT)
		return
	if slot_index + 1 > _active_slot_count:
		_active_slot_count = slot_index + 1


## Kayıttan slot durumlarını yükler ve offline pişirmeyi uygular.
## SaveLoadManager tarafından startup'ta çağrılır.
## speed_multiplier: 1.0 + Fırın Ustası efekti — GDD Offline Production #16 F-1
func initialize_from_save(slot_data: Array[Dictionary],
		speed_multiplier: float = 1.0) -> void:
	var now_unix: int = Time.get_unix_time_from_system()
	for data in slot_data:
		var id: int = data.get("slot_id", -1)
		if id < 0 or id >= MAX_SLOT_COUNT:
			continue
		var slot: BakingSlot = _slots[id]
		var saved_state: String = data.get("state", "EMPTY")
		match saved_state:
			"BAKING":
				slot.recipe_id = data.get("recipe_id", &"")
				slot.bake_time_seconds = data.get("bake_time_seconds", 0.0)
				slot.gold_reward = data.get("gold_reward", 0)
				slot.bake_start_timestamp = data.get("bake_start_timestamp", now_unix)
				slot.state = BakingSlot.State.BAKING
				var elapsed: float = float(now_unix - slot.bake_start_timestamp)
				slot.apply_offline(elapsed, OFFLINE_CAP_SECONDS, speed_multiplier)
			"READY":
				slot.recipe_id = data.get("recipe_id", &"")
				slot.bake_time_seconds = data.get("bake_time_seconds", 0.0)
				slot.gold_reward = data.get("gold_reward", 0)
				slot.bake_start_timestamp = data.get("bake_start_timestamp", 0)
				slot.state = BakingSlot.State.READY


## Mevcut slot durumlarını kayıt formatında döner.
## SaveLoadManager tarafından _save_game() sırasında çağrılır.
func get_save_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(_active_slot_count):
		var slot: BakingSlot = _slots[i]
		result.append({
			"slot_id": i,
			"state": BakingSlot.State.keys()[slot.state],
			"recipe_id": slot.recipe_id,
			"bake_start_timestamp": slot.bake_start_timestamp,
			"bake_time_seconds": slot.bake_time_seconds,
			"gold_reward": slot.gold_reward,
		})
	return result


# ── Internal ──────────────────────────────────────────────────────────────────

func _init_slots() -> void:
	for i in range(MAX_SLOT_COUNT):
		var slot := BakingSlot.new()
		slot.slot_id = i
		slot.name = "BakingSlot%d" % i
		add_child(slot)
		slot.bake_completed.connect(_on_slot_bake_completed)
		_slots.append(slot)


func _find_empty_slot() -> int:
	for i in range(_active_slot_count):
		if _slots[i].state == BakingSlot.State.EMPTY:
			return i
	return -1


func _start_baking_in_slot(slot_id: int, recipe_id: StringName) -> bool:
	var content := _get_content()
	if not content:
		push_error("OvenManager: ContentRegistry sistemi bulunamadı!")
		return false
	var recipe: RecipeData = content.get_recipe(recipe_id)
	if not recipe:
		return false
	var slot: BakingSlot = _slots[slot_id]
	if not slot.start_baking(recipe_id, recipe.bake_time_seconds, recipe.base_value):
		return false
	bake_started.emit(slot_id, recipe_id)
	return true


func _on_slot_bake_completed(slot_id: int, recipe_id: StringName) -> void:
	bake_completed.emit(slot_id, recipe_id)


func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem


func _get_content() -> ContentRegistry:
	if _content_ref:
		return _content_ref
	return get_node_or_null("/root/ContentRegistry") as ContentRegistry
