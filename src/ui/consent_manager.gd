## ConsentManager — GDPR / UMP Rıza Yöneticisi
##
## Google User Messaging Platform (UMP) SDK entegrasyonunu yönetir.
## AB bölgesi kullanıcıları için rıza durumunu kontrol eder;
## AdMobBridge'e rıza durumunu bildirir.
##
## Rıza Durumları:
##   UNKNOWN   — Henüz kontrol edilmedi
##   REQUIRED  — Rıza gerekli, form gösterilmeli
##   NOT_REQUIRED — Rıza gerekmiyor (AB dışı)
##   OBTAINED  — Rıza verildi
##
## Production entegrasyon adımları (S8-05):
##   1. Google UMP GDExtension veya Android plugin ekle
##   2. _check_consent() içindeki stub → gerçek UMP çağrısı ile değiştir
##   3. consent_updated sinyali → AdMobBridge.set_consent_state() bağla
##
## GDD: design/gdd/ad-monetization-system.md §5 (GDPR)
class_name ConsentManager
extends Node

signal consent_updated(state: ConsentState)

enum ConsentState {
	UNKNOWN,
	REQUIRED,
	NOT_REQUIRED,
	OBTAINED,
	DENIED,
}

const CONSENT_KEY: String = "gdpr_consent_state"

var _state: ConsentState = ConsentState.UNKNOWN
var _ad_bridge: AdMobBridge = null


func _ready() -> void:
	_load_persisted_state()
	_check_consent()


# ── Public API ────────────────────────────────────────────────────────────────

func get_state() -> ConsentState:
	return _state


## Reklam gösterimi izin var mı? (rıza alındı veya AB dışı)
func can_show_ads() -> bool:
	return _state == ConsentState.OBTAINED or _state == ConsentState.NOT_REQUIRED


## Rıza formunu göster (AB kullanıcıları).
func request_consent_form() -> void:
	if _state != ConsentState.REQUIRED:
		return
	# Production'da: UMP SDK form gösterimi buraya
	push_warning("ConsentManager: UMP SDK bağlı değil — stub modu")
	_set_state(ConsentState.OBTAINED)   # Stub: otomatik kabul


# ── Internal ──────────────────────────────────────────────────────────────────

func _check_consent() -> void:
	# Production'da: UMP SDK requestConsentInfoUpdate() çağrısı
	# Bölge tespiti → REQUIRED veya NOT_REQUIRED
	#
	# Stub davranışı: AB bölgesi simüle edilmiyorsa NOT_REQUIRED
	if _state == ConsentState.UNKNOWN:
		_set_state(ConsentState.NOT_REQUIRED)


func _set_state(new_state: ConsentState) -> void:
	_state = new_state
	_persist_state()
	consent_updated.emit(_state)
	_notify_ad_bridge()


func _notify_ad_bridge() -> void:
	var bridge := _get_ad_bridge()
	if not bridge:
		return
	# AdMobBridge henüz set_consent_state API'si yok — S8-05 tamamlandığında eklenecek
	# bridge.set_consent_state(can_show_ads())


func _persist_state() -> void:
	# SaveLoadManager ile entegrasyon — basit prefs kaydı
	# Production'da ConfigFile veya SaveLoadManager üzerinden
	pass


func _load_persisted_state() -> void:
	# Önceki oturumdan rıza durumu yüklenir
	pass


func _get_ad_bridge() -> AdMobBridge:
	if _ad_bridge:
		return _ad_bridge
	return get_node_or_null("/root/AdMobBridge") as AdMobBridge
