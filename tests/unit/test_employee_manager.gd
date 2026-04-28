## GUT Test Suite — EmployeeManager
## design/gdd/employee-system.md — Acceptance Criteria
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_employee_manager.gd
extends GutTest


var mgr: EmployeeManager
var economy: EconomySystem

## Test için hazır EmployeeData yapıcısı.
func _make_data(role: GameEnums.EmployeeRole, wage: int, effect: float,
		max_lv: int = 3) -> EmployeeData:
	var d := EmployeeData.new()
	d.id = StringName("emp_%d" % role)
	d.role = role
	d.daily_wage = wage
	d.effect_type = GameEnums.UpgradeEffectType.BAKE_SPEED
	d.effect_per_level = []
	for _i in range(max_lv):
		d.effect_per_level.append(effect)
	d.max_level = max_lv
	return d


func before_each() -> void:
	economy = EconomySystem.new()
	add_child(economy)
	mgr = EmployeeManager.new()
	mgr._economy_ref = economy
	add_child(mgr)


func after_each() -> void:
	if is_instance_valid(mgr):
		mgr.queue_free()
	if is_instance_valid(economy):
		economy.queue_free()


# ── hire_cost formülü ─────────────────────────────────────────────────────────

func test_hire_cost_formula_level_1() -> void:
	# Arrange / Act / Assert
	assert_eq(EmployeeManager.hire_cost(50, 1), 500,
		"hamurcu sev.1: 50×10×1 = 500")


func test_hire_cost_formula_level_2() -> void:
	assert_eq(EmployeeManager.hire_cost(80, 2), 1600,
		"fırıncı sev.2: 80×10×2 = 1600")


func test_hire_cost_formula_level_3() -> void:
	assert_eq(EmployeeManager.hire_cost(100, 3), 3000,
		"teslimatçı sev.3: 100×10×3 = 3000")


# ── hire ─────────────────────────────────────────────────────────────────────

func test_hire_deducts_hire_cost_from_economy() -> void:
	# Arrange
	economy.earn_gold(1000)
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)

	# Act
	var ok := mgr.hire(data)

	# Assert
	assert_true(ok, "İşe alma başarılı")
	assert_eq(economy.gold_balance, 500, "1000 - 500 = 500 altın kaldı")


func test_hire_returns_false_when_insufficient_gold() -> void:
	# Arrange
	economy.earn_gold(100)  # 500 gerekiyor
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)

	# Act / Assert
	assert_false(mgr.hire(data), "Yetersiz altın → false")
	assert_false(mgr.has_employee(GameEnums.EmployeeRole.DOUGH_MAKER),
		"Çalışan eklenmedi")


func test_hire_same_role_twice_returns_false() -> void:
	# Arrange
	economy.earn_gold(5000)
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	mgr.hire(data)

	# Act
	var second := mgr.hire(data)

	# Assert
	assert_false(second, "Aynı rol ikinci kez işe alınamaz")


func test_hire_emits_employee_hired_signal() -> void:
	# Arrange
	economy.earn_gold(5000)
	var data := _make_data(GameEnums.EmployeeRole.OVEN_MASTER, 80, 0.20)
	watch_signals(mgr)

	# Act
	mgr.hire(data)

	# Assert
	assert_signal_emitted(mgr, "employee_hired")


func test_hire_different_roles_both_active() -> void:
	# Arrange
	economy.earn_gold(5000)
	var d1 := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	var d2 := _make_data(GameEnums.EmployeeRole.OVEN_MASTER, 80, 0.20)

	# Act
	mgr.hire(d1)
	mgr.hire(d2)

	# Assert
	assert_true(mgr.has_employee(GameEnums.EmployeeRole.DOUGH_MAKER))
	assert_true(mgr.has_employee(GameEnums.EmployeeRole.OVEN_MASTER))


# ── fire ─────────────────────────────────────────────────────────────────────

func test_fire_removes_employee() -> void:
	# Arrange
	economy.earn_gold(5000)
	var data := _make_data(GameEnums.EmployeeRole.CASHIER, 60, 0.30)
	mgr.hire(data)

	# Act
	var ok := mgr.fire(GameEnums.EmployeeRole.CASHIER)

	# Assert
	assert_true(ok, "İşten çıkarma başarılı")
	assert_false(mgr.has_employee(GameEnums.EmployeeRole.CASHIER))


