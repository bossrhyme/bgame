# Animation State Machine

> **Status**: Draft Complete
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-04
> **Implements Pillar**: ASMR & Tactile Feel — "Her tap bir şeyi ilerletmeli"

## Overview

Animation State Machine, Ekmek Ustası'ndaki tüm gameplay animasyonlarının koordinasyon
merkezidir: hamur yoğurma, fırın üretim döngüsü, hasat, müşteri hareketleri ve para
efektleri. Her sahne nesnesi kendi `AnimationPlayer` bileşenini barındırır; hamur gibi
çok katmanlı geçiş gerektiren nesneler `AnimationTree` ile yönetilir. Sistem, oyun
mekaniği olaylarına (gesture tamamlandı, pişirme bitti, müşteri geldi) tepki olarak
doğru animasyon durumunu tetikler ve `Settings`'ten gelen `battery_saver` bayrağına
göre animasyon kalitesini otomatik olarak ayarlar. ASMR odaklı tasarım gereği her
animasyon belirli bir "his" hedefi taşır: hamur kabarma hipnotik, fırından çıkış
tatmin edici, para animasyonu ödüllendirici hissettirmelidir.

## Player Fantasy

Animation State Machine oyuncunun farkında olmadığı ama her dokunuşta hissettiği bir
sistemdir. Doğru çalıştığında oyuncu şunu hisseder: *"Bu fırın canlı — hamur ellerin
altında gerçekten şekilleniyor, fırından çıkan ekmek gerçekten altın rengi kazanıyor."*
Her animasyon kasıtlı olarak bir duyguya hizmet eder:

- **Hamur yoğurma:** Hipnotik, döngüsel. Parmak kaldırılana kadar devam etmek istenir.
  ASMR hissinin kaynağı.
- **Fırına atış:** Ağır, kalıcı. Kapının gıcırtısı ve ekmeğin içeri kayması "bir şey
  başladı" hissi verir.
- **Hasat tap:** Kuru, tok, anlık tatmin. Her tap bir küçük ödüldür.
- **Para animasyonu:** Coinlerin havada dönerek sayaca gitmesi — sayı artışını görmek
  değil, *hissetmek*.

Yanlış çalıştığında (animasyon kısa kesiliyor, geçiş patlıyor, FPS düşünce hareketler
sertleşiyor) oyuncu ASMR hissini kaybeder ve oyun "mekanik" hisseder.

## Detailed Design

### Core Rules

1. **Dağıtık sahip modeli.** Her animasyonlu nesne kendi `AnimationPlayer` bileşenini
   barındırır. Merkezi kontrol düğümü yoktur; `AnimationManager` autoload yalnızca
   global kalite modunu (battery_saver) yayar.
2. **`AnimationTree` yalnızca hamur için.** Hamur `AnimationTree + StateMachinePlayback`
   kullanır — diğer tüm nesneler doğrudan `AnimationPlayer.play()` çağrısı yapar.
3. **Olay-tetiklemeli.** Tüm animasyon geçişleri sinyal/metod çağrısıyla gelir;
   `_process()` içinde animasyon durumu sorgulanmaz veya değiştirilmez (ADR-0003 uyumu).
4. **Crossfade geçiş.** `AnimationPlayer.play(name, blend_time)` parametresi ile iki
   animasyon arasında crossfade uygulanır. Varsayılan blend süreleri Tuning Knobs
   tablosunda tanımlanır.
5. **battery_saver kalite modu.** `AnimationManager`, `Settings`'ten `battery_saver`
   bayrağını startup'ta ve değişimde okur:
   - `false` (60 FPS): Blend süreleri aktif; `GPUParticles2D` düğümleri etkin.
   - `true` (30 FPS): Tüm blend süreleri `0.0` (anlık kesme); `GPUParticles2D.emitting = false`.
     `speed_scale` değişmez. Coin animasyonu tamamen atlanır — yalnızca sayaç güncellenir.
6. **Animasyon isimlendirme.** `"nesne_durum"` snake_case formatı: `"dough_kneading"`,
   `"oven_door_opening"`, `"coin_fly"`.
7. **Tamamlanma sinyali.** Animasyon bitişini gereken yerde `animation_finished`
   sinyali dinlenir. Polling yapılmaz.
