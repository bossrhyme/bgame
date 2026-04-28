# Location/Prestige System GDD

**Sistem:** #17 / 29
**Kategori:** Progression — Vertical Slice
**Durum:** Designed (implementasyon S4+)
**Bağımlılıklar:** Recipe System (#10), Upgrade Tree System (#12), Economy System (#4), Unlock/Condition Resolver (#14)

---

## 1. Overview

Location/Prestige System, oyuncunun farklı şehir lokasyonlarını açarak yeni tarif kategorilerine erişmesini ve belirli bir noktada "prestij" yaparak oyunu daha yüksek bir başlangıç avantajıyla yeniden başlatmasını sağlar. Beş lokasyon vardır: Başlangıç (açık), İç Anadolu, İstanbul, Paris, Roma. Her lokasyon belirli açma koşullarına sahiptir; koşullar `UnlockConditionResolver` üzerinden değerlendirilir. Prestij tüm altını sıfırlar, Rozet bakiyesini korur ve bonus Rozet verir — oyuncuya daha derin bir progression döngüsü sunar.

## 2. Player Fantasy

**Temel his:** "Yeni şehir açıldı!" — Saatler boyunca ekmek yapıp satmanın karşılığı somut bir ödülle geliyor: İstanbul haritada beliriyor, yeni tariflerin kilidinin açılacağı o şehrin fırını sana ait. Her şehir kendi kültürel kimliğini, rengini ve tarifini taşır.

**İkincil his:** Prestij kararı. "Sıfırlamak istiyor muyum?" sorusu önemli bir an. Tekrar başlamak cesaret ister — ama bilinen yolda daha hızlı ilerleme ve kalıcı Rozet bonusu caziptir. Her prestij oyuncu için kişisel bir "sen X kez prestij yaptın" statüsü yaratır.

**Kaçınılması gereken:** Lokasyon açmanın çok kolay veya çok zor hissettirmesi. 2. şehir, oyunun ilk saatlerinde erişilebilir olmalı; 5. şehir ise haftalık oynama gerektirmelidir. Prestij, ilk açılıştan en az 3 gün sonra kullanıcı için anlamlı olmalı.

## 3. Detailed Rules

### Lokasyon Listesi

| # | Lokasyon ID | Görünen Ad | Bağlı Tarif Kategorisi | Tarif Sayısı |
|---|-------------|------------|------------------------|--------------|
| 1 | `start` | Başlangıç | `basic` | 6 |
| 2 | `inner_anatolia` | İç Anadolu | `wheat` | 8 |
| 3 | `istanbul` | İstanbul | `sweet` | 8 |
| 4 | `paris` | Paris | `french` | 10 |
| 5 | `rome` | Roma | `italian` | 8 |

### Lokasyon Açma Sıralaması

- Lokasyonlar yalnızca **sırayla** açılabilir. 4. lokasyon açılmadan 5. açılamaz.
- Açık bir lokasyon **kapatılamaz** — ilerleme kalıcıdır (prestij dahil; aşağıya bkz.).

### Açma Koşulları (Unlock/Condition Resolver üzerinden)

| Lokasyon | Koşul 1 | Koşul 2 | Tip |
|----------|---------|---------|-----|
| İç Anadolu | `basic` kategoriden 50 ekmek satıldı | — | `sale_count` |
| İstanbul | `wheat` kategoriden 100 ekmek satıldı | `oven_capacity` ≥ seviye 2 | `sale_count` + UpgradeTree |
| Paris | `sweet` kategoriden 150 ekmek satıldı | `showcase_width` ≥ seviye 1 | `sale_count` + UpgradeTree |
| Roma | Prestij sayısı ≥ 1 | `french` kategoriden 200 ekmek satıldı | `prestige_count` + `sale_count` |

Koşullar AND mantığıyla değerlendirilir; tüm koşullar sağlanmalıdır.

### Lokasyon Geçiş Akışı

```
Oyuncu lokasyon butonuna basar
    → UnlockConditionResolver.evaluate_all(koşullar)
        [false] → "Koşullar henüz karşılanmadı" UI mesajı
        [true]  → LocationSystem.unlock_location(location_id)
                    → _locations[location_id].unlocked = true
                    → location_unlocked.emit(location_id)
                    → UnlockConditionResolver.unlock_location(location_id)
                        (Resolver watch listelerini günceller)
                    → RecipeManager yeni tarifler AVAILABLE durumuna geçer
```

### Prestij Kuralları

1. Prestij yalnızca **Roma lokasyonu açıksa** kullanılabilir.
2. Oyuncu onay ekranını geçmeden prestij gerçekleşmez (geri alınamaz).
3. Prestij yapılınca:
   - `gold_balance = 0` (Economy sıfırlanır)
   - `rozet_balance` korunur
   - Tüm upgrade seviyeleri 0'a sıfırlanır
   - Tüm tarif durumları `UNLOCKED → LOCKED` döner (koşullar yeniden sağlanmalı)
   - Lokasyonlar 1. lokasyona döner (sadece Başlangıç açık)
   - `prestige_count` +1 artar
   - Bonus Rozet kazanılır (F-2)
4. `prestige_count` save dosyasına kaydedilir; prestij sayısı kalıcıdır.

### Yeni Koşul Tipi: `prestige_count`

`UnlockConditionResolver` bu koşul tipini desteklemeli:
- `required_prestige_count: int` — minimum prestij sayısı
- Değerlendirme: `location_system.prestige_count >= required_prestige_count`

Bu, S4 implementasyonunda Resolver'a eklenecek yeni bir `UnlockConditionType` gerektirmektedir.

## 4. Formulas

### F-1: Lokasyon Açma Satış Koşulu

```
sale_condition_met = recipe_manager.get_category_sale_count(category_id) >= required_count
```

| Lokasyon | category_id | required_count |
|----------|-------------|----------------|
| İç Anadolu | `basic` | 50 |
| İstanbul | `wheat` | 100 |
| Paris | `sweet` | 150 |
| Roma | `french` | 200 |

### F-2: Prestij Rozet Bonusu

```
prestige_rozet_bonus(n) = 10 × n
```

| Prestij # (n) | Rozet Bonusu |
|--------------|--------------|
| 1 | 10 |
| 2 | 20 |
| 3 | 30 |
| 4 | 40 |
| 5+ | 10 × n |

**Örnek:** İlk prestijde +10 Rozet. Üçüncü prestijde +30 Rozet, kümülatif toplam +60 Rozet.

**Mantık:** Her prestij bir öncekinden daha değerli; oyuncu ilerledikçe ödül büyür.

### F-3: Upgrade Seviye Koşulu

```
upgrade_condition_met = upgrade_tree.get_current_level(upgrade_id) >= required_level
```

### F-4: Minimum Oyun Süresi Tahmini (Tasarım Referansı)

| Lokasyon | Tahmini Süre (Aktif Oyun) |
|----------|--------------------------|
| İç Anadolu | ~1 saat |
| İstanbul | ~4 saat |
| Paris | ~12 saat |
| Roma | ~1–3 gün + 1 prestij |

Bu değerler tuning sırasında ayarlanacaktır; formüle girmez.

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Roma açık değilken prestij menüsü açılırsa | Buton devre dışı, "Önce Roma'yı aç" mesajı |
| Lokasyon açıkken aynı lokasyon tekrar açılmaya çalışılırsa | Yoksayılır; `location_unlocked` tekrar yayımlanmaz |
| Prestij sırasında Economy.spend() başarısız olursa | gold=0 zaten prestij tarafından force-set edilir; spend atlanır |
| Prestij sonrası save dosyası bozulursa | prestige_count meta verisi ayrı bir bölümde kaydedilir; bozulursa 0 varsayılır ve uyarı basılır |
| 5. lokasyon açıkken `sale_count` koşulu olan lokasyon açılmaya çalışılırsa | Roma zaten son lokasyon; bu durum oluşamaz |
| Tüm lokasyonlar açık değilken prestige_count ≥ 1 olan kayıt yüklenirse | Locasyonlar prestige_count'a göre yeniden hesaplanmaz; kayıttaki unlocked durumu geçerlidir |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Recipe System (#10)** | Lokasyon açılınca ilgili kategori tarifleri AVAILABLE olur |
| **Upgrade Tree System (#12)** | İstanbul/Paris için upgrade seviye koşulu |
| **Economy System (#4)** | Prestijde gold sıfırlama |
| **Unlock/Condition Resolver (#14)** | Koşul değerlendirmesi; `location_unlocked` bildirimi |
| **Save/Load System (#8)** | `prestige_count`, `unlocked_locations`, `category_sale_counts` kaydedilir |

**Ters bağımlılık:** Unlock/Condition Resolver, `prestige_count` sorgusunda bu sisteme bağımlıdır. Dairesel bağımlılık önlemek için LocationSystem bir `get_prestige_count() -> int` metodu sunar; Resolver DI ile bu referansı alır.

## 7. Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Etki |
|-----------|-----------|----------------|------|
| İç Anadolu satış koşulu | 50 | [20, 150] | Düşük → 2. şehir çok hızlı; yüksek → ilk saatlerde sıkıcı |
| İstanbul satış koşulu | 100 | [50, 300] | Orta dönem progression hızı |
| Paris satış koşulu | 150 | [100, 500] | |
| Roma satış koşulu | 200 | [150, 800] | |
| Prestij Rozet bonusu çarpanı | 10 | [5, 25] | Yüksek → prestige ekonomisini domine eder |
| `upgrade_capacity` minimum (İstanbul) | 2 | [1, 3] | Düşük → upgrade yatırımı önemsiz hissettirer |

## 8. Acceptance Criteria

- [ ] İç Anadolu lokasyonu: 50 `basic` kategorisi satışı koşulu doğru değerlendiriliyor
- [ ] İstanbul lokasyonu: `wheat` satış + `oven_capacity` seviyesi AND mantığıyla doğrulanıyor
- [ ] Lokasyonlar sıralı açılıyor; 3. lokasyon 2. açılmadan erişilemiyor
- [ ] Prestij yalnızca Roma açıkken kullanılabilir
- [ ] Prestij sonrası: gold=0, rozet korunuyor, prestige_count +1 artıyor
- [ ] Prestij Rozet bonusu F-2 formülüne uyuyor (n=1 → +10, n=3 → +30)
- [ ] Prestij sonrası lokasyonlar 1'e dönüyor, upgrade'ler sıfırlanıyor
- [ ] prestige_count save dosyasına kaydedilip doğru yükleniyor
- [ ] Lokasyon açılınca `location_unlocked` sinyali yayılıyor
- [ ] Lokasyon açılınca bağlı tarif kategorisi AVAILABLE durumuna geçiyor
