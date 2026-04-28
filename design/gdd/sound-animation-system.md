# Sound & Animation System GDD

**Sistem:** #26 / 29
**Kategori:** UI — Vertical Slice
**Durum:** Designed
**Bağımlılıklar:** Audio System (#7), Animation System (#7), Oven/Baking System (#5), Customer/Order System (#11), Recipe System (#10)

---

## 1. Overview

Sound & Animation System, gameplay olaylarını (ekmek pişme, müşteri hizmet, tarif açılımı) ses efektlerine ve animasyon tetikleyicilerine bağlayan köprü katmanıdır. `GameAudioBridge` sınıfı gameplay sistemlerinin sinyallerini dinler ve `AudioManager.play_sfx()` ile `AnimationManager` metodlarını çağırır. `AudioStream` kaynakları sahne inspector'ından atanır; kod hardcode yol içermez.

## 2. Player Fantasy

**Temel his:** "Ekmek pişti" — Fırından çıkış sesi, ekranın altından gelen o hafif "ding" anı oyuncunun dikkatini çeker. Para kazanma sesi ise küçük bir tatmin anı yaratır. Sesler taktiksel değil, duygusal: doğru anda doğru ses.

**İkincil his:** Sessiz kalibrasyon. Müşteri kaçınca hafif bir hayal kırıklığı sesi. Yeni tarif açılınca küçük bir fanfare. Her ses bir geribildirim döngüsüdür.

**Kaçınılması gereken:** Ses yağmuru. Aynı anda 5 ekmek pişip hasat edilirse 5 kez "ding" çınlamaz — polyphony sistemi zaten bunu önler. Ses öncelikleri bunu yönetir.

## 3. Detailed Rules

### Gameplay → Ses Eşlemesi

| Olay | Kaynak Sinyal | SFX Öncelik | AnimationManager Çağrısı |
|------|--------------|-------------|--------------------------|
| Ekmek pişme tamamlandı | `OvenManager.bake_completed` | LOW | — |
| Ekmek hasat edildi | `OvenManager.bread_harvested` | MEDIUM | `coin_spawn_requested` tetiklenir (AnimMgr zaten bağlı) |
| Müşteri siparişi teslim edildi | `CustomerOrderSystem.order_delivered` | MEDIUM | — |
| Müşteri kaçtı | `CustomerOrderSystem.customer_escaped` | LOW | — |
| Tarif açıldı | `RecipeManager.recipe_unlocked` | HIGH | — |
| Hamur yüklendi | `AnimationManager.dough_loaded` | LOW | — |

### Ses Öncelik Kuralları (AudioManager entegrasyonu)

```
HIGH  → tarif açılımı (oyuncunun mutlaka duyması gerekir)
MEDIUM → para/müşteri geri bildirimi (oyun sürecinde çok tekrar eder)
LOW   → fırın sesi, hamur sesi (arka plan sesleri)
```

AudioManager polyphony limiti (8 eşzamanlı); doluysa en düşük öncelikli kesilir.

### Battery Saver Entegrasyonu

Battery saver modunda `AudioManager` bus'ları zaten sessiz olabilir; `GameAudioBridge` battery saver'ı ayrıca kontrol etmez. AudioManager bu kural için sorumludur.

### AudioStream Kaynakları

`GameAudioBridge`, `@export` ile sahne inspector'ından `AudioStream` referansı alır:

```
@export var sfx_bake_complete: AudioStream
@export var sfx_bread_harvest: AudioStream
@export var sfx_order_delivered: AudioStream
@export var sfx_customer_escaped: AudioStream
@export var sfx_recipe_unlocked: AudioStream
@export var sfx_dough_loaded: AudioStream
```

`null` stream → `play_sfx()` atlanır, `push_warning` basılır; gameplay etkilenmez.

## 4. Formulas

Matematiksel formül içermez. Ses eşlemeleri kural tablosunda tanımlanmıştır.

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| AudioManager null ise | `push_warning` + sinyal bağlantısı atlanır |
| SFX stream null ise | `push_warning` + `play_sfx()` çağrısı atlanır |
| Aynı anda 10 ekmek hasat edilirse | AudioManager polyphony sistemi en düşük öncelikliyi keser |
| Battery saver açıkken sinyal gelirse | Bridge olayı alır; AudioManager bus sessizse ses çıkmaz (AudioManager sorumluluğu) |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Audio System — AudioManager (#7)** | `play_sfx(stream, priority)` çağrısı |
| **Animation System — AnimationManager (#7)** | `dough_loaded` sinyalini dinler |
| **Oven/Baking System (#5)** | `bake_completed`, `bread_harvested` sinyalleri |
| **Customer/Order System (#11)** | `order_delivered`, `customer_escaped` sinyalleri |
| **Recipe System (#10)** | `recipe_unlocked` sinyali |

## 7. Tuning Knobs

| Parametre | Değer | Güvenli Aralık | Etki |
|-----------|-------|----------------|------|
| SFX stream referansları | Inspector | — | Ses içeriğini değiştirir; kod değişmez |
| `sfx_bake_complete` öncelik | LOW | LOW–MEDIUM | Çok sık tetiklenebilir; HIGH olursa diğerleri kesilir |
| `sfx_recipe_unlocked` öncelik | HIGH | MEDIUM–HIGH | Önemli an; düşürülmemeli |

## 8. Acceptance Criteria

- [ ] `OvenManager.bake_completed` → `play_sfx(sfx_bake_complete, LOW)` çağrılıyor
- [ ] `OvenManager.bread_harvested` → `play_sfx(sfx_bread_harvest, MEDIUM)` çağrılıyor
- [ ] `CustomerOrderSystem.order_delivered` → `play_sfx(sfx_order_delivered, MEDIUM)` çağrılıyor
- [ ] `CustomerOrderSystem.customer_escaped` → `play_sfx(sfx_customer_escaped, LOW)` çağrılıyor
- [ ] `RecipeManager.recipe_unlocked` → `play_sfx(sfx_recipe_unlocked, HIGH)` çağrılıyor
- [ ] AudioStream null ise `push_warning` basılıyor, sistem çökmiyor
- [ ] AudioManager null ise `push_warning` basılıyor, sistem çökmiyor
