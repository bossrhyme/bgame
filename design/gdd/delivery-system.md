# Delivery System GDD

**Sistem:** #27 / 29
**Kategori:** Gameplay — Alpha
**Durum:** Designed
**Bağımlılıklar:** Economy System (#4), Upgrade Tree System (#12), Time Tracking System (#1)

---

## 1. Overview

Delivery System, oyuncunun toplu sipariş (teslimat) göndererek pasif altın kazanmasını sağlar. Bir teslimat slotu dolusu ekmek seçilir, hedef belirlenir (şehir içi, şehirlerarası), teslimat süresi timer ile ölçülür; tamamlanınca ödül alınır. Upgrade Tree entegrasyonu: `delivery_speed` upgrade teslimat süresini kısaltır, `delivery_slots` upgrade eşzamanlı teslimat sayısını artırır. Sistem idle döngüsünü tamamlar: aktif oyuncu fırını optimize ederken teslimatlar arka planda ilerler.

## 2. Player Fantasy

**Temel his:** "Tahılı ekmek olarak değil, fırından çıkmış lezzet olarak şehre yolluyorum." — Büyük bir siparişi kapaktan çıkarmak hem ölçek hissi hem de belirli bir sabır ödülü verir.

**İkincil his:** Paralel yönetim — Birden fazla teslimat rotası aynı anda aktifken oyuncu "empire building" hisseder. Fırından çıkan ekmekler hem vitrine hem teslimat vagonuna gider.

**Kaçınılması gereken:** Tek tıkla bitirme. Teslimat süresi OFFLINE_CAP'ın bir parçası gibi hissettirmeli; teslimat sırasında oyun beklemiyor.

## 3. Detailed Rules

### 3.1 Teslimat Türleri

| ID | Hedef | Baz Süre | Baz Ödül Çarpanı |
|----|-------|----------|-----------------|
| `local` | Mahalle içi | 120s (2 dk) | 1.0× |
| `city` | Şehir geneli | 600s (10 dk) | 2.5× |
| `intercity` | Şehirlerarası | 3600s (1 saat) | 8.0× |

### 3.2 Teslimat Slotu

- Varsayılan: 1 eşzamanlı teslimat slotu.
- `delivery_slots` upgrade her seviyede +1 slot ekler (max +2 → toplam 3 slot).
- Slot dolduğunda yeni teslimat başlatılamaz.

### 3.3 Teslimat Akışı

1. Oyuncu slot UI'ından teslimat türünü seçer.
2. Stoktan gerekli ekmek miktarını otomatik düşer (`DELIVERY_BREAD_REQ` adet).
3. Timer başlar (`get_unix_time_from_system()` bazlı — ADR-0003 uyumlu).
4. Süre dolunca slot "teslim hazır" durumuna geçer; otomatik ödeme OLMAZ.
5. Oyuncu slotu tıklayarak ödülü talep eder → `economy.earn_gold(reward)`.
6. Talep edilmemiş ödül `DELIVERY_UNCLAIMED_CAP_HOURS` (4 saat) sonra expire olur.

### 3.4 Ekmek Gereksinimi

- Her teslimat türü sabit ekmek sayısı gerektirir.
- `DELIVERY_BREAD_REQ = { local: 5, city: 15, intercity: 50 }`
- Yeterli stok yoksa başlatılamaz; UI "Yeterli ekmek yok" bilgisi gösterir.

### 3.5 Offline Uyum

- Teslimat timer'ları unix timestamp ile saklanır; offline süre geçse bile doğru hesaplanır.
- `DELIVERY_UNCLAIMED_CAP_HOURS` = 4 saat — Offline dönüş ödülü + teslimat ödülü birikmesi kontrol altında tutulur.

## 4. Formulas

### F-1: Teslimat Ödülü

```
delivery_reward = base_unit_value × bread_count × type_multiplier × delivery_speed_bonus
```

Değişkenler:
- `base_unit_value` — ekmek türünün temel altın değeri (RecipeData.base_value)
- `bread_count` = DELIVERY_BREAD_REQ[type]
- `type_multiplier` — teslimat türüne göre (1.0 / 2.5 / 8.0)
- `delivery_speed_bonus` = 1.0 (upgrade yoksa)

Örnek (local, simit, base_value=5):
`5 × 5 × 1.0 × 1.0 = 25 altın` (2 dakika için)

Örnek (intercity, pogaça, base_value=12):
`12 × 50 × 8.0 × 1.0 = 4800 altın` (1 saat için)

### F-2: Teslimat Süresi (Upgrade Sonrası)

```
actual_duration = base_duration × (1 - delivery_speed_reduction)
delivery_speed_reduction = delivery_speed_level × SPEED_REDUCTION_PER_LEVEL
```

`SPEED_REDUCTION_PER_LEVEL = 0.1` (her seviye %10 hız artışı)

Max 3 seviye → max %30 süre azalması:
- local: 120s → 84s
- city: 600s → 420s
- intercity: 3600s → 2520s

### F-3: Slot Sayısı

```
max_slots = BASE_SLOTS + delivery_slots_level
```

`BASE_SLOTS = 1`, `delivery_slots_level` ∈ {0, 1, 2}

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Stok teslimat sırasında tükenir | Başlatma sırasında stok kilitleniyor; sonradan azalması etkilemez |
| Expire olmuş teslimat | Slot boşalır, ödül silinir, push_warning; oyuncu bilgilendirilir |
| Economy null | Ödül verilmez; push_error; slot "teslim hazır" durumunda bekler |
| Eşzamanlı tüm slotlar dolu | "Başlat" butonu devre dışı |
| `delivery_slots` upgrade maxlı (3 slot) | Slot UI üçüncü slotu aktif gösterir |
| Zaman geri giderse (clock skew) | Negatif süre → 0 olarak işle; süre bitmemiş sayılır |
| Prestige sonrası ekmek stoku sıfırlandıysa | Devam eden teslimatlar tamamlanır; stok yokluğu yeni teslimatı engeller |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Economy System (#4)** | `earn_gold()` — teslimat ödülü |
| **Upgrade Tree System (#12)** | `delivery_speed`, `delivery_slots` upgrade seviyeleri |
| **Time Tracking System (#1)** | Unix timestamp bazlı timer; offline uyum |
| **Save/Load System (#5)** | Aktif teslimat slot durumları serialize/deserialize |

## 7. Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Etki |
|-----------|-----------|----------------|------|
| `BASE_SLOTS` | 1 | [1, 2] | Daha fazla → erken pasif gelir çok yüksek |
| `SPEED_REDUCTION_PER_LEVEL` | 0.1 | [0.05, 0.2] | Upgrade değerini belirler |
| `DELIVERY_UNCLAIMED_CAP_HOURS` | 4 | [1, 8] | Kısa → ceza hissi; uzun → idle döngüsü çöküyor |
| `type_multiplier[intercity]` | 8.0 | [5.0, 15.0] | Uzun teslimatın cazibesini ayarlar |
| `DELIVERY_BREAD_REQ[local]` | 5 | [2, 10] | Düşük → çok kolay başlatılır |

## 8. Acceptance Criteria

- [ ] 3 teslimat türü (local/city/intercity) doğru süre ve ödülle çalışıyor
- [ ] F-1 formülü: ödül hesabı doğru (manual test ile doğrula)
- [ ] F-2 formülü: `delivery_speed` upgrade süresi %10/seviye azaltıyor
- [ ] F-3: `delivery_slots` upgrade +1 slot ekliyor (max 3 slot)
- [ ] Stok yetersizse teslimat başlamıyor; kullanıcı dostu mesaj gösterildi
- [ ] Expire: 4 saat sonra talep edilmeyen ödül silindi, slot boşaldı
- [ ] Offline uyum: unix timestamp ile süre hesabı; offline dönüşte doğru durum
- [ ] Teslimat durumları SaveLoad üzerinden persist edildi
- [ ] Economy null guard: push_error + slot "bekliyor" durumunda kalıyor
- [ ] GUT testleri: F-1 ödül hesabı, F-2 hız azalma, expire, null guard, serialize/deserialize
