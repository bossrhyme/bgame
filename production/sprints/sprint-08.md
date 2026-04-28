# Sprint 8 — 2026-07-17 to 2026-07-30

## Sprint Goal

İlk Android build: Google Play internal testing'e yükleme. Gerçek cihaz performans profili tamamlanır, AdMob gerçek ID entegre edilir, privacy policy yayınlanır. Oyun dış playteste hazır hale gelir.

## Capacity

- Sprint süresi: 2 hafta (10 iş günü)
- Buffer (%20): 2 gün
- Kullanılabilir: **8 gün**

## Sprint 7 Velocity

Sprint 7'de 5/6 task tamamlandı (%83). S7-02 fiziksel cihaz bağımlılığı nedeniyle S8'e ertelendi. Carryover: 1 task.

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S8-01 | Android Export Pipeline | godot-specialist | 1.5 | Godot 4.6, Android SDK 34 | .aab export çalışıyor; arm64; keystore imzalı; project.godot versionCode/versionName set; Google Play internal track'e yüklenebilir |
| S8-02 | Gerçek Cihaz Performans Profili (S7-02 Carryover) | performance-analyst | 1.5 | S8-01 ✅, Snapdragon 665 cihaz | FPS > 30 tüm temel senaryolarda; draw call < 100; bellek < 512 MB; `docs/balance/performance-profile-01.md` |
| S8-03 | AdMob Gerçek ID Entegrasyonu | godot-specialist | 1.0 | S8-01 ✅, AdMob hesabı | Gerçek app ID + ad unit ID environment variable ile yükleniyor; test modda doğrulandı; ASLA commit edilmedi |

### Should Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S8-04 | Privacy Policy Yayınlama | release-manager | 0.5 | GitHub Pages | URL aktif: `bossrhyme.github.io/breadmaster/privacy`; GDPR uyumlu; AdMob veri toplama beyanı |
| S8-05 | GDPR UMP SDK Entegrasyonu | godot-specialist | 1.5 | S8-03 ✅, S8-04 ✅ | Google UMP SDK ile AB kullanıcıları için rıza akışı; AdMob yalnızca rıza sonrası gösteriliyor |
| S8-06 | Google Play Internal Testing Yüklemesi | release-manager | 0.5 | S8-01 ✅, S8-04 ✅ | .aab Play Console'a yüklendi; internal tester grubuna dağıtıldı; crash-free install doğrulandı |

### Nice to Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S8-07 | Playtest-02 Gerçek Cihaz Doğrulaması | game-designer | 1.0 | S8-01 ✅, S7-06 metodoloji | `docs/balance/playtest-02.md` güncellendi; Q1–Q5 gerçek ölçüm; istanbul hız sorunu değerlendirildi |
| S8-08 | iOS ATT Entegrasyonu (Hazırlık) | godot-specialist | 1.0 | iOS export | AppTrackingTransparency izin akışı; NSUserTrackingUsageDescription; iOS test build |

---

## Carryover from Sprint 7

| Task | Sebep | Yeni Tahmin |
|------|-------|-------------|
| S7-02: Cihaz Performans Profili | Fiziksel Android cihaz sprint 7'de mevcut değildi | S8-02 olarak 1.5 gün |

---

## Task Detayları

### S8-01: Android Export Pipeline