func test_fire_nonexistent_returns_false() -> void:
	assert_false(mgr.fire(GameEnums.EmployeeRole.DELIVERY),
		"Olmayan çalışanı çıkarma → false")


func test_fire_emits_employee_fired_signal() -> void:
	# Arrange
	economy.earn_gold(5000)
	var data := _make_data(GameEnums.EmployeeRole.CASHIER, 60, 0.30)
	mgr.hire(data)
	watch_signals(mgr)

	# Act
	mgr.fire(GameEnums.EmployeeRole.CASHIER)

	# Assert
	assert_signal_emitted(mgr, "employee_fired")


# ── upgrade ──────────────────────────────────────────────────────────────────

func test_upgrade_increases_level() -> void:
	# Arrange
	economy.earn_gold(5000)
	var data := _make_data(GameEnums.EmployeeRole.OVEN_MASTER, 80, 0.20)
	mgr.hire(data)

	# Act: upgrade → Sev.2, maliyet 80×10×2=1600
	var ok := mgr.upgrade(GameEnums.EmployeeRole.OVEN_MASTER)

	# Assert
	assert_true(ok)
	var effect: float = mgr.get_effect(GameEnums.EmployeeRole.OVEN_MASTER)
	assert_almost_eq(effect, 0.40, 0.001, "Sev.2 efekti: 0.20×2 = 0.40")


func test_upgrade_at_max_level_returns_false() -> void:
	# Arrange: max_level=1
	economy.earn_gold(5000)
	var data := _make_data(GameEnums.EmployeeRole.OVEN_MASTER, 80, 0.20, 1)
	mgr.hire(data)

	# Act
	assert_false(mgr.upgrade(GameEnums.EmployeeRole.OVEN_MASTER),
		"Max seviyede upgrade → false")


func test_upgrade_insufficient_gold_returns_false() -> void:
	# Arrange
	economy.earn_gold(800)  # hire 800, upgrade sev.2 = 1600 → yetersiz
	var data := _make_data(GameEnums.EmployeeRole.OVEN_MASTER, 80, 0.20)
	mgr.hire(data)  # 800 harcandı, bakiye 0

	# Act / Assert
	assert_false(mgr.upgrade(GameEnums.EmployeeRole.OVEN_MASTER))


# ── get_effect ────────────────────────────────────────────────────────────────

func test_get_effect_returns_zero_when_no_employee() -> void:
	assert_almost_eq(mgr.get_effect(GameEnums.EmployeeRole.DOUGH_MAKER), 0.0, 0.001,
		"Çalışan yok → efekt 0")


func test_get_effect_level_1() -> void:
	# Arrange
	economy.earn_gold(5000)
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	mgr.hire(data)

	# Assert: 0.25 × 1 = 0.25
	assert_almost_eq(mgr.get_effect(GameEnums.EmployeeRole.DOUGH_MAKER), 0.25, 0.001)


# ── get_daily_cost ────────────────────────────────────────────────────────────

func test_get_daily_cost_empty() -> void:
	assert_eq(mgr.get_daily_cost(), 0, "Çalışan yok → günlük maliyet 0")


func test_get_daily_cost_multiple_employees() -> void:
	# Arrange
	economy.earn_gold(10000)
	var d1 := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	var d2 := _make_data(GameEnums.EmployeeRole.OVEN_MASTER, 80, 0.20)
	mgr.hire(d1)
	mgr.hire(d2)

	# Assert: 50 + 80 = 130
	assert_eq(mgr.get_daily_cost(), 130, "Toplam günlük maliyet 130")


# ── process_daily_wages ───────────────────────────────────────────────────────

func test_daily_wages_deducted_for_one_day() -> void:
	# Arrange
	economy.earn_gold(5000)
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	mgr.hire(data)  # -500, kalan 4500
	var before: int = economy.gold_balance

	# Act: 1 gün geçti
	mgr.process_daily_wages(1)

	# Assert: 50 altın düşüldü
	assert_eq(economy.gold_balance, before - 50, "1 günlük maaş: -50")


func test_daily_wages_for_multiple_days() -> void:
	# Arrange
	economy.earn_gold(10000)
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	mgr.hire(data)  # -500
	var before: int = economy.gold_balance

	# Act: 3 gün geçti
	mgr.process_daily_wages(3)

	# Assert: 50×3 = 150 düşüldü
	assert_eq(economy.gold_balance, before - 150, "3 günlük maaş: -150")


