# Oven/Baking System

> **Status**: Approved
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-04
> **Implements Pillar**: Core Loop — "Hamur hazırla → Fırına at → Bekle → Hasat et"

## Overview

Oven/Baking System, oyuncunun hamur koyduğu ve belirli bir süre sonra ekmek çıkardığı çekirdek
üretim döngüsünün kalp atışıdır. Fırın başlangıçta 1 slot içerir; Upgrade Tree aracılığıyla
maksimum 4 slota kadar genişletilebilir. Her slot bağımsız olarak çalışır ve yalnızca bir hamuru
kabul eder. Pişirme süresi tarife özgüdür — basit ekmekler 8 saniye içinde hazır olurken özel
tarifler 60 saniyeye kadar sürebilir. Süre dolduğunda slot otomatik olarak "hazır" durumuna
geçer; oyuncu tap ile hasat eder ve Economy sistemine altın kazanımı bildirilir. Aktif pişirme
`Timer.timeout` sinyali üzerinden yönetilir (ADR-0003 uyumlu). Uygulama kapandığında pişirme
devam eder; açılışta `TimeManager.get_elapsed_seconds()` ile geçen süre hesaplanır ve otomatik
tamamlanan slotlar hasat'a hazır hale gelir.

## Player Fantasy

Fırına hamuru koyduğun an kapı gıcırdar, sıcaklık hissedilir. Timer dolmaya başlar — bu bekleme
sinir bozucu değil, tatmin edici bir gerilimdir. Birden fazla slot açıksa iki hamuru aynı anda
koyabilirsin; her birini ayrı ayrı yönetmek küçük bir orkestrasyon hissi yaratır. Timer
bittiğinde slot parlar. Bir tap ile ekmek fırlar, altın akar — ve slot tekrar boş, tekrar
bekliyor. Seni bekliyor. Oyuna geri döndüğünde fırın çalışmış: ya hasat bekleyen ekmekler ya da
fresh-start için boş slotlar. Her iki durumda da "geri döndüm, devam ediyorum" hissi güçlü.

## Detailed Design

### Core Rules

1. Fırın başlangıçta 1 `BakingSlot` içerir. Upgrade Tree ile 2, 3, 4 slota çıkarılabilir.
   Maksimum 4 slot — hardcoded üst sınır; GDD dışı config edilemez.

2. Her `BakingSlot` bağımsız bir `Timer` node barındırır. Slotlar birbirini etkilemez.

3. **Slot'a hamur yükleme:** `receive_dough(recipe_id: String) -> bool` çağrısıyla başlar.
   Başarılı olursa `true`, slot dolu veya geçersiz `recipe_id` ise `false` döner.
   `recipe_id` → `ContentDatabase`'den `bake_time_seconds` ve `gold_reward` okunur.
   Baking başladığında `bake_started(slot_id: int, recipe_id: String)` sinyali emit edilir.

4. **Pişirme tamamlanması:** `Timer.timeout` tetiklenince slot `READY` durumuna geçer
   ve `bake_completed(slot_id: int, recipe_id: String)` sinyali emit edilir.
   Oyuncu hasat edene kadar READY'de **süresiz** bekler.

5. **Hasat:** `harvest(slot_id: int)` çağrısı →
   `EconomySystem.earn_gold(gold_reward)` → slot `EMPTY`'e döner.
   `bread_harvested(slot_id, recipe_id, gold_earned)` sinyali emit edilir.

6. **Offline pişirme:** Uygulama açılışında her BAKING slot için, pişirme başlangıcından
   itibaren geçen toplam süre `bake_start_timestamp` ile hesaplanır:
   `elapsed_for_slot = Time.get_unix_time_from_system() - slot.bake_start_timestamp`
   `elapsed_for_slot` `OFFLINE_CAP_SECONDS` ile kırpılır.
   `remaining = bake_time_seconds - elapsed_for_slot`
   `remaining ≤ 0` → slot `READY`; `remaining > 0` → Timer `remaining` saniye ile yeniden başlar.

