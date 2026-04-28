# Playtest-02 — Denge Doğrulama (Sprint 7 Düzeltmeleri)

**Tarih:** 2026-04-28  
**Sprint:** S7-06  
**Yöntem:** Formül tabanlı teorik doğrulama (B2/B3/B5/B6 düzeltmeleri uygulanmış build)  
**Önceki:** `docs/balance/playtest-01.md` (S6-02)  
**Hedef cihaz:** Android mid-range (Snapdragon 665 — S7-02 profili ile eşleşecek)

> **Not:** Bu oturum fiziksel Android cihazda gerçekleştirilmeyi planlamaktadır.  
> Cihaz mevcut olmadığından bu belge teorik doğrulama + metodoloji içerir.  
> Gerçek cihaz verisi Sprint 8'te güncellenecektir.

---

## 1. Doğrulama Soruları

Sprint 6 playtest bulgularına dayanarak yapılan B2/B3/B5/B6 düzeltmelerinin  
hedeflerine ulaşıp ulaşmadığını doğrulama soruları:

| # | Soru | Hedef | Kaynağı |
|---|------|-------|---------|
| Q1 | İlk upgrade (50g) tutorial tamamlama anında alınabilir mi? | Evet | B6: STARTING_GOLD 50 |
| Q2 | inner_anatolia 30 satışla ~25 dakikada açılıyor mu? | 20–30 dk | B2: 50→30 satış |
| Q3 | istanbul 60 satış + oc_level≥1 koşulu ulaşılabilir mi? | ~2 saat | B3: 100→60 satış |
| Q4 | EASY görev (SELL_BREAD 20) tamamlanabilir mi? | ~15 dk | B5: 50→20 |
| Q5 | Offline 8h cap anlamlı kalıyor mu (aşırı değil)? | Anlamlı, not-OP | playtest-01 Q3 doğrulandı |

---

## 2. B6 Doğrulaması — Tutorial Tamamlama → İlk Upgrade

### Değişiklik
```
TutorialSystem.STARTING_GOLD: 30 → 50
```

### Teorik hesap
- Tutorial 5 adım tamamlanırsa ödül: 10 + 15 + 15 + 20 + 25 = **85 altın**
- Tutorial skip: **50 altın** (STARTING_GOLD)
- İlk upgrade maliyeti: **50 altın** (bkz. `upgrade-tree-cost-simulation.md`)

| Senaryo | Altın (tutorial bitişi) | İlk upgrade | Sonuç |
|---------|-------------------------|-------------|-------|
| Tutorial tamamlama | 85g | 50g | ✅ Anında alınabilir |
| Tutorial skip | 50g | 50g | ✅ Tam karşılanıyor |

**Karar: B6 hedefi karşılandı.**

---

## 3. B2 Doğrulaması — inner_anatolia Erişim Süresi

### Değişiklik
```
LocationSystem.SALE_REQ[&"inner_anatolia"]: 50 → 30
```

### Teorik hesap (B5 düzeltmesi dahil, 1 slot, bake 30s)

| Parametre | Değer |
|-----------|-------|
| Sipariş hızı | ~2 /dk |
| Satış dönüşümü | ~%60 (müşteri random satisfaction) |
| Efektif satış/dk | ~1.2 |
| 30 satış için süre | **~25 dakika** |

> Playtest-01'deki 42 dk → 25 dk iyileşmesi (%40 hızlanma).

| Hedef | Önceki | Sonrası | Delta |
|-------|--------|---------|-------|
| ~30 dk | ~42 dk | ~25 dk | ✅ Hedef içinde |

**Karar: B2 hedefi karşılandı. Lokasyon açılışı anlamlı ama ulaşılabilir.**

---

## 4. B3 Doğrulaması — istanbul Erişim Zorluğu

### Değişiklik
```
SALE_REQ[&"istanbul"]: 100 → 60
LocationSystem: istanbul_condition oc_level >= 2 → >= 1
```

### Teorik hesap

inner_anatolia açıldıktan sonra oyuncu slot yükseltmesi yapabilir.  
Slot 2 maliyeti: 3^2 × 50 = **450 altın** — yaklaşık 45 dakika ek gelir.

