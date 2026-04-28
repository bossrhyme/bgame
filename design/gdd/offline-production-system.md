# Offline Production System GDD

**Sistem:** #16 / 29
**Kategori:** Gameplay — Vertical Slice
**Durum:** Designed
**Bağımlılıklar:** Time Tracking System (#1), Oven/Baking System (#9), Employee System (#13), Save/Load System (#5)

---

## 1. Overview

Offline Production System, oyuncu uygulamadan çıktıktan sonra geçen gerçek süreyi hesaplayarak fırın yuvalarındaki pişirme işlemlerini tamamlar. Uygulama yeniden açıldığında SaveLoadManager, TimeManager aracılığıyla geçen süreyi elde eder; OvenManager bu süreyi her aktif BAKING slot'una uygular. Fırın Ustası çalışanının hız bonusu offline süreye de yansır. Maksimum 8 saatlik cap aşılırsa fazlası silinir — süresiz offline birikim yoktur. Sistem tamamen mevcut `apply_offline()` altyapısı üzerine inşa edilmiştir; yeni bir sınıf oluşturmaz, bağımlı sistemler arasındaki veri akışını standartlaştırır.

## 2. Player Fantasy

**Temel his:** "Ben yokken de çalışıyordu." — Oyuncu sabah uygulamayı açar, birkaç fırın yuvasının READY beklediğini görür. Bir ekmek pişmiş, diğeri yarı yolda. Ekrana dokunmadan bir şeyler olmuş olması idle oyunun temel vaadini yerine getirir.

**İkincil his:** Tatil suçluluğu yok. Gece 23:00'de uygulamayı kapatan oyuncu, sabah 07:00'de açtığında 8 saatlik cap dolmuş, tüm pişirilecekler READY. Daha uzun bırakmak anlamsız — bu cap baskı yaratmaz, her açılış dolu tablo hissi verir.

**Kaçınılması gereken:** Offline sırasında altın rakamının anında "patlaması". Para sayacı animasyonu makul tutulmalı; `ResourceBar` 0.3 sn tween ile işler — bu süre yeterli.

## 3. Detailed Rules

### Tetikleme Akışı

```
Uygulama açılır
└─ SaveLoadManager._load_game()
   ├─ last_seen_unix → TimeManager.get_elapsed_seconds()
   ├─ EmployeeManager.get_effect(OVEN_MASTER) → speed_multiplier hesabı
   └─ OvenManager.initialize_from_save(slots, speed_multiplier)
      └─ Her BAKING slot için BakingSlot.apply_offline(elapsed, cap, speed_multiplier)
```

### Offline Cap

- **Sabit cap:** `OFFLINE_CAP_SECONDS = 28800.0` (8 saat) — OvenManager sabiti
- Cap aşılan süre silinir; slot sayacı cap kadar ileri alınır
- Cap sonrası tüm slotlar READY durumuna geçmiş olabilir; bu durum beklenen davranıştır

### Çalışan Hız Bonusu (Fırın Ustası)

- Fırın Ustası grevde değilse offline pişirme hızlanır
- `speed_multiplier = 1.0 + EmployeeManager.get_effect(OVEN_MASTER)`
- Grev veya işe alınmamışsa: `speed_multiplier = 1.0` (bonus yok)

### Slot Bağımsızlığı

- Her slot bağımsız işlenir; birinin tamamlanması diğerini etkilemez
- READY veya EMPTY slot'lar `apply_offline()` içinde erken çıkar (no-op)

### Günlük Ücret Kesimi (Employee Entegrasyonu)

- Offline geçen gün sayısı `TimeManager.get_elapsed_days(last_seen_unix)` ile hesaplanır
- `EmployeeManager.process_daily_wages(elapsed_days)` çağrılır
- Yetersiz altında çalışanlar greve çıkar → Fırın Ustası bonusu bu açılıştan itibaren etkilenmez
  (Pişirme offline hız hesabı ücret kesilmeden ÖNCE yapılır — bu adım sırası GDD kuralıdır)

## 4. Formulas

### Etkin Pişirme Süresi (F-1)

```
effective_bake_time = bake_time_seconds / speed_multiplier
```

Değişkenler:
- `bake_time_seconds`: tarif kayıt verisi (saniye, > 0)
- `speed_multiplier`: 1.0 + Fırın Ustası efekti (aralık: [1.0, 1.60])

### Kalan Süre Hesabı (F-2)

```
clamped_elapsed = clamp(elapsed_seconds, 0.0, OFFLINE_CAP_SECONDS)
remaining       = effective_bake_time - clamped_elapsed

if remaining <= 0:  → slot READY
else:               → Timer.start(remaining)
```

### Hız Çarpanı Tablosu

| Fırın Ustası Durumu | speed_multiplier | 60s tarifin offline tamamlanma eşiği |
|--------------------|-----------------|--------------------------------------|
| Yok / Grevde | 1.00 | 60s geçmeli |
| Sev.1 (+%20) | 1.20 | 50s geçmeli |
| Sev.2 (+%40) | 1.40 | ~42.9s geçmeli |
| Sev.3 (+%60) | 1.60 | 37.5s geçmeli |

### Örnek Hesap

Fırın Ustası Sev.2 ile 300s tarifin pişirilmesi:
```
speed_multiplier    = 1.0 + (0.20 × 2) = 1.40
effective_bake_time = 300 / 1.40       = ~214.3s
elapsed (3h)        = 10800s → cap altında
remaining           = 214.3 - 10800   → 0'ın altı → READY
```

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Tüm slotlar EMPTY (oyuncu pişirme başlatmamış) | `apply_offline()` no-op; oyun devam eder |
| `last_seen_unix = 0` (ilk kurulum) | `TimeManager.get_elapsed_seconds()` → 0.0; sıfır elapsed; hiçbir slot güncellenmez |
| Negatif elapsed (sistem saati geri alınmış) | `clampf(elapsed, 0.0, cap)` → 0.0; pişirme ilerlemesi sıfır; anti-cheat tampon |
| 8 saatten fazla offline kalınmış | Elapsed cap'e sabitlenir; tüm BAKING slotlar READY; fazla süre atılır |
| Fırın Ustası grevde, offline hesap yapılıyor | `speed_multiplier = 1.0`; hız bonusu bu oturumda geçersiz (grev SaveLoadManager akışında önce işlenir) |
| Pişirme süresi 0 veya negatifse (bozuk kayıt) | `effective_bake_time ≤ 0 → slot READY` (sıfır/negatif süre zaten tamamlanmış sayılır) |
| Uygulama crash edip aynı saniyede tekrar açılırsa | Elapsed ≈ 0; hiçbir slot değişmez; güvenli |
| Birden fazla açılış aynı gün içinde yapılırsa | Her açılışta yalnızca son kapanıştan bu yana geçen süre uygulanır (SaveLoadManager son kayıttan okur) |

## 6. Dependencies

| Sistem | Kullanım | Yön |
|--------|----------|-----|
| **Time Tracking System (#1)** | `get_elapsed_seconds(last_seen_unix)` → offline süre | Bu sistem → TimeManager |
| **Oven/Baking System (#9)** | `initialize_from_save(slots, speed_mult)` → slot başına `apply_offline()` | Bu sistem → OvenManager |
| **Employee System (#13)** | `get_effect(OVEN_MASTER)` → hız çarpanı; `process_daily_wages(days)` → ücret kesimi | Bu sistem → EmployeeManager |
| **Save/Load System (#5)** | `last_seen_unix` sağlar; `_finish_load()` içinde bu sistemi tetikler | SaveLoadManager → Bu sistem |

**Ters bağımlılıklar:**
- Oven/Baking System GDD §6'ya not: "Offline Production System tarafından initialize_from_save() aracılığıyla tetiklenir"
- Employee System GDD §6'ya not: "Offline Production System OVEN_MASTER efektini offline hesapta kullanır"

## 7. Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Etki |
|-----------|-----------|----------------|------|
| `OFFLINE_CAP_SECONDS` | 28800 (8h) | [14400, 86400] | Kısa → günlük açılış zorunluluğu; uzun → geri dönme motivasyonu azalır |
| `oven_master_speed_per_level` | 0.20 | [0.10, 0.40] | Yüksek → çalışan çok güçlü; aktif tıklama anlamsızlaşır |
| Ücret kesimi sırası | Önce hız hesabı, sonra ücret | Değiştirilmemeli | Grev cezası sadece bir sonraki oturumdan başlar; aksi oyuncu deneyimini bozar |

## 8. Acceptance Criteria

- [ ] 8 saatlik offline sonrası başlatılmış BAKING slotlar READY durumuna geçiyor
- [ ] `elapsed = 0` ise hiçbir slot değişmiyor
- [ ] Negatif elapsed (saat manipülasyonu) → slot ilerlemesi 0; oyun çökmüyor
- [ ] Fırın Ustası Sev.2 ile 300s tarif: elapsed=150s → tarif tamamlanıyor (300/1.4 ≈ 214s > 150s değil; elapsed=215s → READY)
- [ ] Fırın Ustası grevde → speed_multiplier=1.0; aynı tarif normal sürede tamamlanıyor
- [ ] `process_daily_wages(elapsed_days)` çağrısı pişirme hız hesabından SONRA yapılıyor
- [ ] GUT testi: 8h offline, employee bonus, negatif elapsed, tüm slotlar boş senaryoları
