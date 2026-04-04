# Economy System

> **Status**: Approved
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-04
> **Implements Pillar**: Idle Progression — "Her oturumun ekonomik anlamı olmalı"

## Overview

Economy System, Ekmek Ustası'ndaki iki para biriminin — **Altın** (günlük operasyon)
ve **Unlu Rozet** (premium, yalnızca oyun içi kazanılır) — güvenilir saklama ve
dağıtım merkezidir. `earn_gold`, `spend_gold`, `earn_rozet` ve `spend_rozet` adlı
dört public metod sunar; her çağrıda bakiyeyi doğrular, günceller ve `gold_changed` /
`rozet_changed` sinyalleri aracılığıyla UI ile diğer sistemleri bilgilendirir.
Kimin ne kazandığını veya neden harcandığını bilmez — yalnızca miktarları alır.

Oyuncu bu sistemi ekranda görmez; hisseder: upgrade butonunun aktif hale gelmesi,
vitrin satışından sonra sayacın artması, rozet biriktirmenin küçük gururu. Bu sistem
olmadan hiçbir para akışı güvenilir olmaz — fırın üretir ama kazanım kaydedilmez,
upgrade satın alınır ama bakiye bozulur.

## Player Fantasy

Economy System, oyuncunun farkında olmadığı ama her tıklamada deneyimlediği sessiz
bir sistemdir. Doğru çalıştığında oyuncu şunu hisseder: *"Ekmek sattım, altınum arttı,
upgrade aldım — ilerliyorum."* Bu hissin kesintisiz akması için ekonomi görünmez
kalmalı — ne çok cömert (anlamsız bolluk) ne çok kısıtlayıcı (her işlem için bekleme).

**Altın** günlük çalışmanın ödülüdür: satış yaptın, kazandın, harcadın, büyüdün.
Döngü hızlı ve tatmin edici. **Unlu Rozet** ise biriktirmenin gururu — her günlük
görevi tamamladığında, her koleksiyonu bitirdiğinde küçük bir "biriyor" hissi.
1.000 rozeti biriktirip VIP Lounge açmak, haftalarca küçük kazanımların zirveye
ulaşmasıdır. Gerçek parayla kısayol yok — bu his, "hak ettim" duygusunu korur.

## Detailed Design

### Core Rules

1. Economy System yalnızca iki değer saklar: aktif `gold_balance: int` ve
   `rozet_balance: int`. Başka hiçbir oyun verisi tutmaz.
2. `earn_gold(amount: int)` ve `earn_rozet(amount: int)`: `amount <= 0` ise işlem
   yapılmaz, sinyal yayılmaz. Sessiz no-op.
3. `spend_gold(amount: int) -> bool` ve `spend_rozet(amount: int) -> bool`: bakiye
   yeterliyse düşer ve `true` döner; yetersizse bakiye değişmez ve `false` döner.
   Negatif bakiye hiçbir koşulda oluşamaz.
4. Her **başarılı** `earn_*` veya `spend_*` çağrısı ilgili sinyali yayar:
   `gold_changed(new_balance: int)` veya `rozet_changed(new_balance: int)`.
   Başarısız veya no-op çağrılar sinyal yaymaz.
5. Economy System kazanımın kaynağını, harcamanın nedenini bilmez ve sorgulamaz.
   Doğruluk sorumluluğu tamamen çağıran sisteme aittir.
6. `_process()` içinde hiçbir bakiye güncellemesi yapılmaz (ADR-0003). Tüm
   değişimler olay-bazlıdır (sinyal veya doğrudan metod çağrısı).
7. **LOADING durumunda** `earn_*` ve `spend_*` çağrıları sessizce reddedilir
   (return early). `initialize()` çağrılana kadar sistem LOADING'de kalır.
8. `initialize(gold: int, rozet: int) -> void` — yalnızca Save/Load sistemi çağırır,
   oyun ömründe bir kez. Bakiyeleri atar, `LOADING → READY` geçişini tetikler ve
   başlangıç sinyallerini yayar. Negatif değer gelirse `0` ile başlatılır.
9. Başlangıç sabitleri: `STARTING_GOLD = 0`, `STARTING_ROZET = 0`. Yeni kayıt
   olmadığında Save/Load `initialize(0, 0)` ile çağırır.

### Currency Architecture

#### Altın (Gold) — Günlük Operasyon Birimi

