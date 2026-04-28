# Playtest-01 — Ekonomi Dengesi Analizi

**Tarih:** 2026-04-28
**Sprint:** S6-02
**Yöntem:** Formül tabanlı teorik simülasyon (gerçek cihaz verisi henüz mevcut değil)
**Referans:** `docs/balance/upgrade-tree-cost-simulation.md`, GDD'ler

---

## 1. Analiz Soruları

| # | Soru | Hedef |
|---|------|-------|
| Q1 | İlk upgrade (Fırın Sıcaklığı, 50g) ilk 3 dakikada ulaşılabilir mi? | Evet |
| Q2 | Location 2 (inner_anatolia, 50 satış) ~30 dakikada açılır mı? | Evet |
| Q3 | 8h offline gap anlamlı altın veriyor mu? | Evet, cap içinde |
| Q4 | Upgrade curve (3^n) gece-gündüz oynanabilir mi? | Kısmen — 2 risk noktası |

---

## 2. Gelir Modeli (Teorik)

### 2a. Erken Oyun Temel Gelir Varsayımları

| Parametre | Değer | Kaynak |
|-----------|-------|--------|
| Simit base_value | 5 altın | `RecipeData` (`content-database.md`) |
| Müşteri gold_multiplier | 1.0× (normal) | `CustomerOrderSystem` |
| Bake time (başlangıç) | 30s | `oven-baking-system.md` |
| Slot sayısı (başlangıç) | 1 | `OvenManager` |
| Sipariş aralığı | 15–30s | `customer-order-system.md` |

**Dakika başına tahmini gelir (ilk slot, simit):**
- 60s / 30s bake = 2 pişirme/dk
- 2 pişirme × 5g = **10 altın/dk** (aktif oynama)

### 2b. Q1: İlk Upgrade (50g) — 3 Dakikada Ulaşılabilir mi?

| Senaryo | Süre | Gelir | Sonuç |
|---------|------|-------|-------|
| Aktif oynama (10g/dk) | 3 dk | 30g | **YETERSİZ** — 50g için 5 dk gerekiyor |
| Tutorial ödülü (85g) dahil | 0 dk | 85g | **YETERLİ** — tutorial bitince zaten karşılanmış |
| Tutorial skip (30g) | 2 dk | +20g = 50g | **SINIRDA** — 5. dakika |

**Bulgu:** Tutorial tamamlandığında (85g) oyuncu ilk upgrade'i anında alabilir. Skip seçeneğinde ise 5. dakikada ulaşılıyor; "3 dakika" hedefi kaçıyor.

**Öneri:** İlk upgrade'in `base_cost` değerini 50 → 30'a düşür. 30 altın; tutorial skip (30g) ile bile anında karşılanır.  
**Risk:** Erken satış kolaylaşırsa oyuncu tutma motivasyonu azalabilir. Alternatif: skip bonusunu 30 → 50 yükselt (upgrade_tree.md değişikliği yok, TutorialSystem değişikliği).

### 2c. Q2: Location 2 (inner_anatolia) — 30 Dakikada Açılır mı?

Koşul: "50 temel kategori satışı"

| Parametre | Değer |
|-----------|-------|
| Sipariş teslim hızı | ~2/dk (bake 30s + servis 5s) |
| EASY müşteri oranı | ~%60 ilk lokasyonda |
| Satış/dakika | ~1.2 satış/dk |

**50 satış için:** 50 / 1.2 = **~42 dakika**

**Bulgu:** 30 dakika hedefinin %40 üzerinde. Location 2 koşulu çok sıkı.

**Öneri A:** İlk lokasyon satış eşiğini 50 → 30'a düşür.  
**Öneri B:** Bake time'ı ilk upgrade almadan önce 30s → 20s yap (Fırın Sıcaklığı başlangıç bonusu ekle).  
**Seçilen:** Öneri A — eşik değişikliği daha temiz. `LocationSystem.SALE_REQ` güncellenmeli.

### 2d. Q3: 8h Offline Gap Analizi

| Parametre | Değer | Kaynak |
|-----------|-------|--------|
| Offline cap | 28.800s (8 saat) | `OvenManager.OFFLINE_CAP_SECONDS` |
| Offline üretim oranı | ~1g/s (simit, 1 slot) | Formül: base_value/bake_time |
| Max offline altın (1 slot) | 28.800 × (5/30) = **4.800g** | |
| Max offline altın (3 slot, Sev.1) | 4.800 × 3 = **14.400g** | |

**Bulgu:** 8 saatlik offline getirisi late-game'de (3 slot) 14.400g — bu Fırın Kapasitesi Sev.4 (2.025g) satın almaya yeterli. Anlamlı ve bağımlılık oluşturucu. ✅

