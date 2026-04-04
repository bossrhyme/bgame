# Save/Load System

> **Status**: Designed — Approved (Post-Review)
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-04
> **Implements Pillar**: Idle Progression — "Her oturumun ekonomik anlamı olmalı"

## Overview

Save/Load System, Ekmek Ustası'ndaki tüm kalıcı oyun verisinin tek güvenilir
depolama noktasıdır. `ConfigFile` API'si kullanarak `user://save_game.cfg`
dosyasına yazar ve okur — `user://settings.cfg` oyun tercihlerinden tamamen
ayrı tutulur. Kaydedilen veriler dört kategoriye ayrılır: (1) **Temel** —
para birimleri ve offline hesaplama için `last_seen_unix` zaman damgası;
(2) **Progression** — satın alınmış upgrade'ler ve kilidi açılmış tarifler;
(3) **Gameplay** — işe alınmış çalışanlar, aktif lokasyonlar, koleksiyon
ilerlemesi; (4) **Meta** — tutorial adımı ve günlük görev geçmişi.

`SaveLoadManager` autoload olarak çalışır ve tüm sistemlerin autoload
sıralamasında **ilk** yüklenir. Oyun başlayınca kaydı okur ve zincirleme
initialize'ı tetikler: `Economy.initialize(gold, rozet)` ve `TimeManager`'a
`last_seen_unix` iletilir. Uygulama arka plana geçtiğinde veya kapandığında
`NOTIFICATION_WM_GO_BACK_REQUEST` ile anında kayıt yapılır — ayrıca her
önemli state değişiminde (upgrade satın alma, lokasyon açma) otomatik kayıt
tetiklenir. Kayıt yoksa yeni oyun varsayılanlarıyla başlanır.

## Player Fantasy

Save/Load System oyuncunun farkında olmadığı ama güvendiği bir sistemdir.
Doğru çalıştığında oyuncu hiçbir şey hissetmez — sadece kapatır, açar,
kaldığı yerden devam eder. *"Kapattım, geri geldim — her şey burada."*
Bu güvenin kırılması (veri kaybı, sıfırlanmış bakiye, kaybolmuş upgrade)
oyunun tüm ilerleme sistemine duyulan güveni yıkar.

**İlk kapanış istisnası:** Oyuncu uygulamayı ilk kez kapattığında küçük
bir "İlerleme kaydedildi" toast bildirimi gösterilir — tek seferlik onay.
Sonraki tüm kayıtlar sessizdir.

Bu sistemin görevi: oyuncunun hiçbir zaman "Kaydettim mi?" diye
düşünmemesini sağlamak.

## Detailed Design

### Core Rules

1. **Autoload yükleme sırası garantisi.** `SaveLoadManager`, Godot proje
   ayarlarında (`Project → Project Settings → Autoload`) listenin **en üstüne**
   yerleştirilir. Godot autoload'ları listedeki sırayla `_ready()` çağırır;
   bu nedenle `Economy`, `TimeManager` ve tüm gameplay sistemleri `_ready()`
   çalışmadan önce Save/Load'un kaydı belleğe aldığı garantilenir. Bu sıra
   `project.godot`'un `[autoload]` bölümüne yazılır — elle değiştirilmesi
   **yasaktır**. (Economy OQ-4 çözümü)

2. **Tek okuma, çoklu yazma (startup-read / event-write).** Kayıt dosyası
   uygulama başlangıcında bir kez okunur; sonuçlar bellekte tutulur. Yazma
   yalnızca olay-tetiklemeli gerçekleşir; `_process()` içinde polling yoktur
   (ADR-0003 uyumu).

3. **`_process()` yasağı.** Hiçbir kayıt veya okuma işlemi `_process()` ya
   da `_physics_process()` içinde gerçekleştirilmez (ADR-0003).