| Parametre | Değer (2 slot, inner_anatolia) |
|-----------|-------------------------------|
| Sipariş hızı | ~3.5 /dk |
| Satış/dk | ~2.0 |
| 60 satış için süre (inner_anatolia'da) | **~30 dakika** |
| Toplam (başlangıçtan) | ~25 + 30 = **~55 dakika** |

| Hedef | Sonuç |
|-------|-------|
| ~2 saat (1.5–2.5h aralığı) | ⚠️ 55 dk — hedeften kısa |

**Bulgu:** B3 sonrası istanbul ~55 dakikada ulaşılabilir hale geldi. Bu, oyunun erken  
dönemde hızlı genişleme hissi vermesi açısından olumlu; ancak lokasyon mekanizmasının  
"milestone" ağırlığını azaltabilir.

**Öneri (Sprint 8):** istanbul'a yatırım maliyeti (örn. unlock_cost: 200g) eklenmesini  
değerlendirin. Zaman koşulu 60 satış korunur, altın kapısı ek bir yatırım gerektirsin.  
→ game-designer + economy-designer konsültasyonu

---

## 5. B5 Doğrulaması — Günlük Görev Erişilebilirliği

### Değişiklik
```
DailyTaskSystem SELL_BREAD targets:
  EASY:   50 → 20
  MEDIUM: 100 → 50
  HARD:   200 → 100
```

### Teorik hesap

| Zorluk | Hedef | Efektif satış/dk | Süre |
|--------|-------|-----------------|------|
| EASY | 20 | 1.2 | **~17 dk** |
| MEDIUM | 50 | 1.5 (upgrade sonrası) | **~33 dk** |
| HARD | 100 | 2.0 (slot 2) | **~50 dk** |

| Hedef | Sonuç |
|-------|-------|
| EASY ~15 dk | ~17 dk — ✅ kabul edilebilir |
| Günlük tüm görevler 1 oturumda tamamlanabilir | ✅ ~2h oturum ile tümü |

**Karar: B5 hedefi karşılandı. Görevler erişilebilir ama anında kolay değil.**

---

## 6. Q5 — Offline Cap Dengesi (Onaylama)

Playtest-01 Q3 sonuçları (8h cap) B2/B3/B5/B6 değişiklikleri sonrası hâlâ geçerli mi?

### Offline üretim hesabı (8h, 1 slot)
```
8h = 480 dk
Pişirme döngüsü: 30s/ekmek = 2/dk = 960 ekmek
Her ekmek 5g → 960 × 5 = 4.800 altın
```

| Kıyas | Değer |
|-------|-------|
| 8h offline gelir | ~4.800g |
| Slot 2 upgrade maliyeti | ~450g |
| Slot 3 upgrade maliyeti | ~1.350g |
| Lokasyon 2 açma | 30 satış (altın değil) |

**Karar:** 8h offline, 2–3 upgrade alınabilecek miktarda altın veriyor.  
Aşırı değil — oyuncunun geri dönüşünü anlamlı kılar. ✅

---

## 7. Gerçek Cihaz Oturumu Metodolojisi (Sprint 8)

Fiziksel cihaz mevcut olduğunda uygulanacak test protokolü:

### Hazırlık
- [ ] Build: Godot 4.6 Android export (arm64, Mobile Renderer, FPS cap 30)
- [ ] Cihaz: Snapdragon 665 veya eşdeğeri, Android 10+
- [ ] PerformanceMonitor etkin (debug build)
- [ ] Yeni kayıt dosyası (önceki save yok)

### Oturum Protokolü (20 dakika minimum)

| Dakika | Eylem | Beklenen Gözlem |
|--------|-------|----------------|
| 0–2 | Tutorial tamamla | 5 adım, 85g ödül |
| 2–3 | İlk upgrade al | 50g maliyet — anında karşılanıyor mu? |
| 3–10 | Aktif satış | inner_anatolia kilit koşulu izle |
| ~25 | inner_anatolia açılmalı | Satış sayacı = 30 |
| 25–40 | inner_anatolia aktif | Slot 2 upgrade almak için altın birikimi |
| ~55 | istanbul açılmalı? | SALE_REQ 60 + oc_level ≥ 1 |
| 60 | Uygulamadan çık | Offline timer başlar |

### Ölçülecek Metrikler

| Metrik | Araç | Hedef |
|--------|------|-------|
| FPS (avg/min) | PerformanceMonitor | avg ≥ 30, min ≥ 20 |
| Draw calls | PerformanceMonitor | < 100/frame |
| Memory | PerformanceMonitor | < 512 MB |
| İlk upgrade süresi | Manuel zamanlama | ≤ 3 dk |
| inner_anatolia açılma süresi | Manuel zamanlama | 20–30 dk |
| Görev tamamlama süresi | Manuel zamanlama | EASY ≤ 20 dk |

### Bulgular Rapor Formatı

Gerçek cihaz oturumu sonrası bu dosya şu bölümle güncellenecek:

```markdown
## 8. Gerçek Cihaz Sonuçları — [Tarih]

**Cihaz:** [Model, Android sürümü]
**Build:** v[X.Y.Z], Godot 4.6, arm64

| Q# | Hedef | Gerçek | Sonuç |
|----|-------|--------|-------|
| Q1 | Tutorial → anında upgrade | ... | ✅/⚠️/❌ |
| ...
```

---

## 8. Sonuç Özeti

| Düzeltme | Teorik Doğrulama | Gerçek Cihaz |
|----------|-----------------|-------------|
| B2: inner_anatolia 30 satış | ✅ ~25 dk | ⏳ Sprint 8 |
| B3: istanbul 60 satış, oc≥1 | ⚠️ 55 dk (hızlı) | ⏳ Sprint 8 |
| B5: EASY görev 20 satış | ✅ ~17 dk | ⏳ Sprint 8 |
| B6: STARTING_GOLD 50 | ✅ Skip → anında upgrade | ⏳ Sprint 8 |

**Önerilen Sprint 8 aksiyon:**  
istanbul için altın unlock maliyeti (~200g) eklenmesi değerlendirilmeli — ekonomi-designer incelemesi.

---

## Referanslar

- `docs/balance/playtest-01.md` — temel analiz
- `src/progression/location_system.gd` — B2/B3 değişiklikleri
- `src/tasks/daily_task_system.gd` — B5 değişiklikleri
- `src/ui/tutorial_system.gd` — B6 değişikliği
- `production/sprints/sprint-07.md` — S7-06 görev tanımı
