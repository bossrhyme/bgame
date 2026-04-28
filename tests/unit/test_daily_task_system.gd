## GUT Test Suite — DailyTaskSystem
## design/gdd/daily-task-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_daily_task_system.gd
extends GutTest


var sys: DailyTaskSystem
var economy: EconomySystem


func before_each() -> void:
	economy = EconomySystem.new()
	add_child(economy)
	sys = DailyTaskSystem.new()
	sys._economy_ref = economy
	add_child(sys)


func after_each() -> void:
	if is_instance_valid(sys):
		sys.queue_free()
	if is_instance_valid(economy):
		economy.queue_free()


# ── Görev Üretimi ─────────────────────────────────────────────────────────────

func test_generate_tasks_produces_three_tasks() -> void:
	# Arrange / Act
	sys.check_daily_reset(1)

	# Assert
	assert_eq(sys.get_tasks().size(), 3, "Günlük 3 görev üretildi")


func test_generate_tasks_one_per_difficulty() -> void:
	# Arrange / Act
	sys.check_daily_reset(1)
	var tasks := sys.get_tasks()

	# Assert: birer EASY, MEDIUM, HARD
	var easy_count := 0
	var medium_count := 0
	var hard_count := 0
	for t: DailyTaskSystem.TaskEntry in tasks:
		match t.difficulty:
			DailyTaskSystem.TaskDifficulty.EASY:   easy_count += 1
			DailyTaskSystem.TaskDifficulty.MEDIUM: medium_count += 1
			DailyTaskSystem.TaskDifficulty.HARD:   hard_count += 1
	assert_eq(easy_count, 1, "1 EASY görev")
	assert_eq(medium_count, 1, "1 MEDIUM görev")
	assert_eq(hard_count, 1, "1 HARD görev")


func test_generate_tasks_deterministic_same_seed() -> void:
	# Aynı day_number → aynı görevler
	sys.check_daily_reset(1)
	var types_a: Array = []
	for t: DailyTaskSystem.TaskEntry in sys.get_tasks():
		types_a.append(t.task_type)

	# Yeni sistem, aynı seed
	var sys2 := DailyTaskSystem.new()
	sys2._economy_ref = economy
	add_child(sys2)
	sys2.check_daily_reset(1)
	var types_b: Array = []
	for t: DailyTaskSystem.TaskEntry in sys2.get_tasks():
		types_b.append(t.task_type)

	assert_eq(types_a, types_b, "Aynı seed → aynı görev tipleri")
	sys2.queue_free()


func test_no_tasks_without_reset() -> void:
	# elapsed_days=0 → yeni gün yok → görev üretilmez
	sys.check_daily_reset(0)
	assert_eq(sys.get_tasks().size(), 0, "elapsed=0 → görev üretilmez")


func test_check_daily_reset_emits_tasks_reset_signal() -> void:
	# Arrange
	watch_signals(sys)

	# Act
	sys.check_daily_reset(1)

	# Assert
	assert_signal_emitted(sys, "tasks_reset")


# ── record_progress ───────────────────────────────────────────────────────────

func test_record_progress_advances_matching_task() -> void:
	# Arrange: SELL_BREAD görevi bul
	sys.check_daily_reset(1)
	var sell_task: DailyTaskSystem.TaskEntry = null
	for t: DailyTaskSystem.TaskEntry in sys.get_tasks():
		if t.task_type == DailyTaskSystem.TaskType.SELL_BREAD:
			sell_task = t
			break
	if sell_task == null:
		# Bu seed'de SELL_BREAD görevi yoksa testi atla
		pass_test()
		return

	var before: int = sell_task.current_count

	# Act
	sys.record_progress(DailyTaskSystem.TaskType.SELL_BREAD, 10)

	# Assert
	assert_eq(sell_task.current_count, before + 10, "İlerleme 10 arttı")


func test_record_progress_does_not_exceed_target() -> void:
	# Arrange: görevi manuel oluştur
	sys.check_daily_reset(1)
	var task := sys.get_tasks()[0]
	task.current_count = task.target_count - 1

	# Act: hedefi aşacak kadar ilerleme
	sys.record_progress(task.task_type, 9999)

	# Assert: current_count hedefte sabit
	assert_eq(task.current_count, task.target_count,
		"İlerleme target'ı aşmaz")


func test_record_progress_does_not_advance_completed_task() -> void:
	# Arrange: tamamlanmış görev
	sys.check_daily_reset(1)
	var task := sys.get_tasks()[0]
	task.current_count = task.target_count  # tamamlandı

	# Act: tekrar progress
	var before: int = task.current_count
	sys.record_progress(task.task_type, 5)

	# Assert: değişmez
	assert_eq(task.current_count, before, "Tamamlanmış göreve ilerleme eklenmez")


func test_record_progress_emits_task_completed_signal() -> void:
	# Arrange
	sys.check_daily_reset(1)
	var task := sys.get_tasks()[0]
	task.current_count = task.target_count - 1
	watch_signals(sys)

	# Act: son ilerleme
	sys.record_progress(task.task_type, 1)

	# Assert
	assert_signal_emitted(sys, "task_completed")


# ── claim_reward ──────────────────────────────────────────────────────────────

func test_claim_reward_adds_gold_to_economy() -> void:
	# Arrange: tamamlanmış EASY görev (50 altın ödül)
	sys.check_daily_reset(1)
	var task := sys.get_tasks()[0]  # EASY görev
	task.current_count = task.target_count

	# Act
	var ok := sys.claim_reward(task.task_id)

	# Assert
	assert_true(ok, "claim başarılı")
	assert_eq(economy.gold_balance, task.reward_gold, "Economy ödülü aldı")


