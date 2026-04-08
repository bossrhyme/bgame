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
<!-- TBD -->

## 5. Edge Cases
<!-- TBD -->

## 6. Dependencies
<!-- TBD -->

## 7. Tuning Knobs
<!-- TBD -->

## 8. Acceptance Criteria
<!-- TBD -->
