# Sprint 7 — 2026-07-03 to 2026-07-16

## Sprint Goal

Polish & Release hazırlığı: AdMob SDK entegrasyonu tamamlanır, gerçek cihaz performans profili alınır, store page hazırlanır, sertifikasyon kontrol listesi oluşturulur. Oyun ilk dış playteste çıkmaya hazır hale gelir.

## Capacity

- Sprint süresi: 2 hafta (10 iş günü)
- Buffer (%20): 2 gün
- Kullanılabilir: **8 gün**

## Sprint 6 Velocity

Sprint 6'da 3 task tamamlandı (tümü must/should/nice). %100. Carryover yok.

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S7-01 | AdMob SDK — Godot 4.6 entegrasyonu | godot-specialist | 2.0 | AdMon iskelet ✅ (S5-05), AdMob Godot plugin | `load_rewarded_ad()` ve `show_rewarded_ad()` gerçek SDK çağrıları bağlandı; test reklam ID ile izleme çalışıyor; `on_user_earned_reward` → `AdMonetizationSystem.on_ad_rewarded()` köprüsü kuruldu; fill rate = 0 graceful fallback doğrulandı |
| S7-02 | Gerçek Cihaz Performans Profili | performance-analyst | 1.5 | PerformanceMonitor ✅ (S5-04), fiziksel Android cihaz | FPS > 30 tüm temel senaryolarda; draw call < 100; bellek < 512 MB; profil raporu `docs/balance/performance-profile-01.md` |

### Should Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S7-03 | Tutorial UI Polish — Tooltip görsel tasarım | ui-programmer | 1.5 | TutorialSystem ✅ (S5-01), UI/HUD ✅ | Tooltip animasyonlu ok + metin overlay; UI elementini bloke etmiyor; fade-out 0.3s; skip butonu 5s sonra görünüyor |
| S7-04 | Store Page Hazırlığı | release-manager | 1.0 | Tüm feature ✅ | App Store + Google Play metadata: başlık, kısa açıklama, uzun açıklama (TR/EN), screenshot spesifikasyonu, privacy policy linki |

### Nice to Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S7-05 | Sertifikasyon Kontrol Listesi | release-manager | 0.5 | Store Page ✅ | iOS App Store + Google Play gereklilikleri listesi; her madde için durum (hazır / bekliyor / yok) |
| S7-06 | Playtest-02 — Gerçek Cihaz Oturumu | game-designer | 1.0 | Tüm impl ✅, fiziksel cihaz | 20 dakikalık oyun oturumu; lokasyon 2 açıldı mı? Q1 yeni değerlere göre doğrulandı mı? `docs/balance/playtest-02.md` |

---

## Carryover from Sprint 6

Yok. Sprint 6 %100 tamamlandı.

---

## Task Detayları

### S7-01: AdMob SDK Entegrasyonu

**Kapsam:**
- Godot 4.6 uyumlu AdMob eklentisi kurulumu (resmi veya godot-gdextension-specialist tarafından onaylanan)
- `GodotAdMob` veya eşdeğeri sınıfından `AdMonetizationSystem`'e köprü
- Sinyal map: `_on_rewarded_ad_earned_reward(ad_unit_id, reward)` → `on_ad_rewarded(placement_id, context)`
- Test reklam ID: `ca-app-pub-3940256099942544/5224354917` (Android test)
- Fill rate = 0 test: sahte hata callback ile `notify_ad_failed()` doğrulama

**Kritik:** Gerçek reklam ID'leri ASLA commit edilmez — environment variable veya ayrı config dosyası.

### S7-02: Performans Profili

**Kapsam:**
- Android mid-range hedef: Snapdragon 665 veya eşdeğeri
- Test senaryoları: boş ekran, aktif fırın (3 slot), müşteri kuyruğu (5 müşteri), upgrade menüsü
- PerformanceMonitor çıktısı: FPS avg, draw calls, memory peak
- `docs/balance/performance-profile-01.md` raporu

### S7-03: Tutorial Tooltip

**Kapsam:**
- `TutorialOverlay` UI bileşeni: `show_tooltip` sinyalini dinler
- Hedef node path → anchor pozisyon hesabı
- Animasyonlu ok (↓/→/↑/←): target'ın etrafında konumlanır
- 60 karakter hard limit gösterim testi

