# Sprint 5 — 2026-06-05 to 2026-06-18

## Sprint Goal

Vertical Slice'ı kapat: Tutorial/Onboarding implementasyonuyla oyunun ilk açılışı polislenmiş ve öğretilebilir hale gelir. Delivery System ile idle döngüsüne yeni pasif gelir kanalı eklenir. Alpha katmanı için Seasonal Events ve Performance Monitoring GDD tasarımları yapılır.

## Capacity

- Sprint süresi: 2 hafta (10 iş günü)
- Buffer (%20): 2 gün (teknik borç, blocker)
- Kullanılabilir: **8 gün**

## Sprint 4 Velocity

Sprint 4'te 6 task tamamlandı (tüm must/should/nice-to-have). Tahmin: 7.0 gün, fiili: ~8.5 gün (kapsamlı GDD'ler dahil). Hız: **%100**. Sprint 5'e carryover yok.

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S5-01 | Tutorial/Onboarding System — impl | godot-gdscript-specialist | 2.5 | Tutorial GDD ✅ (S4-05), Tüm MVP sistemleri ✅ | 5 adım sıralı çalışıyor; her adım sonrası doğru ödül veriliyor; Skip flow: confirm dialog → flag yazılıyor → ödül verilmiyor; tutorial_completed SaveLoad'a yazılıyor; prestige sonrası tekrar başlamıyor; hint sistemi 3 event doğru tetikliyor; GUT testleri yeşil |
| S5-02 | Delivery System — impl | godot-gdscript-specialist | 2.0 | Delivery GDD ✅ (S4-06), Economy ✅, UpgradeTree ✅ | 3 teslimat türü (local/city/intercity) doğru süre ve ödülle çalışıyor; F-1 ödül formülü doğrulandı; `delivery_speed` upgrade %10/seviye süre azaltıyor; `delivery_slots` upgrade slot ekliyor; expire (4h) çalışıyor; unix timestamp offline uyum; serialize/deserialize; GUT testleri yeşil |

### Should Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S5-03 | Seasonal Events System — GDD tasarımı | game-designer | 1.5 | Daily Task ✅, Economy ✅, Time Tracking ✅ | 8 bölümlü GDD: etkinlik tetikleme koşulları, sınırlı süreli tarif/ödül mekanizması, Ramazan / Kurban Bayramı / Yeni Yıl etkinlik örnekleri, anti-FOMO tasarım kuralları |
| S5-04 | Performance Monitoring — GDD + iskelet impl | engine-programmer | 1.0 | Tüm sistemler | GDD: izlenecek metrikler (FPS, draw call, memory), sampling stratejisi, profiler hook noktaları; iskelet: `PerformanceMonitor` sınıfı sinyalleri tanımlı, `_process()` yasak → SceneTreeTimer bazlı örnekleme |

### Nice to Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S5-05 | Ad Monetization System — iskelet impl (AdMob-bağımsız) | godot-gdscript-specialist | 1.0 | AdMon GDD ✅ (S4-04), Economy ✅ | `AdMonetizationSystem` sınıfı: 5 placement tanımlı, cooldown/kota state yönetimi, ödül callback interface'i; AdMob SDK bağımlılığı YOK — stub/mock ile çalışır; GUT testleri: F-4 can_show(), ödül güvenliği, null guard |

---

## Carryover from Sprint 4

Yok. Sprint 4 %100 tamamlandı.

---

## Task Detayları

### S5-01: Tutorial/Onboarding System impl

**Kapsam:**
- `TutorialSystem` sınıfı (`src/ui/tutorial_system.gd`)
- 5 step state machine: `tut_knead` → `tut_bake` → `tut_harvest` → `tut_sell` → `tut_upgrade`
- Tooltip overlay konumlandırması (UI element referansları DI ile)
- Skip flow: 5 saniye delay, confirm dialog, `tutorial_completed` flag
- Hint sistemi: `hint_offline_return`, `hint_new_upgrade`, `hint_daily_task` (her biri 1 kez)
- `tut_active` property: AdMonetizationSystem için; tutorial devamında reklam baskılama
- SaveLoad entegrasyonu: `tutorial_completed`, `current_step`, `hint_shown[]`