7. **Offline süre cap:** Slot başına hesaplanan `elapsed_for_slot`, `OFFLINE_CAP_SECONDS`
   (28800s = 8h) ile kırpılır. Her slot yalnızca 1 kez tamamlanır (READY otomatik
   yeniden yükleme yapmaz). Toplam offline altın = (READY olan slot sayısı) × gold_reward.

8. **`_process()` yasak** (ADR-0003). Tüm zamanlama `Timer.timeout` sinyali üzerinden yönetilir.

### Oven States

Her `BakingSlot` ayrı bir state machine'dir:

```
EMPTY  (bread_node invisible/disabled)
  │ receive_dough(recipe_id) — hamur drag-to-drop ile yüklendi
  │ emit bake_started(slot_id, recipe_id)
  ▼
BAKING  (bread_node invisible; progress bar görünür)
  ← Timer çalışıyor; bake_start_timestamp kaydedildi
  │ Timer.timeout
  │ emit bake_completed(slot_id, recipe_id)
  ▼
READY  (bread_node visible + tappable; parlama animasyonu)
  ← süresiz bekleme
  │ harvest(slot_id) — oyuncu tap ile hasat etti
  │ emit bread_harvested(slot_id, recipe_id, gold_earned)
  ▼
EMPTY
```

Özel geçiş: Uygulama açılışında BAKING slot'larına `bake_start_timestamp` tabanlı offline elapsed uygulanır:
- `remaining ≤ 0` → BAKING'den doğrudan READY'ye; `bake_completed` emit edilir (Timer hiç çalışmaz)
- `remaining > 0` → BAKING kalır; Timer kalan süre ile yeniden başlar

> **Not:** ASM GDD (D-06), `bake_started(slot_id)` ve `bake_completed(slot_id)` sinyallerini
> fırın kapısı ve ekmek animasyonu için dinler. ASM GDD parametre adı olarak `oven_id` kullanır;
> bu GDD'de eşdeğer `slot_id` kullanılmaktadır (her ikisi de 0–3 arası int).

### Baking Slot Architecture

Her `BakingSlot` aşağıdaki verileri tutar:

| Alan | Tip | Açıklama |
|------|-----|----------|
| `slot_id` | `int` | 0–3 arası slot indeksi |
| `state` | `enum {EMPTY, BAKING, READY}` | Mevcut durum |
| `recipe_id` | `String` | Pişirilmekte olan tarif ID'si; EMPTY'de `""` |
| `bake_start_timestamp` | `int` | Unix timestamp; offline hesap için; EMPTY'de `0` |
| `bake_time_seconds` | `float` | Tariften okunan toplam pişirme süresi |
| `gold_reward` | `int` | Tariften okunan hasat altın miktarı |
| `timer` | `Timer` | Godot Timer node; yalnızca BAKING'de `start()` çağrılır |

`BakingSlot` bir Godot Resource veya Node'a ait `@export` alanları olarak implement edilir.

### Offline Baking

**Açılış rutini (OvenManager.initialize_from_save):**

```
1. SaveSystem'den slot_data[] (recipe_id, bake_start_timestamp, state) yükle
2. now = Time.get_unix_time_from_system()
3. Her BAKING slot için:
     elapsed_for_slot = now - slot.bake_start_timestamp
     elapsed_for_slot = clamp(elapsed_for_slot, 0.0, OFFLINE_CAP_SECONDS)  # 8h cap per slot
     remaining = slot.bake_time_seconds - elapsed_for_slot
     if remaining <= 0:
         slot.state = READY
         emit bake_completed(slot_id, recipe_id)
     else:
         slot.timer.start(remaining)
4. READY ve EMPTY slotlar: state olduğu gibi restore edilir
```