func test_claim_reward_twice_no_double_payment() -> void:
	# Arrange
	sys.check_daily_reset(1)
	var task := sys.get_tasks()[0]
	task.current_count = task.target_count
	sys.claim_reward(task.task_id)
	var after_first: int = economy.gold_balance

	# Act: ikinci claim
	var ok2 := sys.claim_reward(task.task_id)

	# Assert
	assert_false(ok2, "İkinci claim → false")
	assert_eq(economy.gold_balance, after_first, "Çift ödeme yok")


func test_claim_reward_incomplete_task_returns_false() -> void:
	# Arrange
	sys.check_daily_reset(1)
	var task := sys.get_tasks()[0]
	# current_count = 0, tamamlanmamış

	# Act / Assert
	assert_false(sys.claim_reward(task.task_id), "Tamamlanmamış görev → false")
	assert_eq(economy.gold_balance, 0, "Economy değişmez")


func test_claim_reward_nonexistent_id_returns_false() -> void:
	assert_false(sys.claim_reward(99999), "Olmayan ID → false")


# ── Günlük bonus (all_tasks_completed) ───────────────────────────────────────

func test_all_tasks_completed_emits_signal_and_pays_bonus() -> void:
	# Arrange: tüm görevleri tamamla
	sys.check_daily_reset(1)
	var tasks := sys.get_tasks()
	var expected_total: int = 0
	for t: DailyTaskSystem.TaskEntry in tasks:
		expected_total += t.reward_gold

	var expected_bonus: int = int(float(expected_total) * DailyTaskSystem.DAILY_BONUS_MULTIPLIER)
	watch_signals(sys)

	# Act: tüm görevleri tamamla (ilerleme ile)
	for task: DailyTaskSystem.TaskEntry in tasks:
		sys.record_progress(task.task_type, task.target_count)

	# Assert
	assert_signal_emitted(sys, "all_tasks_completed")
	assert_eq(economy.gold_balance, expected_bonus,
		"Günlük bonus economy'ye eklendi")


func test_daily_bonus_formula_150_percent() -> void:
	# F-1: bonus = sum(reward_gold) × 1.5
	sys.check_daily_reset(1)
	var tasks := sys.get_tasks()
	var total_reward: int = 0
	for t: DailyTaskSystem.TaskEntry in tasks:
		total_reward += t.reward_gold

	for task: DailyTaskSystem.TaskEntry in tasks:
		sys.record_progress(task.task_type, task.target_count)

	var expected: int = int(float(total_reward) * 1.5)
	assert_eq(economy.gold_balance, expected, "Bonus = toplam ödül × 1.5")


# ── Günlük sıfırlama ─────────────────────────────────────────────────────────

func test_daily_reset_clears_previous_tasks() -> void:
	# Arrange: görev üret
	sys.check_daily_reset(1)
	assert_eq(sys.get_tasks().size(), 3, "Önce 3 görev var")

	# Act: bir gün geçti → sıfırla
	sys.check_daily_reset(1)

	# Assert: yeni 3 görev (eskiler temizlendi)
	assert_eq(sys.get_tasks().size(), 3, "Sıfırlama sonrası 3 yeni görev")


func test_daily_reset_removes_incomplete_tasks_no_penalty() -> void:
	# Tamamlanmamış görevler silinir; ceza yok (economy değişmez)
	sys.check_daily_reset(1)
	assert_eq(economy.gold_balance, 0, "Sıfırlama öncesi economy sıfır")
	sys.check_daily_reset(1)
	assert_eq(economy.gold_balance, 0, "Sıfırlama sonrası ceza yok — economy sıfır")


func test_multiple_elapsed_days_resets_once() -> void:
	# elapsed_days=3 → tek bir sıfırlama yapılır (3×değil)
	sys.check_daily_reset(3)
	assert_eq(sys.get_tasks().size(), 3, "3 gün geçse de 3 görev üretildi (çarpıltılmaz)")


# ── serialize / deserialize ───────────────────────────────────────────────────

func test_serialize_deserialize_preserves_progress() -> void:
	# Arrange: görev üret ve ilerleme ekle
	sys.check_daily_reset(1)
	var task := sys.get_tasks()[0]
	sys.record_progress(task.task_type, 5)

	# Act
	var saved: Dictionary = sys.serialize()
	var sys2 := DailyTaskSystem.new()
	sys2._economy_ref = economy
	sys2.deserialize(saved)
	add_child(sys2)

	# Assert
	var restored_tasks := sys2.get_tasks()
	assert_eq(restored_tasks.size(), 3, "Görevler restore edildi")
	var restored_task: DailyTaskSystem.TaskEntry = null
	for t: DailyTaskSystem.TaskEntry in restored_tasks:
		if t.task_id == task.task_id:
			restored_task = t
			break
	assert_not_null(restored_task, "Görev ID bulundu")
	assert_eq(restored_task.current_count, task.current_count, "İlerleme restore edildi")
	sys2.queue_free()


func test_serialize_preserves_last_reset_unix() -> void:
	# Arrange
	sys.check_daily_reset(1)
	var saved: Dictionary = sys.serialize()

	# Assert
	assert_true(saved.get("last_reset_unix", 0) > 0, "last_reset_unix kaydedildi")
