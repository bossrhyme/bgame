## EmployeeManager — Service
##
## Çalışan işe alma, yükseltme, maaş kesimi ve grev yönetimini üstlenir.
## Dört çalışan tipi (DOUGH_MAKER, OVEN_MASTER, CASHIER, DELIVERY); her tipten
## yalnızca bir çalışan aktif olabilir.
##
## Mimari kuralları (GDD Employee System #13):
##   - _process() yasaktır (ADR-0003); ücret kesimi process_daily_wages() ile yapılır
##   - Offline günler SaveLoadManager'ın load aşamasında process_daily_wages() çağrısıyla uygulanır
##   - Efektler pull-based: get_effect(role) → downstream sistemler çeker
##   - Dependency injection: _economy_ref — test izolasyonu için
##
## GDD Formulas:
##   hire_cost(data, level) = data.daily_wage × HIRE_COST_MULTIPLIER × level
##   total_effect(role)     = effect_per_level × current_level  (grev yoksa)
class_name EmployeeManager
extends Node

## Çalışan işe alındığında.
signal employee_hired(role: GameEnums.EmployeeRole, level: int)
## Çalışan işten çıkarıldığında.
signal employee_fired(role: GameEnums.EmployeeRole)
## Çalışan yükseltildiğinde.
signal employee_upgraded(role: GameEnums.EmployeeRole, new_level: int)
## Yetersiz altın nedeniyle tüm çalışanlar greve çıktığında.
signal strike_started
## pay_strike_wages() ile grev çözüldüğünde.
signal strike_resolved
## Günlük ücret başarıyla kesildiğinde.
signal daily_wages_paid(total_gold: int)

const HIRE_COST_MULTIPLIER: int = 10


## Çalışanın runtime durumu. Yalnızca EmployeeManager içinde oluşturulur.
class EmployeeEntry:
	extends RefCounted
	var data: EmployeeData
	var level: int = 1
	var on_strike: bool = false


## Aktif çalışanlar: GameEnums.EmployeeRole → EmployeeEntry.
var _employees: Dictionary = {}

## Dependency injection. null ise autoload'dan alınır.
var _economy_ref: EconomySystem = null

## Herhangi bir çalışan grevdeyse true.
var any_on_strike: bool:
	get:
		for entry: EmployeeEntry in _employees.values():
			if entry.on_strike:
				return true
		return false


# ── Public API ────────────────────────────────────────────────────────────────

## Çalışanı işe alır. Aynı rolde başka çalışan varsa veya altın yetmezse false.
## hire_cost = daily_wage × HIRE_COST_MULTIPLIER × 1 (Sev.1 girişi)
func hire(data: EmployeeData) -> bool:
	if _employees.has(data.role):
		push_warning("EmployeeManager: %s rolü zaten dolu" % GameEnums.EmployeeRole.keys()[data.role])
		return false
	var cost: int = hire_cost(data.daily_wage, 1)
	var economy := _get_economy()
	if not economy:
		push_error("EmployeeManager: Economy sistemi bulunamadı")
		return false
	if not economy.spend_gold(cost):
		return false  # yetersiz altın
	var entry := EmployeeEntry.new()
	entry.data = data
	entry.level = 1
	entry.on_strike = false
	_employees[data.role] = entry
	employee_hired.emit(data.role, 1)
	return true


## Çalışanı işten çıkarır. Efekt anında durur; ücret iadesi yapılmaz.
func fire(role: GameEnums.EmployeeRole) -> bool:
	if not _employees.has(role):
		return false
	_employees.erase(role)
	employee_fired.emit(role)
	return true


## Mevcut çalışanı bir seviye yükseltir.
## Maliyet: daily_wage × HIRE_COST_MULTIPLIER × (level + 1)
## Zaten max seviyede veya altın yetmezse false.
func upgrade(role: GameEnums.EmployeeRole) -> bool:
	var entry: EmployeeEntry = _employees.get(role)
	if not entry:
		return false
	if entry.level >= entry.data.max_level:
		return false
	var next_level: int = entry.level + 1
	var cost: int = hire_cost(entry.data.daily_wage, next_level)
	var economy := _get_economy()
	if not economy or not economy.spend_gold(cost):
		return false
	entry.level = next_level
	employee_upgraded.emit(role, next_level)
	return true


