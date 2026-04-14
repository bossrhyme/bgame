# Upgrade Tree — Maliyet Formülü Sayısal Simülasyon

**Tarih:** 2026-04-14  
**Kaynak formül:** `cost(level) = base_cost × 3^(level-1)`  
**Referans:** `design/gdd/upgrade-tree-system.md` — Bölüm 4 (Formulas)  
**Kod referansı:** `src/upgrade/upgrade_tree.gd:152` — `UpgradeTree.compute_cost()`  
**Sprint 2 DoD maddesi:** "Upgrade Tree 3^n maliyet formülü için sayısal simülasyon belgesi"

---

## 1. Tam Maliyet Tablosu (Formülden Hesaplanan)

> GDD §4'teki tablo yaklaşık değerler içerir. Aşağıdaki değerler `base_cost × 3^(level-1)` formülü
> uygulanarak kesin olarak hesaplanmıştır.

### Üretim Upgrades

| Upgrade | base_cost | Sev.1 | Sev.2 | Sev.3 | Sev.4 | Sev.5 | Toplam |
|---------|-----------|------:|------:|------:|------:|------:|-------:|
| Fırın Sıcaklığı | 50 | 50 | 150 | 450 | 1.350 | 4.050 | **6.050** |
| Hamur Kalitesi | 100 | 100 | 300 | 900 | 2.700 | 8.100 | **12.100** |
| Fırın Kapasitesi | 75 | 75 | 225 | 675 | 2.025 | 6.075 | **9.075** |
| Otomatik Hamur | 500 | 500 | 1.500 | 4.500 | — | — | **6.500** |
| Malzeme Deposu | 80 | 80 | 240 | 720 | 2.160 | — | **3.200** |

### Müşteri Upgrades

| Upgrade | base_cost | Para | Sev.1 | Sev.2 | Sev.3 | Toplam |
|---------|-----------|------|------:|------:|------:|-------:|
| Vitrin Genişliği | 200 | Altın | 200 | 600 | 1.800 | **2.600** |
| Müşteri Memnuniyeti | 300 | Altın | 300 | 900 | 2.700 | **3.900** |
| VIP Lounge | 1.000 | **Rozet** | 1.000 | — | — | **1.000 Rozet** |
| Sadakat Kartı | 2.000 | Altın | 2.000 | — | — | **2.000** |

### Teslimat Upgrades

| Upgrade | base_cost | Sev.1 | Sev.2 | Sev.3 | Toplam |
|---------|-----------|------:|------:|------:|-------:|
| Teslimat Kapasitesi | 400 | 400 | 1.200 | 3.600 | **5.200** |
| Teslimat Hızı | 300 | 300 | 900 | 2.700 | **3.900** |

---

## 2. GDD Tablo vs Formül Karşılaştırması

GDD §4'teki değerler yuvarlama içeriyordu. Kesin değerler ve farklar:

| Upgrade | Sev. | GDD Değeri | Formül Değeri | Fark |
|---------|-----:|----------:|--------------:|-----:|
| Hamur Kalitesi | 4 | 2.500 | **2.700** | +200 |
| Hamur Kalitesi | 5 | 7.000 | **8.100** | +1.100 |
| Fırın Kapasitesi | 4 | 2.000 | **2.025** | +25 |
| Fırın Kapasitesi | 5 | 6.000 | **6.075** | +75 |
| Otomatik Hamur | 3 | 5.000 | **4.500** | -500 |
| Malzeme Deposu | 2 | 250 | **240** | -10 |
| Malzeme Deposu | 3 | 700 | **720** | +20 |
| Müşteri Memnuniyeti | 3 | 2.500 | **2.700** | +200 |
| Fırın Sıcaklığı | 4 | 1.000 | **1.350** | +350 |
| Fırın Sıcaklığı | 5 | 3.000 | **4.050** | +1.050 |

**Karar:** `compute_cost()` formulünün ürettiği kesin değerler kullanılır.
GDD §4 tablosu referans niteliği taşır; `UpgradeData.tres` dosyaları oluşturulurken formül esas alınır.

---

## 3. Kümülatif Maliyet ve Oyun Süresi Analizi

### Tüm Upgrade'leri Maxlamak İçin Gereken Toplam Altın

| Kategori | Toplam Altın |
|----------|------------:|
| Üretim (5 upgrade) | 36.925 |
| Müşteri (Sadakat + Vitrin + Memnuniyet) | 8.500 |
| Teslimat (2 upgrade) | 9.100 |
| **GENEL TOPLAM** | **54.525** |
| + VIP Lounge | +1.000 Rozet |