4. **Kayıt tetikleyicileri.** Aşağıdaki olaylar `_save_game()` tetikler:
   - `NOTIFICATION_WM_GO_BACK_REQUEST` — geri tuşu / uygulama kapanması
   - `NOTIFICATION_APPLICATION_FOCUS_OUT` — iOS arka plan geçişi güvenlik katmanı
     (Time Tracking OQ-1 yanıtı)
   - Upgrade satın alma (Upgrade Tree sinyali)
   - Lokasyon kilidi açma (Location/Prestige sinyali)
   - Tarif kilidi açma (Recipe System sinyali)
   - Çalışan işe alma / çıkarma (Employee System sinyali)
   - Koleksiyon öğesi keşfedildi (Collection/Dex sinyali)
   - Tutorial adımı ilerledi (Tutorial System sinyali)
   - Günlük görev tamamlandı veya sıfırlandı (Daily Task sinyali)

   > **Kapsam notu:** `tutorial_step`, `collection_progress`, `daily_task_history`
   > ve `daily_task_reset_unix` alanları yalnızca bu tetikleyiciler aracılığıyla
   > güncel tutulur. Uygulama kapanışı tetikleyicisi (`NOTIFICATION_*`) bunları
   > da kapsar — bu nedenle en kötü senaryoda veri yalnızca son kapanışta
   > yazılmış olabilir; ilgili sinyal geldiğinde ise anında kaydedilir.

5. **Atomik yazma (geçici dosya + rename pattern).** Doğrudan üzerine yazmak
   yerine:
   1. `ConfigFile.set_value()` çağrıları ile tüm veriler bellek nesnesine yazılır
   2. `ConfigFile.save("user://save_game.cfg.tmp")` çağrısı fiziksel yazımı yapar
      ve `Error` kodu döner; `OK` dışında bir değer yazma başarısızlığını gösterir
   3. Başarı (`OK`): `DirAccess.rename("user://save_game.cfg.tmp",
      "user://save_game.cfg")` ile atomik taşıma yapılır
   4. Başarısızlık: `.tmp` silinir, mevcut `.cfg` bozulmadan korunur
   Bu yöntem yarı yazılmış / bozuk kayıt riskini ortadan kaldırır.

6. **Bozuk kayıt tespiti ve kurtarma.** `_load_game()` şu koşulları işler:
   - Dosya mevcut değil → yeni oyun varsayılanlarıyla başla
   - `ConfigFile.load()` → `ERR_PARSE_ERROR` / `ERR_FILE_CORRUPT` → varsayılanlar
   - Beklenen anahtar eksik (`has_section_key()` → `false`) → o anahtarın
     varsayılanı kullanılır, diğerleri korunur
   - Negatif para birimi → `0`'a klamplanır
   Tüm kurtarma durumlarında `push_warning()` ile log bırakılır; oyuncu
   hiçbir zaman hata ekranıyla karşılaşmaz.

7. **Economy initialize zinciri.** `_load_game()` tamamlanınca okunan gold
   ve rozet değerleriyle `Economy.initialize(gold, rozet)` çağrılır — oyun
   ömründe bir kez (Economy OQ-4 çözümü). Economy bu çağrıya kadar
   `LOADING` durumunda kalır.

8. **TimeManager zinciri (pull mimarisi).** Yüklenen `last_seen_unix` değeri
   `SaveLoadManager.last_seen_unix` property'sinde tutulur. Downstream sistemler
   (`Oven/Baking`, `Employee`, `Daily Task`) kendi `_ready()` içinde
   `TimeManager.get_elapsed_seconds(SaveLoadManager.last_seen_unix)` çağırarak
   elapsed süreyi hesaplar. SaveLoadManager downstream'e itmez.

9. **`last_seen_unix` her kayıtta güncellenir.** `_save_game()` çağrısı sırasında
   `Time.get_unix_time_from_system()` alınır ve `[time] last_seen_unix` anahtarına
   yazılır.

10. **`get_save_data() / apply_save_data()` sözleşmesi.** Her downstream sistem
    iki metodu implemente eder:
    - `get_save_data() -> Dictionary` — mevcut state'in serileştirilebilir
      snapshot'ını döner
    - `apply_save_data(data: Dictionary) -> void` — yüklenen veriyi state'e uygular
    `SaveLoadManager` downstream sistemlerin iç yapısını bilmez; yalnızca bu
    sözleşmeyi bilir.

