## AdMobBridge — AdMob SDK → AdMonetizationSystem Köprüsü
##
## AdMob SDK (veya stub) sinyallerini AdMonetizationSystem API çağrılarına dönüştürür.
## Placement ID ↔ ad_unit_id eşleşmesini yönetir.
## Production'da AdMobStub yerine gerçek GDExtension node kullanılır.
##
## Gerçek entegrasyon adımları (S7-01):
##   1. addons/admob_stub/ → gerçek AdMob GDExtension ile değiştir
##   2. AD_UNIT_IDS içindeki TEST ID'leri → gerçek app ID'lerle değiştir
##      (environment variable veya ayrı config; ASLA commit etme)
##   3. Bu dosya değişmez — SDK değişimi şeffaftır
##
## GDD: design/gdd/ad-monetization-system.md
class_name AdMobBridge
extends Node

## Placement ID → ad_unit_id eşleşmesi.
## TEST ID'ler: Google resmi test reklamları — gerçek gelir yok.
const AD_UNIT_IDS: Dictionary = {
	&"offline_boost": "ca-app-pub-3940256099942544/5224354917",
	&"daily_bonus":   "ca-app-pub-3940256099942544/5224354917",
	&"instant_bake":  "ca-app-pub-3940256099942544/5224354917",
	&"vip_extend":    "ca-app-pub-3940256099942544/5224354917",
	&"task_double":   "ca-app-pub-3940256099942544/5224354917",
}

## Tersine eşleşme: ad_unit_id → placement_id
var _unit_to_placement: Dictionary = {}
## Aktif reklam için context (ödül hesabı için).
var _pending_context: Dictionary = {}   # StringName placement_id → context dict

var _admob: AdMobStub = null
var _ad_system: AdMonetizationSystem = null


func _ready() -> void:
	_build_reverse_map()
	_wire_admob()


# ── Public API ────────────────────────────────────────────────────────────────

## Rewarded reklam isteği. context: ödül hesabı için veri (offline_gold vb.)
func request_rewarded_ad(placement_id: StringName, context: Dictionary = {}) -> void:
	if not _ad_system:
		push_error("AdMobBridge: AdMonetizationSystem bağlı değil")
		return
	if not _ad_system.can_show(placement_id):
		return

	var unit_id: String = AD_UNIT_IDS.get(placement_id, "")
	if unit_id.is_empty():
		push_warning("AdMobBridge: Bilinmeyen placement '%s'" % placement_id)
		return

	_pending_context[placement_id] = context

	var admob := _get_admob()
	if admob:
		admob.load_rewarded_ad(unit_id)
	else:
		push_warning("AdMobBridge: AdMob SDK bağlı değil — teklif atlandı")
		_ad_system.notify_ad_failed(placement_id)


# ── AdMob Signal Handlers ─────────────────────────────────────────────────────

func _on_ad_loaded(ad_unit_id: String) -> void:
	var placement_id := _resolve_placement(ad_unit_id)
	if placement_id == &"":
		return
	_ad_system.notify_ad_loaded(placement_id)
	# Yükleme tamamlandı → otomatik göster
	var admob := _get_admob()
	if admob:
		admob.show_rewarded_ad(ad_unit_id)


func _on_ad_failed_to_load(ad_unit_id: String, _error_code: int, _error_message: String) -> void:
	var placement_id := _resolve_placement(ad_unit_id)
	if placement_id != &"":
		_ad_system.notify_ad_failed(placement_id)
		_pending_context.erase(placement_id)


func _on_user_earned_reward(ad_unit_id: String, _reward_type: String, _reward_amount: int) -> void:
	var placement_id := _resolve_placement(ad_unit_id)
	if placement_id == &"":
		return
	var ctx: Dictionary = _pending_context.get(placement_id, {})
	_pending_context.erase(placement_id)
	_ad_system.on_ad_rewarded(placement_id, ctx)


func _on_ad_closed(ad_unit_id: String) -> void:
	var placement_id := _resolve_placement(ad_unit_id)
	if placement_id == &"":
		return
	# Ödül callback gelmediyse → skip
	if _pending_context.has(placement_id):
		_pending_context.erase(placement_id)
		_ad_system.on_ad_closed(placement_id)


# ── Internal ──────────────────────────────────────────────────────────────────

func _build_reverse_map() -> void:
	_unit_to_placement.clear()
	for p: StringName in AD_UNIT_IDS:
		_unit_to_placement[AD_UNIT_IDS[p]] = p


func _resolve_placement(ad_unit_id: String) -> StringName:
	return _unit_to_placement.get(ad_unit_id, &"")


func _wire_admob() -> void:
	var admob := _get_admob()
	if not admob:
		push_warning("AdMobBridge: AdMob SDK bulunamadı — stub veya gerçek eklenti yok")
		return
	admob.ad_loaded.connect(_on_ad_loaded)
	admob.ad_failed_to_load.connect(_on_ad_failed_to_load)
	admob.user_earned_reward.connect(_on_user_earned_reward)
	admob.ad_closed.connect(_on_ad_closed)

	if _ad_system:
		for p: StringName in AD_UNIT_IDS:
			_ad_system.notify_ad_loaded(p)  # Başlangıçta mevcut say (stub için)


func _get_admob() -> AdMobStub:
	if _admob:
		return _admob
	return get_node_or_null("/root/AdMobStub") as AdMobStub
