## DailyTaskSystem — Service
##
## Her gün 3 görev (1 EASY + 1 MEDIUM + 1 HARD) üretir. Görevler gün numarasından
## türetilen deterministik seed ile seçilir; ilerleme record_progress() ile güncellenir.
##
## Mimari kuralları (GDD Daily Task System #19):
##   - _process() yasaktır (ADR-0003); sıfırlama check_daily_reset() ile
##   - Deterministik üretim: day_number → seed → task_pool shuffle
##   - Dependency injection: _economy_ref — test izolasyonu için
##
## GDD: design/gdd/daily-task-system.md
class_name DailyTaskSystem
extends Node

## Görev tamamlandığında (henüz claim edilmedi).
signal task_completed(task_id: int)
## Tüm 3 görev tamamlandığında; daily_bonus economy'ye eklendi.
signal all_tasks_completed(bonus_gold: int)
## Görevler günlük sıfırlandığında.
signal tasks_reset

enum TaskType {
	SELL_BREAD,
	BAKE_COMPLETE,
	SERVE_CUSTOMER,
	EARN_GOLD,
	SPEND_GOLD,
}

enum TaskDifficulty { EASY = 0, MEDIUM = 1, HARD = 2 }

const TASKS_PER_DAY: int = 3
const DAILY_BONUS_MULTIPLIER: float = 1.5
## Son N günün görevleri havuzdan hariç tutulur (tekrar önleme).
const HISTORY_EXCLUSION_DAYS: int = 3

## Görev runtime durumu.
class TaskEntry:
	extends RefCounted
	var task_id: int = 0
	var template_index: int = 0   # havuzdaki şablon indeksi
	var task_type: TaskType = TaskType.SELL_BREAD
	var difficulty: TaskDifficulty = TaskDifficulty.EASY
	var target_count: int = 1
	var current_count: int = 0
	var reward_gold: int = 50
	var reward_claimed: bool = false

	var is_complete: bool:
		get: return current_count >= target_count

## Bugünkü aktif görevler.
var _tasks: Array[TaskEntry] = []

## Son sıfırlama zamanı (unix). SaveLoadManager tarafından yüklenir.
var last_reset_unix: int = 0

## Son N günde kullanılan şablon indeks geçmişi.
var _template_history: Array[int] = []

## Dependency injection.
var _economy_ref: EconomySystem = null


# ── Görev Şablonu Havuzu ──────────────────────────────────────────────────────

## [type, difficulty, base_target, reward_gold]
const _TASK_TEMPLATES: Array = [
	# EASY
	[TaskType.SELL_BREAD,     TaskDifficulty.EASY,   50,  50],
	[TaskType.BAKE_COMPLETE,  TaskDifficulty.EASY,    5,  50],
	[TaskType.SERVE_CUSTOMER, TaskDifficulty.EASY,    3,  50],
	[TaskType.EARN_GOLD,      TaskDifficulty.EASY,  200,  50],
	[TaskType.SPEND_GOLD,     TaskDifficulty.EASY,  150,  50],
	# MEDIUM
	[TaskType.SELL_BREAD,     TaskDifficulty.MEDIUM, 100, 100],
	[TaskType.BAKE_COMPLETE,  TaskDifficulty.MEDIUM,  10, 100],
	[TaskType.SERVE_CUSTOMER, TaskDifficulty.MEDIUM,   5, 100],
	[TaskType.EARN_GOLD,      TaskDifficulty.MEDIUM, 500, 100],
	[TaskType.SPEND_GOLD,     TaskDifficulty.MEDIUM, 300, 100],
	# HARD
	[TaskType.SELL_BREAD,     TaskDifficulty.HARD,   200, 200],
	[TaskType.BAKE_COMPLETE,  TaskDifficulty.HARD,    20, 200],
	[TaskType.SERVE_CUSTOMER, TaskDifficulty.HARD,    10, 200],
	[TaskType.EARN_GOLD,      TaskDifficulty.HARD,  1000, 200],
	[TaskType.SPEND_GOLD,     TaskDifficulty.HARD,   600, 200],
]


# ── Public API ────────────────────────────────────────────────────────────────

## Geçen gün sayısına göre görevleri sıfırlar. SaveLoadManager load akışında çağrılır.
func check_daily_reset(elapsed_days: int) -> void:
	if elapsed_days >= 1:
		_generate_tasks(_current_day_number())
		last_reset_unix = Time.get_unix_time_from_system()
		tasks_reset.emit()


## Görev ilerlemesini günceller. Birden fazla görev aynı tipi paylaşabilir.
func record_progress(task_type: TaskType, amount: int = 1) -> void:
	for task: TaskEntry in _tasks:
		if task.task_type != task_type or task.is_complete:
			continue
		task.current_count = mini(task.current_count + amount, task.target_count)
		if task.is_complete:
			task_completed.emit(task.task_id)
			_check_all_completed()


## Tamamlanmış görevin ödülünü talep eder. Başarıyla ödeme yapıldıysa true.
func claim_reward(task_id: int) -> bool:
	var task: TaskEntry = _find_task(task_id)
	if task == null:
		push_warning("DailyTaskSystem: claim_reward — görev bulunamadı (id=%d)" % task_id)
		return false
	if not task.is_complete:
		return false
	if task.reward_claimed:
		return false
	var economy := _get_economy()
	if not economy:
		push_error("DailyTaskSystem: Economy sistemi bulunamadı — ödül verilmedi")
		return false
	economy.earn_gold(task.reward_gold)
	task.reward_claimed = true
	return true