11. **Settings dosyası ayrı tutulur.** `user://save_game.cfg` yalnızca oyun
    ilerlemesini içerir. Ses, dil, bildirim tercihleri `user://settings.cfg`
    dosyasında `SettingsManager` tarafından yönetilir. İki dosya birleştirilmez.

12. **Debounce.** Ardışık kayıt çağrıları `SAVE_DEBOUNCE_MS` (varsayılan: 500 ms)
    içinde tekilleştirilir. Pencere içinde gelen ikinci tetikleyici yoksayılır;
    yalnızca tek fiziksel yazma gerçekleşir. Bu, `NOTIFICATION_APPLICATION_FOCUS_OUT`
    ile `NOTIFICATION_WM_GO_BACK_REQUEST`'in aynı anda tetiklenmesi durumunu kapsar.

13. **Versiyon şeması.** `[meta] save_version: int` her kayıt dosyasında bulunur
    (mevcut: `1`). Şema değişirse `SaveLoadManager` farkı tespit eder ve
    migration script'ini çalıştırır; eksik anahtarlar varsayılanla doldurulur.

### Save Structure

`ConfigFile` bölüm ve anahtar şeması. Her kategori ayrı bir `[section]` altında.

#### Şema Tablosu

| Section | Key | Type | Default | Açıklama |
|---------|-----|------|---------|----------|
| `meta` | `save_version` | `int` | `1` | Şema versiyonu; migration için |
| `meta` | `tutorial_step` | `int` | `0` | Tutorial adımı; `0` = başlamadı |
| `meta` | `first_close_shown` | `bool` | `false` | "İlerleme kaydedildi" toast gösterildi mi |
| `meta` | `daily_task_history` | `Dictionary` | `{}` | `{task_id: {completed: bool, date_unix: int}}` |
| `meta` | `daily_task_reset_unix` | `int` | `0` | Görev havuzu son sıfırlanma timestamp'i |
| `economy` | `gold` | `int` | `0` | Mevcut altın bakiyesi |
| `economy` | `rozet` | `int` | `0` | Mevcut Unlu Rozet bakiyesi |
| `time` | `last_seen_unix` | `int` | `0` | Son kapanma Unix timestamp (UTC) |
| `progression` | `purchased_upgrades` | `Array[String]` | `[]` | Satın alınmış upgrade ID listesi |
| `progression` | `unlocked_recipes` | `Array[String]` | `[]` | Kilidi açılmış tarif ID listesi |
| `gameplay` | `hired_employees` | `Array[Dictionary]` | `[]` | `[{id, slot, hire_time_unix}]` |
| `gameplay` | `unlocked_locations` | `Array[String]` | `[]` | Açılmış lokasyon ID listesi |
| `gameplay` | `active_location` | `String` | `"bakery_1"` | Aktif lokasyon ID'si |
| `gameplay` | `oven_state` | `Dictionary` | `{}` | `{slot_id: {recipe_id, start_time_unix, is_active}}` ⚠ Oven/Baking GDD'de kesinleşir |
| `gameplay` | `collection_progress` | `Dictionary` | `{}` | `{item_id: {discovered: bool, count: int}}` |

**Örnek içerik:**
```ini
[meta]
save_version=1
tutorial_step=3
first_close_shown=true

[economy]
gold=1250
rozet=340

[time]
last_seen_unix=1743750000

[progression]
purchased_upgrades=["oven_slot_2","bake_speed_1","bake_speed_2"]
unlocked_recipes=["white_bread","whole_wheat","baguette"]

[gameplay]
unlocked_locations=["bakery_1","bakery_2"]
active_location="bakery_2"
oven_state={"slot_0":{"recipe_id":"baguette","start_time_unix":1743748000,"is_active":true}}
```

### States and Transitions

| Durum | Açıklama |
|-------|----------|
| `UNINITIALIZED` | `_ready()` henüz çalışmadı. Hiçbir API çağrısı güvenli değil. |
| `LOADING` | `_load_game()` çalışıyor: dosya okunuyor, parse ediliyor. |
| `READY` | Yükleme tamamlandı, `Economy.initialize()` çağrıldı. Yazma tetikleyicileri aktif. |
| `SAVING` | `_save_game()` çalışıyor: `.tmp`'ye yazılıyor, rename yapılıyor. |