| Yön | Kaynak / Hedef | Çağıran Sistem |
|-----|---------------|----------------|
| **Kazanım** | Fırın üretimi tamamlandı | Oven/Baking |
| **Kazanım** | Vitrin satışı (sipariş teslimi) | Customer/Order |
| **Kazanım** | Offline üretim hesaplandı | Oven/Baking (offline path) |
| **Kazanım** | Günlük görev ödülü | Daily Task |
| **Kazanım** | Rewarded ad gold ödülü | Ad Monetization |
| **Harcama** | Upgrade satın alma | Upgrade Tree |
| **Harcama** | Çalışan işe alma / ücret | Employee |
| **Harcama** | Lokasyon kiralama | Location/Prestige |

Altın kısa döngünün birimidir: kazan → harca → büyü. Birikmesi normaldir;
geç oyunda enflasyon koruması Upgrade Tree'nin üstel maliyet eğrisi ile sağlanır.

#### Unlu Rozet — Premium Uzun-Döngü Birimi

| Yön | Kaynak / Hedef | Çağıran Sistem |
|-----|---------------|----------------|
| **Kazanım** | Günlük görev serisi + rozet bonusu | Daily Task |
| **Kazanım** | Koleksiyon tamamlama ödülü | Collection/Dex |
| **Kazanım** | Rewarded ad rozet milestone | Ad Monetization |
| **Harcama** | Premium upgrade kilidi (VIP Lounge vb.) | Upgrade Tree |
| **Harcama** | Kozmetik / dekorasyon | Visual Progression |

Rozet yalnızca oyun içi kazanılır — gerçek parayla satın alma yolu yoktur (ADR-0002).
Bu kural, "hak ettim" hissini ve IAP-free monetizasyon modelini korur.

### States and Transitions

| Durum | Açıklama |
|-------|----------|
| `LOADING` | Başlangıç durumu. `initialize()` bekleniyor. Tüm `earn/spend` çağrıları reddedilir. |
| `READY` | `initialize()` tamamlandı. Tüm API çağrıları aktif. Sinyaller yayılır. |

**Normal akış:**
```
Oyun başlar → Economy: LOADING
  → Save/Load kaydı okur
  → Economy.initialize(saved_gold, saved_rozet)
  → Economy: READY
  → gold_changed(gold) + rozet_changed(rozet) yayılır  ← UI ilk değeri alır
```

**Yeni oyun (kayıt yok):**
```
Save/Load kayıt bulamaz
  → Economy.initialize(STARTING_GOLD, STARTING_ROZET)  # = (0, 0)
  → Economy: READY
```

**Bozuk kayıt (negatif değer):**
```
Save/Load negatif değer okursa
  → Economy.initialize(0, 0)  # güvenli varsayılan
  → Economy: READY
```

### Interactions with Other Systems

| Sistem | Economy'den aldığı | Çağırdığı / Dinlediği | Yön |
|--------|-------------------|-----------------------|-----|
| **Save/Load** | — | `initialize(gold, rozet)` → READY | Save/Load → Economy |
| **Save/Load** | `gold_balance`, `rozet_balance` okur (kayıt anında) | — | Economy → Save/Load |
| **Oven/Baking** | — | `earn_gold(amount)` — pişirme / offline sonucu | Oven → Economy |
| **Customer/Order** | — | `earn_gold(amount)` — sipariş teslimi | Customer → Economy |
| **Upgrade Tree** | `gold_changed`, `rozet_changed` sinyalleri | `spend_gold(cost) -> bool`, `spend_rozet(cost) -> bool` | Çift yön |
| **Employee** | `gold_changed` sinyali (ödeme gücü kontrolü) | `spend_gold(wage) -> bool` — günlük ücret | Çift yön |
| **Daily Task** | — | `earn_gold(amount)`, `earn_rozet(amount)` — görev ödülü | Daily Task → Economy |
| **Ad Monetization** | — | `earn_gold(amount)`, `earn_rozet(amount)` — ad ödülü | Ad → Economy |
| **UI/HUD** | `gold_changed(new_balance)`, `rozet_changed(new_balance)` sinyalleri | — | Economy → UI |
| **VFX/Particle** | `gold_changed` sinyali — coin burst tetikler | — | Economy → VFX |

> **Not:** Economy System hiçbir downstream sistemi doğrudan çağırmaz.
> Push değil, event-driven (sinyal) mimari — downstream sistemler abone olur.

