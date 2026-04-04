# Time Tracking System

> **Status**: Designed — Pending Review
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-04
> **Implements Pillar**: Idle Progression — "geri döndüğünde fırın onu bekliyor olur"

## Overview

Time Tracking System, Ekmek Ustası'ndaki tüm zaman-bazlı ilerlemenin temelidir.
İki ayrı katmandan oluşur:

**(1) Offline Süre Katmanı** — `Time.get_unix_time_from_system()` ile uygulama
kapanış/açılış zaman damgaları arasındaki farkı hesaplar; bu değeri Oven/Baking,
Employee ve Offline Production sistemleri çeker.

**(2) Aktif Timer Katmanı** — pişirme süreleri, müşteri sabır sayaçları ve çalışan
maaş döngüleri için Godot `Timer` node'ları kullanılır; her sistem kendi
`Timer`'ını sahnesinde barındırır.

`TimeManager` autoload, yalnızca geçen süreyi hesaplayan saf bir servis
katmanıdır — veri depolamaz. Save/Load sistemi tarafından kaydedilen
son-kapanma zaman damgasını okur ve `elapsed_seconds: float` döner. Oyuncu
uygulamayı kapattığında ilerleme durmaz; geri döndüğünde tüm offline üretim
bu sistemin çıktısına göre hesaplanır.

## Player Fantasy

Time Tracking System, oyuncunun farkında olmadığı ama hissettiği bir sistemdir.
Doğru çalıştığında oyuncu şunu hisseder: *"Dün gece kapattım, sabah açtım —
fırın benim için çalışmış."* Bu his, oyunun temel vaadini yerine getirir: boş
ekranda bekleme yok, her geri dönüş bir sürpriz ve ödüldür.