8. **Kesme koruması.** Henüz tamamlanmamış animasyona yeni animasyon tetiklenirse
   blend süresi ≥ 0.1 sn olmalı (anlık pop yaşanmasın). İstisnalar: müşteri TIMEOUT
   ve para ABSORBED anlık kesme uygular.

---

### States and Transitions

#### 1. Hamur (`AnimationTree — StateMachinePlayback`)

| Durum | Animasyon | Süre | Giriş | Çıkış |
|-------|-----------|------|-------|-------|
| `IDLE` | `dough_idle` — hafif nefes bob | Döngü | Başlangıç / hasat sonrası | Gesture başladı |
| `KNEADING` | `dough_kneading` — genişle/daral döngüsü | Döngü (≥ 3×) | Döngüsel gesture aktif | 3. döngü tamamlandı |
| `READY` | `dough_ready` — yavaş şişme + titreme | 8–12 sn | 3 gesture döngüsü bitti | Fırına sürüklendi |
| `SHAPING` | `dough_shaping` — forma geçiş | Gesture süresi | Long-press + drag aktif | Bırakıldı |
| `OVEN_LOADING` | `dough_slide_in` — arc hareketi fırına | 0.5 sn | Fırın DropZone'a bırakıldı | `animation_finished` → nesne deactivate |

**Hamur drag-to-oven detayı:**
- Oyuncu READY hamuru sürüklemeye başlayınca hamur parmağı Tween ile takip eder
  (animasyon değil — pozisyon interpolasyonu)
- Bırakma noktası fırın `DropZone` içindeyse: `OVEN_LOADING` tetiklenir; `dough_slide_in`
  hamuru fırın kapısına arc yayı çizerek taşır
- Bırakma noktası `DropZone` dışındaysa: `dough_return` animasyonu (0.3 sn) orijinal
  konuma döner; `READY` durumu korunur
- `OVEN_LOADING` sırasında yeni gesture kabul edilmez (input blok)

---

#### 2. Fırın Kapısı (`AnimationPlayer`)

```
CLOSED
  → [bake_started] → OPENING (1 sn, kapı gıcırtısı)
  → OPEN (dough_slide_in oynuyor)
  → [dough_slide_in bitti] → CLOSING (1 sn) → CLOSED

  → [bake_completed] → OPENING (1 sn)
  → OPEN (bread_slide_out oynuyor)
  → [bread_slide_out bitti] → CLOSING (1 sn) → CLOSED
```

OPENING sırasında yeni açma isteği gelirse yoksayılır; mevcut geçiş tamamlanır.

---

#### 3. Hasat Ekmeği (`AnimationPlayer`)

| Durum | Animasyon | Süre | Not |
|-------|-----------|------|-----|
| `BAKED` | `bread_idle` — fırında sabit, buhar parçacığı | Döngü | Tap bekleniyor |
| `SLIDING` | `bread_slide_out` — arc hareketi vitrine | 0.5 sn | Hasat tap'ta tetiklenir |
| `DISPLAY` | `bread_display` — vitrine yerleşti, hafif parıltı | Döngü | Sipariş bekleniyor |
| `SOLD` | `bread_sold` — hızlı kaybolma | 0.2 sn | Sipariş karşılandı |

**Hasat edge case'leri:**

| Durum | Davranış |
|-------|----------|
| Vitrin dolu, yeni ekmek pişti | `bread_slide_out` oynanmaz; ekmek `BAKED` kalır; HUD uyarı gösterir |
| SLIDING sırasında ikinci tap | Yoksayılır; tek ekmek tek kez taşınır |
| SLIDING sırasında uygulama arka plana | Animasyon durdurulur; açılışta `DISPLAY` durumundan devam edilir |
| Birden fazla ekmek aynı anda hasat | Her biri bağımsız `AnimationPlayer`; paralel çalışır |

---

#### 4. Para / Coin Animasyonu (`AnimationPlayer`)

`Economy.gold_changed` sinyalinde delta > 0 olduğunda tetiklenir. `AnimationManager`
önceki bakiyeyi kendi state'inde tutarak delta'yı hesaplar (Economy GDD R-3 notu).