## Aktif görevlerin salt okunur kopyasını döner (UI için).
func get_tasks() -> Array[TaskEntry]:
	return _tasks.duplicate()


## Tamamlanmamış görev sayısını döner.
func get_incomplete_count() -> int:
	var count: int = 0
	for task: TaskEntry in _tasks:
		if not task.is_complete:
			count += 1
	return count


## Kayıt formatında veriyi döner.
func serialize() -> Dictionary:
	var tasks_data: Array = []
	for task: TaskEntry in _tasks:
		tasks_data.append({
			"task_id": task.task_id,
			"template_index": task.template_index,
			"task_type": task.task_type,
			"difficulty": task.difficulty,
			"target_count": task.target_count,
			"current_count": task.current_count,
			"reward_gold": task.reward_gold,
			"reward_claimed": task.reward_claimed,
		})
	return {
		"tasks": tasks_data,
		"last_reset_unix": last_reset_unix,
		"template_history": _template_history,
	}


## SaveLoadManager tarafından çağrılır.
func deserialize(data: Dictionary) -> void:
	last_reset_unix = data.get("last_reset_unix", 0)
	_template_history = data.get("template_history", [])
	_tasks.clear()
	var tasks_data: Array = data.get("tasks", [])
	for entry: Dictionary in tasks_data:
		var task := TaskEntry.new()
		task.task_id = entry.get("task_id", 0)
		task.template_index = entry.get("template_index", 0)
		task.task_type = entry.get("task_type", TaskType.SELL_BREAD) as TaskType
		task.difficulty = entry.get("difficulty", TaskDifficulty.EASY) as TaskDifficulty
		task.target_count = entry.get("target_count", 1)
		task.current_count = entry.get("current_count", 0)
		task.reward_gold = entry.get("reward_gold", 50)
		task.reward_claimed = entry.get("reward_claimed", false)
		_tasks.append(task)


# ── Internal ──────────────────────────────────────────────────────────────────

## Günlük görevleri deterministik seed ile üretir (GDD §3, §4 F-2).
func _generate_tasks(day_number: int) -> void:
	_tasks.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = day_number % 1_000_000

	# Havuzdan hariç tutulacak indeksler
	var excluded: Array[int] = []
	for idx: int in _template_history:
		excluded.append(idx)

	# Her zorluk seviyesinden birer şablon seç
	var difficulties: Array = [TaskDifficulty.EASY, TaskDifficulty.MEDIUM, TaskDifficulty.HARD]
	var next_id: int = day_number * 10  # gün başına benzersiz task_id aralığı

	for diff: TaskDifficulty in difficulties:
		var candidates: Array[int] = []
		for i: int in range(_TASK_TEMPLATES.size()):
			if _TASK_TEMPLATES[i][1] == diff and not excluded.has(i):
				candidates.append(i)
		if candidates.is_empty():
			# Tüm havuz tükendiyse (history çok geniş) hepsini aday yap
			for i: int in range(_TASK_TEMPLATES.size()):
				if _TASK_TEMPLATES[i][1] == diff:
					candidates.append(i)
		if candidates.is_empty():
			push_warning("DailyTaskSystem: Görev havuzu boş (difficulty=%d)" % diff)
			continue

		var pick: int = candidates[rng.randi() % candidates.size()]
		var tmpl: Array = _TASK_TEMPLATES[pick]

		var task := TaskEntry.new()
		task.task_id = next_id
		task.template_index = pick
		task.task_type = tmpl[0] as TaskType
		task.difficulty = tmpl[1] as TaskDifficulty
		task.target_count = tmpl[2]
		task.reward_gold = tmpl[3]
		_tasks.append(task)

		excluded.append(pick)
		next_id += 1

	# Geçmişi güncelle (maksimum HISTORY_EXCLUSION_DAYS × TASKS_PER_DAY kayıt)
	for task: TaskEntry in _tasks:
		_template_history.append(task.template_index)
	var max_history: int = HISTORY_EXCLUSION_DAYS * TASKS_PER_DAY
	if _template_history.size() > max_history:
		_template_history = _template_history.slice(_template_history.size() - max_history)


func _check_all_completed() -> void:
	for task: TaskEntry in _tasks:
		if not task.is_complete:
			return
	# Tüm görevler tamamlandı — bonus hesapla ve öde
	var total_reward: int = 0
	for task: TaskEntry in _tasks:
		total_reward += task.reward_gold
	var bonus: int = int(float(total_reward) * DAILY_BONUS_MULTIPLIER)
	var economy := _get_economy()
	if economy:
		economy.earn_gold(bonus)
	else:
		push_error("DailyTaskSystem: Economy sistemi bulunamadı — günlük bonus verilemedi")
	all_tasks_completed.emit(bonus)


func _find_task(task_id: int) -> TaskEntry:
	for task: TaskEntry in _tasks:
		if task.task_id == task_id:
			return task
	return null


## Unix timestamp'ten gün numarasını hesaplar (GDD §3 Deterministik Üretim).
func _current_day_number() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem
