# Sprint 9 — 2026-07-31 to 2026-08-13

## Sprint Goal

İlk dış playtest: gerçek Android cihazda build doğrulanır, Google Play internal testing'e yüklenir. Test kapsamı %80'e çıkarılır. GDD meta-belgeleri güncellenir.

## Capacity

- Sprint süresi: 2 hafta (10 iş günü)
- Buffer (%20): 2 gün
- Kullanılabilir: **8 gün**

## Sprint 8 Velocity

Sprint 8'de 5/7 task tamamlandı (%71). S8-02 ve S8-06 fiziksel cihaz bağımlılığı nedeniyle ertelendi. Carryover: 2 task.

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S9-01 | Gerçek Cihaz Performans Profili (S8-02 Carryover) | performance-analyst | 1.5 | Fiziksel Snapdragon 665 cihaz, S8-01 ✅ | FPS > 30 tüm temel senaryolarda; draw call < 100; bellek < 512 MB; `docs/balance/performance-profile-01.md` gerçek verilerle dolduruldu |
| S9-02 | Google Play Internal Testing (S8-06 Carryover) | release-manager | 1.0 | S9-01 ✅, Google Play Developer hesabı, S8-01 ✅ | .aab Play Console'a yüklendi; internal tester grubuna dağıtıldı; crash-free install doğrulandı |

### Should Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S9-03 | Test Coverage %80 | qa-lead | 2.0 | — | test_game_audio_bridge.gd, test_performance_monitor.gd, test_hud_manager.gd tamamlandı; toplam ≥ 30 test dosyası, ≥ 380 test; gut_cli 0 failure |
| S9-04 | Playtest-02 Gerçek Cihaz Doğrulaması | game-designer | 1.0 | S9-01 ✅ | `docs/balance/playtest-02.md` gerçek ölçüm verileriyle güncellendi; Q1–Q5 gerçek cihaz sonuçları; istanbul hız sorunu değerlendirildi |
| S9-05 | Privacy Policy GitHub Pages | release-manager | 0.5 | — | `bossrhyme.github.io/breadmaster/privacy` URL aktif; TR+EN içerik; Google Play + App Store için geçerli link |

### Nice to Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S9-06 | Gerçek AdMob ID Entegrasyonu | godot-specialist | 0.5 | AdMob hesabı, S9-02 ✅ | Gerçek app ID + ad unit ID ortam değişkeniyle yüklendi; test modda ödül callback doğrulandı; ID asla commit edilmedi |
| S9-07 | Kapalı Beta Grubu Kurulumu | release-manager | 0.5 | S9-02 ✅ | ≥ 5 dış playtest kullanıcısı invite edildi; geri bildirim formu hazır |

---

## Carryover from Sprint 8

| Task | Sebep | Yeni ID | Tahmin |
|------|-------|---------|--------|
| S8-02: Cihaz Performans Profili | Fiziksel Android cihaz yoktu | S9-01 | 1.5 gün |
| S8-06: Google Play Internal Testing | Cihaz + hesap eksikti | S9-02 | 1.0 gün |

---

## Task Detayları

### S9-01: Gerçek Cihaz Performans Profili

**Kapsam:**
- `docs/balance/performance-profile-01.md` şablonu gerçek ölçüm verileriyle doldur
- 4 senaryo: boş menü, aktif fırın (3 slot), müşteri kuyruğu (5 müşteri), upgrade ekranı
- `adb logcat` veya Godot profiler remote ile PerformanceMonitor logları
- FPS < 30 durumunda draw call optimizasyon listesi

**Test Protokolü:**
```bash
./tools/build/export_android.sh debug
adb install build/android/breadmaster.apk
adb logcat -s GodotPrint  # PerformanceMonitor logları
```

### S9-02: Google Play Internal Testing

**Kapsam:**
- Release keystore ile `.aab` export: `./tools/build/export_android.sh release`
- Google Play Console → Internal testing → Yeni sürüm yükle
- Android vitals: ANR rate, crash rate izle
- Tester davetleri gönder (email)

### S9-03: Test Coverage

**Kapsam:**
- `test_game_audio_bridge.gd` — signal wiring, null stream fallback, _play() ✅
- `test_performance_monitor.gd` — sample_now(), moving avg, eşik sinyalleri ✅
- `test_hud_manager.gd` — toast kuyruğu, satisfaction low bildirimi ✅
- Hedef: toplam test dosyası ≥ 33, test sayısı ≥ 380

### S9-04: Playtest-02 Güncelleme

**Kapsam:**
- `docs/balance/playtest-02.md` §8 bloğunu gerçek veriyle doldur
- Q1–Q5 gerçek ölçümler: inner_anatolia süresi, istanbul açılışı, görev tamamlama
- istanbul 55 dk sorunu için öneri: unlock_cost: 200g mü eklenecek?
- economy-designer + game-designer konsültasyonu gerekirse

### S9-05: Privacy Policy Hosting

**Kapsam:**
- `gh-pages` branch veya GitHub Pages repo kurulumu
- `docs/privacy-policy/privacy-policy.md` → HTML sayfaya dönüştür
- URL doğrulama: Google Play Data Safety formu için aktif link

---

## Risks

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| Google Play review 3–7 gün | Yüksek | Orta | Internal track önce (review gerekmez); production S10 |
| Cihaz profili FPS < 30 bulgusu | Orta | Yüksek | Texture atlas review; shader simplification; draw call audit |
| AdMob hesabı onay gecikme | Orta | Yüksek | Test ID ile devam; gerçek ID S10'da |
| istanbul denge sorunu (55 dk) | Orta | Orta | playtest verisi ile karar; unlock_cost eklenmesi 1 sprint iş |

---

## External Dependencies

- Fiziksel Android cihaz (Snapdragon 665, Android 10+)
- Google Play Developer hesabı ($25 tek seferlik)
- AdMob hesabı (gerçek ID için)
- GitHub Pages erişimi (privacy policy için)

---

## Definition of Done

- [ ] S9-01: performance-profile-01.md gerçek cihaz verisiyle dolu
- [ ] S9-02: .aab internal track'te, crash-free install doğrulandı
- [ ] S9-03: test_game_audio_bridge.gd + test_performance_monitor.gd + test_hud_manager.gd ✅
- [ ] S9-04: playtest-02.md §8 gerçek veri
- [ ] S9-05: privacy policy URL aktif
- [ ] GUT: 0 failure
- [ ] Kod commit edildi ve push edildi
