## AdMobStub — AdMob SDK Stub (Test & Geliştirme Ortamı)
##
## Gerçek AdMob SDK olmadan AdMonetizationSystem'in test edilmesini sağlar.
## Production'da bu dosya gerçek AdMob GDExtension ile değiştirilir.
## Aynı sinyal arayüzünü sağlar; reklam gösterimi simüle edilir.
##
## Gerçek SDK sinyalleri (referans):
##   ad_loaded(ad_unit_id)
##   ad_failed_to_load(ad_unit_id, error_code, error_message)
##   user_earned_reward(ad_unit_id, reward_type, reward_amount)
##   ad_closed(ad_unit_id)
class_name AdMobStub
extends Node

signal ad_loaded(ad_unit_id: String)
signal ad_failed_to_load(ad_unit_id: String, error_code: int, error_message: String)
signal user_earned_reward(ad_unit_id: String, reward_type: String, reward_amount: int)
signal ad_closed(ad_unit_id: String)

## Test reklam ID'leri (Google resmi test ID'leri — üretim geliri YOK).
const TEST_AD_UNIT_ANDROID: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_AD_UNIT_IOS: String     = "ca-app-pub-3940256099942544/1712485313"

## Stub ayarları: simüle edilen davranış.
var simulate_success: bool = true    # false → ad_failed_to_load tetikler
var simulate_reward: bool = true     # false → yalnızca ad_closed tetikler
var load_delay_sec: float = 0.5      # Yükleme gecikmesi simülasyonu

var _loaded_ads: Dictionary = {}     # ad_unit_id → bool


## Rewarded reklam yüklemeyi başlat.
func load_rewarded_ad(ad_unit_id: String) -> void:
	_loaded_ads[ad_unit_id] = false
	if not get_tree():
		_finish_load(ad_unit_id)
		return
	get_tree().create_timer(load_delay_sec).timeout.connect(
		func() -> void: _finish_load(ad_unit_id), CONNECT_ONE_SHOT
	)


## Rewarded reklamı göster.
func show_rewarded_ad(ad_unit_id: String) -> void:
	if not _loaded_ads.get(ad_unit_id, false):
		push_warning("AdMobStub: Reklam yüklenmedi ('%s')" % ad_unit_id)
		return
	_loaded_ads[ad_unit_id] = false  # Gösterim sonrası yeniden yüklenmeli

	if simulate_reward:
		user_earned_reward.emit(ad_unit_id, "gold", 1)
	ad_closed.emit(ad_unit_id)


func _finish_load(ad_unit_id: String) -> void:
	if simulate_success:
		_loaded_ads[ad_unit_id] = true
		ad_loaded.emit(ad_unit_id)
	else:
		ad_failed_to_load.emit(ad_unit_id, -1, "Simulated failure")