**Normal akış:**
```
Uygulama başlar → UNINITIALIZED
  → autoload _ready() tetiklendi → LOADING
  → Dosya okundu, Economy.initialize() çağrıldı → READY
  → Kayıt tetikleyicisi (kapatma / upgrade vb.) → SAVING
  → .tmp → .cfg rename tamamlandı → READY (döngü)
```

**Olağandışı geçişler:**
```
LOADING: kayıt yok → varsayılanlar → Economy.initialize(0,0) → READY
LOADING: bozuk kayıt → push_warning + varsayılanlar → READY
SAVING: FileAccess hatası → .tmp silinir + push_error → READY (mevcut .cfg korunur)
```

### Interactions with Other Systems

| Sistem | Interface | Yön | Ne Zaman |
|--------|-----------|-----|----------|
| **Economy** | `Economy.initialize(gold, rozet)` | SaveLoad → Economy | Startup; bir kez |
| **Economy** | `Economy.get_save_data() -> Dict` | Economy → SaveLoad | Her `_save_game()` |
| **TimeManager** | `SaveLoadManager.last_seen_unix` property okuma | Downstream ← SaveLoad | Downstream `_ready()` içinde pull |
| **Oven/Baking** | `get_save_data()` / `apply_save_data(data)` | Çift yön | Startup yükle; tetikleyicide kaydet |
| **Upgrade Tree** | `get_save_data()` / `apply_save_data(data)` | Çift yön | Startup yükle; upgrade sinyalinde kaydet |
| **Recipe System** | `get_save_data()` / `apply_save_data(data)` | Çift yön | Startup yükle; tarif kilidi sinyalinde kaydet |
| **Employee System** | `get_save_data()` / `apply_save_data(data)` | Çift yön | Startup yükle; işe alma/çıkarma sinyalinde |
| **Location/Prestige** | `get_save_data()` / `apply_save_data(data)` | Çift yön | Startup yükle; lokasyon sinyalinde |
| **Collection/Dex** | `get_save_data()` / `apply_save_data(data)` | Çift yön | Startup yükle; koleksiyon değişiminde |
| **Tutorial System** | `get_save_data()` / `apply_save_data(data)` | Çift yön | Startup yükle; adım ilerleyince |
| **Daily Task** | `get_save_data()` / `apply_save_data(data)` | Çift yön | Startup yükle; görev tamamlandığında / sıfırlandığında |

## Formulas

Save/Load System kendi hesaplama formülü içermez. Matematiksel değerleri
üretmez; yalnızca diğer sistemlerin ürettiği değerleri okur/yazar.

### F-1: Save Schema Migration

```
CURRENT_SAVE_VERSION = 1

if loaded_version < CURRENT_SAVE_VERSION:
    → eksik anahtarlar varsayılan değerleriyle doldurulur
    → save_version = CURRENT_SAVE_VERSION olarak yazılır
elif loaded_version > CURRENT_SAVE_VERSION:
    → push_warning("Save daha yeni sürümden — bilinmeyen anahtarlar yoksayılır")
    → okuma devam eder (tolerant parsing)
```

### F-2: Atomik Yazma Başarı Kontrolü

`ConfigFile` API'si: değerler `set_value()` ile bellekte tutulur; `save(path)` çağrısı
fiziksel yazımı yapar ve `Error` kodu döner. Granüler bool döngüsü yoktur.

```
config = ConfigFile.new()
config.set_value("economy", "gold", gold)
config.set_value("economy", "rozet", rozet)
config.set_value("time", "last_seen_unix", now_unix)
# ... diğer tüm set_value() çağrıları ...

var err: Error = config.save("user://save_game.cfg.tmp")
if err == OK:
    DirAccess.rename("user://save_game.cfg.tmp", "user://save_game.cfg")  # atomik
else:
    DirAccess.remove("user://save_game.cfg.tmp")  # kirli dosyayı temizle
    push_error("Save failed (%s) — previous save preserved" % error_string(err))
```

