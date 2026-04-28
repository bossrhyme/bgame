# Sprint 4 — 2026-05-22 to 2026-06-04

## Sprint Goal

Vertical Slice'ı tamamla: Location/Prestige impl, Collection/Dex sistemi, Motivation Hooks ile oyunun 20 dakikalık polislenmiş döngüsü oynanabilir hale gelir.

## Capacity

- Sprint süresi: 2 hafta (10 iş günü)
- Buffer (20%): 2 gün (teknik borç, beklenmedik blocker)
- Kullanılabilir: **8 gün**

## Sprint 3 Velocity

Sprint 3'te 8 task tamamlandı (8.0 gün tahmini, tümü teslim edildi). Hız: %100. Sprint 4'e carryover yok.

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S4-01 | Location/Prestige System — impl | godot-specialist | 2.5 | LocationPrestige GDD ✅ (S3-06), Recipe ✅, UpgradeTree ✅, Economy ✅, UnlockConditionResolver ✅ | 5 lokasyon sıralı açılıyor; satış koşulu AND upgrade koşulu doğru değerlendiriliyor; prestij gold sıfırlıyor, Rozet koruyor, F-2 bonus formülü çalışıyor; prestige_count serialize/deserialize; GUT testleri yeşil |
| S4-02 | Collection/Dex System — GDD + impl | godot-specialist | 1.5 | Recipe ✅, Location GDD ✅ | Açılan tarifler koleksiyona ekleniyor; kategori bazlı tamamlanma yüzdesi hesaplanıyor; unlock_all_in_category bonusu çalışıyor; GUT testleri yeşil |

### Should Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S4-03 | Motivation Hooks System — GDD + impl | godot-specialist | 1.5 | HUDManager ✅, NotificationManager ✅, DailyTaskSystem ✅ | "N altın daha" progress bar çalışıyor; "Vitrin dolmak üzere" uyarısı tetikleniyor; "Geri dön" push notification hook iskelet; GUT testleri yeşil |
| S4-04 | Ad Monetization System — GDD tasarımı (impl yok) | godot-specialist | 1.0 | Economy ✅, HUDManager ✅ | 8 bölümlü GDD: rewarded ad trigger koşulları, "2× kazanım" formülü, cooldown penceresi, etik tasarım kuralları tanımlandı |

### Nice to Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S4-05 | Tutorial/Onboarding System — GDD tasarımı (impl yok) | godot-specialist | 1.0 | Tüm MVP sistemleri ✅ | İlk 5 dakika akışı tasarlandı; highlight overlay, coach mark, skip logic kuralları tanımlandı; GDD 8 bölümü tamamlandı |
| S4-06 | Delivery System — GDD tasarımı (impl yok) | godot-specialist | 0.5 | UpgradeTree ✅ | Teslimat slotu sayısı, zaman bazlı kazanım formülü, upgrade entegrasyonu tanımlandı |

---

## Carryover from Sprint 3

Yok. Sprint 3 tüm task'larla (%100) kapandı.

---

## Task Detayları

### S4-01: Location/Prestige System impl

**Kapsam:**
- `LocationSystem` sınıfı (`src/progression/location_system.gd`)
- 5 lokasyon tanımı + açma koşulları (UnlockConditionResolver entegrasyonu)
- Yeni koşul tipi: `prestige_count` — UnlockConditionResolver'a eklenmeli
- Prestij akışı: Economy sıfırlama, UpgradeTree sıfırlama, RecipeManager kilit geri alma
- serialize/deserialize: `unlocked_locations[]`, `prestige_count`, `category_sale_counts{}`
- SaveLoadManager entegrasyonu

**Kritik tasarım notu:** Prestige sıfırlaması SaveLoadManager `_finish_load()` sırasında ÇALIŞMAZ — yalnızca oyuncu aksiyonuyla tetiklenir.

### S4-02: Collection/Dex System impl

**Kapsam:**
- `CollectionDexSystem` sınıfı (`src/progression/collection_dex_system.gd`)
- `RecipeManager.recipe_unlocked` → koleksiyona ekle
- `get_category_completion(category_id) -> float` (0.0–1.0)
- `get_total_completion() -> float`
- Tüm kategoride tamamlanma bonusu: HUDManager üzerinden bildirim
- serialize/deserialize

### S4-03: Motivation Hooks System impl

**Kapsam:**
- `MotivationHooksSystem` sınıfı (`src/ui/motivation_hooks_system.gd`)
- Economy izle: "N altın daha → upgrade" hesabı
- OvenManager izle: "Vitrin dolmak üzere" (kapasite %80)
- DailyTaskSystem izle: "2 görev kaldı" bildirimi
- SessionTimer: 20 dakika sessizlik → "Geri dön!" hook iskelet
- NotificationManager entegrasyonu (MEDIUM priority)

---

## Risks

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| Prestij sıfırlaması RecipeManager state'ini bozabilir | Orta | Yüksek | Prestige reset öncesi tam snapshot al; GUT entegrasyon testi yaz |
| UnlockConditionResolver'a yeni koşul tipi eklenmesi mevcut testleri kırabilir | Düşük | Orta | Mevcut test suite'i çalıştır; regresyon testi ekle |
| Collection/Dex + Location bağımlılığı: Location impl tamamlanmadan Dex test edilemez | Yüksek | Orta | LocationSystem mock'u ile CollectionDex ayrı test edilebilir (DI) |
| Motivation Hooks "geri dön" push notifik. Godot 4.6'da platform permission gerektiriyor | Yüksek | Düşük | S4'te yalnızca iskelet — gerçek platform push S5'e ertelendi |
| Prestij loop dengesi (F-2 bonus) playtestsiz belirlenemez | Orta | Orta | F-2 formülü GDD'de tanımlandı; S4 sonunda /balance-check çalıştır |

---

## External Dependencies

- Godot 4.6 platform push notification API — S4'te kullanılmıyor; S5'e ertelendi
- Playtest verisi: Lokasyon açma satış koşulları (50/100/150/200) dengesini doğrulamak için gerçek oyun oturumu gerekiyor

---

## Definition of Done

- [ ] S4-01 ve S4-02 (Must Have) tamamlandı
- [ ] Prestij sıfırlaması GUT entegrasyon testinden geçti
- [ ] Tüm tamamlanan task'lar GDD acceptance criteria ile karşılaştırıldı
- [ ] GUT testleri yazıldı; 0 failure
- [ ] ADR-0003 ihlali yok
- [ ] UnlockConditionResolver prestige_count koşulu mevcut testleri kırmıyor
- [ ] systems-index.md Vertical Slice ilerleme güncel
- [ ] Kod commit edildi ve push edildi