func test_daily_wages_zero_days_no_deduction() -> void:
	# Arrange
	economy.earn_gold(5000)
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	mgr.hire(data)
	var before: int = economy.gold_balance

	# Act
	mgr.process_daily_wages(0)

	# Assert
	assert_eq(economy.gold_balance, before, "0 gün → kesinti yok")


func test_daily_wages_insufficient_triggers_strike() -> void:
	# Arrange: hire ama maaş için altın yok
	economy.earn_gold(500)
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	mgr.hire(data)  # bakiye = 0
	watch_signals(mgr)

	# Act
	mgr.process_daily_wages(1)

	# Assert
	assert_signal_emitted(mgr, "strike_started")
	assert_true(mgr.any_on_strike, "Çalışan grevde")


func test_strike_effect_returns_zero() -> void:
	# Arrange: grev
	economy.earn_gold(500)
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	mgr.hire(data)
	mgr.process_daily_wages(1)  # bakiye 0 → grev

	# Assert: grevdeki çalışanın efekti 0
	assert_almost_eq(mgr.get_effect(GameEnums.EmployeeRole.DOUGH_MAKER), 0.0, 0.001,
		"Grevdeyken efekt 0")


# ── pay_strike_wages ──────────────────────────────────────────────────────────

func test_pay_strike_wages_resolves_strike() -> void:
	# Arrange: greve çıkmış çalışan
	economy.earn_gold(500)
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	mgr.hire(data)
	mgr.process_daily_wages(1)  # grev
	assert_true(mgr.any_on_strike, "Grev başladı")

	# Act: para ekle ve öde
	economy.earn_gold(200)
	watch_signals(mgr)
	var ok := mgr.pay_strike_wages()

	# Assert
	assert_true(ok, "Grev çözme başarılı")
	assert_false(mgr.any_on_strike, "Grev bitti")
	assert_signal_emitted(mgr, "strike_resolved")


func test_pay_strike_wages_insufficient_keeps_strike() -> void:
	# Arrange
	economy.earn_gold(500)
	var data := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	mgr.hire(data)
	mgr.process_daily_wages(1)  # grev; bakiye 0

	# Act: hâlâ para yok
	var ok := mgr.pay_strike_wages()

	# Assert
	assert_false(ok)
	assert_true(mgr.any_on_strike, "Grev devam ediyor")


# ── serialize / deserialize ───────────────────────────────────────────────────

func test_serialize_returns_empty_when_no_employees() -> void:
	var data: Dictionary = mgr.serialize()
	assert_eq(data.size(), 0, "Çalışan yok → boş dict")


func test_serialize_deserialize_round_trip() -> void:
	# Arrange
	economy.earn_gold(5000)
	var d1 := _make_data(GameEnums.EmployeeRole.DOUGH_MAKER, 50, 0.25)
	var d2 := _make_data(GameEnums.EmployeeRole.OVEN_MASTER, 80, 0.20)
	mgr.hire(d1)
	mgr.hire(d2)
	var data_map := {
		d1.id: d1,
		d2.id: d2,
	}

	# Act
	var saved: Dictionary = mgr.serialize()
	var mgr2 := EmployeeManager.new()
	mgr2._economy_ref = economy
	mgr2.deserialize(saved, data_map)

	# Assert
	assert_true(mgr2.has_employee(GameEnums.EmployeeRole.DOUGH_MAKER))
	assert_true(mgr2.has_employee(GameEnums.EmployeeRole.OVEN_MASTER))
	assert_almost_eq(mgr2.get_effect(GameEnums.EmployeeRole.DOUGH_MAKER), 0.25, 0.001,
		"Efekt restore edildi")
	mgr2.free()


func test_deserialize_preserves_strike_state() -> void:
	# Arrange: grev durumunda serialize
	economy.earn_gold(500)
	var data := _make_data(GameEnums.EmployeeRole.CASHIER, 60, 0.30)
	mgr.hire(data)
	mgr.process_daily_wages(1)  # grev
	var data_map := { data.id: data }

	# Act
	var saved: Dictionary = mgr.serialize()
	var mgr2 := EmployeeManager.new()
	mgr2._economy_ref = economy
	mgr2.deserialize(saved, data_map)

	# Assert
	assert_true(mgr2.any_on_strike, "Grev durumu restore edildi")
	mgr2.free()
