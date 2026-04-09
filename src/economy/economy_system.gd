## EconomySystem — Autoload
##
## Altın ve Unlu Rozet para birimlerinin güvenilir saklama ve dağıtım merkezi.
##
## Mimari kuralları (GDD #4):
##   - Yalnızca iki değer saklar: gold_balance, rozet_balance
##   - Kazanımın kaynağını ve harcamanın nedenini bilmez
##   - _process() içinde bakiye güncellemesi yasaktır (ADR-0003)
##   - LOADING'de earn/spend çağrıları reddedilir
##   - initialize() yalnızca Save/Load tarafından, oyun ömründe bir kez çağrılır
##   - Negatif bakiye hiçbir koşulda oluşamaz
class_name EconomySystem
extends Node

## Altın bakiyesi değiştiğinde yayılır.
signal gold_changed(new_balance: int)
## Rozet bakiyesi değiştiğinde yayılır.
signal rozet_changed(new_balance: int)

const STARTING_GOLD: int = 0
const STARTING_ROZET: int = 0
## Overflow koruması: bakiye bu değerle klamplanır.
const GOLD_BALANCE_CAP: int = 999_999_999
const ROZET_BALANCE_CAP: int = 999_999_999

enum State { LOADING, READY }

var _state: State = State.LOADING
var _gold: int = 0
var _rozet: int = 0


## Salt okunur bakiye erişimi.
var gold_balance: int:
	get: return _gold

var rozet_balance: int:
	get: return _rozet


## Bakiyeleri atar ve sistemi READY durumuna geçirir.
## Yalnızca Save/Load sistemi çağırır; oyun ömründe bir kez.
## Negatif değerler 0'a sabitlenir (GDD EC-10).
func initialize(gold: int, rozet: int) -> void:
	if _state == State.READY:
		return  # GDD EC-9: ikinci çağrı yoksayılır
	_gold = maxi(gold, 0)
	_rozet = maxi(rozet, 0)
	_state = State.READY
	gold_changed.emit(_gold)
	rozet_changed.emit(_rozet)


# ── Altın API ─────────────────────────────────────────────────────────────────

## Belirtilen miktarda altın ekler.
## amount <= 0 veya LOADING → sessiz no-op, sinyal yayılmaz.
func earn_gold(amount: int) -> void:
	if _state != State.READY or amount <= 0:
		return
	_gold = mini(_gold + amount, GOLD_BALANCE_CAP)
	gold_changed.emit(_gold)


## Belirtilen miktarda altın harcamayı dener.
## Başarılıysa true + gold_changed; yetersizse false + sinyal yok.
## amount <= 0 veya LOADING → false.
func spend_gold(amount: int) -> bool:
	if _state != State.READY or amount <= 0:
		return false
	if _gold < amount:
		return false
	_gold -= amount
	gold_changed.emit(_gold)
	return true


# ── Rozet API ─────────────────────────────────────────────────────────────────

## Belirtilen miktarda Rozet ekler.
## amount <= 0 veya LOADING → sessiz no-op, sinyal yayılmaz.
func earn_rozet(amount: int) -> void:
	if _state != State.READY or amount <= 0:
		return
	_rozet = mini(_rozet + amount, ROZET_BALANCE_CAP)
	rozet_changed.emit(_rozet)


## Belirtilen miktarda Rozet harcamayı dener.
## Başarılıysa true + rozet_changed; yetersizse false + sinyal yok.
## amount <= 0 veya LOADING → false.
func spend_rozet(amount: int) -> bool:
	if _state != State.READY or amount <= 0:
		return false
	if _rozet < amount:
		return false
	_rozet -= amount
	rozet_changed.emit(_rozet)
	return true