## Geçen gün sayısı kadar günlük ücret keser.
## Ödeme başarısızsa tüm çalışanlar greve çıkar.
## SaveLoadManager load aşamasında ve oyun içi günlük zamanlayıcıdan çağrılır.
func process_daily_wages(elapsed_days: int) -> void:
	if elapsed_days <= 0 or _employees.is_empty():
		return
	var economy := _get_economy()
	if not economy:
		push_error("EmployeeManager: Economy sistemi bulunamadı — ücret kesilmedi")
		return
	var total: int = get_daily_cost() * elapsed_days
	if economy.spend_gold(total):
		daily_wages_paid.emit(total)
	else:
		for entry: EmployeeEntry in _employees.values():
			entry.on_strike = true
		strike_started.emit()


## Grevdeki tüm çalışanların birikmiş maaşını öder.
## Yeterli altın yoksa false döner; çalışanlar grevde kalır.
## Birikmiş gün takibi yapılmaz — sadece tek günlük toplam ücret alınır.
func pay_strike_wages() -> bool:
	if not any_on_strike:
		return true
	var economy := _get_economy()
	if not economy:
		push_error("EmployeeManager: Economy sistemi bulunamadı")
		return false
	var total: int = get_daily_cost()
	if not economy.spend_gold(total):
		return false
	for entry: EmployeeEntry in _employees.values():
		entry.on_strike = false
	strike_resolved.emit()
	return true


## Belirtilen roldeki aktif, grevde olmayan çalışanın kümülatif efektini döner.
## Grevdeyse veya aktif çalışan yoksa 0.0.
## total_effect = effect_per_level × current_level
func get_effect(role: GameEnums.EmployeeRole) -> float:
	var entry: EmployeeEntry = _employees.get(role)
	if not entry or entry.on_strike:
		return 0.0
	if entry.data.effect_per_level.is_empty():
		return 0.0
	return entry.data.effect_per_level[0] * float(entry.level)


## Tüm aktif çalışanların toplam günlük ücretini döner.
func get_daily_cost() -> int:
	var total: int = 0
	for entry: EmployeeEntry in _employees.values():
		total += entry.data.daily_wage
	return total


## Belirtilen rolde aktif çalışan var mı?
func has_employee(role: GameEnums.EmployeeRole) -> bool:
	return _employees.has(role)


## Kayıt formatında veriyi döner.
func serialize() -> Dictionary:
	var result: Dictionary = {}
	for role: GameEnums.EmployeeRole in _employees:
		var entry: EmployeeEntry = _employees[role]
		result[role] = {
			"employee_id": entry.data.id,
			"level": entry.level,
			"on_strike": entry.on_strike,
		}
	return result


## SaveLoadManager tarafından çağrılır.
## Eksik ya da bilinmeyen çalışan ID'leri yoksayılır; oyun çökmez.
## EmployeeData nesneleri registry üzerinden eşleştirilmez —
## caller'ın data_map (id → EmployeeData) sağlaması gerekir.
func deserialize(data: Dictionary, data_map: Dictionary) -> void:
	_employees.clear()
	for role_key in data:
		var entry_data: Dictionary = data[role_key]
		var emp_id: StringName = entry_data.get("employee_id", &"")
		var emp_data: EmployeeData = data_map.get(emp_id)
		if emp_data == null:
			push_warning("EmployeeManager: '%s' ID'li çalışan bulunamadı — atlandı" % emp_id)
			continue
		var entry := EmployeeEntry.new()
		entry.data = emp_data
		entry.level = clampi(entry_data.get("level", 1), 1, emp_data.max_level)
		entry.on_strike = entry_data.get("on_strike", false)
		_employees[emp_data.role] = entry


# ── Formulas ──────────────────────────────────────────────────────────────────

## İşe alma / yükseltme maliyeti: daily_wage × HIRE_COST_MULTIPLIER × level
static func hire_cost(daily_wage: int, level: int) -> int:
	return daily_wage * HIRE_COST_MULTIPLIER * level


# ── Internal ──────────────────────────────────────────────────────────────────

func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem
