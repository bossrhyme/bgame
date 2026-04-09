# Unlock/Condition Resolver GDD

**Sistem:** #14 / 29
**Kategori:** Core — MVP
**Durum:** Designed
**Bağımlılıklar:** Recipe System, Upgrade Tree, Location/Prestige System

---

## 1. Overview

Unlock/Condition Resolver, oyundaki tüm kilit açma koşullarını merkezi olarak değerlendiren servis sistemidir. Recipe System, Upgrade Tree ve Location/Prestige System kilit koşullarını bu sisteme bildirir; Resolver bu koşulların sağlanıp sağlanmadığını oyun durumuna göre hesaplar ve ilgili sistemi sinyal ile bilgilendirir. Üç koşul tipi desteklenir: `sale_count` (belirli sayıda ekmek satılması), `location_unlocked` (bir şehrin açılması) ve `ingredient_owned` (özel malzeme edinilmesi). Resolver veri deposu değil servis katmanıdır — koşul verisini ilgili sistemden alır, oyun durumunu Economy/Recipe/Location'dan sorgular, sonucu döndürür.

## 2. Player Fantasy

**Temel his:** Oyuncu Unlock/Condition Resolver'ı hiç duymaz — ama her "yeni tarif açıldı!" anının arkasında o vardır. Koşul sağlandığı an tetiklenen bildirim, animasyon ve ses; tüm bunları zamanında, doğru şekilde ateşleyen sessiz bir motor.

**Tasarımcı perspektifi:** Tüm unlock koşulları tek bir yerde tanımlanır ve test edilir. Yeni bir koşul tipi eklemek için Recipe System veya Location System'e dokunmak gerekmez — sadece Resolver'a yeni bir tip eklenir.

**Kaçınılması gereken:** Koşul değerlendirmesinin farklı sistemlere dağılması. Her sistem kendi unlock mantığını yazarsa tutarsızlık ve test güçlüğü kaçınılmaz olur.

## 3. Detailed Rules

### Koşul Tipleri

| Tip | Açıklama | Gerekli Veri |
|-----|----------|-------------|
| `sale_count` | Belirli sayıda ekmek satılması | `target_category`, `required_count` |
| `location_unlocked` | Belirli bir şehrin açılmış olması | `required_location_id` |
| `ingredient_owned` | Belirli malzemeden en az 1 adet sahibi olunması | `required_ingredient_id` |

### Değerlendirme Akışı

1. İlgili sistem (Recipe, Location, vb.) `evaluate(condition)` çağırır
2. Resolver koşul tipine göre ilgili sistemi sorgular
3. Koşul sağlandıysa `true` döner → çağıran sistem `LOCKED → AVAILABLE` geçişini yapar
4. Resolver sinyal yayımlamaz; sadece bool döndürür — bildirim çağıran sistemin sorumluluğundadır

### AND Mantığı

- Bir içerik birden fazla koşul içeriyorsa tüm koşulların `true` olması gerekir
- `evaluate_all(conditions: Array[UnlockCondition]) → bool`

### Tetikleme Zamanlaması

- `sale_count`: Her satış sonrası ilgili tarifler için evaluate çağrılır
- `location_unlocked`: Lokasyon açılış sinyalinde ilgili tarifler için evaluate çağrılır
- `ingredient_owned`: Malzeme envantere girdiğinde ilgili tarifler için evaluate çağrılır

## 4. Formulas

Bu sistem matematiksel formül içermez — boolean mantık kullanır.

### Tekil Koşul

```
evaluate(condition) → bool:
  match condition.type:
    "sale_count"        → SaleTracker.get_count(condition.target_category) >= condition.required_count
    "location_unlocked" → LocationSystem.is_unlocked(condition.required_location_id)
    "ingredient_owned"  → Inventory.get_count(condition.required_ingredient_id) >= 1
    _                   → false  # bilinmeyen tip → güvenli varsayılan
```

### Çoklu Koşul (AND)

```
evaluate_all(conditions) → bool:
  return conditions.all(func(c): evaluate(c))
```

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Bilinmeyen koşul tipi | `evaluate()` `false` döner + hata loglanır; oyun çökmez |
| `target_category` boş string (`""`) ile `sale_count` | Tüm kategorilerdeki satışlar toplanır |
| Koşul birden fazla kez sağlanırsa | `AVAILABLE` durumu değişmez; duplicate tetikleme yoksayılır |
| Lokasyon sistemi henüz başlatılmamışken evaluate çağrılırsa | `false` döner + uyarı logu; sistem hazır olunca tekrar değerlendirilir |
| Malzeme envanteri sistemi yokken `ingredient_owned` değerlendirilirse | `false` döner + hata logu |
| Tüm koşullar boş array ile `evaluate_all` çağrılırsa | `true` döner (boş AND = her zaman doğru) |
| Aynı tarif için birden fazla evaluate aynı frame'de tetiklenirse | İlk `true` sonucunda işlem yapılır, sonrakiler yoksayılır |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Recipe System** (#10) | `UnlockCondition` verisini sağlar; koşul sağlanınca `LOCKED → AVAILABLE` geçişini yapar |
| **Location/Prestige System** (#17) | `location_unlocked` koşulu için `is_unlocked()` sorgusu |
| **Economy System** (#4) *(dolaylı)* | `sale_count` için satış sayacı Economy üzerinden takip edilir |
| **Save/Load System** (#5) | Satış sayacı ve malzeme envanteri kayıt/yükleme için bağımlı sistemlerden alınır |

## 7. Tuning Knobs

> Bu sistem parametre içermez — boolean değerlendirme yapar. Koşul eşik değerleri (`required_count`, vb.) `RecipeData` Resource'larında tanımlanır; Resolver bunları okur, değiştirmez.

## 8. Acceptance Criteria

- [ ] `sale_count` koşulu: toplam satış sayısı eşiğe ulaşınca `evaluate()` `true` döner
- [ ] `sale_count` ile `target_category = ""`: tüm kategoriler sayılır
- [ ] `location_unlocked` koşulu: lokasyon açılınca `evaluate()` `true` döner
- [ ] `ingredient_owned` koşulu: malzeme envanterde varken `evaluate()` `true` döner
- [ ] `evaluate_all([])` boş array için `true` döner
- [ ] Bilinmeyen koşul tipi: `false` döner, hata loglanır, oyun çökmez
- [ ] AND mantığı: tüm koşullar sağlanmadan `evaluate_all()` `false` döner
- [ ] Duplicate tetikleme: aynı tarif için ikinci `true` sonucu yoksayılır
- [ ] GUT testleri: her koşul tipi için pozitif/negatif senaryolar, boş array, bilinmeyen tip
