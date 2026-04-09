## TimeManager — Autoload
##
## Tüm zaman-bazlı ilerlemenin merkezi servis katmanı.
## Uygulama kapanış/açılış arasındaki gerçek süreyi hesaplar.
##
## Mimari kuralları (GDD #1 / ADR-0003):
##   - Veri depolamaz; salt hesaplama servisi
##   - Downstream sistemlere doğrudan çağrı yapmaz (pull mimarisi)
##   - _process() içinde zaman birikimi yasaktır
##   - Save/Load sistemi last_seen_unix'i yazar; bu sistem yalnızca okur
##
## Kullanım:
##   var elapsed := TimeManager.get_elapsed_seconds(last_seen_unix)
class_name TimeManager
extends Node

## Manipülasyon engel sabiti: 24 saat (86400 sn).
## Oyunun kendi offline_cap_seconds değerinden bağımsızdır.
## Downstream sistemler kendi cap'lerini ayrıca uygular.
const ANTI_CHEAT_CAP_SECONDS: int = 86400

## Geçen süreyi saniye cinsinden döner.
##
## [param last_seen_unix] Save/Load'dan okunan son kapanma Unix timestamp'i.
##   0 veya negatif → ilk kurulum veya bozuk kayıt → 0.0 döner.
##
## Dönüş değeri: [0.0, ANTI_CHEAT_CAP_SECONDS] aralığında float.
func get_elapsed_seconds(last_seen_unix: int) -> float:
	if last_seen_unix <= 0:
		return 0.0
	var now: int = Time.get_unix_time_from_system()
	var delta: float = float(now - last_seen_unix)
	return clamp(delta, 0.0, float(ANTI_CHEAT_CAP_SECONDS))


## Geçen tam gün sayısını döner (Employee maaş döngüsü için).
##
## [param last_seen_unix] Son kapanma Unix timestamp'i.
##
## Dönüş değeri: Tam gün sayısı (int). 23:59 → 0, 24:00 → 1.
func get_elapsed_days(last_seen_unix: int) -> int:
	return int(get_elapsed_seconds(last_seen_unix) / 86400.0)