## Formulas

Economy System kendi hesaplama yapmaz; aşağıdaki formüller downstream sistemlere
aittir. Bu bölüm denge analizi ve çapraz referans için sunulmuştur.

### F-1: Günlük Gelir Senaryoları

> **Uyarı:** Tüm değerler referans analizidir. Playtest kalibrasyonuna tabidir;
> gerçek oyuncu davranışı bu projeksiyonlardan anlamlı ölçüde sapabilir.

**Varsayımlar:** `bake_time = 120 sn`, aktif oturum = 2 × 7 dk = 14 dk/gün,
offline = 8 saat (erken) / 12 saat (geç).

| Aşama | Tarif | Efektif değer | Kapasite | Aktif/gün | Offline/gün | Toplam/gün | Harcama/gün | Net birikim |
|-------|-------|--------------|---------|-----------|-------------|-----------|-------------|------------|
| **Erken (Sev.1-10)** | Beyaz ekmek | 10 altın | 2/tur | ~120 | ~2.400 | ~2.500 | ~400 | ~2.100 |
| **Orta (Sev.20-35)** | Baguette | ~133 altın* | 6/tur | ~3.300 | ~47.700 (×2) | ~51.000 | ~3.000 | ~48.000 |
| **Geç (Sev.50+)** | Paris özel | ~1.313 altın | 12/tur | ~78.800 | **[⚠ ŞÜPHELI]** | **[PLAYTEST]** | ~10.000+ | — |

> \* Orta oyun: `85 × 1.30 × 1.2 = ~133 altın`. `bread-master-core-design.md`'deki
> 28.000/gün tahmini quality_bonus ve location_multiplier içermez; hesaplanan değer
> ~51.000'dir. İkisi arasındaki fark playtest ile kalibre edilecektir.
>
> **Geç oyun kırmızı bayrak:** 6 lokasyon + tam upgrade varsayımıyla teorik üst sınır
> günlük **milyonlar** mertebesine çıkabilir. Upgrade maliyet eğrisi (3^n) bu değerle
> birlikte kalibre edilmelidir — bkz. Açık Sorular.

### F-2: Rozet Akış Analizi

**Kazanım kaynakları:**

| Kaynak | Günlük miktar | Haftalık toplam | Not |
|--------|--------------|----------------|-----|
| Günlük görev tamamlama | 500 rozet (max) | 3.500 | Tüm görevler tamamlanırsa |
| Rewarded ad bonusu (3 reklam × 50) | 150 rozet | 1.050 | Fill rate'e bağlı |
| Koleksiyon tamamlama | Belirsiz (tek seferlik) | — | Miktar tanımsız — tuning gerekli |
| **Toplam (aktif + reklam)** | **~650 rozet/gün** | **~4.550/hafta** | |
| **Toplam (pasif)** | **~500 rozet/gün** | **~3.500/hafta** | |

**Harcama hedefleri:**

| Hedef | Maliyet (mevcut) | Erişim (aktif oyuncu) | Not |
|-------|-----------------|----------------------|-----|
| VIP Lounge | 1.000 rozet | ~1.5 gün | ⚠ Çok hızlı — bkz. Açık Sorular |
| Kozmetik / dekorasyon | Belirsiz | — | Harcama hedefi çeşitliliği eksik |

> **Rozet ekonomisi notu:** Mevcut tasarımda VIP Lounge'a ~1.5 günde ulaşılıyor.
> "Uzun döngü biriktirme gururu" hedefiyle çelişiyor. Karar Upgrade Tree GDD'ye
> ertelenmiştir — bkz. Açık Sorular.

### F-3: Formül Çapraz Referansları

Economy System bu formüllerin sahibi değildir. Sadece sonucu `earn/spend` API'si
üzerinden alır.

| Formül | Kanonik Kaynak | Economy'nin rolü |
|--------|---------------|-----------------|
| `cost(n) = base_cost × 3^(n-1)` | `bread-master-core-design.md` | `spend_gold(cost)` alır |
| `recipe_value = base_value × (1+quality) × location_mult` | `bread-master-core-design.md` | `earn_gold(recipe_value)` alır |
| `final_gold = base_gold × max(0.5, 1 - loss/100)` | `bread-master-core-design.md` | `earn_gold(final_gold)` alır |
| `items_produced = floor(min(elapsed,cap)/bake_time) × oven_capacity` | `bread-master-core-design.md` | `earn_gold(items × value)` alır |
| Günlük çalışan ücreti | `[Employee System GDD — henüz yazılmadı]` | `spend_gold(wage) -> bool` alır |
| Rewarded ad rozet miktarı | `[Ad Monetization GDD — henüz yazılmadı]` | `earn_rozet(amount)` alır |

