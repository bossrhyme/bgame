## ResourceBar — HUD Kaynak Çubuğu
##
## Sol üst: Altın bakiyesi. Sağ üst: Rozet bakiyesi.
## Economy sinyallerine bağlanır; _process() kullanmaz (ADR-0003).
## Animasyonlu sayaç: Tween ile 0.3 sn ease-out geçiş.
##
## GDD: design/gdd/ui-hud-system.md — Kaynak Çubuğu
class_name ResourceBar
extends Control

## Altın Label node referansı. Inspector'dan veya test için atanır.
@export var gold_label: Label
## Rozet Label node referansı.
@export var rozet_label: Label

## Animasyon süresi (GDD §4: 0.3 sn).
const COUNTER_TWEEN_DURATION: float = 0.3

## Görüntülenen anlık değerler (Tween arası çakışmayı önlemek için).
var _displayed_gold: int = 0
var _displayed_rozet: int = 0

## Dependency injection. null ise autoload'dan alınır.
var _economy_ref: EconomySystem = null


func _ready() -> void:
	var economy := _get_economy()
	if economy:
		economy.gold_changed.connect(_on_gold_changed)
		economy.rozet_changed.connect(_on_rozet_changed)
		_displayed_gold = economy.gold_balance
		_displayed_rozet = economy.rozet_balance
		_update_gold_label(_displayed_gold)
		_update_rozet_label(_displayed_rozet)
	else:
		push_warning("ResourceBar: Economy sistemi bulunamadı")


# ── Internal ──────────────────────────────────────────────────────────────────

func _on_gold_changed(new_balance: int) -> void:
	_animate_counter(new_balance, true)


func _on_rozet_changed(new_balance: int) -> void:
	_animate_counter(new_balance, false)


## target: hedef değer. is_gold: true = altın, false = Rozet.
func _animate_counter(target: int, is_gold: bool) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	if is_gold:
		tween.tween_method(
			func(v: int) -> void: _update_gold_label(v),
			_displayed_gold, target, COUNTER_TWEEN_DURATION
		)
		tween.finished.connect(func() -> void: _displayed_gold = target)
	else:
		tween.tween_method(
			func(v: int) -> void: _update_rozet_label(v),
			_displayed_rozet, target, COUNTER_TWEEN_DURATION
		)
		tween.finished.connect(func() -> void: _displayed_rozet = target)


func _update_gold_label(value: int) -> void:
	if gold_label:
		gold_label.text = _format_currency(value)


func _update_rozet_label(value: int) -> void:
	if rozet_label:
		rozet_label.text = _format_currency(value)


## Sayıyı okunabilir formata çevirir (1000 → "1.000").
static func _format_currency(value: int) -> String:
	var s := str(value)
	var result := ""
	var count := 0
	for i: int in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = s[i] + result
		count += 1
	return result


func _get_economy() -> EconomySystem:
	if _economy_ref:
		return _economy_ref
	return get_node_or_null("/root/Economy") as EconomySystem