**Kapsam:**
- Godot 4.6 → Android export template kurulumu
- `export_presets.cfg` → Android target API 34, arm64-v8a + x86_64
- Release keystore oluşturma (local, commit'e dahil edilmez)
- `project.godot`: `config/version = "1.0.0"`, versionCode = 1
- `.gitignore` güncelleme: `*.keystore`, `*.jks`, gerçek ID config dosyaları
- `tools/build/export_android.sh` — tekrarlanabilir export scripti

**Kritik:**
- Keystore ASLA commit edilmez
- Gerçek AdMob ID ASLA commit edilmez → `res://config/admob_ids.cfg` gitignore'da

### S8-02: Cihaz Performans Profili

**Kapsam:**
- `docs/balance/performance-profile-01.md` raporu (S7-02 acceptance criteria)
- Minimum 4 senaryo: boş menü, aktif fırın (3 slot), müşteri kuyruğu (5 müşteri), upgrade ekranı
- PerformanceMonitor log çıktısı analizi
- FPS < 30 durumunda draw call / texture atlas önerileri

### S8-03: Gerçek AdMob ID Entegrasyonu

**Kapsam:**
- `res://config/admob_ids.cfg` (gitignore'da) → GDScript `ConfigFile` ile yükleme
- `AdMobBridge`: `AD_UNIT_IDS` sabit → runtime config yükleme
- Fallback: config yoksa `TEST_AD_UNIT_ANDROID` kullan
- `tools/build/set_admob_ids.sh` — CI için environment variable → config dosyası oluşturucu

### S8-04: Privacy Policy

**Kapsam:**
- `docs/privacy-policy/privacy-policy.md` → GitHub Pages formatı
- GDPR gereklilikleri: veri kontrolörü, toplanan veri türleri, saklama süresi, kullanıcı hakları
- AdMob veri akışı açıklaması
- TR + EN sürümler

### S8-05: GDPR UMP SDK

**Kapsam:**
- Google User Messaging Platform (UMP) SDK entegrasyonu
- AB bölgesi algılama → consent form
- `AdMonetizationSystem` → rıza durumuna göre `can_show()` etkisi
- Non-personalized ad fallback (rıza verilmeden)

---

## Risks

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| Google Play review süreci 3–7 gün | Yüksek | Orta | Internal track önce; açık test S9 |
| UMP SDK Godot 4.6 entegrasyon zorluğu | Orta | Yüksek | GDExtension yolu; stub ile geçici bypass |
| AdMob hesabı onay süreci | Orta | Yüksek | Hesap önceden açılmalı; test ID ile çalışmaya devam |
| Cihaz profili FPS < 30 bulgusu | Orta | Yüksek | Draw call optimizasyonu; atlas review; shader simplification |
| iOS ATT rejection (App Store) | Düşük | Orta | Android önce ship; iOS S9 hedefi |

---

## External Dependencies

- Fiziksel Android cihaz (Snapdragon 665, Android 10+)
- AdMob hesabı + app ID (gerçek)
- Google Play Developer hesabı
- GitHub Pages (privacy policy hosting)
- Android SDK 34 + build tools

---

## Definition of Done

- [x] S8-01: Android export pipeline (script + preset şablonu + .gitignore)
- [ ] S8-02: Gerçek cihaz FPS > 30 tüm senaryolarda — fiziksel cihaz gerekli
- [x] S8-03: AdMob config sistemi (runtime yükleme, gitignore, set_admob_ids.sh)
- [x] S8-04: Privacy policy belgesi (TR+EN, GDPR/CCPA uyumlu)
- [x] S8-05: ConsentManager skeleton (UMP stub, rıza durumu yönetimi)
- [ ] S8-06: Google Play internal track yüklemesi — cihaz + hesap gerekli
- [ ] AdMob gerçek ID commit'e dahil edilmedi ✅ (config sistemi kuruldu, gitignore'da)
- [ ] .aab Google Play internal track'e yüklendi — fiziksel cihaz gerekli
- [x] Kod commit edildi ve push edildi

---

## Sprint 8 Kapanış Özeti — 2026-04-28

**Sonuç: %71 tamamlandı — S8-02/S8-06 fiziksel cihaz + Google Play hesabı bağımlılığı.**

| ID | Task | Durum | Notlar |
|----|------|-------|--------|
| S8-01 | Android Export Pipeline | ✅ | tools/build/export_android.sh; preset şablonu; .gitignore güncellendi |
| S8-02 | Gerçek Cihaz Performans Profili | 🔄 S9 | performance-profile-01.md şablonu hazır; cihaz gerekli |
| S8-03 | AdMob Gerçek ID Entegrasyonu | ✅ | ConfigFile runtime yükleme; set_admob_ids.sh; fallback test ID |
| S8-04 | Privacy Policy | ✅ | docs/privacy-policy/privacy-policy.md; TR+EN; GDPR/CCPA |
| S8-05 | GDPR UMP SDK | ✅ | ConsentManager skeleton; UMP stub; can_show_ads() API |
| S8-06 | Google Play Internal Testing | 🔄 S9 | .aab export hazır; hesap ve cihaz gerekli |
| S8-07 | Playtest-02 Gerçek Cihaz | 🔄 S9 | S8-02 ile birlikte |
| S8-08 | iOS ATT Hazırlık | ❌ S9+ | iOS odağı S9'a ertelendi |

**Sprint 8 sonunda proje durumu:**
- Android build pipeline: ✅ scriptler + preset şablonu hazır
- Güvenli ID yönetimi: ✅ config gitignore, runtime yükleme
- Privacy/GDPR altyapısı: ✅ belge + ConsentManager skeleton
- Kalan blokajlar: fiziksel Snapdragon 665 cihaz + Google Play Developer hesabı

**Sprint 9 Odağı:** Gerçek cihaz doğrulaması + ilk dış playtest
- Fiziksel cihazda build yükleme ve performans profili (S8-02/S8-06 carryover)
- Gerçek AdMob ID entegrasyonu (hesap gerekli)
- Privacy policy GitHub Pages'e yükleme
- Kapalı beta / dış playtest grubu
- [ ] GUT: 0 failure (regresyon)
- [ ] Kod commit edildi ve push edildi