Yanlış çalıştığında (hesap kaçarsa, süre sıfırlanırsa veya 10 saatlik üretim
kaybolursa) oyuncu anında güven kaybeder. Bu sistem görünmez kalmalı — ne çok
cömert (cap'siz sonsuz üretim) ne çok cezalandırıcı (kısa cap). Offline ödülün
*"tam hak ettiğim kadar"* hissettirmesi gerekir.

## Detailed Design

### Core Rules

1. `TimeManager` autoload tek bir public metod sunar:
   `get_elapsed_seconds(last_timestamp: int) -> float`
2. Uygulama kapanırken / arka plana geçerken: Save/Load sistemi
   `Time.get_unix_time_from_system()` değerini `last_seen_timestamp` olarak
   kaydeder.
3. Uygulama açılırken / ön plana gelirken: `TimeManager` delta'yı hesaplar:
   `delta = now - last_seen_timestamp`
4. Delta kırpılır:
   `delta = clamp(delta, 0.0, ANTI_CHEAT_CAP_SECONDS)`
   — Negatif delta (saat geri sarıldı) → 0 olarak işlenir.
   — Aşırı büyük delta → `ANTI_CHEAT_CAP_SECONDS` ile üst sınırlanır.
5. `ANTI_CHEAT_CAP_SECONDS` = 86400 (24 saat) — oyunun kendi
   `offline_cap_seconds`'ından bağımsız, salt manipülasyon engeli.
6. Aktif `Timer` node'ları: Her sistem kendi sahnesinde barındırır.
   `TimeManager` bunları yönetmez, oluşturmaz veya referans almaz.
7. `_process()` içinde zaman birikimi **yasaktır** (ADR-0003).

### States and Transitions

| Durum | Açıklama | Girişi Tetikleyen |
|-------|----------|-------------------|
| `ACTIVE` | Uygulama ön planda, Godot `Timer`'lar çalışıyor | App başlatma / resume tamamlandı |
| `SUSPENDED` | Uygulama arka planda veya kapalı; `last_seen_timestamp` kaydedildi | `NOTIFICATION_WM_GO_BACK_REQUEST` / minimize |
| `RESUMING` | Açılış anı — elapsed hesaplanıp downstream'e iletiliyor | App ön plana geldi |
| `FIRST_LAUNCH` | `last_seen_timestamp` kayıtlı değil — elapsed = 0 döner | Yeni kurulum |

Geçiş sırası:
```
FIRST_LAUNCH / ACTIVE → [kapanma] → SUSPENDED
SUSPENDED → [açılma] → RESUMING → [downstream işledi] → ACTIVE
```

### Interactions with Other Systems

| Downstream Sistem | Alır | İle Ne Yapar |
|-------------------|------|-------------|
| **Save/Load** | — | `last_seen_timestamp` yazar (kapanırken), TimeManager'a okutmak üzere geri verir (açılırken) |
| **Offline Production** | `elapsed_seconds: float` | Offline üretilen ekmek miktarını hesaplar |
| **Oven/Baking** | `elapsed_seconds` (offline) + kendi `Timer` (aktif) | Aktif pişirme: Timer; offline batch: elapsed |
| **Employee** | `elapsed_seconds` | Kaç tam gün geçtiğini hesaplar (maaş kesintisi) |
| **Daily Task** | `elapsed_seconds` | 24 saat geçtiyse görev sıfırlama bayrağı oluşturur |
| **Customer/Order** | Kendi `Timer` node'u | Aktif sabır geri sayımı — TimeManager'a bağımlı değil |

> **Not:** `TimeManager` hiçbir downstream sisteme doğrudan çağrı yapmaz.
> Push değil, pull mimarisi — downstream sistemler açılışta kendi
> `elapsed_seconds` isteğini yapar.

## Formulas

### F-1: Elapsed Seconds (TimeManager birincil çıktısı)

```
elapsed_seconds = clamp(now_unix - last_seen_unix, 0.0, ANTI_CHEAT_CAP_SECONDS)
```

| Değişken | Tür | Açıklama | Aralık |
|----------|-----|----------|--------|
| `now_unix` | `int` | `Time.get_unix_time_from_system()` — açılış anı | [0, ∞) |
| `last_seen_unix` | `int` | Save/Load'dan okunan son kapanma zaman damgası | [0, ∞) |
| `ANTI_CHEAT_CAP_SECONDS` | `int` | Sabit: 86400 (24 saat) — ayarlanamaz | 86400 |
| **`elapsed_seconds`** | `float` | Çıktı | **[0.0, 86400.0]** |

> **İki ayrı cap mekanizması:**
> - `ANTI_CHEAT_CAP_SECONDS` = 86400 (24 saat) — yalnızca saat manipülasyonunu engeller; oyuncu hiçbir zaman bu sınıra ulaşmamalıdır.
> - `offline_cap_seconds` = 28.800 (8 saat, erken oyun) — gerçek üretim sınırı; Offline Production GDD'si sahipliğinde. `elapsed_seconds` bu ikinci cap'i bilmez; downstream sistemler kendi cap'lerini uygular.
>
> Örnek: Oyuncu 30 saat offline kalırsa → `elapsed_seconds = 86400` (ANTI_CHEAT_CAP). Offline Production sistemi bunu `min(86400, 28800) = 28800` ile 8 saate indirir.

### F-2: Elapsed Days (Employee maaşı için)

```
days_elapsed = floor(elapsed_seconds / 86400.0)
```

Tam gün tabanlı — 23 saat 59 dk = 0 gün, 24 saat = 1 gün.
Employee sistemi bu değeri `int` olarak alır.

### F-3: Offline Üretim (referans — Offline Production sistemi sahipliğinde)

```
items_produced = floor(min(elapsed_seconds, offline_cap_seconds) / bake_time_seconds)
               × oven_capacity
```

> Bu formülün değişkenleri (`offline_cap_seconds`, `bake_time_seconds`,
> `oven_capacity`) Time Tracking System'a ait değildir. Burada çapraz
> referans olarak yer alır; canonical tanımı Offline Production GDD'sinde
> bulunur.

## Edge Cases

| # | Durum | Beklenen Davranış |
|---|-------|-------------------|
| EC-1 | **İlk kurulum** — `last_seen_unix` kayıtlı değil | `elapsed_seconds = 0.0`; tüm downstream sistemler sıfır üretimle başlar |
| EC-2 | **Saat geri sarıldı** — delta negatif | `clamp` → 0.0; ceza yok, ödül de yok |
| EC-3 | **Saat ileri sarıldı aşırı** — delta > 86400 | `clamp` → 86400.0; ANTI_CHEAT_CAP aşılamaz |
| EC-4 | **Bozuk kayıt** — `last_seen_unix = 0` | delta = now (çok büyük) → ANTI_CHEAT_CAP ile kırpılır; kayıp olmaz |
| EC-5 | **Hızlı suspend/resume** — anlık arka plan/ön plan | Her suspend yeni timestamp yazar; birkaç saniyelik küçük delta hesaplanır |
| EC-6 | **Saat dilimi değişikliği** | Unix timestamp UTC tabanlı → saat dilimine duyarsız |
| EC-7 | **Yaz saati geçişi** | Unix timestamp DST'den etkilenmez → saat başına kayıp/fazla yok |
| EC-8 | **App çöktü, timestamp kaydedilemedi** | Son başarılı kayıttan hesaplanır → gerçek süreden az üretim; exploit yok (az ödül) |
| EC-9 | **NTP senkronizasyonu mid-session** | Uygulama `ACTIVE` durumda — elapsed hesabı yapılmaz; Godot `Timer`'lar etkilenmez |
| EC-10 | **`elapsed_seconds = 0.0` downstream'e iletildi** | Tüm downstream sistemler `0` üretimle temiz şekilde çalışır; hata fırlatmaz |

## Dependencies

### Upstream (bu sistem bunlara bağımlı)

**Yok.** Time Tracking System, Foundation katmanında yer alır ve başka
hiçbir oyun sistemine bağımlı değildir.

### Downstream (bu sisteme bağımlı olanlar)

| Sistem | Bağımlılık Türü | Interface |
|--------|----------------|-----------|
| **Save/Load** | Hard — timestamp saklamazsa elapsed hesaplanamaz | `last_seen_unix: int` yaz/oku |
| **Offline Production** | Hard — offline üretimin tek zaman kaynağı | `TimeManager.get_elapsed_seconds(ts) -> float` |
| **Oven/Baking** | Soft — aktif mod için `Timer` kullanır, offline hesap için hard | `get_elapsed_seconds(ts) -> float` |
| **Employee** | Hard — günlük maaş döngüsü | `get_elapsed_seconds(ts) -> float` |
| **Daily Task** | Hard — 24 saat geçince görev sıfırlama | `get_elapsed_seconds(ts) -> float` |
| **Customer/Order** | None — aktif sabır için kendi `Timer`'ını kullanır | — |

## Tuning Knobs

| Değer | Varsayılan | Güvenli Aralık | Çok Düşükse | Çok Yüksekse |
|-------|-----------|----------------|-------------|--------------|
| `ANTI_CHEAT_CAP_SECONDS` | 86400 (24 saat) | 43200–172800 | Uzun offline oturumlar (tatil, hastane) yanlış kırpılır | Saat manipülasyonu ile aşırı offline üretim mümkün |

> **Not:** Oyunun kendi `offline_cap_hours` değeri (8–12 saat) bu knob'dan
> bağımsızdır ve Offline Production GDD'sinde yönetilir.
> `ANTI_CHEAT_CAP_SECONDS` yalnızca clock manipulation engeli olarak var —
> tipik oyuncu bu sınıra hiçbir zaman ulaşmaz.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

| # | Kriter | Test Yöntemi |
|---|--------|-------------|
| AC-1 | `get_elapsed_seconds(now)` → 0.0 | Unit test |
| AC-2 | `get_elapsed_seconds(now - 3600)` → 3600.0 | Unit test |
| AC-3 | `get_elapsed_seconds(now + 3600)` (gelecek) → 0.0 (negatif kırpma) | Unit test |
| AC-4 | `get_elapsed_seconds(now - 200000)` → 86400.0 (ANTI_CHEAT_CAP) | Unit test |
| AC-5 | Uygulama 1 saat kapatılıp açılınca Offline Production doğru miktarda üretim verir | Integration test (mock timestamp) |
| AC-6 | Cihaz saati 10 saat geri sarılıp açılınca `elapsed_seconds = 0.0`, hata yok | Manual / unit test |
| AC-7 | Cihaz saati 5 gün ileri sarılıp açılınca `elapsed_seconds = 86400.0` | Manual / unit test |
| AC-8 | `NOTIFICATION_WM_GO_BACK_REQUEST` tetiklenince `last_seen_unix` kaydedilir | Log doğrulama |
| AC-9 | `last_seen_unix` kaydı yoksa (`ConfigFile.has_section_key()` → false) `elapsed_seconds = 0.0`, çökme yok; `null` veya `0` dönmez | Unit test (EC-1) |
| AC-10 | `TimeManager` kaynak dosyasında downstream sistem adı import/referansı bulunmaz | Kod incelemesi |
| AC-11 | EC-1 – EC-10 arası tüm edge case'ler mock timestamp'le GUT test koşumundan geçer | GUT test suite |

## Open Questions

| # | Soru | Sahip | Hedef |
|---|------|-------|-------|
| OQ-1 | Uygulama arka planda çalışırken (iOS background app refresh) Godot `NOTIFICATION_WM_GO_BACK_REQUEST` güvenilir tetikleniyor mu? Yoksa ek `_notification(NOTIFICATION_APPLICATION_PAUSED)` de dinlenmeli mi? | Engine Programmer | Save/Load GDD tasarımı |
| OQ-2 | Sunucu zamanı ilerleyen milestone'larda (leaderboard, sezonsal etkinlikler) eklenirse `TimeManager`'ın API'si değişmeli mi? | Technical Director | Sezonsal Etkinlik GDD |
