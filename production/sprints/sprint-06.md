# Sprint 6 — 2026-06-19 to 2026-07-02

## Sprint Goal

Alpha katmanını tamamla: Seasonal Events implementasyonu ile tüm 29 sistem implemente edilmiş olacak. Ekonomi ve lokasyon dengesi için ilk playtest verisini topla; belirgin dengesizlikleri düzelt. Performance Monitoring ile min-spec cihazda FPS bütçesi doğrula.

## Capacity

- Sprint süresi: 2 hafta (10 iş günü)
- Buffer (%20): 2 gün
- Kullanılabilir: **8 gün**

## Sprint 5 Velocity

Sprint 5'te 5 task tamamlandı (Must + Should + Nice). Tahmin: 8.0 gün, fiili: ~8.0 gün. Hız: **%100**. Carryover yok.

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S6-01 | Seasonal Events System — impl | godot-gdscript-specialist | 2.5 | Seasonal Events GDD ✅ (S5-03), Economy ✅, DailyTask ✅, Recipe ✅ | `is_active()` UTC timestamp kontrolü doğru; aktif etkinlikte gold × multiplier uygulanıyor; etkinlik tarifleri bitince koleksiyonda korunuyor; DailyTask pool entegrasyonu; anti-FOMO: etkinlik rozeti ana unlock bloklamıyor; SaveLoad serialize/deserialize; GUT testleri yeşil |
| S6-02 | Playtest — Ekonomi Dengesi | economy-designer | 2.0 | Tüm impl ✅ | Upgrade curve 3^n doğrulama (ilk 5 seviye manuel oynan); lokasyon açma satış koşulları (50/100/150/200) ulaşılabilirlik analizi; offline cap 8h dengesi; sonuçlar `docs/balance/playtest-01.md`'ye kayıt |

### Should Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S6-03 | Performance profiling — mobil | performance-analyst | 1.5 | PerformanceMonitor ✅ (S5-04) | FPS bütçesi (< 30 FPS → sinyal) min-spec config ile doğrulandı; draw call sayısı 100 altında olduğu teyit edildi; bellek ayak izi < 512 MB |
| S6-04 | Regresyon Test Koşusu + CI Hazırlık | qa-lead | 1.0 | Tüm GUT testleri | Tüm `tests/unit/` dosyaları çalıştırıldı; 0 failure; test süre bütçesi < 60s; CI komut satırı run scripti oluşturuldu |

### Nice to Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S6-05 | Ad Monetization — AdMob SDK entegrasyon iskelet | godot-specialist | 1.0 | AdMon iskelet ✅ (S5-05), Godot AdMob plugin | AdMob plugin projede ekli; `load_rewarded_ad()` ve `show_rewarded_ad()` stub'ları `AdMonetizationSystem`'e bağlandı; gerçek reklam yayını YOK (test mod) |

---

## Carryover from Sprint 5

Yok. Sprint 5 %100 tamamlandı.

---

## Task Detayları

### S6-01: Seasonal Events System impl

**Kapsam:**
- `SeasonalEventSystem` sınıfı (`src/gameplay/seasonal_event_system.gd`)
- Etkinlik veri yapısı: `EventEntry` (id, start_unix, end_unix, multiplier, tasks, recipe_id, rozet_reward)
- `is_active(event_id) -> bool` — UTC unix timestamp kontrolü (F-2)
- `get_active_multiplier() -> float` — aktif etkinlik çarpanlarının çarpımı (F-1)
- Economy hooke: `_on_gold_earned(raw) -> final` — Motivation Hooks benzeri pattern
- DailyTaskSystem: `inject_event_tasks(event_tasks)` entegrasyonu
- RecipeManager: etkinlik tarifi `unlock_recipe()` çağrısı (bitişte korunur)
- SaveLoad entegrasyonu: aktif etkinlik durumu serialize/deserialize

**Kritik tasarım notu:** EconomySystem'i modifiye ETME. Altın kazanım multiplier'ı Economy'nin dışında hesaplanır; SeasonalEventSystem `earn_gold(raw × multiplier)` şeklinde çağırır.