**Offline altın davranışı:** Her slot yalnızca 1 kez tamamlanır — READY state otomatik
yeniden yüklenme yapmaz. Toplam offline altın = (READY olan slot sayısı) × her slotun
`gold_reward`'ı. Runtime'da ayrıca altın kırpma yapılmaz; cap `elapsed_for_slot`'un 8h
ile sınırlanmasıyla dolaylı olarak uygulanır. (bkz. F-3 — tasarım doğrulaması için)

### Interactions with Other Systems

| Sistem | Veri Akışı | Sahip |
|--------|-----------|-------|
| **Touch/Gesture Input** | `drag_dropped(oven_node)` → `receive_dough(recipe_id)` | Gesture → Oven |
| **Touch/Gesture Input** | `tapped(bread_node)` → `harvest(slot_id)` (context-resolution) | Gesture → Oven |
| **Economy System** | Hasat'ta `earn_gold(gold_reward)` çağrılır | Oven → Economy |
| **Time Tracking System** | `get_elapsed_seconds(last_timestamp)` — açılış offline hesabı | Oven → TimeManager |
| **Content Database** | `get_recipe(recipe_id)` → `bake_time_seconds`, `gold_reward` | Oven → ContentDB |
| **Save/Load System** | Slot durumları (`state`, `recipe_id`, `bake_start_timestamp`) kayıt/yükleme | Save ↔ Oven |
| **Upgrade Tree System** | `unlock_slot(slot_index)` → `active_slot_count` arttırılır | Upgrade → Oven |
| **Offline Production** | `get_offline_summary()` → hasat bekleyen ekmek listesi | Oven → OfflineProd |
| **Animation State Machine** | `bake_started(slot_id, recipe_id)` → fırın kapısı kapanır; `bake_completed(slot_id, recipe_id)` → parıltı + kapı açılır | Oven → ASM |

## Formulas

### F-1: Baking Progress Fraction

```
progress = clamp(1.0 - (remaining_seconds / bake_time_seconds), 0.0, 1.0)
```

| Değişken | Tip | Açıklama |
|----------|-----|----------|
| `remaining_seconds` | float | Timer'da kalan süre — `slot.timer.time_left` ile okunur |
| `bake_time_seconds` | float | Tariften gelen toplam pişirme süresi |
| `progress` | float [0.0, 1.0] | UI ilerleme çubuğu için |

**Örnek (bake_time = 30s):**

| Geçen süre | remaining | progress |
|-----------|-----------|---------|
| 0s | 30s | 0.00 |
| 10s | 20s | 0.33 |
| 15s | 15s | 0.50 |
| 30s | 0s | 1.00 |

---

### F-2: Gold Reward per Bake

```
gold_earned = recipe.base_gold_reward × efficiency_multiplier
```

| Değişken | Tip | Açıklama |
|----------|-----|----------|
| `base_gold_reward` | int | ContentDatabase'deki tarif verisi |
| `efficiency_multiplier` | float ≥ 1.0 | Çalışan bonusu veya upgrade'den gelen çarpan; varsayılan 1.0 |
| `gold_earned` | int | `floor()` ile tam sayıya yuvarlanır |

> `efficiency_multiplier` bu sistem tarafından hesaplanmaz — Employee System veya Upgrade Tree
> inject eder. Bu GDD'de varsayılan 1.0 kullanılır.

---

### F-3: Max Offline Gold — Tasarım Doğrulama Formülü

```
max_offline_gold_per_slot = gold_reward_of_recipe
total_max_offline_gold    = active_slot_count × max_gold_reward_among_slots
```

Bu formül **tasarım referansıdır** — runtime'da hesaplanmaz. Her slot yalnızca 1 kez
tamamlanır; dolayısıyla offline maksimum kazanım slot sayısı × en yüksek tarif ödülüdür.

| Değişken | Değer | Açıklama |
|----------|-------|----------|
| `OFFLINE_CAP_SECONDS` | 28800 | Her slot için max hesaplanan süre (8h) |
| `active_slot_count` | 1–4 | Açık slot sayısı |
| `max_gold_reward_among_slots` | TBD | ContentDatabase'de tanımlanacak (Recipe GDD D-10) |

