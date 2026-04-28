# Performance Monitoring GDD

**Sistem:** #29 / 29
**Kategori:** Meta — Alpha
**Durum:** Designed
**Bağımlılıklar:** Tüm sistemler (pasif izleme)

---

## 1. Overview

Performance Monitoring System, oyunun hedef platformlarda (mobil mid-range, 60 FPS / 30 FPS minimum) çalıştığını doğrulamak için periyodik metrik örnekleme ve eşik aşımı sinyali yayar. FPS, draw call ve bellek izlenir; uzun pişirme işlemlerinin frame budget aşıp aşmadığı raporlanır. Sistem yalnızca DEBUG build'de aktiftir; production'da `_MONITORING_ENABLED` false'a düşürülür.

## 2. Player Fantasy

**Temel his:** (Oyuncu görmez.) — Bu sistem tamamen geliştirici aracıdır. Oyuncuya görünür bir UI'ı yoktur. Amaç: mobil cihazda FPS düşüşü, bellek sızıntısı veya fazla draw call tespit edince sinyalle uyarı üretmek.

**Geliştirici hedefi:** "Telefonda test ederken FPS 30'un altına düşünce anlık haberdar olayım; hangi sistem suçlu olduğunu görmek için ayrıca profiler açmam gerekmez."

**Kaçınılması gereken:** `_process()` ile her karede izleme — örneklemenin kendisi performans maliyeti yaratmamalı.

## 3. Detailed Rules

### 3.1 Örnekleme Stratejisi

- SceneTreeTimer ile `SAMPLE_INTERVAL_SEC` (5 saniye) aralıklarla Godot `Performance` singleton'ı sorgulanır.
- Her tick'te FPS, draw call ve bellek okunur; N örneklik kayan ortalama hesaplanır.
- `_process()` kullanılmaz (ADR-0003).

### 3.2 İzlenen Metrikler

| Metrik | Godot API | Eşik | Sinyal |
|--------|-----------|------|--------|
| FPS | `Performance.TIME_FPS` | < 30 FPS | `fps_dropped(fps: float)` |
| Draw Call | `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` | > 100 | `draw_calls_exceeded(count: int)` |
| Bellek | `Performance.STATIC_MEMORY_USAGE_BY_TYPE` | > 512 MB | `memory_warning(mb: float)` |
| Bake süresi | Özel — `OvenManager.bake_completed` latency | > 33ms | `bake_latency_warning(ms: float)` |

### 3.3 Kayan Ortalama

Son `WINDOW_SIZE` (3) örneklemenin ortalaması eşik kontrolünde kullanılır. Tek spikelar sinyal üretmez; sürekli düşük performans üretir.

### 3.4 Build Modu Kontrolü

```gdscript
const _MONITORING_ENABLED: bool = OS.is_debug_build()
```

Production exportta sistem `_ready()` içinde erken çıkar.

### 3.5 Raporlama

- Sinyaller `GUT` test ortamında `watch_signals()` ile yakalanabilir.
- Opsiyonel: `get_report() -> Dictionary` anlık metrik snapshot döner (debug HUD için).

## 4. Formulas

### F-1: Kayan Ortalama

```
moving_avg = sum(samples[-WINDOW_SIZE:]) / WINDOW_SIZE
```

### F-2: FPS Eşik Kontrolü

```
fps_alert ← moving_avg_fps < FPS_WARN_THRESHOLD
```

`FPS_WARN_THRESHOLD = 30.0` (güvenli aralık: [15, 60])

### F-3: Bellek MB Dönüşümü

```
memory_mb = Performance.get_monitor(Performance.STATIC_MEMORY_USAGE_BY_TYPE) / (1024.0 * 1024.0)
```

`MEMORY_WARN_MB = 512.0` (güvenli aralık: [256, 800])

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Production build | `_MONITORING_ENABLED = false` → `_ready()` içinde erken çıkış; no-op |
| SceneTree yok (`get_tree()` null) | Timer kurulmaz; push_warning |
| Bellek API farklı platformda değer 0 döndürürse | 0 < 512 → sinyal yayılmaz; false negative kabul edilebilir |
| Bake süresi ölçümü: OvenManager null | Bake latency sadece OvenManager bağlandığında izlenir |
| Pencere dolmadan (< WINDOW_SIZE örnek) eşik geçilirse | Mevcut örneklerle ortalama hesaplanır; N < WINDOW_SIZE için `sum / n` kullanılır |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Godot `Performance` Singleton** | FPS, draw call, bellek metrikleri |
| **OvenManager (#9)** | `bake_completed` sinyali — bake latency ölçümü |
| **Tüm sistemler (pasif)** | Sinyal tabanlı izleme; hiçbir sisteme bağımlılık enjekte etmez |

## 7. Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Etki |
|-----------|-----------|----------------|------|
| `SAMPLE_INTERVAL_SEC` | 5.0 | [1.0, 30.0] | Kısa → sık sampling; uzun → gecikmiş uyarı |
| `WINDOW_SIZE` | 3 | [1, 10] | Küçük → spike'lara duyarlı; büyük → gecikmiş ortalama |
| `FPS_WARN_THRESHOLD` | 30.0 | [15, 60] | Hedef min FPS |
| `DRAW_CALL_LIMIT` | 100 | [50, 200] | Mobil renderer limiti |
| `MEMORY_WARN_MB` | 512.0 | [256, 800] | Mid-range mobil hedef |

## 8. Acceptance Criteria

- [ ] `_MONITORING_ENABLED = false` ile production build'de sistem no-op
- [ ] `SAMPLE_INTERVAL_SEC` aralığında SceneTreeTimer örnekleme çalışıyor
- [ ] FPS < 30 olduğunda `fps_dropped` sinyali yayılıyor
- [ ] Draw call > 100 olduğunda `draw_calls_exceeded` sinyali yayılıyor
- [ ] Bellek > 512 MB olduğunda `memory_warning` sinyali yayılıyor
- [ ] Kayan ortalama: tek spike sinyal üretmiyor, WINDOW_SIZE üzerinde kalıcı düşüş üretiyor
- [ ] `get_report()` anlık metrikleri döndürüyor
- [ ] `_process()` hiçbir yerde kullanılmıyor (ADR-0003)
- [ ] GUT testleri: mock değer enjeksiyonu ile FPS/bellek eşik kontrolü, kayan ortalama