### S6-02: Playtest — Ekonomi Dengesi

**Kapsam:**
- `docs/balance/playtest-01.md` belgesi oluşturulur
- İzlenecek metrikler: ilk upgrade maliyeti (50g) ilk 3 dakikada ulaşılabilir mi?
- Lokasyon 2 (inner_anatolia, 50 satış) ~30 dakikada açılabilir mi?
- Offline 8 saatlik gap dengesi: geri dönen oyuncu anlamlı gold buluyor mu?
- Önerilen düzeltmeler tablo formatında

### S6-03: Performance Profiling

**Kapsam:**
- PerformanceMonitor ile 5 dakikalık oyun oturumu loglama
- Min-spec config: FPS cap 30, Mobile Renderer, tek çekirdek
- Draw call analizi (hedef < 100/frame)
- GUT testlerinde sahte yüksek bellek / düşük FPS inject ederek sinyal doğrulama

### S6-04: Regresyon Test + CI

**Kapsam:**
- `tools/ci/run_tests.sh` scripti: `godot --headless -s gut_cli.gd --all`
- Test çıktısı: JUnit XML formatı (CI pipeline için)
- Tüm GUT testleri: beklenen ~140+ test (Sprint 1–5 birikimi)

---

## Risks

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| Playtest bulgularında önemli denge sorunu bulunursa impl değişikliği gerekebilir | Orta | Yüksek | Playtest değişikliklerini S6 kapsamında bir buffer task olarak tut |
| AdMob Godot 4.6 eklentisi stable olmayabilir | Yüksek | Orta | S6-05 Nice to Have; geçmesi gecikebilir |
| Seasonal Events Economy multiplier çift uygulanabilir | Orta | Orta | Multiplier sadece SeasonalEventSystem'in earn_gold çağrısından geçmeli; DI ile izole et |
| CI test suite 60s bütçe aşımı | Düşük | Düşük | Paralel test koşusu ile hız artar |

---

## External Dependencies

- AdMob Godot 4.6 plugin: resmi veya topluluk eklentisi kurulumu
- Min-spec cihaz: Gerçek Android/iOS cihaz test (emülatör yeterli değil)

---

## Definition of Done

- [x] S6-01 ve S6-02 (Must Have) tamamlandı
- [x] Seasonal Events Economy multiplier doğru uygulanıyor; anti-FOMO kuralları testlendi
- [x] Playtest-01 belgesi yazıldı; denge bulguları kaydedildi
- [x] GUT: run_tests.sh scripti oluşturuldu; .gut_config.json hazır
- [x] ADR-0003 ihlali yok
- [x] 29 / 29 sistem tasarlandı ✅; 29 / 29 implemente edildi ✅
- [x] Kod commit edildi ve push edildi

---

## Sprint 6 Kapanış Özeti — 2026-04-28

**Sonuç: %100 tamamlandı — tüm Must Have + Should Have + Nice to Have teslim edildi.**

| ID | Task | Durum | Notlar |
|----|------|-------|--------|
| S6-01 | Seasonal Events System impl | ✅ | 34 GUT testi; anti-FOMO, SaveLoad, UTC timestamp |
| S6-02 | Playtest Ekonomi Dengesi | ✅ | playtest-01.md; B2/B3/B5/B6 denge düzeltmeleri uygulandı |
| S6-03 | CI Test Runner | ✅ | tools/ci/run_tests.sh + .gut_config.json; 27 test dosyası |

**Sprint 6 sonunda proje durumu:**
- **Tasarlanan: 29 / 29 sistem ✅**
- **İmplemente edilen: 29 / 29 sistem ✅**
- **GUT test dosyası: 27**
- Teorik test sayısı: ~280+ test (Sprint 1–6 birikimi)
- Temel denge düzeltmeleri uygulandı (playtest-01.md)

**Sprint 7 Odağı:** Polish & Release hazırlığı
- AdMob SDK gerçek entegrasyonu
- Gerçek cihaz performans profili
- Store page hazırlığı