**Kritik tasarım notları:**
- Tutorial ödülleri idempotent: `reward_given[step]` flag ile çift ödeme engellenir
- Tooltip: UI elementini bloke etmez, yalnızca visual overlay
- Skip → başlangıç altını 30 (sabit starting_gold); tutorial ödülleri verilmez

### S5-02: Delivery System impl

**Kapsam:**
- `DeliverySystem` sınıfı (`src/gameplay/delivery_system.gd`)
- `DeliverySlot` iç sınıfı: type, start_unix, duration, bread_count, reward, expired
- `start_delivery(type)` → stok düşür + unix timestamp kaydet
- `claim_reward(slot_idx)` → `economy.earn_gold()`
- `tick_deliveries()` → expire kontrolü (SceneTreeTimer bazlı, 60s aralık)
- UpgradeTree: `delivery_speed` ve `delivery_slots` seviye okuma
- SaveLoad entegrasyonu: aktif slot state'leri serialize/deserialize

**Kritik tasarım notu:** Timer tabanlı tick — ADR-0003 uyumu. `_process()` kullanılmaz.

### S5-03: Seasonal Events System GDD

**Kapsam:**
- 8 bölümlü GDD: etkinlik tanımı, türler, tetikleme koşulları, sınırlı süreli ödüller
- Önerilen etkinlikler: Ramazan Bayramı (simit üretim bonus), Yeni Yıl (altın 1.5×)
- Anti-FOMO tasarım kuralları: etkinlik ödülleri unique değil, oyunu bloklamamalı
- Gelecek sprint (S6) için impl iskelet: etkinlik takvimi veri yapısı

### S5-04: Performance Monitoring GDD + iskelet

**Kapsam:**
- GDD: FPS, draw call, memory, bake timer ortalama metrikleri
- İskelet: `PerformanceMonitor.new()` → SceneTreeTimer (5s) → `Performance.get_monitor()` örnekleme
- Sinyaller: `fps_dropped(fps: float)`, `memory_warning(mb: float)`
- ADR-0003 uyumu: `_process()` yasak; Timer ile örnekleme

---

## Risks

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| Tutorial tooltip konumlandırması farkl ekran boyutlarında bozulabilir | Orta | Orta | Anchor-based konumlandırma; minimum 2 ekran boyutunda test |
| Delivery System expire logic: arka planda uygulama kapalıysa timer çalışmaz | Yüksek | Düşük | unix timestamp check `_ready()` ve her tick'te; offline uyum garantili |
| `delivery_slots` upgrade mevcut UpgradeTree şemasında tanımlı olmayabilir | Orta | Orta | UpgradeTree veri yapısını kontrol et; yoksa `upgrade_data` resource ekle |
| AdMob SDK Godot 4.6 uyumluluğu belirsiz | Yüksek | Yüksek | S5-05 SDK bağımsız iskelet; gerçek SDK entegrasyonu S6'ya ertelendi |
| Seasonal Events anti-FOMO tasarımı GDD'de yeterince spesifik olmayabilir | Orta | Düşük | GDD acceptance criteria'ya "etkinlik kaçırılan içerik = sıfır" kuralı ekle |

---

## External Dependencies

- Tutorial impl: UI/HUD node path'leri belirsiz; impl sırasında DI enjeksiyonla çözülecek
- Delivery System: `delivery_speed` / `delivery_slots` upgrade ID'leri UpgradeTree config'inde tanımlı olmalı

---

## Definition of Done

- [ ] S5-01 ve S5-02 (Must Have) tamamlandı
- [ ] Tutorial 5 adım sıralı; skip flow ve hint sistemi çalışıyor
- [ ] Delivery System unix timestamp offline uyumlu; expire çalışıyor
- [ ] GUT testleri yazıldı; 0 failure
- [ ] ADR-0003 ihlali yok (`_process()` hiçbir yeni sistemde kullanılmadı)
- [ ] systems-index.md Alpha katmanı ilerleme güncellendi
- [ ] Vertical Slice impl tamamlanma oranı ≥ %90 (11'de 10)
- [ ] Kod commit edildi ve push edildi
