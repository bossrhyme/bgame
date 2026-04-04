# Content Database

> **Status**: Designed — Pending Review
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-04
> **Implements Pillar**: Data-Driven Design — "Gameplay değerleri asla hardcode edilmez"

## Overview

Content Database, Ekmek Ustası'nın tüm statik oyun içeriğini — tarifler,
upgrade'ler, çalışanlar, lokasyonlar ve müşteri tipleri — kod dışında, Godot
`Resource` dosyaları olarak tanımlayan veri katmanıdır.

Her içerik türü için bir `Resource` alt sınıfı tanımlanır:
`RecipeData`, `UpgradeData`, `EmployeeData`, `LocationData`, `CustomerTypeData`.
Veriler `assets/data/` altında `.tres` dosyalarına kaydedilir.

Uygulama başlangıcında `ContentRegistry` autoload tüm bu Resource'ları yükler ve
ID-tabanlı `Dictionary` yapıları aracılığıyla sisteme sunar. Gameplay kodu hiçbir
zaman sayısal değerleri doğrudan içermez; hepsini
`ContentRegistry.get_recipe("white_bread")` gibi çağrılarla alır.

## Player Fantasy

Content Database, oyuncunun hiç duymadığı ama her tıklamada deneyimlediği bir
sistemdir. Doğru çalıştığında: yeni bir tarif açıldığında rakam doğrudur,
"Baguette 85 altın" gerçekten 85 altın getirir, 5. seviye upgrade gerçekten
%120 hız sağlar.

Oyuncu rakamların *"hissettiriyor"* olmasını bekler — bu güveni yaratan şey
tutarlı, merkezi, test edilmiş bir veri katmanıdır. Yanlış çalıştığında
(bir tarifin değeri hardcode edilmiş ama başka bir yerde farklı tanımlıysa)
oyuncu dengeyi kırık hisseder. Bu sistem tasarımcının not defteri gibidir:
tüm oyun dengesini tek bir yerde görmek ve değiştirmek.

## Detailed Design

### Core Rules

1. Her içerik türü için bir `Resource` alt sınıfı tanımlanır; her kayıt
   bir `.tres` dosyasıdır (`assets/data/<type>/`).
2. `ContentRegistry` autoload, `_ready()` içinde tüm `.tres` dosyalarını
   tarayarak `Dictionary[StringName, Resource]` yapılarına yükler.
3. Her kayıtta `id: StringName` alanı zorunludur ve dosya adıyla eşleşmelidir
   (örn: `white_bread.tres` → `id = &"white_bread"`).
4. Gameplay kodu doğrudan `.tres` dosyasına referans almaz; hep
   `ContentRegistry.get_recipe(id)` gibi erişir.
5. `ContentRegistry` **salt okunur** — runtime'da kayıt eklenemez, silinemez
   veya değiştirilemez.
6. Bilinmeyen `id` sorgulandığında: `null` döner + hata logu basılır. Çökmez.

### Resource Schemas

```gdscript
# RecipeData extends Resource
@export var id: StringName
@export var display_name: String
@export var category: RecipeCategory          # BASIC, WORLD, SPECIAL, SWEET, LEGENDARY
@export var base_value: int                   # altın/adet
@export var bake_time_seconds: float
@export var location_id: StringName           # "" = her yerde açık
@export var animation_key: StringName         # AnimationStateMachine referansı
@export var sfx_bake_key: StringName          # AudioBus referansı
@export var sfx_harvest_key: StringName

# UpgradeData extends Resource
@export var id: StringName
@export var display_name: String
@export var category: UpgradeCategory         # PRODUCTION, CUSTOMER, DELIVERY
@export var effect_type: UpgradeEffectType    # BAKE_SPEED, OVEN_CAPACITY, DOUGH_QUALITY,
                                              # AUTO_DOUGH, STORAGE_CAP, CUSTOMER_CAPACITY,
                                              # PATIENCE, VIP_RATE, DELIVERY_CAPACITY,
                                              # DELIVERY_SPEED
@export var effect_per_level: Array[float]    # indeks 0 = seviye 1 etkisi
@export var base_cost: int                    # cost(n) = base_cost × 3^(n-1)
@export var max_level: int                    # effect_per_level.size() ile eşleşmeli

# EmployeeData extends Resource
@export var id: StringName
@export var display_name: String
@export var role: EmployeeRole                # DOUGH_MAKER, OVEN_MASTER, CASHIER, DELIVERY
@export var daily_wage: int
@export var effect_type: UpgradeEffectType    # UpgradeEffectType ile paylaşımlı enum
@export var effect_per_level: Array[float]
@export var max_level: int

# LocationData extends Resource
@export var id: StringName
@export var display_name: String
@export var income_multiplier: float          # 1.0 = köy, 1.5 = Paris
@export var exclusive_recipe_ids: Array[StringName]
@export var theme_key: StringName             # VisualProgression için

# CustomerTypeData extends Resource
@export var id: StringName
@export var display_name: String
@export var patience_seconds: float
@export var gold_multiplier: float
@export var spawn_weight: float               # göreceli olasılık; normalize edilir
```

