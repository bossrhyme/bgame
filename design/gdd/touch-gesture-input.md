# Touch/Gesture Input

> **Status**: Approved
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-04
> **Implements Pillar**: ASMR Loop — "Tek el, hipnotik, tatmin edici dokunma mekaniği"

## Overview

Touch/Gesture Input, Ekmek Ustası'ndaki tüm dokunma girişlerini yorumlayan ve üst seviye oyun
sinyallerine dönüştüren çekirdek giriş sistemidir. Dört gesture türünü tanır: hamur yoğurma için
**dairesel sürükleme** (3 tam tur), fırına atmak için **sürükle-bırak** (drag-to-drop), ekmek
hasat / müşteri satışı / çalışan ataması için **kısa tap** (context-resolution alıcı tarafında)
ve şekil verme için **uzun basış + sürükle** (long-press + drag). Her gesture tipi ayrı bir
detector sınıfı olarak tasarlanmış (`CircularGestureDetector`, `DragToDropDetector`,
`TapDetector`, `LongPressDetector`), yapılandırma bir `GestureConfig` resource'undan okunur ve
haptic feedback `SettingsSystem.get_haptic_enabled()` aracılığıyla kontrol edilir. Sistem yalnızca
giriş yorumlama sorumluluğunu üstlenir; gameplay sonuçları (hamur state değişimi, altın kazanımı,
çalışan aktivasyonu vb.) ilgili sistemlerin sinyallere kendi bağlantılarıyla karşılamasıyla
gerçekleşir.

## Player Fantasy

Oyuncu hamuru yoğururken parmak ekranda döndükçe hamur rengi ısınır, hafifçe genişler, her tam
turda telefon titrer. Üçüncü tur tamamlandığında ekran bir an durur — küçük bir "pop" animasyonu,
tek bir güçlü titreşim. Bu an tekrar edilmek istenir. Gesture sistemi oyuncuya "kontrol bendeyken
her şey doğru çalışıyor" hissini verir: tap anında tepki verir, sürükleme parmağı takip eder,
fırına atılan hamur bir fırlatma değil, bir teslim hissi yaratır. Oyuncu hiçbir zaman "parmağımı
nereye basmam gerekiyor?" diye düşünmez — hedefler büyük, tepkiler anlık, başarı kaçınılmazdır.

## Detailed Design

### Core Rules

