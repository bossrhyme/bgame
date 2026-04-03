# ADR-0003 — Idle Loop: Timer Bazlı Güncelleme (_process() Yok)

**Status:** Accepted
**Date:** 2026-04-03
**Deciders:** Proje sahibi

---

## Context

Ekmek Ustası bir idle oyundur. Üretim hesaplamaları sürekli çalışır:
fırın pişirme döngüsü, müşteri sabır azalması, çalışan verimliliği, offline süre.
Bu hesaplamaların hangi döngüde yapılacağı hem performansı hem pil tüketimini doğrudan etkiler.

## Problem

Idle oyun sistemlerini (pişirme, müşteri bekleme, offline delta) nasıl güncellemeliyiz?
- `_process(delta)` her frame çalışır → mobilde gereksiz CPU + pil tüketimi
- Ağır hesaplama `_process()` içinde → forbidden pattern (technical-preferences.md)

## Kısıtlar

- Hedef: 60 FPS, 16.6ms frame bütçesi
- Mobil mid-range cihaz (512MB RAM, orta CPU)
- `_process()` içinde ağır hesaplama yasak (technical-preferences.md)
- Offline üretim: uygulama kapalıyken geçen süre hesaplanmalı

## Karar

**Timer node + zaman damgası delta hesabı** kullanılacak.

### Uygulama Paterni

```gdscript
# Her sistem kendi Timer'ına sahip
# Örnek: OvenSystem
var bake_timer: Timer

func _ready() -> void:
    bake_timer = Timer.new()
    bake_timer.wait_time = bake_time_seconds
    bake_timer.timeout.connect(_on_bake_complete)
    add_child(bake_timer)
    bake_timer.start()

func _on_bake_complete() -> void:
    _produce_bread()
    # Bir sonraki döngüyü otomatik başlat
```

### Offline Üretim

```gdscript
# Uygulama açılışında tek seferlik delta hesabı
func calculate_offline_production(last_save_timestamp: int) -> int:
    var elapsed_seconds := Time.get_unix_time_from_system() - last_save_timestamp
    var capped_seconds := min(elapsed_seconds, OFFLINE_CAP_SECONDS)
    return floor(capped_seconds / bake_time_seconds) * oven_capacity
```

## Değerlendirilen Alternatifler

| Yaklaşım | Artı | Eksi | Eleme Gerekçesi |
|----------|------|------|-----------------|
| **Timer node** ✓ | Düşük CPU, Godot native, okunabilir | Çok sayıda timer yönetimi | — Seçildi |
| `_process(delta)` sürekli | Hassas zamanlama | Her frame CPU, pil israfı, forbidden pattern | Forbidden pattern ihlali |
| Coroutine (`await`) | Okunabilir akış | Debug zor, iptal yönetimi karmaşık | Çok sayıda sistemi yönetmek zor |
| Thread bazlı | Paralel hesaplama | Godot'da thread-safe olmayan API'ler, karmaşıklık | Overkill + risk |

## Sonuçlar

**Olumlu:**
- Frame bütçesi korunur — idle hesaplamalar sadece timer tetiklendiğinde çalışır
- Pil tüketimi düşer (sürekli frame work yok)
- Offline delta hesabı açılışta tek seferlik → basit ve güvenilir
- Her sistem bağımsız timer → modüler, test edilebilir

**Olumsuz / Riskler:**
- Çok sayıda aktif timer → dikkatli bellek yönetimi gerekli
- Timer duyarlılığı ms düzeyinde değil → sub-second hassasiyet gerektiren sistemler için uygun değil (bu oyunda yok)
- Sahne ağacından ayrılan (freed) node'un timer'ı → dikkatli temizlik gerekli

## Tasarım Kuralları (Bu Karardan Türeyen)

1. Her gameplay sistemi kendi Timer'ını yönetir — merkezi tick sistemi yok
2. Offline üretim: açılışta `Time.get_unix_time_from_system()` ile delta hesabı
3. UI güncellemeleri: Timer'a bağlı değil, sinyal (signal) ile tetiklenir
4. `_process()` sadece animasyon ve input — hiçbir gameplay hesabı

## Doğrulama Kriterleri

- [ ] Profiler'da `_process()` içinde gameplay hesabı gözlemlenmiyor
- [ ] 10 aktif timer ile 60 FPS hedefi korunuyor
- [ ] 8 saat offline sonrası açılışta doğru üretim miktarı hesaplanıyor
- [ ] Timer leak yok — freed node'larda timer temizleniyor

## İlgili Kararlar

- ADR-0001: Engine seçimi (Godot Timer node bu kararın altyapısı)
- ADR-0002: Rewarded Ad — offline üretim 2x teklifi bu hesaba bağımlı
