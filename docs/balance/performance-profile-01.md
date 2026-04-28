# Performans Profili 01 — Android Cihaz Profili

**Sprint:** S7-02 / S8-02  
**Tarih:** ⏳ Fiziksel cihaz mevcut olduğunda güncellenecek  
**Hedef Cihaz:** Snapdragon 665 veya eşdeğeri (mid-range Android)  
**Build:** Godot 4.6, arm64, Mobile Renderer, FPS cap 30

> **Durum:** Bu belge şablon olarak oluşturulmuştur. Gerçek ölçüm verileri  
> fiziksel cihaz test oturumu tamamlandıktan sonra doldurulacaktır.

---

## Test Ortamı

| Parametre | Hedef | Gerçek |
|-----------|-------|--------|
| Cihaz modeli | Snapdragon 665 veya eşdeğeri | ⏳ |
| Android sürümü | 10+ | ⏳ |
| Godot sürümü | 4.6 | ✅ |
| Renderer | Mobile | ✅ |
| FPS cap | 30 | ✅ |
| Build türü | Debug (PerformanceMonitor etkin) | ⏳ |

---

## Test Senaryoları

### S1: Boş Menü

Ana menü açık, oyun başlamadı.

| Metrik | Hedef | Sonuç |
|--------|-------|-------|
| FPS (ortalama) | ≥ 30 | ⏳ |
| FPS (minimum) | ≥ 20 | ⏳ |
| Draw calls/frame | < 100 | ⏳ |
| Memory (MB) | < 512 | ⏳ |

### S2: Aktif Fırın (3 Slot)

3 fırın slotu aktif, ekmek pişiyor, müşteri bekliyor.

| Metrik | Hedef | Sonuç |
|--------|-------|-------|
| FPS (ortalama) | ≥ 30 | ⏳ |
| FPS (minimum) | ≥ 20 | ⏳ |
| Draw calls/frame | < 100 | ⏳ |
| Memory (MB) | < 512 | ⏳ |

### S3: Müşteri Kuyruğu (5 Müşteri)

5 müşteri kuyruğu, animasyonlar aktif, UI güncellemeleri.

| Metrik | Hedef | Sonuç |
|--------|-------|-------|
| FPS (ortalama) | ≥ 30 | ⏳ |
| FPS (minimum) | ≥ 20 | ⏳ |
| Draw calls/frame | < 100 | ⏳ |
| Memory (MB) | < 512 | ⏳ |

### S4: Upgrade Menüsü

Upgrade ağacı açık, tüm öğeler görünür.

| Metrik | Hedef | Sonuç |
|--------|-------|-------|
| FPS (ortalama) | ≥ 30 | ⏳ |
| FPS (minimum) | ≥ 20 | ⏳ |
| Draw calls/frame | < 100 | ⏳ |
| Memory (MB) | < 512 | ⏳ |

---

## PerformanceMonitor Çıktısı

```
[BURAYA GERÇEK LOG EKLENECEK]

Örnek format:
[PerformanceMonitor] S2 — FPS avg: 34.2, min: 28.1 | Draw calls: 67 | Memory: 284 MB
```

---

## Darboğaz Analizi

*Gerçek cihaz verisi sonrası doldurulacak.*

| Kategori | Bulgu | Önlem |
|----------|-------|-------|
| Draw calls | ⏳ | — |
| Shader | ⏳ | — |
| Memory | ⏳ | — |
| GDScript CPU | ⏳ | — |

---

## Optimizasyon Önerileri (Ön Değerlendirme)

Draw call bütçesini korumak için bilinen riskler:

| Risk | Önlem | Durum |
|------|-------|-------|
| Her sprite ayrı draw call | Texture atlas kullanımı | ⏳ Gözden geçirilecek |
| CanvasLayer sayısı | Maksimum 4 (bkz. technical-preferences.md) | ✅ Planlandı |
| Fragment shader döngüsü | Mobile Renderer'da yasak | ✅ Uyuldu |
| Particle VFX | Mobile'da düşük parçacık sayısı | ⏳ Gözden geçirilecek |

---

## Sonuç

| Kriter | Hedef | Sonuç |
|--------|-------|-------|
| FPS > 30 (tüm senaryolar) | Evet | ⏳ |
| Draw calls < 100 | Evet | ⏳ |
| Memory < 512 MB | Evet | ⏳ |
| **Genel** | **PASS** | **⏳** |

---

## Test Protokolü (Sprint 8 Fiziksel Cihaz Oturumu)

1. Debug build export et: `./tools/build/export_android.sh debug`
2. Cihaza yükle: `adb install build/android/breadmaster.apk`
3. Godot Profiler bağla: `adb forward tcp:6007 tcp:6007`
4. Her senaryo için 2 dakika bekle, PerformanceMonitor loglarını kaydet
5. `sample_now()` çağrısı ile anlık ölçüm al
6. Bu belgeyi gerçek verilerle güncelle

---

*Referans: `src/core/performance_monitor.gd`, `production/sprints/sprint-08.md` S8-02*