| Durum | Animasyon | Süre | Detay |
|-------|-----------|------|-------|
| `SPAWN` | `coin_spawn` — kazanım noktasında pop | 0.1 sn | Ekmek/sipariş noktasında doğar |
| `FLYING` | `coin_fly` — arc yayı sayaca | 0.8 sn | Fan şeklinde ardışık 0.1 sn aralıkla |
| `ABSORBED` | — (node `queue_free`) | — | Sayaç güncelleme animasyonu ayrıca tetiklenir |

**Coin sayısı (delta'ya göre):**

| Kazanım | Coin sayısı |
|---------|------------|
| 1–50 altın | 1 |
| 51–500 altın | 3 |
| 501–2.000 altın | 5 |
| 2.001+ altın | 8 (maksimum) |

battery_saver modunda coin animasyonu tamamen atlanır (Rule 5).

---

#### 5. Müşteri (`AnimationPlayer`) — *Provisional: Customer/Order GDD yazılmadan önce*

| Durum | Animasyon | Süre | Giriş | Çıkış |
|-------|-----------|------|-------|-------|
| `ENTERING` | `customer_enter` — slide-in | 0.4 sn | Spawn tetiklendi | Animasyon bitti |
| `WAITING` | `customer_idle` — hafif bob döngüsü | Döngü | ENTERING bitti | Sipariş karşılandı / süre doldu |
| `IMPATIENT` | `customer_impatient` — ayak sallama | Döngü | Sabır < %30 | Sipariş verildi / süre doldu |
| `HAPPY` | `customer_happy` — zıplama, yıldız | 0.6 sn | Zamanında teslim | `LEAVING` |
| `DISAPPOINTED` | `customer_disappointed` — omuz düşürme | 0.4 sn | Geç teslim | `LEAVING` |
| `LEAVING` | `customer_leave` — slide-out | 0.5 sn | HAPPY / DISAPPOINTED bitti | `queue_free` |
| `TIMEOUT` | `customer_leave` (hızlı) | 0.25 sn | Sabır tamamen doldu | `queue_free` + memnuniyet -10 |

- WAITING → IMPATIENT blend: 0.3 sn
- IMPATIENT → HAPPY/DISAPPOINTED: anlık kesme (tatmin hissi)
- TIMEOUT, normal LEAVING'ten 2× hızlı çalışır

---

### Interactions with Other Systems

| Sistem | ASM'den Aldığı | ASM'e Verdiği | Arayüz |
|--------|---------------|---------------|--------|
| **Settings** | — | `battery_saver: bool` | `SettingsManager.battery_saver_changed` sinyali |
| **Touch/Gesture** | — | Gesture olayları (döngü, long-press, drop) | Sinyal → hamur `AnimationTree` state |
| **Oven/Baking** | — | `bake_started`, `bake_completed` | Kapı + ekmek animasyonu tetikler |
| **Economy** | — | `gold_changed(new_balance)` | Coin delta hesabı + animasyon tetikler |
| **Customer/Order** *(provisional)* | — | Müşteri durum değişimi sinyalleri | Customer/Order GDD yazılınca kesinleşir |
| **VFX/Particle** *(provisional)* | `GPUParticles2D.emitting` flag | — | `battery_saver` bayrağı üzerinden |
| **Sound & Animation** *(provisional)* | Animasyon track event callback'leri | — | `AnimationPlayer` track event |

## Formulas

Animation State Machine doğrudan oyun mekaniği hesabı yapmaz. İki pratik hesap vardır:

### F-1: Gold Delta (Coin Animasyonu İçin)

```
delta = new_balance - prev_balance
prev_balance = new_balance   # AnimationManager state güncellenir
```

`delta ≤ 0` ise coin animasyonu tetiklenmez.

### F-2: Coin Spawn Sayısı

```
coin_count = 1   if delta ≤ 50
coin_count = 3   if 51 ≤ delta ≤ 500
coin_count = 5   if 501 ≤ delta ≤ 2000
coin_count = 8   if delta > 2000   # maksimum
```

### F-3: Coin Fan Gecikme

```
spawn_delay(i) = i × COIN_FAN_INTERVAL_SEC   # varsayılan: 0.1 sn
# i = 0..coin_count-1
```

Örnek: `coin_count = 5` → coinler 0.0s, 0.1s, 0.2s, 0.3s, 0.4s aralıklarıyla fırlatılır.

## Edge Cases

| # | Durum | Beklenen Davranış |
|---|-------|-------------------|
| 1 | `battery_saver` uygulama çalışırken değiştirilirse | `AnimationManager` sinyali anında alır; blend=0.0, `GPUParticles2D.emitting=false` — mevcut animasyon kesilmez, sonraki geçişten itibaren etkin |
| 2 | Aynı nesne üzerinde animasyon oynarken `play()` tekrar çağrılırsa | Blend süresi ≥ 0.1 sn ile crossfade; TIMEOUT/ABSORBED istisnalarında anlık kesme |
| 3 | Hamur `OVEN_LOADING` sırasında uygulama kapanırsa | Animasyon yeniden başlatılmaz; açılışta hamur sahnesi görünmez — Oven/Baking sistemi kendi state'ini restore eder |
| 4 | Çok hızlı ardışık `gold_changed` sinyalleri | Her sinyal bağımsız coin seti spawn eder; çakışan coin grupları kabul edilen davranış; maximum 8 coin × sinyal sayısı draw call eklenir |
| 5 | `dough_ready` tamamlanmadan yeni gesture gelirse | KNEADING'e geri dönülür; `READY` olmayan hamur fırına sürüklenemez (input guard aktif) |
| 6 | Müşteri ENTERING sırasında sipariş iptal edilirse | ENTERING → LEAVING blend geçişi (0.3 sn); müşteri tam yerleşmeden ayrılır |
| 7 | Vitrin doluyken hasat tap | `bread_slide_out` oynanmaz; ekmek `BAKED` kalır; HUD "Vitrin dolu!" uyarısı tetiklenir |
| 8 | 4 müşteri aynı anda IMPATIENT | Her biri bağımsız `AnimationPlayer`; paralel döngüler; draw call bütçesi (≤ 100) aşılmamalı |
| 9 | `AnimationPlayer` referansı null (eksik bileşen) | `push_error` ile log; animasyon atlanır; gameplay devam eder |
| 10 | `dough_return` oynarken yeni gesture | Yoksayılır; `dough_return` tamamlanana kadar input blok |

## Dependencies

### Upstream — ASM'ye Veri Sağlayan Sistemler

| # | Sistem | Bağımlılık Tipi | Interface | Notlar |
|---|--------|-----------------|-----------|--------|
| 1 | **Settings & Preferences** | Hard | `SettingsManager.battery_saver_changed(value: bool)` sinyali | Startup'ta bir kez + değişimde alınır; ASM `user://settings.cfg` doğrudan okumaz |
| 2 | **Economy System** | Hard | `Economy.gold_changed(new_balance: int)` sinyali | AnimationManager `prev_balance` önbelleğiyle delta hesaplar (F-1, F-2) |
| 3 | **Touch/Gesture Input** | Hard | `gesture_loop_completed`, `gesture_long_press_started`, `gesture_drag_released(position: Vector2)` | Hamur `AnimationTree` state geçişlerini tetikler; sinyal isimleri Touch/Gesture GDD yazılınca kesinleşir |
| 4 | **Oven/Baking System** | Hard | `OvenBaking.bake_started(oven_id: int)`, `OvenBaking.bake_completed(oven_id: int)` | Fırın kapısı ve ekmek animasyonunu tetikler |
| 5 | **Customer/Order System** | Soft | `customer_spawned`, `customer_served(timing: String)`, `customer_patience_changed(ratio: float)`, `customer_timeout` | GDD yazılmadan önce — provisional; sinyal imzaları değişebilir |

### Downstream — ASM'nin Kontrol İlettiği Sistemler

| # | Sistem | Bağımlılık Tipi | Interface | Notlar |
|---|--------|-----------------|-----------|--------|
| 6 | **VFX/Particle System** | Soft | `GPUParticles2D.emitting: bool` doğrudan ayarlanır; referans sahne yüklendiğinde inject edilir | GDD yazılmadan önce — provisional |
| 7 | **Sound & Animation System** | Soft | `AnimationPlayer` track event callback'leri; ses tetikleme ASM'nin sorumluluğu değil | GDD yazılmadan önce — provisional |
| 8 | **UI/HUD System** | Soft | `AnimationManager.coin_absorbed` sinyali — sayaç güncelleme animasyonunu HUD kendi tetikler | HUD GDD yazılmadan önce — provisional |

**Hard:** ASM bu sistem olmadan başlatılamaz veya temel işlev göremez.
**Soft:** ASM bu sistem olmadan çalışmaya devam eder; ilgili özellik devre dışı kalır veya atlanır.

## Tuning Knobs

| Sabit | Varsayılan | Güvenli Aralık | Çok düşükse | Çok yüksekse | Sahip |
|-------|-----------|----------------|-------------|--------------|-------|
| `COIN_FAN_INTERVAL_SEC` | `0.1` sn | 0.05 – 0.25 sn | Coinler art arda pop görünür; "fan" hissi kaybolur | Coin animasyonu çok uzar; oyuncu beklemek zorunda kalır | AnimationManager |
| `COIN_SPAWN_THRESHOLD_1` | `50` altın | 10 – 100 | Tek coin çok sık görünür; sıradan hissettir | Küçük kazanımlar hiç coin almaz | Economy/Denge |
| `COIN_SPAWN_THRESHOLD_2` | `500` altın | 100 – 1.000 | 3-coin grubu çok erken tetiklenir | Orta kazanımlar tek coin alır; görsel karşılık zayıf | Economy/Denge |
| `COIN_SPAWN_THRESHOLD_3` | `2.000` altın | 500 – 5.000 | 5-coin grubu sıradan kazanımlarda görünür | Büyük kazanımlar görsel olarak kutlanamaz | Economy/Denge |
| `COIN_FLYING_DURATION` | `0.8` sn | 0.4 – 1.2 sn | Coin sayaca "ışınlanır"; tatmin azalır | Coin çok yavaş; oyuncu sıradaki aksiyonu bekler | AnimationManager |
| `DOUGH_READY_MIN_SEC` | `8.0` sn | 4.0 – 12.0 sn | READY animasyonunun hipnotik etkisi görülmez | Oyuncu idle döngüsünü çok uzun bekler | Gameplay/Denge |
| `DOUGH_READY_MAX_SEC` | `12.0` sn | 8.0 – 20.0 sn | MIN–MAX aralığı dar; süre öngörülebilir | Oyuncu beklentiden uzun sürdü hisseder | Gameplay/Denge |
| `OVEN_DOOR_DURATION` | `1.0` sn | 0.5 – 1.5 sn | Kapı "patlar"; kalıcı his kaybolur | Kapı çok yavaş; bekleme süresi artar | AnimationManager |
| `BREAD_SLIDE_DURATION` | `0.5` sn | 0.25 – 0.8 sn | Arc çok kısa; hasat tatmini azalır | Arc çok yavaş; zincirleme hasatta gecikme birikir | AnimationManager |
| `CUSTOMER_ENTER_DURATION` | `0.4` sn | 0.2 – 0.6 sn | Müşteri "zıplar"; doğallık kaybolur | Müşteri ekrana çok yavaş girer; tempo düşer | AnimationManager |
| `CUSTOMER_LEAVE_DURATION` | `0.5` sn | 0.3 – 0.8 sn | Ayrılış fark edilmez | Yeni müşteri slot'u serbest kalması gecikmeli hisseder | AnimationManager |
| `CUSTOMER_TIMEOUT_DURATION` | `0.25` sn | 0.15 – 0.4 sn | Timeout normal ayrılıştan ayırt edilemez | Sabırsız müşteri yeterince dramatik ayrılmaz | AnimationManager |
| `IMPATIENT_THRESHOLD` | `0.30` | 0.15 – 0.50 | Müşteri çok erken IMPATIENT; baskı bunaltıcı | Süre uyarısı etkinliğini kaybeder | Gameplay/Denge |
| `BLEND_STANDARD` | `0.2` sn | 0.1 – 0.3 sn | Geçiş pop görünür | İki animasyon uzun süre üst üste biner | AnimationManager |
| `BLEND_FAST` | `0.1` sn | 0.05 – 0.2 sn | `BLEND_INSTANT` ile fark kalmaz | `BLEND_STANDARD` ile değer çakışır | AnimationManager |
| `BLEND_INSTANT` | `0.0` sn | Sabit | — | Sabit; battery_saver ve istisna geçişler için | AnimationManager |

## Visual/Audio Requirements

### Animasyon Varlıkları

Her state için animasyon artist tarafından üretilmesi gereken varlıklar:

| Varlık | Format | Loop | Notlar |
|--------|--------|------|--------|
| `dough_idle` | Sprite sheet / AnimationPlayer track | Evet | Hafif nefes bob; 2–3 sn döngü |
| `dough_kneading` | Sprite sheet | Evet | 1 döngü = 1 gesture turu; 3 tur = READY |
| `dough_ready` | Sprite sheet | Evet | 8–12 sn; ASMR hipnotik his |
| `dough_shaping` | Sprite sheet | Hayır | Gesture süresiyle eşlenecek; blendable |
| `dough_slide_in` | AnimationPlayer (position + scale track) | Hayır | 0.5 sn arc; fırın kapısına kadar |
| `dough_return` | AnimationPlayer (position track) | Hayır | 0.3 sn orijinal konuma geri |
| `oven_door_opening` | Sprite sheet veya bones | Hayır | 1 sn; kapı gıcırtısı SFX eşleşmeli |
| `oven_door_closing` | (yukarısının tersi) | Hayır | 1 sn |
| `bread_idle` | Sprite sheet | Evet | Buhar parçacığı `GPUParticles2D` |
| `bread_slide_out` | AnimationPlayer (position + scale track) | Hayır | 0.5 sn arc vitrine |
| `bread_display` | Sprite sheet | Evet | Hafif parıltı döngüsü |
| `bread_sold` | Sprite sheet | Hayır | 0.2 sn hızlı kaybolma |
| `coin_spawn` | Sprite sheet | Hayır | 0.1 sn pop |
| `coin_fly` | AnimationPlayer (position + rotation track) | Hayır | 0.8 sn arc; 8 varyant (fan açıları) |
| `customer_enter` | Sprite sheet | Hayır | 0.4 sn slide-in |
| `customer_idle` | Sprite sheet | Evet | Bob döngüsü |
| `customer_impatient` | Sprite sheet | Evet | Hızlı ayak sallama |
| `customer_happy` | Sprite sheet | Hayır | 0.6 sn; yıldız efekti ayrı particle |
| `customer_disappointed` | Sprite sheet | Hayır | 0.4 sn |
| `customer_leave` | Sprite sheet | Hayır | 0.5 sn slide-out |

### Ses Eşleştirme

Ses tetikleme `AnimationPlayer` `call_method` track event'leriyle Sound & Animation sistemine delege edilir. ASM doğrudan ses çalmaz.

| Animasyon | Ses Event | Zamanlama |
|-----------|-----------|-----------|
| `oven_door_opening` | `sfx_door_creak` | Frame 0 |
| `oven_door_closing` | `sfx_door_slam` | Son frame |
| `bread_slide_out` | `sfx_bread_plop` | Frame 0 |
| `coin_spawn` | `sfx_coin_pop` | Frame 0 |
| `coin_absorbed` | `sfx_coin_ding` | `queue_free` öncesi |
| `customer_happy` | `sfx_customer_cheer` | Frame 0 |
| `customer_timeout` | `sfx_customer_grumble` | Frame 0 |

## UI Requirements

- **HUD "Vitrin dolu!" uyarısı:** Ekmek `BAKED` state'te kalırken hasat tap gelirse HUD uyarı tetiklenir. Format ve süre UI/HUD GDD yazılınca kesinleşir (OQ-03).
- **Coin sayaç animasyonu:** `coin_absorbed` sinyalinde HUD sayaç kendi güncelleme animasyonunu tetikler. Animasyon ASM'nin sorumluluğu değil.
- **Sabır göstergesi:** Müşteri `IMPATIENT` state'ine geçtiğinde UI sabır çubuğu görsel değişim gösterir. Bağlantı Customer/Order GDD ile kesinleşir.

## Acceptance Criteria

| # | Kriter | Test Yöntemi |
|---|--------|--------------|
| AC-01 | `battery_saver=true` iken animasyon geçişi tetiklendiğinde blend süresi `0.0` sn olur | GUT: `battery_saver_changed(true)` gönder; `last_blend_time == 0.0` assert et |
| AC-02 | `battery_saver=true` iken sahne içindeki tüm `GPUParticles2D.emitting == false` | GUT: sinyal sonrası tüm particles düğümlerini tara; `emitting` assert et |
| AC-03 | `battery_saver=true` iken `gold_changed` sinyalinde coin node spawn edilmez | GUT: sinyal gönder; coin node sayısı == 0 assert et |
| AC-04 | `battery_saver=false` iken geçiş blend süresi `BLEND_STANDARD (0.2 sn)` değerini alır | GUT: `battery_saver_changed(false)` sonrası geçiş tetikle; `last_blend_time == 0.2` assert et |
| AC-05 | 3 gesture döngüsü tamamlandığında `AnimationTree` state `READY`'e geçer | GUT: `gesture_loop_completed` sinyalini 3× emit et; `StateMachinePlayback.get_current_node() == "READY"` assert et |
| AC-06 | READY hamuru `DropZone` dışına bırakınca `dough_return` oynar ve state `READY` kalır | GUT: `gesture_drag_released(out_of_zone_pos)` emit et; animasyon ve state assert et |
| AC-07 | READY hamuru `DropZone` içine bırakınca `dough_slide_in` oynar ve `OVEN_LOADING` state'e geçilir | GUT: `gesture_drag_released(in_zone_pos)` emit et; animasyon ve state assert et |
| AC-08 | `gold_changed` ile delta = 300 (eşik: 51–500) → tam 3 coin spawn edilir | GUT: `Economy.gold_changed(prev + 300)` emit et; coin node sayısı == 3 assert et |
| AC-09 | `gold_changed` ile delta ≤ 0 → hiç coin spawn edilmez | GUT: negatif ve sıfır delta ile sinyal gönder; coin node sayısı == 0 assert et |
| AC-10 | 3. coin, ilk coinden `2 × COIN_FAN_INTERVAL_SEC (0.2 sn)` sonra spawn edilir | GUT: timer mock ile gecikmeyi simüle et; `spawn_time[2] - spawn_time[0] >= 0.2` assert et |
| AC-11 | Vitrin dolu iken hasat tap → `bread_slide_out` oynanmaz; ekmek `BAKED` kalır | GUT: vitrin dolu durumunu simüle et, tap sinyali gönder; `current_animation != "bread_slide_out"` assert et |
| AC-12 | Müşteri sabır oranı `IMPATIENT_THRESHOLD (0.30)` altına düştüğünde `IMPATIENT` state'e geçilir | GUT: `customer_patience_changed(0.29)` emit et; state ve animasyon adını assert et |
| AC-13 | `AnimationPlayer` referansı `null` olan nesnede animasyon tetiklendiğinde `push_error` çağrılır; gameplay devam eder | GUT: `AnimationPlayer`'sız sahne node'u ver, tetikle; hata raporlandı + sonraki frame çalışıyor assert et |
| AC-14 | `_process()` override'ı içinde `AnimationPlayer.play()` veya animasyon state değişikliği yapılmaz | Statik kod incelemesi: ASM `.gd` dosyalarında `_process` bloğu içinde `AnimationPlayer.play()` çağrısı bulunmamalı |

## Open Questions

| # | Soru | Sahip | Hedef |
|---|------|-------|-------|
| OQ-01 | AC-10 için coin fan gecikme testi gerçek zamana mı bağlanacak yoksa `timer_factory` enjeksiyonuyla mı mock'lanacak? Injection mimarisi Lead Programmer onayı gerektiriyor. | Lead Programmer | Customer/Order GDD'den önce |
| OQ-02 | Müşteri animasyon sinyallerinin kesin imzaları: `customer_served(timing: String)` mi yoksa enum mi? Customer/Order GDD yazılınca bu bölüm provisional'dan çıkar. | Game Designer | Customer/Order GDD sırasında |
| OQ-03 | Vitrin dolu durumunda HUD "Vitrin dolu!" uyarısı hangi format ve süreyle gösterilir? (toast mu, inline uyarı mı?) | UX Designer | UI/HUD GDD sırasında |