## Edge Cases

| # | Durum | Beklenen Davranış |
|---|-------|-------------------|
| 1 | Kayıt dosyası yok (ilk oyun) | `ERR_FILE_NOT_FOUND`; varsayılanlar yüklenir, `Economy.initialize(0, 0)`, `push_warning()` |
| 2 | Kayıt parse edilemiyor (`ERR_PARSE_ERROR` / `ERR_FILE_CORRUPT`) | Bozuk dosya yoksayılır; varsayılanlar; `push_error("Save corrupted — defaults loaded")` |
| 3 | Beklenen anahtar eksik (yarı tamamlanmış kayıt) | `has_section_key()` ile tespit; yalnızca o anahtarın varsayılanı kullanılır; diğerleri korunur |
| 4 | `gold` veya `rozet` negatif okunursa | `max(0, value)` ile klamplanır; `Economy.initialize(0, rozet)` / `initialize(gold, 0)` |
| 5 | `save_version` < `CURRENT_SAVE_VERSION` | Migration çalışır; eksik anahtarlar varsayılanla doldurulur; `save_version` güncellenir |
| 6 | `save_version` > `CURRENT_SAVE_VERSION` | `push_warning`; bilinen anahtarlar okunur; bilinmeyenler sessizce yoksayılır |
| 7 | Atomik yazma sırasında kapanma (`.tmp` diskte kalır) | Mevcut `.cfg` bozulmamış; veri kaybı yok; bir sonraki açılışta 8. madde devreye girer |
| 8 | Açılışta `save_game.cfg.tmp` kalıntısı tespit edilir | `FileAccess.remove()` ile silinir; `push_warning("Stale .tmp removed")`; normal yükleme devam eder |
| 9 | İki notification aynı anda / kısa aralıkla tetiklenir | Debounce (`SAVE_DEBOUNCE_MS`): ilk tetikleyici yazar, ikincisi yoksayılır; tek fiziksel yazma |
| 10 | `LOADING` durumunda `_save_game()` tetiklenir | State guard: `if _state != READY: return`; `push_warning("Save skipped — still loading")`. LOADING süresi < 1 sn olduğundan veri kaybı riski minimumdur. LOADING sırasında uygulama çökerse (batarya / crash) en son kapanış kaydı korunur — o oturumda yapılan değişiklikler (henüz kaydedilmemiş upgrade vb.) kaybolabilir; bu kabul edilen bir risk. |
| 11 | Disk dolu — `FileAccess.store_*` `false` döner | `.tmp` silinir; mevcut `.cfg` korunur; `push_error("Save failed: disk full")` |
| 12 | `last_seen_unix = 0` (yeni oyun) | Downstream sistemler elapsed = 0 alır; offline üretim hesaplanmaz |
| 13 | `get_save_data()` listede olmayan sistemden bekleniyor | Yeni sistem eklenmek için GDD güncellemesi ve autoload sırası revizyonu gerekir — mimari olarak kasıtlı kısıt |

## Dependencies

### Upstream (SaveLoadManager'a veri sağlayan / tetikleyen sistemler)

| Sistem | Bağımlılık Türü | Interface |
|--------|----------------|-----------|
| **Godot OS** | Hard | `NOTIFICATION_WM_GO_BACK_REQUEST`, `NOTIFICATION_APPLICATION_FOCUS_OUT` |
| **Upgrade Tree** | Hard | Satın alma sinyali → `_save_game()`; `get_save_data() -> Dict` |
| **Location/Prestige** | Hard | Lokasyon kilidi sinyali → `_save_game()`; `get_save_data() -> Dict` |
| **Recipe System** | Hard | Tarif kilidi sinyali → `_save_game()`; `get_save_data() -> Dict` |
| **Employee System** | Hard | İşe alma/çıkarma sinyali → `_save_game()`; `get_save_data() -> Dict` |
| **Economy** | Hard | `Economy.get_save_data() -> Dict` — kayıt anında gold/rozet snapshot |
| **Oven/Baking** | Soft | `get_save_data() -> Dict` — fırın slot durumu (GDD kesinleşmedi) |
| **Collection/Dex** | Soft | `get_save_data() -> Dict` |
| **Tutorial System** | Soft | `get_save_data() -> Dict` |
| **Daily Task** | Soft | `get_save_data() -> Dict` |