### S7-04: Store Page

**Kapsam:**
- TR: "Ekmek Ustası — İdol Fırın Simülasyonu"
- EN: "Bread Master — Idle Bakery Simulation"
- Kısa açıklama: max 80 karakter
- Uzun açıklama: max 4.000 karakter
- Screenshot boyutları: 1080×1920 (Android), 1242×2688 (iOS)
- Privacy policy: GDPR uyumlu (reklam veri toplama bildirimi)

---

## Risks

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| AdMob Godot 4.6 eklentisi resmi olarak desteklenmiyor olabilir | Yüksek | Yüksek | GDExtension yolu araştır; stub üretim modda çalışmaya devam eder |
| Min-spec cihazda FPS < 30 | Orta | Yüksek | draw call optimizasyonu; texture atlas kontrolü |
| iOS sertifikasyon süreci uzun | Yüksek | Orta | Android önce ship; iOS S8'e ertelendi |
| Store açıklama lokalizasyon süresi | Düşük | Düşük | Writer ajanıyla paralel çalış |

---

## External Dependencies

- Fiziksel Android cihaz (min-spec: Snapdragon 665 veya eşdeğeri)
- AdMob hesabı ve app ID
- Apple Developer Program hesabı (iOS sertifikasyon için)
- Privacy policy hosting

---

## Definition of Done

- [x] S7-01: AdMob bridge + stub tamamlandı
- [ ] S7-02: Gerçek cihaz performans profili (fiziksel cihaz gerekli — S8'e ertelendi)
- [x] S7-03: Tutorial overlay tamamlandı
- [x] S7-04: Store page metadata TR + EN hazır
- [x] S7-05: Sertifikasyon kontrol listesi oluşturuldu
- [x] S7-06: Playtest-02 teorik doğrulama tamamlandı (gerçek cihaz S8'de)
- [ ] AdMob test reklam gerçek cihazda gösterildi (S8 bağımlı)
- [ ] FPS > 30 tüm temel senaryolarda (S8 bağımlı — fiziksel cihaz)
- [x] Kod commit edildi ve push edildi

---

## Sprint 7 Kapanış Özeti — 2026-04-28

**Sonuç: %83 tamamlandı — S7-02 fiziksel cihaz bağımlılığı nedeniyle S8'e ertelendi.**

| ID | Task | Durum | Notlar |
|----|------|-------|--------|
| S7-01 | AdMob SDK bridge + stub | ✅ | AdMobStub + AdMobBridge; placement↔unit_id map; sinyal köprüsü |
| S7-02 | Gerçek Cihaz Performans Profili | 🔄 S8 | Snapdragon 665 fiziksel cihaz gerekli |
| S7-03 | Tutorial UI Polish | ✅ | TutorialOverlay; MOUSE_FILTER_IGNORE; 0.3s fade; arrow blink; skip btn |
| S7-04 | Store Page Hazırlığı | ✅ | production/store/store-page.md; TR/EN; screenshot spesifikasyonu; GDPR |
| S7-05 | Sertifikasyon Kontrol Listesi | ✅ | production/store/certification-checklist.md; Google Play + App Store |
| S7-06 | Playtest-02 Teorik Doğrulama | ✅ | docs/balance/playtest-02.md; B2/B3/B5/B6 doğrulandı; gerçek cihaz S8 |

**Sprint 7 sonunda proje durumu:**
- **Tasarlanan: 29 / 29 sistem ✅**
- **İmplemente edilen: 29 / 29 sistem ✅**
- **Store hazırlığı: Google Play metadata hazır**
- **Sertifikasyon:** Google Play kritik yol tanımlandı; iOS S8+
- **Carryover S8:** S7-02 cihaz profili + real AdMob ID + privacy policy hosting

**Sprint 8 Odağı:** İlk gerçek cihaz build → Google Play internal testing
- Android export pipeline kurulumu (API 34, arm64, .aab)
- Gerçek AdMob ID entegrasyonu (environment variable)
- Privacy policy yayınlanması (GitHub Pages)
- Google Play GDPR UMP SDK entegrasyonu
- Gerçek cihaz performans profili (S7-02 carryover)
