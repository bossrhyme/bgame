# Upgrade Tree System GDD

**Sistem:** #12 / 29
**Kategori:** Progression — MVP
**Durum:** Draft
**Bağımlılıklar:** Economy System, Content Database
**Provisional Arayüzleri Netleştirir:** CustomerConfig Resource (Sistem #11)

---

## 1. Overview

Upgrade Tree System, oyuncunun altın ve Unlu Rozet harcayarak fırınını üç kategoride geliştirdiği progression katmanıdır: **Üretim** (pişirme hızı, kapasite, otomasyon), **Müşteri** (sipariş slotu, sabır, VIP oranı) ve **Teslimat** (sipariş kapasitesi, hız). Her upgrade 1–5 seviyeye sahiptir; maliyet `base_cost × 3^(level-1)` formülüyle üstel olarak artar. Tüm upgrade verileri `UpgradeData` Resource olarak Content Database'de tanımlanır; sistem bu verileri okur, satın alma akışını yönetir, efektleri ilgili sistemlere `UpgradeConfig` Resource'ları aracılığıyla iletir ve durumu Save/Load'a kaydeder.

## 2. Player Fantasy

**Temel his:** "Bir sonraki upgrade'e 340 altın kaldı." — Sayaç gözünün önünde tıkıyor, fırından para akıyor, hedef yaklaşıyor. Upgrade satın alındığında fırın görsel olarak değişir: fırın kapısı yeni bir renk alır, vitrin genişler, yeni bir raf belirir. Oyuncu "büyüttüm" hissini somut görür.

**İkincil his:** Seçim tatmini. Upgrade menüsünü açtığında üç yol var — daha hızlı üretim mi, daha fazla müşteri mi, teslimat mı? Her seçim farklı bir stratejiyi destekler; yanlış seçim yok, ama akıllı seçim var.

**Kaçınılması gereken:** "Hangi upgrade daha iyi?" belirsizliği. Her upgrade'in etkisi satın alma öncesi açıkça gösterilmeli.

## 3. Detailed Rules

### Satın Alma Akışı

1. Oyuncu upgrade menüsünü açar
2. Mevcut seviye, bir sonraki seviyenin etkisi ve maliyeti gösterilir
3. Yeterli altın/Rozet varsa "Satın Al" butonu aktif
4. Onay → Economy'den ödeme düşülür → `current_level` +1 → efekt anında aktif
5. Max seviyeye ulaşınca buton "Maksimum" olarak değişir, tıklanamaz

### Upgrade Kategorileri

| Kategori | Para Birimi | Kapsam |
|----------|------------|--------|
| Üretim | Altın | Pişirme hızı, fırın kapasitesi, hamur otomasyonu, depo |
| Müşteri | Altın + Rozet | Sipariş slotu, sabır, VIP oranı, gelir bonusu |
| Teslimat | Altın | Teslimat kapasitesi ve hızı |

### Efekt Uygulama

- Her kategori için bir `UpgradeConfig` Resource tutulur
- Upgrade satın alındığında ilgili Resource güncellenir
- Bağlı sistemler bu Resource'u okur (polling değil; sinyal ile bildirim)
- `customer_upgrades_changed` sinyali → CustomerManager Resource'u yeniler

### Kayıt/Yükleme

- Her upgrade'in `current_level: int` değeri Save/Load System'e kaydedilir
- Yükleme sırasında tüm `UpgradeConfig` Resource'ları mevcut seviyelere göre yeniden hesaplanır

## 4. Formulas

### Upgrade Maliyeti

```
cost(level) = base_cost × 3^(level - 1)
```

| Upgrade | base_cost | Sev.1 | Sev.2 | Sev.3 | Sev.4 | Sev.5 |
|---------|-----------|-------|-------|-------|-------|-------|
| Fırın Sıcaklığı | 50 | 50 | 150 | 450 | 1.000 | 3.000 |
| Hamur Kalitesi | 100 | 100 | 300 | 900 | 2.500 | 7.000 |
| Fırın Kapasitesi | 75 | 75 | 225 | 675 | 2.000 | 6.000 |
| Otomatik Hamur | 500 | 500 | 1.500 | 5.000 | — | — |
| Malzeme Deposu | 80 | 80 | 250 | 700 | 2.000 | — |
| Vitrin Genişliği | 200 | 200 | 600 | 1.500 | — | — |
| Müşteri Memnuniyeti | 300 | 300 | 900 | 2.500 | — | — |
| Sadakat Kartı | 2.000 | 2.000 | — | — | — | — |

**Rozet ile alınan upgrade:**
```
VIP Lounge: 1.000 Rozet (tek seviye)
```

### Efekt Hesabı

```
effect = UpgradeData.effect_per_level[current_level - 1]
```

Örnek — Fırın Sıcaklığı Sev.3: `effect_per_level[2] = 0.50` → pişirme hızı +%50

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Satın alma sırasında altın yetersiz kalırsa | İşlem engellenir, Economy düşürme yapılmaz, hata tostu gösterilir |
| Aynı upgrade'e aynı anda iki kez tap edilirse | İkinci tap işlemi yoksayılır (`is_purchasing = true` kilidi) |
| Tüm upgrade'ler max seviyede | Upgrade menüsü "Tüm iyileştirmeler tamamlandı" mesajı gösterir; yeni lokasyon/prestige önerilir |
| Yükleme sırasında `current_level > max_level` kayıt varsa | Hata loglanır, `current_level` `max_level`'a sabitlenir; oyun çökmez |
| VIP Lounge Rozet ile alındıktan sonra Rozet iadesi istenir | İade desteklenmez; satın alma öncesi onay ekranı gösterilir |
| Upgrade efekti kayıt dosyasında bozuksa | Yükleme sırasında `current_level = 0` kabul edilir, efektler sıfır seviyeden hesaplanır |
| Otomatik Hamur upgrade'i max'ken oyuncu manuel yoğurursa | Her ikisi paralel çalışır; manuel yoğurma %3 hız bonusu ayrıca uygulanır |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Economy System** (#4) | Altın ve Rozet ödeme işlemi; bakiye kontrolü |
| **Content Database** (#2) | `UpgradeData` Resource'larının okunması |
| **Save/Load System** (#5) | Her upgrade'in `current_level` kaydedilmesi ve yüklenmesi |
| **Customer/Order System** (#11) | `CustomerConfig` Resource aracılığıyla müşteri upgrade efektleri iletilir |
| **Oven/Baking System** (#9) | `ProductionConfig` Resource aracılığıyla üretim upgrade efektleri iletilir |
| **Delivery System** (#27) *(alpha)* | `DeliveryConfig` Resource aracılığıyla teslimat upgrade efektleri iletilir |
| **Visual Progression System** (#20) *(vertical slice)* | Upgrade seviyesi değişince fırın görseli güncellenir |

## 7. Tuning Knobs

| Parametre | Varsayılan | Açıklama |
|-----------|-----------|----------|
| `upgrade_cost_exponent` | 3.0 | Maliyet formülündeki üs; düşük → erken maxlanır |
| `production_speed_per_level` | [0.10, 0.25, 0.50, 0.80, 1.20] | Fırın Sıcaklığı etkileri |
| `income_bonus_per_level` | [0.05, 0.15, 0.30, 0.50, 0.80] | Hamur Kalitesi etkileri |
| `oven_capacity_per_level` | [1, 2, 4, 6, 10] | Fırın Kapasitesi ek slot |
| `customer_slot_per_level` | [2, 2, 2] | Vitrin Genişliği ek sipariş slotu |
| `patience_bonus_per_level` | [0.20, 0.20, 0.20] | Müşteri Memnuniyeti sabır çarpanı artışı |
| `vip_rate_bonus` | 0.50 | VIP Lounge tek seviye etkisi (+%50) |
| `repeat_gold_bonus` | 0.30 | Sadakat Kartı tek seviye etkisi (+%30) |
| `manual_knead_bonus` | 0.03 | Otomatik hamur aktifken manuel yoğurma bonusu |
| `purchase_lock_timeout` | 0.5 sn | Çift tap koruması için kilit süresi |

## 8. Acceptance Criteria

- [ ] `cost(level) = base_cost × 3^(level-1)` formülü tüm upgrade'lerde doğru hesaplanıyor
- [ ] Yeterli altın yokken satın alma engelleniyor; Economy bakiyesi değişmiyor
- [ ] Upgrade satın alındığında efekt anında aktif oluyor (pişirme hızı, kapasite vs.)
- [ ] Max seviyede buton "Maksimum" görünümüne geçiyor, yeni satın alma yapılamıyor
- [ ] VIP Lounge Rozet ile satın alınıyor; altın ile satın alınamıyor
- [ ] `CustomerConfig` Resource upgrade sonrası doğru değerleri taşıyor (`patience_multiplier`, `max_active_orders`, `vip_spawn_rate`, `repeat_customer_gold_bonus`)
- [ ] Save/Load: upgrade seviyeleri kaydedilip yüklenince efektler doğru hesaplanıyor
- [ ] Yükleme sırasında bozuk `current_level` → `max_level`'a sabitlenip oyun çökmeden devam ediyor
- [ ] GUT testleri: maliyet formülü, efekt hesabı, çift tap kilidi, sınır değerleri (level=1, level=max)

---

### Appendix A — Upgrade Kataloğu
<!-- TBD -->

### Appendix B — CustomerConfig Bağlantısı (Provisional → Confirmed)
<!-- TBD -->
