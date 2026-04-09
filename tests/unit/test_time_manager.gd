## GUT Test Suite — TimeManager
## GDD #1 Acceptance Criteria: AC-1 – AC-11
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_time_manager.gd
extends GutTest

var tm: TimeManager

func before_each() -> void:
	tm = TimeManager.new()


func after_each() -> void:
	tm.free()


# AC-1: get_elapsed_seconds(now) → 0.0
func test_same_timestamp_returns_zero() -> void:
	var now: int = Time.get_unix_time_from_system()
	var result: float = tm.get_elapsed_seconds(now)
	assert_almost_eq(result, 0.0, 1.0, "Aynı timestamp → 0 (±1 sn tolerans)")


# AC-2: get_elapsed_seconds(now - 3600) → ~3600.0
func test_one_hour_ago_returns_3600() -> void:
	var now: int = Time.get_unix_time_from_system()
	var result: float = tm.get_elapsed_seconds(now - 3600)
	assert_almost_eq(result, 3600.0, 1.0, "1 saat önce → ~3600 sn")


# AC-3: Gelecek timestamp (negatif delta) → 0.0
func test_future_timestamp_returns_zero() -> void:
	var now: int = Time.get_unix_time_from_system()
	var result: float = tm.get_elapsed_seconds(now + 3600)
	assert_eq(result, 0.0, "Gelecek timestamp → 0.0 (negatif kırpma)")


# AC-4: 200000 sn önce → ANTI_CHEAT_CAP (86400)
func test_very_old_timestamp_capped_at_anti_cheat() -> void:
	var now: int = Time.get_unix_time_from_system()
	var result: float = tm.get_elapsed_seconds(now - 200000)
	assert_eq(result, float(TimeManager.ANTI_CHEAT_CAP_SECONDS),
		"Aşırı eski timestamp → ANTI_CHEAT_CAP")


# AC-6: Saat geri sarılma simülasyonu → 0.0
func test_clock_rolled_back_returns_zero() -> void:
	var now: int = Time.get_unix_time_from_system()
	var future_ts: int = now + 36000  # sanki saat 10 saat ileri gitti, timestamp "gelecekte"
	var result: float = tm.get_elapsed_seconds(future_ts)
	assert_eq(result, 0.0, "Saat geri sarılma → 0.0")


# AC-7: Saat 5 gün ileri sarılma → ANTI_CHEAT_CAP
func test_clock_5_days_forward_capped() -> void:
	var now: int = Time.get_unix_time_from_system()
	var five_days_ago: int = now - (5 * 86400)
	var result: float = tm.get_elapsed_seconds(five_days_ago)
	assert_eq(result, float(TimeManager.ANTI_CHEAT_CAP_SECONDS),
		"5 gün → ANTI_CHEAT_CAP (86400)")


# AC-9: last_seen_unix = 0 (bozuk kayıt / ilk kurulum) → 0.0, çökme yok
func test_zero_timestamp_returns_zero_no_crash() -> void:
	var result: float = tm.get_elapsed_seconds(0)
	assert_eq(result, 0.0, "last_seen_unix=0 → 0.0, çökme yok")


# AC-9 (negatif): Negatif timestamp → 0.0
func test_negative_timestamp_returns_zero() -> void:
	var result: float = tm.get_elapsed_seconds(-1)
	assert_eq(result, 0.0, "Negatif timestamp → 0.0")


# get_elapsed_days: 23 saat → 0 gün
func test_elapsed_days_less_than_one_day() -> void:
	var now: int = Time.get_unix_time_from_system()
	var result: int = tm.get_elapsed_days(now - (23 * 3600))
	assert_eq(result, 0, "23 saat → 0 gün")


# get_elapsed_days: 25 saat → 1 gün
func test_elapsed_days_one_day() -> void:
	var now: int = Time.get_unix_time_from_system()
	var result: int = tm.get_elapsed_days(now - (25 * 3600))
	assert_eq(result, 1, "25 saat → 1 gün")


# get_elapsed_days: 0 timestamp → 0 gün
func test_elapsed_days_zero_timestamp() -> void:
	var result: int = tm.get_elapsed_days(0)
	assert_eq(result, 0, "last_seen_unix=0 → 0 gün")


# ANTI_CHEAT_CAP_SECONDS sabiti doğru değerde
func test_anti_cheat_cap_constant_value() -> void:
	assert_eq(TimeManager.ANTI_CHEAT_CAP_SECONDS, 86400,
		"ANTI_CHEAT_CAP_SECONDS = 86400 (24 saat)")