### Downstream (SaveLoadManager'ın veri ilettiği sistemler)

| Sistem | Bağımlılık Türü | Interface |
|--------|----------------|-----------|
| **Economy** | Hard | `Economy.initialize(gold, rozet)` — startup; bir kez |
| **Economy** | Hard | `Economy.apply_save_data(data)` |
| **TimeManager** | Hard | `SaveLoadManager.last_seen_unix` property — pull mimarisi |
| **Upgrade Tree** | Hard | `apply_save_data(data)` |
| **Location/Prestige** | Hard | `apply_save_data(data)` |
| **Recipe System** | Hard | `apply_save_data(data)` |
| **Employee System** | Hard | `apply_save_data(data)` |
| **Oven/Baking** | Soft | `apply_save_data(data)` |
| **Collection/Dex** | Soft | `apply_save_data(data)` |
| **Tutorial System** | Soft | `apply_save_data(data)` |
| **Daily Task** | Soft | `apply_save_data(data)` |

> **Autoload sırası notu:** `SaveLoadManager` tüm autoload'lardan önce yüklenir
> (`project.godot [autoload]` sırası). Bu nedenle startup'ta **başka sistemlere
> bağımlı değildir**; diğerleri SaveLoadManager'a bağımlıdır.
> Hard bağımlılık koptuğunda progression kaydedilemez veya kritik yol bozulur.
> Soft bağımlılık koptuğunda yalnızca o alt sistemin verisi korunmaz; core loop çalışır.

## Tuning Knobs

| Değer | Varsayılan | Güvenli Aralık | Çok düşükse | Çok yüksekse | Sahip |
|-------|-----------|----------------|-------------|--------------|-------|
| `CURRENT_SAVE_VERSION` | `1` | `1–N` (sıralı tamsayı artış) | — | Migration zinciri karmaşıklaşır; versiyon atlamak yasak (1→3 geçersiz) | Bu GDD |
| `SAVE_FILE_PATH` | `"user://save_game.cfg"` | Production: sabit / Test: `"user://save_game_test.cfg"` | — | Yanlış path ile production kayıtları test'te bozulur | Bu GDD |
| `SAVE_DEBOUNCE_MS` | `500` | `200–1000` | İki hızlı sinyal çift yazma tetikler; gereksiz disk I/O | 1000ms üstü: kritik kapanış sinyali pencere içinde atlanabilir | Bu GDD |
| `first_close_shown` | `false` | `false` / `true` | Flag sıfırlanırsa her kapanışta toast gösterilir | Flag true sabitlenirse ilk kapanış toast hiç gösterilmez | Bu GDD |

> **Test izolasyonu:** GUT testleri `SAVE_FILE_PATH`'i override edebilmek için
> `SaveLoadManager` debug hook desteklemelidir —
> `func _set_save_path(path: String)` (yalnızca DEBUG build). Test sonrası
> `user://save_game_test.cfg` silinir.

## Visual/Audio Requirements

Save/Load System doğrudan görsel veya ses çıktısı üretmez. Tek istisna:

| Tetikleyici | Efekt | Sahip Sistem |
|-------------|-------|-------------|
| `first_close_shown` `false` → `true` geçişi (ilk kapanış) | "İlerleme kaydedildi" toast bildirimi — kısa, sessiz, ekranın altında | UI/HUD |

Sonraki tüm kayıtlar görsel/ses çıktısı vermez.

## UI Requirements

Save/Load System kullanıcıya hiçbir kayıt UI'ı göstermez. Tek görünür
davranış "ilk kapanış toast" bildirimidir — bu da UI/HUD sistemine
`first_close_shown` flag değişimi sinyali ile devredilir. İçerik ve
gösterim süresi UI/HUD GDD'de tanımlanır.

## Acceptance Criteria