**Örnek:** 4 slot, hepsi beyaz ekmek fırlatmış, `gold_reward = 10` → max offline = 4 × 10 = 40 altın.

---

### F-4: Offline Remaining Time per Slot

```
elapsed_for_slot          = clamp(now - bake_start_timestamp, 0.0, OFFLINE_CAP_SECONDS)
remaining_after_offline   = bake_time_seconds - elapsed_for_slot
```

| Değişken | Açıklama |
|----------|----------|
| `now` | `Time.get_unix_time_from_system()` — açılış anı |
| `bake_start_timestamp` | BakingSlot alanı — baking başladığındaki Unix timestamp |
| `OFFLINE_CAP_SECONDS` | 28800 (8h) |
| `bake_time_seconds` | Tariften okunan toplam süre |

- `remaining_after_offline ≤ 0` → slot READY
- `remaining_after_offline > 0` → Timer bu değerle yeniden başlatılır

## Edge Cases

| # | Durum | Davranış |
|---|-------|---------|
| E-1 | Dolu slota ikinci hamur sürüklenirse | `receive_dough()` çağrılmaz; drag `drag_cancelled` ile iptal edilir. Slot durumu değişmez. |
| E-2 | Tüm slotlar dolu iken hamur sürüklenmek istenirse | DropZone devre dışı (highlight yok); `drag_cancelled` emit edilir. |
| E-3 | EMPTY slottan `harvest()` çağrılırsa | No-op; sinyal emit edilmez; hata loglanır. |
| E-4 | Offline süre negatif (sistem saati geri sarıldı) | `clamp(elapsed, 0, CAP)` negatifi sıfırlar; Timer olduğu gibi devam eder. (Time Tracking Core Rule 4 ile tutarlı) |
| E-5 | Offline süre 8 saati (28800s) aşarsa | Elapsed 28800'e kırpılır; 8 saatin ötesi hesaplanmaz. |
| E-6 | `ContentDatabase`'de bulunmayan `recipe_id` ile `receive_dough()` çağrılırsa | `receive_dough()` false döner, slot EMPTY kalır; hata loglanır. Çalışma devam eder. |
| E-7 | Uygulama kapanırken Timer tam timeout anında ise | Kapanış timestamp'i kaydedilir; açılışta elapsed ≥ bake_time → READY. Çift tetikleme riski yok (Timer artık çalışmıyor). |
| E-8 | Upgrade Tree 4. slotu açınca bir slot zaten BAKING veya READY ise | Yeni slot EMPTY olarak eklenir; diğer slotların state'i değişmez. |
| E-9 | 4 slot aynı anda READY iken oyuncu harvestları birbiri ardına yaparsa | Her `harvest()` bağımsız `earn_gold()` çağrısı yapar; Economy sistemi sıralı çağrıları doğru işler (Economy Core Rule 3). |
| E-10 | Pişirme sırasında uygulama crash olursa (save fırsatı olmadan) | Açılışta bake_start_timestamp'e göre offline hesap yapılır; veri kaybı minimum. |
| E-11 | `harvest()` BAKING durumundaki slota çağrılırsa | No-op; sinyal emit edilmez; hata loglanır. Timer devam eder. |
| E-12 | `harvest()` READY durumundaki slota ikinci kez çağrılırsa (race condition) | Slot zaten EMPTY'e dönmüş; no-op; sinyal emit edilmez; hata loglanır. |

## Dependencies

### Upstream (Bu sistem bunlara bağımlı)

| Sistem | Bağımlılık Tipi | Arayüz |
|--------|-----------------|--------|
| **Time Tracking System** | Zorunlu (hard) | `TimeManager.get_elapsed_seconds(last_timestamp: int) → float` |
| **Economy System** | Zorunlu (hard) | `EconomySystem.earn_gold(amount: int) → void` |
| **Content Database** | Zorunlu (hard) | `ContentDatabase.get_recipe(recipe_id) → {bake_time_seconds, gold_reward, …}` |
| **Save/Load System** | Zorunlu (hard) | Slot durumları `save_data` içinde persist edilir |

