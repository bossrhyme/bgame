# Employee System GDD

**Sistem:** #13 / 29
**Kategori:** Gameplay — MVP
**Durum:** Draft
**Bağımlılıklar:** Economy System, Time Tracking System

---

## 1. Overview

Employee System, oyuncunun günlük ücret karşılığında işe aldığı çalışanların fırın operasyonlarını kısmen otomatize ettiği sistemdir. Dört çalışan tipi vardır: **Hamurcu Yardımcısı** (hamur yoğurmayı otomatize eder), **Fırın Ustası** (pişirme hızını artırır), **Kasiyer** (satış işlemlerini hızlandırır) ve **Teslimatçı** (teslimat siparişlerini yönetir). Her çalışan günlük altın ücret alır; ödeme yapılamazsa çalışan "greve çıkar" ve efekti devre dışı kalır. Çalışan ücretleri Economy System üzerinden günlük otomatik düşülür; Time Tracking System günlük sıfırlamayı tetikler.

## 2. Player Fantasy

**Temel his:** "Artık her şeyi tek başıma yapmak zorunda değilim." — İlk çalışanı işe alınca fırın sessizce çalışmaya devam eder; oyuncu uzaklaştığında bile hamur yoğruluyor, ekmek pişiyor. Küçük bir ekibin sahibi olmak, "fırın bana bağımlı" yerine "fırın benim için çalışıyor" hissini verir.

**İkincil his:** Yönetim tatmini. Doğru çalışanı doğru zamanda işe almak — önce Hamurcu, sonra Fırın Ustası — bir optimizasyon bulmacasıdır. Maaş ödemek için kasayı takip etmek oyuna hafif bir gerilim katar.

**Kaçınılması gereken:** Çalışan grevinin oyunu bloke etmesi. Grev bir uyarı olmalı, ceza değil — oyuncu maaşı ödeyince her şey normale döner.

## 3. Detailed Rules

### Çalışan Tipleri

| Tip | Görevi | Günlük Ücret | Efekt | Max Seviye |
|-----|--------|-------------|-------|-----------|
| Hamurcu Yardımcısı | Hamur yoğurmayı otomatize eder | 50 altın | Hız +%25/sev. | 3 |
| Fırın Ustası | Pişirme hızını artırır | 80 altın | Hız +%20/sev. | 3 |
| Kasiyer | Satış animasyonunu atlar | 60 altın | Satış hızı +%30/sev. | 3 |
| Teslimatçı | Teslimat siparişlerini yönetir | 100 altın | Kapasite +1/sev. | 3 |

### İşe Alma Akışı

1. Oyuncu çalışan menüsünü açar
2. Tip ve seviye seçer, günlük maaş gösterilir
3. İşe al → çalışan aktif, efekt anında başlar
4. Ücret her gün (Time Tracking günlük sıfırlamasında) Economy'den otomatik düşer

### Grev Mekanizması

- Günlük ücret ödenemezse (yetersiz altın) → çalışan "greve çıkar"
- Grev durumunda efekt sıfırlanır; çalışan görsel olarak "pasif" konuma geçer
- Oyuncu yeterli altın biriktirip "Maaş Öde" butonuna basınca grev biter, efekt yeniden aktif olur
- Grev süresince çalışan işten çıkmaz; sadece efekt askıya alınır

### Seviye Yükseltme

- Her çalışanın max 3 seviyesi vardır
- Seviye yükseltme maliyeti: işe alma maliyeti ile aynı formülü kullanır
- Yükseltme anında efekt güncellenir

## 4. Formulas

### İşe Alma / Yükseltme Maliyeti

```
hire_cost(level) = daily_wage × 10 × level
```

| Tip | Günlük Ücret | Sev.1 | Sev.2 | Sev.3 |
|-----|-------------|-------|-------|-------|
| Hamurcu Yardımcısı | 50 | 500 | 1.000 | 1.500 |
| Fırın Ustası | 80 | 800 | 1.600 | 2.400 |
| Kasiyer | 60 | 600 | 1.200 | 1.800 |
| Teslimatçı | 100 | 1.000 | 2.000 | 3.000 |

### Efekt Hesabı

```
total_effect = effect_per_level × current_level
```

Örnek — Hamurcu Sev.2: `0.25 × 2 = 0.50` → hamur hızı +%50

### Günlük Ücret Kesintisi

```
daily_cost = sum(active_employee.daily_wage for each active employee)
```

Time Tracking günlük sıfırlamasında Economy'den toplam `daily_cost` düşülür.

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Günlük ücret ödenemez (yetersiz altın) | Tüm çalışanlar greve çıkar; efektler sıfırlanır; UI uyarı gösterir |
| Birden fazla çalışan aynı anda grevdeyken altın yeterse | "Maaş Öde" butonu tüm grevdeki çalışanları tek seferde çözer |
| Oyun arka plandayken gün geçer, ücret ödenemez | Geri dönüşte grev bildirimi gösterilir; oyuncu kasayı kontrol etmeye yönlendirilir |
| Teslimatçı işe alınmış ama Delivery System henüz aktif değil | Teslimatçı görsel olarak "hazır" durumda bekler; efekt Delivery System aktif olunca başlar |
| Max seviyedeki çalışanı yükseltmeye çalışırsa | Buton "Maksimum" görünümüne geçer, işlem engellenir |
| Aynı tipten iki çalışan işe alınabilir mi? | Hayır — her tipten yalnızca bir çalışan aktif olabilir; yükseltme ile seviye artırılır |
| Çalışan işten çıkarılabilir mi? | Evet — işten çıkarma anında efekt durur, günlük ücret kesilmez; işe alma maliyeti iade edilmez |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Economy System** (#4) | İşe alma maliyeti, yükseltme maliyeti ve günlük ücret kesintisi |
| **Time Tracking System** (#1) | Günlük sıfırlama sinyali → ücret kesintisini tetikler |
| **Save/Load System** (#5) | Aktif çalışanlar, seviyeleri ve grev durumları kaydedilir |
| **Oven/Baking System** (#9) | Fırın Ustası efekti pişirme hızını etkiler |
| **Offline Production System** (#16) *(vertical slice)* | Hamurcu ve Fırın Ustası offline üretimde de aktif kalır |
| **Delivery System** (#27) *(alpha)* | Teslimatçı efekti teslimat kapasitesini etkiler |

## 7. Tuning Knobs

| Parametre | Varsayılan | Açıklama |
|-----------|-----------|----------|
| `hamurcu_daily_wage` | 50 altın | Hamurcu günlük ücreti |
| `firinci_daily_wage` | 80 altın | Fırın Ustası günlük ücreti |
| `kasiyer_daily_wage` | 60 altın | Kasiyer günlük ücreti |
| `teslimatci_daily_wage` | 100 altın | Teslimatçı günlük ücreti |
| `hire_cost_multiplier` | 10 | `hire_cost = daily_wage × multiplier × level` |
| `hamurcu_effect_per_level` | 0.25 | Hamur hızı artışı per seviye |
| `firinci_effect_per_level` | 0.20 | Pişirme hızı artışı per seviye |
| `kasiyer_effect_per_level` | 0.30 | Satış hızı artışı per seviye |
| `teslimatci_capacity_per_level` | 1 | Teslimat kapasitesi artışı per seviye |
| `max_employee_level` | 3 | Tüm çalışan tipleri için max seviye |

## 8. Acceptance Criteria
<!-- TBD -->