1. Tüm giriş `InputEventScreenTouch` + `InputEventScreenDrag` üzerinden `_unhandled_input()`
   ile alınır. `_input()` kullanılmaz (UI event'lerinin yutulmasını engeller).

2. Her sahnede maksimum 1 `CircularGestureDetector`, 1 `DragToDropDetector` ve N `TapDetector`
   (N = tappable node sayısı) aktif olabilir. Aynı anda sadece bir gesture tipi aktif olabilir.

3. **Intent-based öncelik:** Parmak basıldığında 250ms içinde hareket yoksa long-press başlar;
   250ms içinde `MIN_RADIUS` dışına çıkılırsa circular/drag detector devralır, long-press iptal
   edilir.

4. **`_touch_id` reset kuralı:** `_touch_id` yalnızca `InputEventScreenTouch.pressed == false`
   (parmak ekrandan kalkma) event'inde sıfırlanır. `gesture_completed` sinyali üzerinde
   sıfırlanmaz. _(Prototype BLOCK fix —
   `prototypes/gesture-test/PROTOTYPE_REPORT.md`)_

5. **Multi-touch:** İlk parmak gesture başlatır; aktif gesture varken ikinci parmak görmezden
   gelinir. İkinci parmak ayrı bir `TapDetector` üzerindeyse izole edilir (farklı `touch_id`'ler).

6. **Haptic feedback:** `SettingsSystem.get_haptic_enabled()` sorgusuna bağlıdır.
   `true` → `Input.vibrate_handheld(duration_ms)`.  `false` → sessiz.
   iOS'ta `vibrate_handheld()` çalışmaz — kapsam dışı, ayrı ADR gerektirir.

7. **Veri-driven config:** Tüm eşik değerleri (`MIN_RADIUS`, `MAX_RADIUS`,
   `CIRCLES_REQUIRED`, `LONG_PRESS_DURATION` vb.) `GestureConfig` resource'undan okunur.
   Hardcode yasak.

8. **`gesture_progress(fraction)` sinyali** continuous emit edilir (0.0–1.0); UI animasyonu
   ve ses için kullanılır. Saniyede ~30–60 kez emit normaldir; listener performans için
   throttle edebilir.

9. **Context-resolution alıcı tarafında:** `tapped(node)` sinyali tek bir ortak sinyaldir.
   Hangi gameplay aksiyonunun (hasat / satış / çalışan ataması) tetikleneceğine alıcı sistemler
   `node` tipini kontrol ederek karar verir. Gesture sistemi context'e karışmaz.

### Gesture Types

| # | Gesture | Detector Sınıfı | Tetikleyici | Çıkış Sinyalleri | Kullanım |
|---|---------|----------------|------------|------------------|---------|
| G1 | **Circular Drag** | `CircularGestureDetector` | 3 tam tur (her iki yön, `abs()`) | `circular_completed`, `circular_progress(fraction)`, `circular_cancelled` | Hamur yoğurma |
| G2 | **Drag-to-Drop** | `DragToDropDetector` | Sürükle → DropZone üzerinde bırak | `drag_dropped(target_node)`, `drag_cancelled` | Hamur fırına atma |
| G3 | **Short Tap** | `TapDetector` | Touch press+release < `TAP_MAX_MS`, < `MIN_RADIUS` hareket | `tapped(node)` | Hasat, müşteri satışı, çalışan ataması |
| G4 | **Long Press + Drag** | `LongPressDetector` | `LONG_PRESS_DURATION_MS` basış sonrası sürükle | `long_drag_started`, `long_drag_ended(end_position)` | Şekil verme (hamur forma girme) |

### States and Transitions

#### CircularGestureDetector

```
IDLE
  │ InputEventScreenTouch.pressed == true + _touch_id serbest
  ▼
TOUCH_DOWN  ── (250ms bekle; hareket < MIN_RADIUS)
  │ hareket ≥ MIN_RADIUS, intent = circular
  ▼
TRACKING
  │ abs(_cumulative_angle) / TAU ≥ CIRCLES_REQUIRED → emit circular_completed
  │                                                    reset gesture state
  │                                                    → IDLE
  │
  │ InputEventScreenTouch.pressed == false → emit circular_cancelled → IDLE
  │ radius > MAX_RADIUS                   → emit circular_cancelled → IDLE
  └──────────────────────────────────────────────────────────────────────────

TOUCH_DOWN ── 250ms geçti + parmak yerinde → LongPressDetector'a devret → IDLE
```

#### DragToDropDetector

```
IDLE
  │ InputEventScreenTouch.pressed == true (draggable node sınırları içinde)
  ▼
INTENT_PENDING  ── (hareket < MIN_RADIUS: tap mı, drag mı belli değil)
  │ hareket ≥ MIN_RADIUS → drag intent onaylandı
  ▼
DRAGGING
  │ InputEventScreenTouch.pressed == false + DropZone içinde
  │   → emit drag_dropped(target_node) → IDLE
  │
  │ InputEventScreenTouch.pressed == false + DropZone dışında
  │   → emit drag_cancelled → IDLE

INTENT_PENDING ── InputEventScreenTouch.pressed == false + hareket < MIN_RADIUS + elapsed < TAP_MAX_MS
  │   → tap intent: DragToDropDetector pasif kalır; TapDetector yakalar → IDLE
```

> **Not:** Draggable bir hamur node'u aynı anda hem `TapDetector` hem `DragToDropDetector`
> barındırabilir. `INTENT_PENDING` süresince ikisi de bekler; hareket `MIN_RADIUS`'u geçerse
> `DragToDropDetector` devralır, geçmezse `TapDetector` sinyali emit eder.

#### TapDetector (per node)

```
IDLE
  │ InputEventScreenTouch.pressed == true (node sınırları içinde)
  ▼
PENDING
  │ InputEventScreenTouch.pressed == false + elapsed < TAP_MAX_MS + hareket < MIN_RADIUS
  │   → emit tapped(node) → IDLE
  │
  │ elapsed ≥ TAP_MAX_MS → Long Press patternia ait → IDLE (tap iptal)
  │ hareket ≥ MIN_RADIUS → Drag intent → IDLE (tap iptal)
```

### Interactions with Other Systems

| Sistem | Veri Akışı | Sahip |
|--------|-----------|-------|
| **Settings & Preferences** | `haptic_enabled` okunur | Settings → Gesture |
| **Dough Controller / ASM** | `circular_completed` → `on_gesture_completed()` | Gesture → ASM |
| **Dough Controller / ASM** | `circular_progress(fraction)` → `on_gesture_progress(f)` | Gesture → ASM |
| **Oven/Baking System** | `drag_dropped(oven_node)` → `receive_dough()` | Gesture → Oven |
| **Economy System** | `tapped(bread_node)` → `harvest_bread()` (context-resolution alıcıda) | Gesture → Economy |
| **Customer/Order System** | `tapped(customer_node)` → `serve_customer()` (context-resolution alıcıda) | Gesture → Customer |
| **Employee System** | `tapped(worker_node)` → `assign_worker()` (context-resolution alıcıda) | Gesture → Employee |
| **GestureConfig resource** | Tüm eşik değerleri tek yönlü okunur | Config → Gesture |

## Formulas

### F-1: Circular Progress Fraction

```
fraction = clamp(abs(cumulative_angle) / (CIRCLES_REQUIRED × TAU), 0.0, 1.0)
```

| Değişken | Tip | Açıklama |
|----------|-----|----------|
| `cumulative_angle` | float (radyan) | ±π normalizasyonlu akümüle rotasyon açısı |
| `CIRCLES_REQUIRED` | int | Tamamlanması gereken tam tur sayısı (config: 3) |
| `TAU` | const | 2π ≈ 6.2832 |
| `fraction` | float [0.0, 1.0] | Tamamlanma oranı; UI ve haptic tick için kullanılır |

**Örnek değerler:**

| Tamamlanan tur | cumulative_angle | fraction |
|----------------|-----------------|---------|
| 0 | 0.0 | 0.00 |
| 1 | 6.28 | 0.33 |
| 1.5 | 9.42 | 0.50 |
| 2 | 12.57 | 0.67 |
| 3 (tamamlandı) | 18.85 | 1.00 |

#### F-1b: Haptic Tick Threshold-Crossing Tespiti

Her tam tur geçişinde haptic tick ve SFX `knead_tick` tetiklenir. Geçiş tespiti:

```
prev_circles = int(prev_fraction * CIRCLES_REQUIRED)
curr_circles = int(curr_fraction * CIRCLES_REQUIRED)
if curr_circles > prev_circles:
    if haptic_enabled: Input.vibrate_handheld(HAPTIC_TICK_MS)
    emit_signal("knead_tick", curr_circles)   # ses tetiklemesi için
```

- `prev_fraction`: bir önceki event'te hesaplanan fraction değeri
- `curr_circles > prev_circles`: tam tur sınırı (0.33, 0.67) geçildi
- Tamamlanma sinyali (`fraction == 1.0`) ayrıca `circular_completed`'da ele alınır;
  F-1b tekrar tetiklenmez.

---

### F-2: Açı Delta Normalizasyonu (±π Wrap-around)

```
delta = current_angle - last_angle
if delta > π:   delta -= TAU
elif delta < -π: delta += TAU
cumulative_angle += delta
last_angle = current_angle
```

- **Amaç:** `atan2` çıkışı `[-π, π]` aralığındadır; 359° → 1° (veya -179° → 179°) geçişinde
  yanlış büyük delta oluşmasını önler.
- **Godot 2D koordinatı:** Y eksenin aşağı artması `atan2` işaretini etkilemez; her iki yön
  `abs()` ile eşdeğer sayılır (F-1'de `abs(cumulative_angle)` kullanılır).

---

### F-3: Tap Detection

```
moved = (finger_current_pos - touch_start_pos).length()
is_tap = (elapsed_ms < TAP_MAX_MS) AND (moved < MIN_RADIUS)
```

| Değişken | Tip | Config | Açıklama |
|----------|-----|--------|---------|
| `TAP_MAX_MS` | float | 300 ms | Bu süreyi geçerse tap değil |
| `MIN_RADIUS` | float | 40.0 px | Bu mesafeyi geçerse drag intent |
| `moved` | float (px) | — | Dokunuş başından itibaren hareket mesafesi |

---

### F-4: Long Press Threshold

```
is_long_press_intent = (elapsed_ms ≥ LONG_PRESS_DURATION_MS) AND (moved < MIN_RADIUS)
```

| Değişken | Tip | Config | Açıklama |
|----------|-----|--------|---------|
| `LONG_PRESS_DURATION_MS` | float | 250 ms | Bu süre dolunca long-press intent onaylanır |
| `MIN_RADIUS` | float | 40.0 px | Hareket bu sınırı geçerse circular/drag intent devralır |

> **Not:** F-3 `TAP_MAX_MS` (300ms) ile F-4 `LONG_PRESS_DURATION_MS` (250ms) kasıtlı örtüşür.
> 250–300ms arası kısa basışlar long-press olarak değerlendirilir; bu normal bekleme-sonrası
> gesture'ları kapsar.

## Edge Cases

| # | Durum | Davranış |
|---|-------|---------|
| E-1 | Gesture tamamlandıktan sonra parmak hâlâ ekranda | `_touch_id` korunur; yeni gesture başlamaz; parmak kalkınca `_touch_id = -1` (Core Rule 4) |
| E-2 | Circular drag esnasında `MAX_RADIUS` aşılırsa | `circular_cancelled` emit edilir; hamur IDLE'a döner |
| E-3 | Drag-to-drop sırasında DropZone dışına bırakılırsa | `drag_cancelled` emit edilir; hamur `dough_return` animasyonuyla READY pozisyonuna döner |
| E-4 | Ekran döndürülürse (landscape ↔ portrait) aktif gesture varken | `circular_cancelled` / `drag_cancelled` emit edilir; tüm gesture state sıfırlanır |
| E-5 | Uygulama arka plana alınırsa aktif gesture varken | `NOTIFICATION_WM_WINDOW_FOCUS_OUT` → tüm gesture'lar iptal; ilgili `_cancelled` sinyalleri emit edilir |
| E-6 | Oyun sahnesi değiştirilirse aktif gesture varken | `_exit_tree()` → detector `queue_free()`; sinyal emit edilmez (normal temizlik; alıcı sistemler temizlendi) |
| E-7 | İki parmak eşzamanlı tap | İlk parmak gesture'ı geçerli; ikinci parmak görmezden gelinir (Core Rule 5) |
| E-8 | Aynı node üzerinde circular + long-press intent çakışması | 250ms kuralı belirler: hareket `≥ MIN_RADIUS` → circular; hareket `< MIN_RADIUS` → long-press. İkisi asla birden tetiklenmez (Core Rule 3) |
| E-9 | Çok hızlı gesture (0.5s'de 3 tur) | Algoritma frekans-bağımsız; yüksek `InputEventScreenDrag` event hızında da doğru sayar |
| E-10 | Çok yavaş gesture (10s'de 3 tur) | Timeout yok; `cumulative_angle` doğru birikir; float precision drift ihmal edilebilir (bkz. `prototypes/gesture-test/PROTOTYPE_REPORT.md`) |
| E-11 | `haptic_enabled` runtime'da değiştirilirse | Sonraki `circular_completed`'dan itibaren yeni değer geçerli; çalışan gesture'ı kesilmez |
| E-12 | iOS cihazda `Input.vibrate_handheld()` çağrısı | Sessiz geçer, crash olmaz; iOS haptic için ayrı ADR gerekir |

## Dependencies

### Upstream (Bu sistem bunlara bağımlı)

| Sistem | Bağımlılık Tipi | Arayüz |
|--------|-----------------|--------|
| **Settings & Preferences** | Zorunlu (hard) | `SettingsSystem.get_haptic_enabled() → bool` |
| **GestureConfig resource** | Zorunlu (hard) | `GestureConfig.tres` — `MIN_RADIUS`, `MAX_RADIUS`, `CIRCLES_REQUIRED`, `LONG_PRESS_DURATION_MS`, `TAP_MAX_MS` |

### Downstream (Bunlar bu sisteme bağımlı)

| Sistem | Beklenen Sinyal | Tetiklenen Aksiyon |
|--------|----------------|-------------------|
| **Animation State Machine** | `circular_progress(f)`, `circular_completed`, `circular_cancelled` | Hamur animasyon state değişimleri |
| **Oven/Baking System** | `drag_dropped(oven_node)` | `receive_dough()` — pişirme döngüsü başlar |
| **Economy System** | `tapped(bread_node)` | `harvest_bread()` — altın kazanımı |
| **Customer/Order System** | `tapped(customer_node)` | `serve_customer()` — sipariş tamamlama |
| **Employee System** | `tapped(worker_node)` | `assign_worker()` — çalışan aktivasyonu |
| **UI/HUD System** | `circular_progress(f)` | İlerleme çubuğu güncelleme |

### Bağımlılık Notları

- Settings GDD `SettingsSystem.get_haptic_enabled()` API'sini tanımlar
  (`design/gdd/settings-preferences.md` → Core Rules → Ses / `haptic_enabled` provision).
  Bu GDD tamamlanana kadar Gesture sistemi haptic kontrolünü varsayılan `true` ile çalıştırır.
- `GestureConfig` resource şeması bu GDD'de tanımlanır (bkz. Tuning Knobs);
  resource dosyası `assets/data/gesture_config.tres` konumunda oluşturulur.

## Tuning Knobs

Tüm değerler `GestureConfig` resource'una (`assets/data/gesture_config.tres`) aittir.
Kod değişikliği gerekmeden Godot Inspector üzerinden ayarlanabilir.

| Parametre | Varsayılan | Güvenli Aralık | Çok Düşükse | Çok Yüksekse |
|-----------|-----------|----------------|-------------|--------------|
| `CIRCLES_REQUIRED` | 3 | 2–5 | Çok kolay — hasat sürtünmesi yok | Yorucu — oyuncu bırakır |
| `MIN_RADIUS` | 40.0 px | 20–80 px | Yanlışlıkla küçük titremeler circular sayılır | Geniş ekranlarda parmak orta bölgeden çıkamaz |
| `MAX_RADIUS` | 200.0 px | 150–300 px | Sadece küçük çemberler kabul edilir — frustrasyonu artırır | Ekranın köşesine kadar sürükleme tanınır — yanlış pozitif riski |
| `TAP_MAX_MS` | 300 ms | 150–500 ms | Hızlı tap'ler kayıt edilmez | Uzun basışlar tap olarak yanlış algılanır |
| `LONG_PRESS_DURATION_MS` | 250 ms | 150–400 ms | Long-press çok kolay tetiklenir — tap'lerle çakışır | Şekil verme mekanizması tepkisiz hissettiriyor |
| `HAPTIC_TICK_MS` | 20 ms | 10–50 ms | Titreşim çok kısa — hissedilmez | Titreşim çok uzun — rahatsız edici |
| `HAPTIC_COMPLETE_MS` | 80 ms | 40–150 ms | Tamamlanma titreşimi zayıf | Fazla güçlü — alarm gibi hissettiriyor |
| `DRAG_DROP_SNAP_RADIUS` | 60.0 px | 40–100 px | DropZone hassas — sürükleme zor | DropZone çok büyük — yanlış fırına atılır |

### Etkileşimler

- `MIN_RADIUS` hem circular hem tap hem long-press'te kullanılır; tek değer tüm gesture'ları etkiler.
  Küçültme circular doğruluğunu düşürür.
- `TAP_MAX_MS` (300ms) ile `LONG_PRESS_DURATION_MS` (250ms) arası kasıtlı örtüşme:
  250–300ms penceresi long-press intent'i kapsar. Bu değerlerin sırası değiştirilmemelidir.

### GestureConfig Resource Şeması

`assets/data/gesture_config.tres` — `Resource` alt sınıfı:

```gdscript
class_name GestureConfig
extends Resource

@export var circles_required: int = 3
@export var min_radius: float = 40.0
@export var max_radius: float = 200.0
@export var tap_max_ms: float = 300.0
@export var long_press_duration_ms: float = 250.0
@export var haptic_tick_ms: int = 20
@export var haptic_complete_ms: int = 80
@export var drag_drop_snap_radius: float = 60.0
```

Her detector sınıfı bu resource'u `@export var config: GestureConfig` ile alır.
Godot Inspector'dan veya proje ayarlarından atanır; kod değişikliği gerekmez.

## Visual/Audio Requirements

### Circular Drag (G1)

- Her tam turda: kısa haptic tick (20ms) + SFX `knead_tick` (AudioBus: SFX, öncelik LOW)
- Tamamlandığında: güçlü haptic (80ms) + SFX `knead_complete` (AudioBus: SFX, öncelik HIGH)
- `circular_progress(fraction)` ile hamur scale ve rengi değişir (ASM sorumluluğu)
- İptal edildiğinde: haptic yok; sessiz geri dönüş

### Drag-to-Drop (G2)

- Sürükleme esnasında: hafif gölge/elevated görsel (ASM sorumluluğu)
- DropZone üzerine girilince: DropZone highlight (UI sorumluluğu)
- Başarılı bırakma: SFX `oven_door_load` (AudioBus: SFX, öncelik MEDIUM)
- İptal: SFX yok; nesne orijinal pozisyona döner (ASM sorumluluğu)

### Short Tap (G3)

- Hasat tap'i: SFX `bread_harvest` (AudioBus: SFX, öncelik HIGH) + coin animasyonu (ASM)
- Müşteri tap'i: SFX `cash_register` (AudioBus: SFX, öncelik HIGH)
- Çalışan tap'i: SFX `worker_assign` (AudioBus: SFX, öncelik LOW)

### Long Press + Drag (G4)

- 250ms basış tamamlandığında: hafif haptic (30ms) + görsel şekil-verme modu aktif (ASM)
- Bırakınca: SFX `dough_shape` (AudioBus: SFX, öncelik MEDIUM)

> Ses asset listesi ve öncelik tanımları `design/gdd/audio-bus-mixer.md`'ye göre yönetilir.

---

## UI Requirements

- Tüm tappable node'ların dokunma alanı minimum **44×44 px** (mobil erişilebilirlik standardı)
- DropZone highlight: tamamlanma rengiyle 200ms fade-in; DropZone'dan çıkılınca 200ms fade-out
- Circular drag progress: ASM'deki hamur scale animasyonu yeterli — ayrı progress bar gerekip
  gerekmediği UI/HUD GDD'de (D-15) kararlaştırılacak
- Gesture iptali geri bildirimi: hamur orijinal pozisyona 200ms ease-out ile döner
- Debug overlay (geliştirici modunda): `debug_circle_count`, `debug_fraction`, `debug_last_radius`
  görünür (prototip `StatusLabel` tasarımından devralınır)

---

## Acceptance Criteria

### Circular Drag (G1)

- [ ] **AC-01:** 3 tam döngüsel sürükleme tamamlandığında `circular_completed` sinyali tam 1 kez emit
      edilir — fazlası yok, eksiği yok. GUT testi: açı birikimi simülasyonu ile doğrula.
- [ ] **AC-02:** Her tam turda `circular_progress(fraction)` 0.33 → 0.67 → 1.0 değerlerinde emit
      edilir (±0.01 tolerans). GUT testi: cumulative_angle mock'u ile doğrula.
- [ ] **AC-03:** Düz yatay sürükleme (0 tur) `circular_completed` tetiklemez; `gesture_progress`
      fraction'ı 0.1'i geçmez.
- [ ] **AC-04:** `circular_completed` emit edildikten sonra parmak ekranda iken yeni circular
      gesture başlamaz — `_touch_id` parmak kalkana kadar korunur.
- [ ] **AC-05:** `MAX_RADIUS` aşılınca `circular_cancelled` emit edilir; ardından yapılan sürükleme
      yeni gesture başlatmaz (parmak kalkana kadar).

### Drag-to-Drop (G2)

- [ ] **AC-06:** Eleman DropZone içine bırakılınca `drag_dropped(target_node)` doğru `target_node`
      referansıyla emit edilir.
- [ ] **AC-07:** DropZone dışına bırakılınca `drag_cancelled` emit edilir; `drag_dropped` emit
      edilmez.

### Short Tap (G3)

- [ ] **AC-08:** 300ms altında, `MIN_RADIUS` içinde parmak kaldırılınca `tapped(node)` emit edilir.
- [ ] **AC-09:** 300ms üzerinde bekleyince tap sinyali emit edilmez.
- [ ] **AC-10:** Parmak `MIN_RADIUS` dışına çıkınca tap sinyali emit edilmez.

### Long Press + Drag (G4)

- [ ] **AC-11:** 250ms hareketsiz basış sonrası sürükleme `long_drag_started` ve
      `long_drag_ended(position)` sinyallerini tetikler.
- [ ] **AC-12:** 250ms önce sürükleme başlarsa `long_drag_started` tetiklenmez; circular/drag
      intent devralır.

### Intent Resolution

- [ ] **AC-13:** Aynı node üzerinde circular başlatma girişimi ile long-press aynı anda mümkün değil;
      250ms kuralı deterministik olarak hangi gesture'ın kazandığını belirler.
- [ ] **AC-14:** İkinci parmak aktif gesture esnasında farklı bir node'a tap yaparsa ilk gesture
      etkilenmez; ikinci tap sinyali emit edilmez.

### Haptic

- [ ] **AC-15:** `haptic_enabled = true` iken `circular_completed` → `Input.vibrate_handheld(HAPTIC_COMPLETE_MS)`
      çağrılır. `haptic_enabled = false` iken çağrılmaz.
- [ ] **AC-16:** Her tam turda (fraction 0.33, 0.67) `Input.vibrate_handheld(20)` çağrılır
      (yalnızca `haptic_enabled = true`).

### Performans

- [ ] **AC-17:** `_unhandled_input()` içindeki gesture işleme süresi frame başına < 0.5ms (Godot
      Profiler ile ölç — mid-range Android cihazda).
- [ ] **AC-18:** 10 dakikalık aktif dairesel sürükleme sonrası memory leak yok (Godot Monitor →
      Memory/Static başlangıç değerine döner).

## Open Questions

| # | Soru | Sahip | Hedef |
|---|------|-------|-------|
| OQ-01 | iOS haptic: GDExtension plugin mi, CoreHaptics bridge mi? `technical-director`'a eskalasyon gerektirir. | technical-director | Alpha öncesi |
| OQ-02 | `circular_progress` event throttle: UI/HUD listener saniyede kaçtan fazla almamalı? | UI/HUD GDD (D-15) | D-15 tasarlanınca |
| OQ-03 | Şekil verme (G4) üretim mekaniklerine tam entegrasyonu: hamur ne forma giriyor, bu Recipe System ile nasıl ilişkilendiriliyor? | Recipe System GDD (D-10) | D-10 tasarlanınca |
| OQ-04 | `DRAG_DROP_SNAP_RADIUS` cihaz DPI'ya göre ölçeklenmeli mi? (Büyük ekran = daha büyük snap zone) | gameplay-programmer | Implementation sırasında |