### Downstream (Bunlar bu sisteme bağımlı)

| Sistem | Beklenen Sinyal / API | Tetiklenen Aksiyon |
|--------|----------------------|-------------------|
| **Touch/Gesture Input** | `drag_dropped(oven_node)` → `receive_dough(recipe_id)` | Pişirme başlatma |
| **Touch/Gesture Input** | `tapped(bread_node)` → `harvest(slot_id)` | Hasat |
| **Offline Production System** | `get_offline_summary() → slot_list` | Açılış ekranı özeti |
| **Animation State Machine** | `bread_ready(slot_id, recipe_id)` | Fırın parıltı/kapı animasyonu |
| **Upgrade Tree System** | `unlock_slot(slot_index: int)` → `active_slot_count += 1` | Slot kilidi açma |
| **Employee System** | `efficiency_multiplier: float` inject eder | Altın çarpanı |

### Bağımlılık Notları

- Content Database GDD (D-02) tarif şemasını tanımlar. `bake_time_seconds` ve `base_gold_reward`
  bu GDD onaylanmadan kesin değer alamaz; bu GDD'de `TBD` olarak işaretlendi.
- Upgrade Tree (D-12) `unlock_slot()` API'sini çağırır; bu API bu GDD'de tanımlanmıştır.

---

## Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Çok Düşükse | Çok Yüksekse |
|-----------|-----------|----------------|-------------|--------------|
| `MAX_SLOT_COUNT` | 4 | 2–6 | Az çeşitlilik; tek slot mono-gameplay | Çok fazla yönetim — ASMR hissi kaybolur |
| `STARTING_SLOT_COUNT` | 1 | 1–2 | — (minimum 1 gerekli) | Upgrade motivasyonu azalır |
| `OFFLINE_CAP_SECONDS` | 28800 (8h) | 14400–86400 | Kısa offline → oyun bırakılır | Sonsuz üretim hissi → daily loop motivasyonu düşer |
| `MIN_BAKE_TIME_SECONDS` | 8s | 5–15s | Çok hızlı; hasat dönemi olmadan sürekli yükleme yorar | Temel tarif bile yavaş hissettiriyor |
| `MAX_BAKE_TIME_SECONDS` | 60s | 30–300s | Tüm tarifler benzer hissettiriyor | Uzun bekleme; idle değil bored hissi |
| `GOLD_PER_SECOND_BASE` | TBD | — | Ekonomi dengesiyle belirlenir (D-10 Recipe GDD) | — |

### Tarif Süresi Referans Tablosu (Tasarım Hedefleri)

| Kategori | Bake Time | Notlar |
|----------|-----------|--------|
| Temel (beyaz ekmek, vb.) | 8–15s | Aktif oturum içinde birden fazla tur yapılabilir |
| Dünya tarifleri | 20–45s | 1 oturumda 1–2 tur |
| Özel tarifler | 45–90s | Sabır gerektiriyor; reward daha yüksek |
| Efsanevi | 120–300s | Offline döngüsü için tasarlanmış |

## Visual/Audio Requirements

- **BAKING:** Fırın kapısı kapalı + sıcaklık shimmer efekti (ASM sorumluluğu)
- **READY:** Slot parlama animasyonu + SFX `bread_ready` (AudioBus: SFX, öncelik HIGH)
  + hafif haptic 50ms (haptic_enabled = true ise)
- **Hasat:** SFX `bread_harvest` + coin animasyonu (Economy sinyal üzerine ASM tetikler)
- **Offline açılış:** Birden fazla slot READY ise overlay ekranında "X ekmek hazır!" bildirimi
  (Offline Production System sorumluluğu)

---

## UI Requirements

