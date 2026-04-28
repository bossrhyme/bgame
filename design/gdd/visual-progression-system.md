# Visual Progression System GDD

**Sistem:** #24a / 29
**Kategori:** UI — Vertical Slice
**Durum:** Designed
**Bağımlılıklar:** Upgrade Tree System (#12), UI/HUD System (#15)

---

## 1. Overview

Visual Progression System, `UpgradeTree.upgrade_purchased` sinyalini dinleyerek fırın sahnesinin görsel durumunu günceller. Her upgrade ID'si üç görsel kategoriden birine (OVEN, SHOWCASE, DECOR) eşlenir; kategori toplamı "görsel tier" değeri olarak sahne node'larına iletilir. Sahne node'ları bu tier değerine göre sprite frame, renk veya animasyon seçer. Sistem veri tutmaz — UpgradeTree'den anlık hesaplar.

## 2. Player Fantasy

**Temel his:** "Fırınom büyüdü." — Üçüncü oven_capacity upgrade'ini aldığında fırın görsel olarak farklılaşır; vitrin genişler, dekorasyon zenginleşir. Oyuncu para harcamanın karşılığını somut görür.

**İkincil his:** Kademeli dönüşüm. Bir tier'dan diğerine geçiş ani değil, kümülatiftir; her satın alma görsel etkiye biraz daha katkıda bulunur.

**Kaçınılması gereken:** Görsel değişimin fark edilemeyeceği kadar küçük olması. Her tier değişimi sahne tarafında en az bir gözle görülür fark üretmeli.

## 3. Detailed Rules

### Görsel Kategori Eşlemesi

| upgrade_id | Görsel Kategori |
|-----------|----------------|
| `oven_temperature` | OVEN |
| `dough_quality` | OVEN |
| `oven_capacity` | OVEN |
| `auto_dough` | OVEN |
| `ingredient_storage` | OVEN |
| `showcase_width` | SHOWCASE |
| `customer_satisfaction` | DECOR |
| `loyalty_card` | DECOR |
| `vip_lounge` | DECOR |

### Tier Hesabı

Her kategori için tier = o kategorideki tüm upgrade'lerin mevcut seviye toplamı:

```
oven_tier     = sum(level for upgrade in OVEN upgrades)
showcase_tier = sum(level for upgrade in SHOWCASE upgrades)
decor_tier    = sum(level for upgrade in DECOR upgrades)
```

### Sinyal Akışı

```
UpgradeTree.upgrade_purchased(id, level)
    → VisualProgressionSystem._on_upgrade_purchased(id, level)
        → Kategori hesapla (OVEN / SHOWCASE / DECOR)
        → Yeni tier = sum(tüm o kategorideki seviyeler)
        → Eski tier ile karşılaştır
        → Değişti ise ilgili sinyal emit et
```

### Başlangıç Durumu

`refresh(upgrade_tree)` metodu çağrıldığında tüm kategoriler yeniden hesaplanır ve mevcut tier sinyalleri emit edilir. Save/Load sonrası çağrılmalıdır.

## 4. Formulas

### F-1: Kategori Tier Hesabı

```
category_tier(C) = Σ upgrade_tree.get_current_level(id)   for id in CATEGORY_MAP[C]
```

**Maksimum değerler:**

| Kategori | Upgrade sayısı | Max tier | (Tüm upgrade'ler maxlenince) |
|---------|----------------|----------|------------------------------|
| OVEN | 5 | 22 | 5+5+5+3+4 |
| SHOWCASE | 1 | 3 | 3 |
| DECOR | 3 | 5 | 3+1+1 |

### F-2: Tier Değişim Koşulu

```
emit_signal ← new_tier ≠ old_tier
```

Sinyal yalnızca değer değişince yayılır; refresh sırasında dahi aynı tier ise sinyal yayılmaz.

**Örnek:**
- Başlangıç: oven_tier = 0
- `oven_temperature` → seviye 1: oven_tier = 1 → `oven_visual_changed(1)` emit
- `dough_quality` → seviye 1: oven_tier = 2 → `oven_visual_changed(2)` emit
- Refresh (her ikisi seviye 1): oven_tier = 2 → değişmedi → sinyal yok

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Bilinmeyen upgrade_id gelirse | Kategori eşlemesi yok → yoksay, push_warning |
| `refresh()` UpgradeTree null ise | push_warning, erken dön |
| Tier değişmeden aynı upgrade tekrar satın alınırsa | Sinyal yayılmaz (bu durum normalde oluşmaz — UpgradeTree seviyeyi artırır) |
| Tüm upgrade'ler maxlenirse | Tier sabit kalır; sonraki satın alma girişimi UpgradeTree tarafından reddedilir |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Upgrade Tree System (#12)** | `upgrade_purchased` sinyali + `get_current_level()` sorgusu |
| **UI/HUD System (#15)** | Sahne node'ları bu sistemin sinyallerine bağlanır |

## 7. Tuning Knobs

| Parametre | Tanım | Notlar |
|-----------|-------|--------|
| `OVEN_UPGRADES` | OVEN kategorisindeki upgrade ID listesi | Yeni upgrade eklenince buraya da ekle |
| `SHOWCASE_UPGRADES` | SHOWCASE kategorisindeki upgrade ID listesi | |
| `DECOR_UPGRADES` | DECOR kategorisindeki upgrade ID listesi | |

Maksimum tier değerleri upgrade ID listeleri değiştikçe otomatik güncellenir; sahne node'larının bu tier aralığını işleyebilmesi gerekir.

## 8. Acceptance Criteria

- [ ] `oven_temperature` upgrade satın alındığında `oven_visual_changed(1)` sinyali emit ediliyor
- [ ] Beş farklı OVEN upgrade satın alındığında tier kümülatif artıyor
- [ ] Bilinmeyen upgrade_id geldiğinde sinyal yayılmıyor, sistem çökmiyor
- [ ] `refresh(upgrade_tree)` çağrıldığında mevcut tier sinyalleri emit ediliyor
- [ ] Tier değişmeden aynı seviyede refresh yapılınca sinyal yayılmıyor
- [ ] GUT testleri: tier hesabı, kategori eşlemesi, sinyal yayımı, refresh davranışı