## Edge Cases

| # | Durum | Beklenen Davranış |
|---|-------|-------------------|
| 1 | `earn_gold(0)` veya `earn_rozet(0)` çağrılır | Sessiz no-op; bakiye değişmez, sinyal yayılmaz |
| 2 | `earn_gold(-50)` gibi negatif amount | Sessiz no-op; bakiye değişmez, sinyal yayılmaz |
| 3 | `spend_gold(amount)`, bakiye ≥ amount | Bakiyeden düşer, `true` döner, `gold_changed` yayılır |
| 4 | `spend_gold(amount)`, bakiye < amount | Bakiye değişmez, `false` döner, sinyal yayılmaz |
| 5 | `spend_gold(0)` veya `spend_rozet(0)` | `false` döner; bakiye değişmez, sinyal yayılmaz. Not: `amount=0` geçerli bir harcama olmadığından false dönmesi kasıtlıdır (`earn_gold(0)` no-op'tan farklı — o sessizce başarılı sayılır, bu açıkça reddeder) |
| 6 | `spend_gold(-100)` gibi negatif amount | `false` döner; bakiye değişmez, sinyal yayılmaz |
| 7 | LOADING'de `earn_gold(500)` çağrılır | Sessiz no-op; READY olmadan hiçbir işlem yapılmaz |
| 8 | LOADING'de `spend_gold(100)` çağrılır | `false` döner; bakiye değişmez, sinyal yayılmaz |
| 9 | `initialize()` ikinci kez çağrılır | İkinci çağrı yoksayılır; durum READY kalır, bakiyeler değişmez |
| 10 | `initialize(-500, -100)` negatif değerlerle | Her negatif değer `0`'a klamplanır; `initialize(0, 0)` gibi davranır |
| 11 | `earn_gold(INT_MAX)` — overflow riski | Bakiye `INT_MAX` ile klamplanır; overflow'a izin verilmez; sinyal yayılır |
| 12 | `gold_changed` sinyalinin hiç alıcısı yokken yayılır | Godot sinyal sistemi alıcısız yayımı hatasız işler; Economy açısından no-op |
| 13 | Aynı karede birden fazla `earn_gold` çağrısı | Her çağrı sıralı işlenir; bakiye birikimli güncellenir; her biri ayrı sinyal yayar |

## Dependencies

### Upstream (Economy'yi çağıran sistemler)

| Sistem | Bağımlılık Türü | Interface |
|--------|----------------|-----------|
| **Save/Load** | Hard | `initialize(gold, rozet)` — READY geçişini tetikler |
| **Oven/Baking** | Hard | `earn_gold(amount)` — pişirme / offline üretim geliri |
| **Customer/Order** | Hard | `earn_gold(amount)` — sipariş teslim ödülü |
| **Upgrade Tree** | Hard | `spend_gold(cost) -> bool`, `spend_rozet(cost) -> bool` |
| **Employee** | Hard | `spend_gold(wage) -> bool` — günlük ücret |
| **Daily Task** | Soft | `earn_gold(amount)`, `earn_rozet(amount)` — görev ödülü |
| **Ad Monetization** | Soft | `earn_gold(amount)`, `earn_rozet(amount)` — reklam ödülü |
| **Location/Prestige** | Soft | `spend_gold(cost) -> bool` — lokasyon kiralama ücreti |
| **Collection/Dex** | Soft | `earn_rozet(amount)` — koleksiyon tamamlama ödülü |

### Downstream (Economy sinyallerini dinleyen sistemler)

| Sistem | Bağımlılık Türü | Interface |
|--------|----------------|-----------|
| **UI/HUD** | Hard | `gold_changed(new_balance)`, `rozet_changed(new_balance)` |
| **Upgrade Tree** | Hard | `gold_changed`, `rozet_changed` — buton aktif/pasif durumu |
| **Save/Load** | Hard | `gold_balance`, `rozet_balance` okur — kayıt anında snapshot |
| **Employee** | Soft | `gold_changed` — ödeme gücü göstergesi |
| **VFX/Particle** | Soft | `gold_changed` — coin burst efekti tetikler |

> **Not:** Economy hiçbir downstream sistemi doğrudan çağırmaz. Soft bağımlılıklar
> kesilebilir; oyun çalışmaya devam eder. Hard bağımlılıklar kesilemez; kritik yol bozulur.

## Tuning Knobs

> **Sahiplik notu:** `†` işaretli değerler başka GDD'lerin canonical sahibidir.
> Değişiklik ilgili GDD üzerinden yapılmalıdır; bu tablo sadece çapraz referans sunar.

| Değer | Varsayılan | Güvenli Aralık | Çok düşükse | Çok yüksekse | Sahip |
|-------|-----------|----------------|-------------|--------------|-------|
| `STARTING_GOLD` | `0` | `0–500` | İlk upgrade çok uzak hissettirir | İlk 10 dk anlamsız (ödülsüzlük) | Bu GDD |
| `STARTING_ROZET` | `0` | `0–0` | — | "Biriktirme gururu" başlamadan zarar görür | Bu GDD |
| `GOLD_BALANCE_CAP` | `INT_MAX` | Pratik: `999.999.999` | Tavan erken gelirse geç oyun motivasyonu çöker | Overflow riski — INT_MAX klamplama zorunlu | Bu GDD |
| Rozet günlük görev miktarı | `500/gün` | `200–800` | VIP Lounge haftalar alır | VIP Lounge ~1 günde açılır, uzun döngü hedefi yok olur | † **Daily Task GDD** |
| Rozet rewarded ad ödülü | `50/reklam` | `20–100` | Reklam izleme motivasyonu düşer | Reklam+görev kombinasyonu VIP Lounge'u trivialize eder | † **Ad Monetization GDD** |
| Upgrade maliyet exponent | `3` | `2.5–4.0` | Upgrade ucuz, progression anlamsızlaşır | Geç upgrade erişilemez, oyuncu takılır | † **bread-master-core-design.md** |
| Offline üretim cap | `8 saat (erken)` | `6–16 saat` | Casual oyuncu offline bonus göremez | Aktif oynamanın avantajı sıfırlanır | † **Oven/Baking GDD** |

## Visual/Audio Requirements

Economy System doğrudan görsel veya ses çıktısı üretmez. Ancak tetiklediği sinyaller
aşağıdaki efektleri başlatır — bu efektlerin implementasyonu ilgili sistemlere aittir:

| Tetikleyici | Efekt | Sahip Sistem |
|-------------|-------|-------------|
| `gold_changed` (pozitif delta) | Coin burst animasyonu — altın coinler kazanım noktasından sayaca "uçar" | VFX/Particle |
| `gold_changed` (büyük kazanım, ör. 1.000+) | Ekstra parıltı + ses katmanı | VFX/Particle, Sound |

> **Sinyal tasarım notu (R-3):** `gold_changed(new_balance)` sadece yeni bakiyeyi taşır,
> delta taşımaz. VFX sistemi önceki bakiyeyi kendi state'inde tutarak delta'yı hesaplamalı
> veya büyük kazanım eşiği `GOLD_BURST_THRESHOLD = 1000` sabiti olarak VFX GDD'de tanımlanmalı.
> Karar: **VFX/Particle GDD** tasarımında alınacak.
| `spend_gold` → `true` | Satın alma "klik" sesi + hafif ekran titreşimi | Sound & Animation |
| `spend_gold` → `false` (yetersiz bakiye) | Kısa "tık" reddetme sesi + bakiye göstergesi titriyor | Sound & Animation, UI/HUD |
| `rozet_changed` (pozitif) | Rozet "parıldama" efekti — premium duygu | VFX/Particle |

## UI Requirements

Economy System'in kendisi UI çizmez; tüm görsel sunum UI/HUD sistemi tarafından yapılır.
Economy'den gelen sinyal değerleri UI'da şu şekillerde kullanılır:

| Sinyal | UI Kullanımı |
|--------|-------------|
| `gold_changed(new_balance)` | Üst çubuktaki altın sayacı anında güncellenir; büyük artışlarda sayaç animasyonu oynar |
| `rozet_changed(new_balance)` | Rozet sayacı güncellenir; yeni rozet gelince küçük parıldama efekti |
| `spend_gold` → `false` | Upgrade / satın alma butonu kısa "titreşim" animasyonu; "Yetersiz Altın" tooltip |
| `spend_rozet` → `false` | Aynı pattern; "Yetersiz Rozet" tooltip |

> Sayaç animasyon hızı, tooltip içerikleri ve tooltip gösterim süresi UI/HUD GDD'de tanımlanır.

## Acceptance Criteria

| # | Kriter | Test Yöntemi |
|---|--------|-------------|
| 1 | `initialize(200, 50)` sonrası sistem READY, `gold_balance = 200`, `rozet_balance = 50` | GUT unit test |
| 2 | `earn_gold(100)` bakiyeyi 100 artırır; `gold_changed(new_balance)` doğru değerle yayılır | GUT unit test + sinyal spy |
| 3 | `spend_gold(50)` (bakiye ≥ 50) bakiyeyi düşürür, `true` döner | GUT unit test |
| 4 | `spend_gold(bakiyeden fazla)` `false` döner, bakiye değişmez, sinyal yayılmaz | GUT unit test + sinyal spy |
| 5 | `spend_gold(0)` `false` döner, sinyal yayılmaz | GUT unit test |
| 6 | LOADING'de `earn_gold(500)` no-op olur; `gold_changed` yayılmaz; bakiye 0 kalır | GUT unit test (initialize öncesinde çağır) |
| 7 | LOADING'de `spend_gold(100)` `false` döner, sinyal yayılmaz | GUT unit test |
| 8 | `initialize()` iki kez çağrılırsa ikincisi yoksayılır; bakiye değişmez | GUT unit test: `initialize(200,50)` → `initialize(999,999)` → bakiye 200/50 kalır |
| 9 | Bakiye hiçbir zaman negatife düşmez — 1.000 rastgele `spend_gold` çağrısı sonrası `gold_balance >= 0` | GUT fuzz test |
| 10 | `gold_changed` sinyali 5 sıralı işlem sonrası her seferinde doğru `new_balance` taşır | GUT unit test + sinyal spy serisi |
| 11 | `_process()` içinde `gold_balance` veya `rozet_balance` ataması yok | Kod incelemesi |
| 12 | `earn_gold(INT_MAX)` overflow'a yol açmaz; bakiye INT_MAX veya önceki değerde kalır | GUT unit test |

## Open Questions

| # | Soru | Sahip | Hedef |
|---|------|-------|-------|
| OQ-1 | **Geç oyun gold scaling:** 6 lokasyon + tam upgrade ile günlük gelir milyonlara çıkabilir. Upgrade maliyet eğrisi (3^n) bu değerle birlikte kalibre edilmeli mi, yoksa geç oyun upgrade'leri farklı bir eğri mi kullanmalı? | Game Designer | Upgrade Tree GDD + Playtest |
| OQ-2 | **VIP Lounge rozet maliyeti:** Mevcut 1.000 rozet ile aktif oyuncu ~1.5 günde erişiyor. "Uzun döngü biriktirme gururu" hedefiyle çelişiyor. Öneri: 5.000–7.000 rozete yükselt veya günlük kazanım tavanını düşür. Karar Upgrade Tree GDD'de alınacak. | Economy Designer + Game Designer | Upgrade Tree GDD |
| OQ-3 | **Koleksiyon rozet ödülleri:** Her koleksiyon tamamlaması ne kadar rozet veriyor? Bu miktar belirlenmeden rozet havuzu analizi tamamlanamaz. | Game Designer | Collection/Dex GDD |
| OQ-4 | ~~**`initialize()` çağrı garantisi ⚠ BLOCKER:** Save/Load sistemi her zaman Economy'den önce mi yükleniyor?~~ **ÇÖZÜLDÜ** — Save/Load GDD Core Rule 1 ve AC-3: `SaveLoadManager` Godot autoload listesinde en üstte; `_ready()` sırası garantilenmiş. | Lead Programmer | Çözüldü — `design/gdd/save-load-system.md` Rule 1 |
| OQ-5 | **Employee grev mantığı:** `spend_gold(wage) -> false` döndüğünde Employee sistemi çalışanı "grevde" işaretliyor. Economy'nin bu durumu bilmesi gerekiyor mu, yoksa Employee kendi state'ini yönetiyor mu? | Systems Designer | Employee System GDD |