> **Level indexing kuralı:**
> - `effect_per_level` array'i **0-indexed**: `effect_per_level[0]` = seviye 1 etkisi, `effect_per_level[2]` = seviye 3 etkisi.
> - Maliyet formülü **1-indexed** `level` parametresi kullanır: `cost(level=3) = base_cost × 3^2 = 450`.
> - Upgrade kodu: `effect_per_level[current_level - 1]` ile seviyeye karşılık gelen etkiyi alır.

### States and Transitions

| Durum | Açıklama | Tetikleyici |
|-------|----------|------------|
| `LOADING` | `_ready()` — `.tres` dosyaları okunuyor, Dictionary'ler dolduruluyor | App başlatma |
| `READY` | Tüm kayıtlar yüklendi, sorgular yanıtlanabilir | Yükleme tamamlandı |
| `ERROR` | Eksik/bozuk `.tres` dosyası — hata logu + null döner | Geçersiz dosya |

Geçiş: `LOADING → READY` (normal) veya `LOADING → ERROR` (bozuk kayıt; sistem
yine `READY`'ye geçer ama o kayıt `null` döner).

### Interactions with Other Systems

| Sistem | Alır | ContentRegistry API |
|--------|------|---------------------|
| **Recipe System** | `RecipeData` | `get_recipe(id) -> RecipeData` |
| **Upgrade Tree** | `UpgradeData` | `get_upgrade(id) -> UpgradeData` |
| **Employee System** | `EmployeeData` | `get_employee(id) -> EmployeeData` |
| **Location System** | `LocationData` | `get_location(id) -> LocationData` |
| **Customer/Order** | `CustomerTypeData` | `get_customer_type(id) -> CustomerTypeData` |
| **Unlock Resolver** | tüm tarifler | `get_all_recipes() -> Array[RecipeData]` |

> **Not:** `ContentRegistry` hiçbir sisteme doğrudan çağrı yapmaz.
> Pull mimarisi — downstream sistemler ihtiyaç duydukça sorgular.

## Formulas

Content Database saf veri katmanıdır — kendi hesaplama mantığı minimumdur.

### F-1: Upgrade Maliyet (referans — canonical tanım Upgrade Tree GDD'sinde)

```
cost(level) = base_cost × 3^(level - 1)
```

| Değişken | Kaynak | Örnek |
|----------|--------|-------|
| `base_cost` | `UpgradeData.base_cost` | 50 |
| `level` | Oyuncunun mevcut seviyesi + 1 | 3 |
| **`cost`** | Çıktı | 450 |

Örnek tablo — `base_cost = 50`:

| Seviye | Maliyet |
|--------|---------|
| 1 | 50 |
| 2 | 150 |
| 3 | 450 |
| 4 | 1.350 |
| 5 | 4.050 |

### F-2: Müşteri Spawn Normalizasyonu

```
normalized_weight(type) = spawn_weight(type) / Σ(all active spawn_weights)
```

`spawn_weight = 0` olan tipler (örn: festival müşterisi etkinlik dışında) aktif
havuzdan çıkarılır, payda hesabına dahil edilmez.

Örnek — 4 tip, etkinlik dışı:

| Tip | spawn_weight | Normalized |
|-----|-------------|-----------|
| Sabırlı | 10 | %55.6 |
| Acele | 6 | %33.3 |
| VIP | 2 | %11.1 |
| Festival | 0 | Pasif — havuzda yok |

> Diğer formüller (`recipe_value`, `offline_production`, `satisfaction_loss`)
> bu sistemin verilerini kullanır fakat hesaplama sahipliği Economy,
> Oven/Baking ve Customer/Order GDD'lerindedir.

## Edge Cases

| # | Durum | Beklenen Davranış |
|---|-------|-------------------|
| EC-1 | `get_recipe("nonexistent_id")` çağrıldı | `null` döner + `push_error()` logu; çökme yok |
| EC-2 | Aynı `id`'ye sahip iki `.tres` dosyası | İkincisi birincinin üzerine yazar; `push_warning()` logu; yükleme sırası alfabetik (deterministik) |
| EC-3 | `UpgradeData.effect_per_level` boş array | Kayıt geçersiz sayılır; `push_error()` logu; sorguda `null` döner |
| EC-4 | `UpgradeData.max_level` ≠ `effect_per_level.size()` | Hata logu; `max_level` otomatik olarak `effect_per_level.size()` değerine sabitlenir |
| EC-5 | `RecipeData.location_id` dolu ama o lokasyon kayıtlı değil | Tarif yüklenir; Location System açılış koşulunu değerlendiremediğinden tarif hiç açılmaz (güvenli default) |
| EC-6 | Tüm `CustomerTypeData.spawn_weight = 0` | Sıfıra bölme riski: registry tespit eder, tüm ağırlıkları `1`'e sıfırlar, `push_error()` basar |
| EC-7 | `.tres` dosyası bozuk (disk hatası) | Kayıt atlanır; `push_error()` logu; diğer kayıtlar normal yüklenir |
| EC-8 | `get_all_recipes()` çağrıldığında 0 tarif yüklü | Boş `Array[RecipeData]` döner; çökmez; hata logu; Unlock Resolver boş array ile çalışır |

## Dependencies

### Upstream (bu sistem bunlara bağımlı)

**Yok.** Content Database, Foundation katmanında yer alır.

### Downstream (bu sisteme bağımlı olanlar)

| Sistem | Bağımlılık Türü | ContentRegistry API |
|--------|----------------|---------------------|
| **Recipe System** | Hard | `get_recipe(id)`, `get_all_recipes()` |
| **Upgrade Tree System** | Hard | `get_upgrade(id)`, `get_all_upgrades()` |
| **Employee System** | Hard | `get_employee(id)`, `get_all_employees()` |
| **Location/Prestige System** | Hard | `get_location(id)`, `get_all_locations()` |
| **Customer/Order System** | Hard | `get_customer_type(id)`, `get_all_customer_types()` |
| **Unlock/Condition Resolver** | Soft | `get_all_recipes()`, `get_all_upgrades()` (koşul taraması) |

## Tuning Knobs

Content Database'in "tuning knob"ları doğrudan `.tres` dosyalarıdır — tasarımcı
kodu açmadan editörde değerleri düzenler. Bu sistemin temel tasarım amacı budur.

`ContentRegistry`'nin kendisindeki ayarlanabilir tek yapı yükleme dizinleridir
(`@export` olarak tutulur, hardcode edilmez).

| Değer | Varsayılan | Güvenli Aralık | Çok Düşükse | Çok Yüksekse |
|-------|-----------|----------------|-------------|--------------|
| Toplam tarif sayısı | 40+ | 1–200 | Az içerik = kısa oyun ömrü | 200+ → mobilde bellek baskısı |
| `spawn_weight` (CustomerTypeData) | 2–10 / tip | 0–100 | 0 = pasif tip; tümü 0 → EC-6 | Yüksek = o tip çok sık spawn |
| `income_multiplier` (LocationData) | 1.0 → 2.0 artan | 0.5–5.0 | < 1.0 → önceki şehirden kötü gelir (regresyon) | > 3.0 → economy dengesi bozulur |
| `base_cost` (UpgradeData) | 50–2000 | 10–50000 | Çok düşük → oyun çok hızlı maxlanır | Çok yüksek → ilerleme imkânsız |

## Visual/Audio Requirements

N/A — pure data layer, no visual or audio output.

## UI Requirements

N/A — no direct UI; data surfaces through Recipe System and Upgrade Tree UI.

## Acceptance Criteria

| # | Kriter | Test Yöntemi |
|---|--------|-------------|
| AC-1 | `ContentRegistry._ready()` sonrası tüm kayıt tipleri sorgulabilir | Integration test |
| AC-2 | `get_recipe("white_bread")` → `RecipeData` döner; `base_value == 10`, `bake_time_seconds == 60.0`, `category == RecipeCategory.BASIC` | Unit test |
| AC-3 | `get_recipe("invalid_id")` → `null` döner, çökme yok, `push_error()` logu var | Unit test (EC-1) |
| AC-4 | Aynı `id`'li iki `.tres` varsa `push_warning()` logu var, son yüklenen geçerli | Unit test (EC-2) |
| AC-5 | `effect_per_level = []` olan `UpgradeData` → `get_upgrade()` `null` döner, hata logu var | Unit test (EC-3) |
| AC-6 | Tüm `spawn_weight = 0` senaryosunda sıfıra bölme hatası yok, `push_error()` var | Unit test (EC-6) |
| AC-7 | `get_all_recipes()` ≥ 40 `RecipeData` döner (tüm starter `.tres` dosyaları yüklüyken) | Integration test |
| AC-8 | `ContentRegistry` kaynak dosyasında downstream sistem import/referansı bulunmaz | Kod incelemesi |
| AC-9 | Yeni `.tres` dosyası `assets/data/recipes/`'a eklenince Registry otomatik bulur; manuel kayıt gerekmez | Manual test |
| AC-10 | Bozuk `.tres` dosyası varlığında diğer kayıtlar normal yüklenir; uygulama çökmez | Unit test (EC-7) |

## Open Questions

| # | Soru | Sahip | Hedef |
|---|------|-------|-------|
| OQ-1 | `ContentRegistry` tüm `.tres` dosyalarını `dir_contents()` ile mi tarasın yoksa bir manifest `.tres` dosyasından mı okusun? Manifest daha hızlı ama elle güncellenmelidir. | Lead Programmer | Implementasyon başlangıcı |
| OQ-2 | Lokalizasyon gerekirse `display_name` alanları StringName key'e mi dönüşmeli (çeviri sistemi için), yoksa şimdi `String` kalabilir mi? | Localization Lead | Localization milestone'u |