**Rewarded Ad × 2 offline:** 4.800 → 9.600g (tek slot). Kullanıcı başına yüksek değer — ad conversion motivasyonu güçlü. ✅

### 2e. Q4: Upgrade Curve Risk Noktaları

Mevcut `upgrade-tree-cost-simulation.md`'den iki risk tespit edilmişti; playtest analizine göre:

#### Risk 1: Level 3→4 Duvarı (Sev.4 = base_cost × 27)
- Fırın Sıcaklığı Sev.4: 1.350g
- Ortalama gelir Sev.3 sonrası: ~30g/dk (3 slot, iyi müşteri)
- Süre: 1.350 / 30 = **45 dakika aktif oynama**
- **Değerlendirme:** Kabul edilebilir. Sev.4 late-game'e bilinçli konumlandırılmış.

#### Risk 2: `auto_dough` Sev.3 = 4.500g
- Late-game gelirine oranla: ~3 günlük pasif → 1 haftalık aktif
- **Değerlendirme:** Çok pahalı — `auto_dough` base_cost 500 → 300 önerilir.
- 300 ile Sev.3 = 2.700g; daha ulaşılabilir ama hâlâ zorlu.

---

## 3. Lokasyon Koşulları Yeniden Değerlendirme

Mevcut koşullar vs önerilen:

| Lokasyon | Mevcut Koşul | Önerilen Koşul | Gerekçe |
|----------|-------------|----------------|---------|
| inner_anatolia | Temel 50 satış | **30 satış** | 30 dk hedefine uygun |
| istanbul | Buğday 100 + oven_capacity ≥ 2 | **Buğday 60 + oven_capacity ≥ 1** | 2 slot erken zorunlu; base level yeterli |
| paris | Tatlı 150 + showcase_width ≥ 1 | Değişiklik yok | Vitrin Sev.1 erişilebilir (200g) |
| rome | Fransız 200 + prestige_count ≥ 1 | Değişiklik yok | Prestige endpoint olarak tasarımlı |

---

## 4. Günlük Görev Denge Değerlendirmesi

| Zorluk | Hedef | Ödül | Aktif Süre (tahmini) | Değerlendirme |
|--------|-------|------|----------------------|---------------|
| EASY (50 ekmek sat) | 50 satış | 50g | ~45 dk | **Çok uzun** — hedef 25'e düşürülmeli |
| EASY (5 pişirme) | 5 bake | 50g | ~5 dk | ✅ Uygun |
| EASY (3 müşteri) | 3 servis | 50g | ~3 dk | ✅ Uygun |
| MEDIUM (100 ekmek sat) | 100 satış | 100g | ~90 dk | **Çok uzun** — 60'a düşür |
| HARD (200 ekmek sat) | 200 satış | 200g | ~180 dk | **Çok uzun** — 100'e düşür |

**Temel sorun:** SELL_BREAD görevleri diğer görevlere göre 3-5× uzun. Ekmek satış oranı düşük olduğunda (servis süresinden bağımsız) bu görev cezaya dönüşüyor.

**Öneri:** `SELL_BREAD` EASY hedefi 50 → 20, MEDIUM 100 → 50, HARD 200 → 100.

---

## 5. Özet: Önerilen Değişiklikler

| ID | Değişiklik | Dosya | Öncelik |
|----|-----------|-------|---------|
| B1 | `oven_temperature` base_cost: 50 → 30 | `src/core/resources/*.tres` veya config | **Yüksek** |
| B2 | `SALE_REQ[inner_anatolia]`: 50 → 30 | `src/progression/location_system.gd:14` | **Yüksek** |
| B3 | `istanbul` koşul: buğday 100 → 60, oven_cap ≥ 2 → ≥ 1 | `location_system.gd:_check_conditions` | **Orta** |
| B4 | `auto_dough` base_cost: 500 → 300 | config | **Orta** |
| B5 | `SELL_BREAD` hedefler: 50/100/200 → 20/50/100 | `src/tasks/daily_task_system.gd:_TASK_TEMPLATES` | **Orta** |
| B6 | Tutorial skip starting_gold: 30 → 50 | `src/ui/tutorial_system.gd:STARTING_GOLD` | **Düşük** |

---

## 6. Sonraki Adımlar

- [ ] B1, B2, B3 değişikliklerini uygula (Sprint 6 buffer kapsamında)
- [ ] Gerçek cihaz oturumu: 20 dakika test — lokasyon 2 açılıyor mu?
- [ ] `economy-balance-simulation.md` belgesi oluştur (gelir vs harcama denk noktası)
- [ ] Rewarded Ad offline × 2 değerinin ekonomiye etkisini simüle et

*Bu belge teorik simülasyon içerir. Gerçek cihaz verisiyle güncellenmesi gerekir.*
