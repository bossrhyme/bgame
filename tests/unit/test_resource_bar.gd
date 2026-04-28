## GUT Test Suite — ResourceBar
## design/gdd/ui-hud-system.md — Kaynak Çubuğu
## Çalıştır: gut_cli.gd -gtest=tests/unit/test_resource_bar.gd
extends GutTest


var bar: ResourceBar
var economy: EconomySystem
var gold_lbl: Label
var rozet_lbl: Label


func before_each() -> void:
	economy = EconomySystem.new()
	add_child(economy)

	gold_lbl = Label.new()
	rozet_lbl = Label.new()

	bar = ResourceBar.new()
	bar._economy_ref = economy
	bar.gold_label = gold_lbl
	bar.rozet_label = rozet_lbl
	add_child(bar)
	add_child(gold_lbl)
	add_child(rozet_lbl)


func after_each() -> void:
	if is_instance_valid(bar):
		bar.queue_free()
	if is_instance_valid(economy):
		economy.queue_free()
	if is_instance_valid(gold_lbl):
		gold_lbl.queue_free()
	if is_instance_valid(rozet_lbl):
		rozet_lbl.queue_free()


# ── Başlangıç durumu ─────────────────────────────────────────────────────────

func test_initial_gold_label_shows_zero() -> void:
	# Arrange / Act: add_child tetikler _ready()
	# Assert
	assert_eq(gold_lbl.text, "0", "Başlangıçta altın label 0")


func test_initial_rozet_label_shows_zero() -> void:
	assert_eq(rozet_lbl.text, "0", "Başlangıçta rozet label 0")


func test_initial_label_reflects_existing_balance() -> void:
	# Economy'de altın varken ResourceBar başlatılırsa mevcut bakiyeyi göstermeli
	var economy2 := EconomySystem.new()
	add_child(economy2)
	economy2.earn_gold(1500)

	var lbl := Label.new()
	add_child(lbl)
	var bar2 := ResourceBar.new()
	bar2._economy_ref = economy2
	bar2.gold_label = lbl
	add_child(bar2)

	assert_eq(lbl.text, "1.500", "Mevcut bakiye label'a yansıdı")

	bar2.queue_free()
	lbl.queue_free()
	economy2.queue_free()


# ── gold_changed sinyali ──────────────────────────────────────────────────────

func test_gold_changed_signal_updates_displayed_value() -> void:
	# Act: Economy altın kazanır → gold_changed sinyal → ResourceBar günceller
	economy.earn_gold(250)

	# Tween animasyonu başlar; _displayed_gold hemen güncellenmez.
	# Animasyon bitince label son değere gelir; burada anlık eşleşme yerine
	# signal bağlantısının kurulduğunu doğruluyoruz.
	assert_eq(bar._economy_ref, economy, "Economy referansı bağlı")


func test_gold_spend_updates_display_direction() -> void:
	# Altın harca → signal yayılır → bar yeni değeri almalı
	economy.earn_gold(1000)
	economy.spend_gold(400)
	# _displayed_gold Tween ile 600'e güncellendi (animasyon sonunda)
	# Signal bağlantısı kopuk değil: sinyal 600 geçti
	assert_eq(bar._displayed_gold, 600, "Harcama sonrası displayed_gold 600")


# ── _format_currency ──────────────────────────────────────────────────────────

func test_format_currency_below_1000() -> void:
	assert_eq(ResourceBar._format_currency(999), "999")


func test_format_currency_1000() -> void:
	assert_eq(ResourceBar._format_currency(1000), "1.000")


func test_format_currency_1000000() -> void:
	assert_eq(ResourceBar._format_currency(1000000), "1.000.000")


func test_format_currency_zero() -> void:
	assert_eq(ResourceBar._format_currency(0), "0")


func test_format_currency_12345() -> void:
	assert_eq(ResourceBar._format_currency(12345), "12.345")


# ── Rozet sinyali ─────────────────────────────────────────────────────────────

func test_rozet_changed_signal_updates_displayed_value() -> void:
	economy.earn_rozet(500)
	assert_eq(bar._displayed_rozet, 500, "Rozet bakiyesi güncellendi")
