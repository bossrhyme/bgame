## GUT Test Suite — EconomySystem
## GDD #4 Acceptance Criteria: AC-1 – AC-12
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_economy_system.gd
extends GutTest

var economy: EconomySystem

## Sinyal takibi
var _gold_signals: Array[int] = []
var _rozet_signals: Array[int] = []


func before_each() -> void:
	economy = EconomySystem.new()
	add_child(economy)
	_gold_signals.clear()
	_rozet_signals.clear()
	economy.gold_changed.connect(func(v): _gold_signals.append(v))
	economy.rozet_changed.connect(func(v): _rozet_signals.append(v))


func after_each() -> void:
	economy.free()


# ── Yardımcı ──────────────────────────────────────────────────────────────────

func _init_ready(gold: int = 0, rozet: int = 0) -> void:
	economy.initialize(gold, rozet)
	_gold_signals.clear()
	_rozet_signals.clear()


# ── AC-1: initialize ──────────────────────────────────────────────────────────

func test_initialize_sets_balances_and_emits_signals() -> void:
	economy.initialize(200, 50)
	assert_eq(economy.gold_balance, 200, "gold = 200")
	assert_eq(economy.rozet_balance, 50, "rozet = 50")
	assert_eq(_gold_signals.size(), 1, "gold_changed 1 kez yayıldı")
	assert_eq(_gold_signals[0], 200, "gold_changed değeri 200")
	assert_eq(_rozet_signals[0], 50, "rozet_changed değeri 50")


# AC-8: initialize ikinci kez çağrılırsa yoksayılır
func test_initialize_second_call_ignored() -> void:
	economy.initialize(200, 50)
	_gold_signals.clear()
	_rozet_signals.clear()
	economy.initialize(999, 999)
	assert_eq(economy.gold_balance, 200, "Bakiye değişmedi")
	assert_eq(_gold_signals.size(), 0, "Sinyal yayılmadı")


# EC-10: Negatif başlangıç değerleri → 0'a sabitlenir
func test_initialize_negative_values_clamped_to_zero() -> void:
	economy.initialize(-500, -100)
	assert_eq(economy.gold_balance, 0, "Negatif gold → 0")
	assert_eq(economy.rozet_balance, 0, "Negatif rozet → 0")


# ── AC-2: earn_gold ───────────────────────────────────────────────────────────

func test_earn_gold_increases_balance_and_emits() -> void:
	_init_ready(100)
	economy.earn_gold(50)
	assert_eq(economy.gold_balance, 150, "100 + 50 = 150")
	assert_eq(_gold_signals.size(), 1, "Sinyal yayıldı")
	assert_eq(_gold_signals[0], 150, "Sinyal değeri 150")


# EC-1: earn_gold(0) → no-op
func test_earn_gold_zero_is_noop() -> void:
	_init_ready(100)
	economy.earn_gold(0)
	assert_eq(economy.gold_balance, 100, "Bakiye değişmedi")
	assert_eq(_gold_signals.size(), 0, "Sinyal yayılmadı")


# EC-2: earn_gold(-50) → no-op
func test_earn_gold_negative_is_noop() -> void:
	_init_ready(100)
	economy.earn_gold(-50)
	assert_eq(economy.gold_balance, 100, "Bakiye değişmedi")
	assert_eq(_gold_signals.size(), 0, "Sinyal yayılmadı")


# AC-6: LOADING'de earn_gold → no-op
func test_earn_gold_in_loading_state_is_noop() -> void:
	economy.earn_gold(500)
	assert_eq(economy.gold_balance, 0, "LOADING'de bakiye değişmez")
	assert_eq(_gold_signals.size(), 0, "Sinyal yayılmadı")


# ── AC-3 & AC-4: spend_gold ───────────────────────────────────────────────────

func test_spend_gold_success() -> void:
	_init_ready(200)
	var result: bool = economy.spend_gold(50)
	assert_true(result, "Yeterli bakiye → true")
	assert_eq(economy.gold_balance, 150, "200 - 50 = 150")
	assert_eq(_gold_signals[0], 150, "Sinyal değeri 150")


func test_spend_gold_insufficient_balance_returns_false() -> void:
	_init_ready(30)
	var result: bool = economy.spend_gold(50)
	assert_false(result, "Yetersiz bakiye → false")
	assert_eq(economy.gold_balance, 30, "Bakiye değişmedi")
	assert_eq(_gold_signals.size(), 0, "Sinyal yayılmadı")


# AC-5: spend_gold(0) → false
func test_spend_gold_zero_returns_false() -> void:
	_init_ready(100)
	var result: bool = economy.spend_gold(0)
	assert_false(result, "spend_gold(0) → false")
	assert_eq(_gold_signals.size(), 0, "Sinyal yayılmadı")


# EC-6: spend_gold(-100) → false
func test_spend_gold_negative_returns_false() -> void:
	_init_ready(100)
	var result: bool = economy.spend_gold(-100)
	assert_false(result, "Negatif amount → false")
	assert_eq(economy.gold_balance, 100, "Bakiye değişmedi")


# AC-7: LOADING'de spend_gold → false
func test_spend_gold_in_loading_returns_false() -> void:
	var result: bool = economy.spend_gold(100)
	assert_false(result, "LOADING'de spend → false")


# ── AC-9: Negatif bakiye asla oluşmamalı ─────────────────────────────────────

func test_balance_never_negative_fuzz() -> void:
	_init_ready(1000)
	for i in range(1000):
		economy.spend_gold(randi() % 200)
	assert_true(economy.gold_balance >= 0, "Bakiye asla negatif olmaz")


# ── AC-10: Sıralı işlemlerde sinyal doğruluğu ────────────────────────────────

func test_sequential_operations_emit_correct_signals() -> void:
	_init_ready(0)
	economy.earn_gold(100)
	economy.earn_gold(50)
	economy.spend_gold(30)
	economy.earn_gold(200)
	economy.spend_gold(100)
	assert_eq(_gold_signals.size(), 5, "5 sinyal yayıldı")
	assert_eq(_gold_signals[0], 100)
	assert_eq(_gold_signals[1], 150)
	assert_eq(_gold_signals[2], 120)
	assert_eq(_gold_signals[3], 320)
	assert_eq(_gold_signals[4], 220)


# ── AC-12: Overflow koruması ──────────────────────────────────────────────────

func test_earn_gold_overflow_clamped_to_cap() -> void:
	_init_ready(EconomySystem.GOLD_BALANCE_CAP - 1)
	economy.earn_gold(1000)
	assert_eq(economy.gold_balance, EconomySystem.GOLD_BALANCE_CAP, "Cap aşılamaz")


# ── Rozet API testleri ────────────────────────────────────────────────────────

func test_earn_rozet_increases_balance() -> void:
	_init_ready(0, 100)
	economy.earn_rozet(200)
	assert_eq(economy.rozet_balance, 300, "100 + 200 = 300")


func test_spend_rozet_success() -> void:
	_init_ready(0, 500)
	var result: bool = economy.spend_rozet(300)
	assert_true(result)
	assert_eq(economy.rozet_balance, 200)


func test_spend_rozet_insufficient_returns_false() -> void:
	_init_ready(0, 100)
	var result: bool = economy.spend_rozet(200)
	assert_false(result)
	assert_eq(economy.rozet_balance, 100, "Bakiye değişmedi")


func test_earn_rozet_zero_is_noop() -> void:
	_init_ready(0, 50)
	economy.earn_rozet(0)
	assert_eq(_rozet_signals.size(), 0, "Sinyal yayılmadı")