- Her slot görsel olarak ayrı; state'e göre renk/ikon değişir (EMPTY: gri, BAKING: turuncu, READY: altın)
- BAKING slot'unda pişirme ilerleme çubuğu görünür (F-1 progress fraction → UI binding)
- READY slot dokunma alanı minimum 44×44 px
- Kilitli slotlar (upgrade henüz alınmadı) lock ikonu ile gösterilir; tappable değil

---

## Acceptance Criteria

### Temel Pişirme Döngüsü

- [ ] **AC-01:** `receive_dough("white_bread")` → 8s sonra `bread_ready(slot_id, "white_bread")`
      sinyali tam 1 kez emit edilir. GUT: Timer mock ile doğrula.
- [ ] **AC-02:** READY durumunda `harvest(slot_id)` çağrısı → `EconomySystem.earn_gold(reward)`
      çağrılır → `bread_harvested` sinyali emit edilir → slot EMPTY'e döner.
- [ ] **AC-03:** Dolu slota `receive_dough()` çağrısı no-op döner; slot state değişmez.
- [ ] **AC-04:** 4 slot bağımsız olarak aynı anda farklı tarifleri pişirebilir; birinin tamamlanması
      diğerlerini etkilemez.

### Offline Pişirme

- [ ] **AC-05:** `bake_start_timestamp = T`, `bake_time = 30s`, açılış `T + 45s` → slot READY;
      `bread_ready` sinyali emit edilir. GUT: TimeManager mock'u.
- [ ] **AC-06:** `bake_start_timestamp = T`, `bake_time = 30s`, açılış `T + 15s` → slot BAKING;
      Timer 15s kalan süre ile yeniden başlar.
- [ ] **AC-07:** Elapsed 28800s (8h) aşarsa kırpılır; slotlar 8h hesabına göre işlenir. GUT: 100000s
      elapsed inject ederek elapsed = 28800 olduğunu assert et.

### Slot Yönetimi

- [ ] **AC-08:** Başlangıçta 1 slot aktif. `unlock_slot(1)` → 2 slot aktif; slot 0 ve 1 kullanılabilir.
- [ ] **AC-09:** `unlock_slot(4)` (index 4 = 5. slot) → no-op; `active_slot_count` 4'ü geçmez.

### Ekonomi Entegrasyonu

- [ ] **AC-10:** 4 slot aynı anda READY → ardışık 4 `harvest()` → toplam altın = 4 × `gold_reward`;
      `EconomySystem.earn_gold()` 4 kez çağrılır.

### Performans

- [ ] **AC-11:** 4 slot BAKING iken `_process()` çağrı izleri yok (Godot Profiler → Scripts).
- [ ] **AC-12:** 100 bake döngüsü sonrası memory leak yok.

---

## Open Questions

| # | Soru | Sahip | Hedef |
|---|------|-------|-------|
| OQ-01 | `base_gold_reward` değerleri tarif bazında ne olmalı? Recipe GDD (D-10) kesinleştirecek. | Recipe GDD | D-10 tasarlanınca |
| OQ-02 | `efficiency_multiplier` ne zaman ve kim tarafından inject edilir? Employee GDD (D-13) + Upgrade Tree GDD (D-12). | D-12 / D-13 | İlgili GDD'ler tasarlanınca |
| OQ-03 | Offline açılış overlay'i (birden fazla READY slot) nasıl gösterilmeli? Offline Production GDD (D-16) kapsıyor. | D-16 | D-16 tasarlanınca |
| OQ-04 | Efsanevi tariflerin 5 dakika (300s) pişirme süresi idle döngüye uyuyor mu? Recipe balance D-10'da doğrulanacak. | economy-designer | D-10 balance review |
| OQ-05 | Save/Load GDD OQ-2: `oven_state` geçici formatı `{slot_id: {recipe_id, start_time_unix, is_active}}` bu GDD'nin veri modeliyle (`bake_start_timestamp`, `state` enum) güncellenmeli. Save/Load GDD onaylanmadan önce yapılacak. | Save/Load GDD | D-09 onaylanınca |
