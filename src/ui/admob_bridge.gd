## AdMobBridge — AdMob SDK → AdMonetizationSystem Köprüsü
##
## AdMob SDK (veya stub) sinyallerini AdMonetizationSystem API çağrılarına dönüştürür.
## Placement ID ↔ ad_unit_id eşleşmesini yönetir.
## Production'da AdMobStub yerine gerçek GDExtension node kullanılır.
##
## ID yükleme önceliği (S8-03):
##   1. config/admob_ids.cfg (CI tarafından enjekte edilir, gitignore'da)
##   2. TEST_AD_UNIT_IDS sabiti (stub / geliştirme ortamı)
##
## GDD: design/gdd/ad-monetization-system.md
class_name AdMobBridge
extends Node

const CONFIG_PATH: String = "res://config/admob_ids.cfg"

## Fallback test ID'leri — config dosyası yoksa kullanılır.
## TEST ID'ler: Google resmi test reklamları — gerçek gelir yok.
const TEST_AD_UNIT_IDS: Dictionary = {
	&"offline_boost": "ca-app-pub-3940256099942544/5224354917",
	&"daily_bonus":   "ca-app-pub-3940256099942544/5224354917",
	&"instant_bake":  "ca-app-pub-3940256099942544/5224354917",
	&"vip_extend":    "ca-app-pub-3940256099942544/5224354917",
	&"task_double":   "ca-app-pub-3940256099942544/5224354917",
}

## Runtime'da doldurulur: config dosyasından veya TEST_AD_UNIT_IDS'ten.
var _ad_unit_ids: Dictionary = {}

## Tersine eşleşme: ad_unit_id → placement_id
var _unit_to_placement: Dictionary = {}
## Aktif reklam için context (ödül hesabı için).
var _pending_context: Dictionary = {}   # StringName placement_id → context dict

var _admob: AdMobStub = null
var _ad_system: AdMonetizationSystem = null
var _consent_ok: bool = true   # false → reklam gösterimini engelle (GDPR)


func _ready() -> void:
	_load_ad_unit_ids()
	_build_reverse_map()
	_wire_admob()


# ── Public API ────────────────────────────────────────────────────────────────

## ConsentManager'dan rıza durumu güncellenir.
func set_consent_state(allowed: bool) -> void:
	_consent_ok = allowed


## Rewarded reklam isteği. context: ödül hesabı için veri (offline_gold vb.)
func request_rewarded_ad(placement_id: StringName, context: Dictionary = {}) -> void:
	var ad_sys := _get_ad_system()
	if not ad_sys:
		push_error("AdMobBridge: AdMonetizationSystem bağlı değil")
		return
	if not _consent_ok:
		push_warning("AdMobBridge: GDPR rızası yok — reklam engellendi")
		return
	if not ad_sys.can_show(placement_id):
		return

	var unit_id: String = _ad_unit_ids.get(placement_id, "")
	if unit_id.is_empty():
		push_warning("AdMobBridge: Bilinmeyen placement '%s'" % placement_id)
		return

	_pending_context[placement_id] = context

	var admob := _get_admob()
	if admob:
		admob.load_rewarded_ad(unit_id)
	else:
		push_warning("AdMobBridge: AdMob SDK bağlı değil — teklif atlandı")
		ad_sys.notify_ad_failed(placement_id)


# ── AdMob Signal Handlers ─────────────────────────────────────────────────────

func _on_ad_loaded(ad_unit_id: String) -> void:
	var placement_id := _resolve_placement(ad_unit_id)
	if placement_id == &"":
		return
	var ad_sys := _get_ad_system()
	if ad_sys:
		ad_sys.notify_ad_loaded(placement_id)
	var admob := _get_admob()
	if admob:
		admob.show_rewarded_ad(ad_unit_id)


func _on_ad_failed_to_load(ad_unit_id: String, _error_code: int, _error_message: String) -> void:
	var placement_id := _resolve_placement(ad_unit_id)
	if placement_id == &"":
		return
	var ad_sys := _get_ad_system()
	if ad_sys:
		ad_sys.notify_ad_failed(placement_id)
	_pending_context.erase(placement_id)


func _on_user_earned_reward(ad_unit_id: String, _reward_type: String, _reward_amount: int) -> void:
	var placement_id := _resolve_placement(ad_unit_id)
	if placement_id == &"":
		return
	var ctx: Dictionary = _pending_context.get(placement_id, {})
	_pending_context.erase(placement_id)
	var ad_sys := _get_ad_system()
	if ad_sys:
		ad_sys.on_ad_rewarded(placement_id, ctx)


func _on_ad_closed(ad_unit_id: String) -> void:
	var placement_id := _resolve_placement(ad_unit_id)
	if placement_id == &"":
		return
	if _pending_context.has(placement_id):
		_pending_context.erase(placement_id)
		var ad_sys := _get_ad_system()
		if ad_sys:
			ad_sys.on_ad_closed(placement_id)


# ── Internal ──────────────────────────────────────────────────────────────────

func _load_ad_unit_ids() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		_ad_unit_ids.clear()
		for key: String in TEST_AD_UNIT_IDS:
			var val: String = cfg.get_value("placements", key, "")
			if val.is_empty():
				push_warning("AdMobBridge: Config'de '%s' eksik — test ID kullanılıyor" % key)
				_ad_unit_ids[key] = TEST_AD_UNIT_IDS[key]
			else:
				_ad_unit_ids[key] = val
		print("AdMobBridge: Gerçek AdMob ID'leri yüklendi (%s)" % CONFIG_PATH)
	else:
		_ad_unit_ids = TEST_AD_UNIT_IDS.duplicate()
		print("AdMobBridge: Config bulunamadı — test ID'leri kullanılıyor")


func _build_reverse_map() -> void:
	_unit_to_placement.clear()
	for p: StringName in _ad_unit_ids:
		_unit_to_placement[_ad_unit_ids[p]] = p


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

	var ad_sys := _get_ad_system()
	if ad_sys:
		for p: StringName in _ad_unit_ids:
			ad_sys.notify_ad_loaded(p)  # Başlangıçta mevcut say (stub için)


func _get_admob() -> AdMobStub:
	if _admob:
		return _admob
	return get_node_or_null("/root/AdMobStub") as AdMobStub


func _get_ad_system() -> AdMonetizationSystem:
	if _ad_system:
		return _ad_system
	return get_node_or_null("/root/AdMonetizationSystem") as AdMonetizationSystem