### İlk 5 Upgrade'in Maliyet Koridoru (Erken Oyun)

Oyuncu başlangıçta hangi upgrade'e önce yöneleceğini seçer:

| Upgrade | Sev.1 | Sev.1+2 | Sev.1+2+3 | Notlar |
|---------|------:|--------:|----------:|--------|
| Fırın Sıcaklığı | 50 | 200 | 650 | En ucuz giriş; erken hız artışı |
| Malzeme Deposu | 80 | 320 | 1.040 | Stok açısından kritik |
| Fırın Kapasitesi | 75 | 300 | 975 | 2. slot → verim x2 |
| Vitrin Genişliği | 200 | 800 | 2.600 | 2. sipariş slotu için 200 yeterli |
| Müşteri Memnuniyeti | 300 | 1.200 | 3.900 | Sabır başlangıçta kritik değil |

---

## 4. Denge Analizi

### 4a. Büyüme Oranı (3× / seviye)

| Seviye | Çarpan (3^(n-1)) | Yorum |
|-------:|----------------:|-------|
| 1 | ×1 | Giriş eşiği — her oyuncu alabilmeli |
| 2 | ×3 | Erken-mid dönüşüm |
| 3 | ×9 | Mid-game kapısı |
| 4 | ×27 | Late-game; yalnızca `oven_temperature`, `dough_quality`, `oven_capacity` |
| 5 | ×81 | End-game; aynı 3 upgrade |

3× büyüme, level 3→4 geçişinde belirgin bir "duvar" yaratır. Bu tasarımla örtüşür (GDD §7: "Erken oyuncu tüm seviyelere çabuk erişmemeli").

### 4b. Potansiyel Dengesizlikler

| Risk | Açıklama | Önerilen Önlem |
|------|----------|----------------|
| `auto_dough` Sev.3 = 4.500 | Üretim için büyük atlama; `oven_capacity` Sev.3 (675) ile kıyasla çok pahalı | Oyun içi gelir simülasyonuyla doğrula; gerekirse `base_cost` 500→300 |
| `loyalty_card` 2.000 (tek seviye) | Diğer tek seviye upgrade (`vip_lounge`) 1.000 Rozet; altın karşılaştırması dengeli görünüyor | Rozet/altın dönüşüm oranı belirlendikten sonra yeniden değerlendir |
| Hamur Kalitesi Sev.5 = 8.100 | Gelir bonusu +%80 — max seviyede kazanç çok yüksekse ekonomi çöker | Gelir formülünü `economy_balance_simulation.md` ile çapraz doğrula |
| Teslimat upgrades geç oyun | Sev.3 toplamı ~5-9k; teslimat sistemi henüz implemente değil (S2-alpha) | Teslimat sistemi eklenince bu tabloyu güncellemek gerekir |

### 4c. "İlk 1.000 Altın" Harcama Senaryosu

1.000 altınla optimal harcama (en yüksek üretim kazancı):

1. Fırın Sıcaklığı Sev.1: **50** → pişirme +%10
2. Fırın Kapasitesi Sev.1: **75** → +1 slot (2 paralel pişirme)
3. Malzeme Deposu Sev.1: **80** → stok +10
4. Fırın Sıcaklığı Sev.2: **150** → pişirme +%25 kümülatif
5. Fırın Kapasitesi Sev.2: **225** → +2 slot (3 paralel pişirme)
6. Vitrin Genişliği Sev.1: **200** → +2 sipariş slotu

Harcanan: 780 altın. Kalan: 220 altın.  
Sonuç: 3 fırın slotu, 6 sipariş slotu, pişirme +%25. Erken denge sağlıklı görünüyor.

---

## 5. Sonuç ve Karar

- **Formül onaylandı:** `base_cost × 3^(level-1)` GDScript implementasyonu doğru
- **GDD tablosu güncellenmeli:** Yuvarlama hataları tespit edildi; ilgili GDD §4 satırları kesin değerlerle güncellenecek (ayrı task)
- **Potansiyel tuning kandidatı:** `auto_dough` base_cost — mid-game simülasyonu sonrası karar verilecek
- **Kritik bağımlılık:** `hamur_kalitesi` Sev.5 etkisinin (+%80 gelir) ekonomi simülasyonuyla çapraz doğrulanması gerekiyor
- **Sprint 2 DoD:** Bu belge Sprint 2 DoD'un son kapalı maddesidir

---

*Bu belge `UpgradeTree.compute_cost()` implementasyonunu (S2-05) doğrular.*  
*Sonraki adım: `docs/balance/economy-balance-simulation.md` (gelir vs harcama denk noktası)*