| # | Kriter | Test Yöntemi |
|---|--------|-------------|
| 1 | Kayıt yok → `Economy.initialize(0, 0)` çağrılır, oyun çökmez | GUT unit test: kayıt olmadan `_load_game()`; Economy mock ile doğrula |
| 2 | Kayıt var → `Economy.initialize(saved_gold, saved_rozet)` doğru değerlerle çağrılır | GUT integration test: `.cfg` yaz → `_load_game()` → mock argüman doğrulama |
| 3 | `SaveLoadManager._ready()` Economy `_ready()`'den önce çalışır | `project.godot [autoload]` sıra doğrulaması + `_ready()` çağrı sırası logu |
| 4 | `NOTIFICATION_WM_GO_BACK_REQUEST` tetiklenince `last_seen_unix` zamanla eşleşir (±1 sn) | GUT integration test: mock timestamp; yazılan `.cfg`'den `last_seen_unix` karşılaştır |
| 5 | Kayıt sırasında önce `.tmp`, sonra `.cfg`; işlem sonrası `.tmp` yok | GUT integration test: ara adımlarda dosya varlığı doğrula |
| 6 | Disk dolu (FileAccess mock → false) → mevcut `.cfg` bozulmaz | GUT unit test: `FileAccess.store_*` mock → önceki `.cfg` içeriği değişmemiş |
| 7 | Bozuk kayıt → varsayılanlar; oyun çökmez | GUT unit test: bozuk `.cfg` → `_load_game()` → exception yok, `initialize(0,0)` |
| 8 | Eksik anahtar → o anahtarın varsayılanı; diğerleri korunur | GUT unit test: `gold` eksik, `rozet=500` → `initialize(0, 500)` |
| 9 | Peş peşe iki sinyal `SAVE_DEBOUNCE_MS` içinde → tek fiziksel yazma | GUT unit test: `_save_game()` spy; iki hızlı sinyal → yazma sayısı `1` |
| 10 | `save_version=0` → migration → bellekte `save_version=1` | GUT integration test: eski versiyonlu `.cfg` → `_load_game()` → versiyon doğrula |
| 11 | `first_close_shown=false` → kapanışta toast gösterilir → `true` kaydedilir; sonraki kapanışta toast yok | GUT integration test: flag takibi + ikinci kapanış doğrulaması |
| 12 | `_process()` / `_physics_process()` içinde dosya I/O yok | Kod incelemesi: `SaveLoadManager.gd`'de `FileAccess`/`ConfigFile`/`DirAccess` kullanımı aranır |
| 13 | `last_seen_unix` kapanışta `Time.get_unix_time_from_system()` ile eşleşir | GUT integration test: Time mock → `_save_game()` → yazılan değer mock değeriyle aynı |

## Open Questions

| # | Soru | Sahip | Hedef |
|---|------|-------|-------|
| OQ-1 | **Autoload sırası ADR:** `SaveLoadManager` ilk autoload olma kararı bir Architecture Decision Record'a bağlanmalı. `docs/architecture/adr-XXXX-saveload-autoload-order.md` oluşturulacak. | Lead Programmer | ADR hazırlanması (D-05 implementasyon öncesi) |
| OQ-2 | **`oven_state` Dictionary formatı geçici:** `{slot_id: {recipe_id, start_time_unix, is_active}}` şeklinde önerildi. Oven/Baking GDD yazılınca bu format değişebilir. Oven GDD tamamlanınca `[gameplay] oven_state` anahtarı bu GDD'de güncellenmeli. | Systems Designer | Oven/Baking GDD (sistem #9) |
| OQ-3 | **`SAVE_DEBOUNCE_MS` = 500 ms cihaz testi:** Debounce değeri düşük güçlü Android cihazlarda disk I/O ile birleşince yeterli mi? Gerçek cihaz testine kadar varsayılan. | Lead Programmer | Vertical Slice playtest |
| OQ-4 | **`get_save_data() / apply_save_data()` GDScript interface standardı:** Tüm downstream sistemlerin bu iki metodu implemente etmesi gerekiyor. Godot 4.6'da `@abstract` anahtar sözcüğü (4.5+) ile bir `Saveable` base class / interface tanımlanabilir mi? | Lead Programmer | Coding Standards güncellemesi |
