# Sprint 2 — 2026-04-24 to 2026-05-07

## Sprint Goal

Kalan MVP sistemlerini implemente ederek tam oynanabilir döngüyü tamamla:
hamur yoğur → tarife göre pişir → müşteriye sat → upgrade al → yeni tarif aç.

## Capacity

- Toplam gün: 10 (2 hafta, 5 gün/hafta)
- Buffer (%20): 2 gün
- Kullanılabilir: 8 gün

## Velocity Referansı (Sprint 1)

Sprint 1 gerçekleşen: 9 task / oturum. Sprint 2 tahminleri bu baza göre yapıldı.

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S2-01 | Touch/Gesture Input implementasyonu | godot-specialist | 1.0 | Settings ✅ | Circular drag 3x → hamur KNEADING→READY; GUT testleri yeşil |
| S2-02 | Audio Bus/Mixer implementasyonu | godot-specialist | 0.5 | Settings ✅ | Ses slider → AudioServer dB; mute çalışıyor; GUT testleri yeşil |
| S2-03 | Recipe System implementasyonu | godot-specialist | 1.0 | ContentDB ✅ | `RecipeManager.unlock(id)` / `is_unlocked(id)` çalışıyor; GUT testleri yeşil |
| S2-04 | Customer/Order System implementasyonu | godot-specialist | 2.0 | TimeTracking ✅, Economy ✅, AnimationSM ✅ | Sipariş gelir → süre sayar → teslim edilince altın kazanılır; timeout → kayıp; GUT testleri yeşil |
| S2-05 | Upgrade Tree System implementasyonu | godot-specialist | 1.5 | Economy ✅, ContentDB ✅ | Upgrade satın alma → maliyet düşülür → efekt uygulanır; 3^n maliyet formülü doğru; GUT testleri yeşil |

### Should Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S2-06 | SaveLoadManager ↔ OvenManager entegrasyonu | godot-specialist | 0.5 | S1-04 ✅, S1-05 ✅ | Pişirme durumu kaydedilip yükleniyor; offline baking round-trip testi geçiyor |
| S2-07 | Unlock/Condition Resolver implementasyonu | godot-specialist | 1.0 | Recipe ✅ (S2-03), UpgradeTree ✅ (S2-05) | `ConditionResolver.evaluate(condition)` doğru bool döner; GUT testleri yeşil |

### Nice to Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S2-08 ✅ | Employee System implementasyonu | godot-specialist | 1.0 | Economy ✅, TimeTracking ✅ | Çalışan kiralanınca oven efficiency_multiplier güncellenir; GUT testleri yeşil |
| S2-09 ✅ | UI/HUD System iskelet | godot-specialist | 0.5 | Economy ✅ | Gold/Rozet HUD node'ları var; gold_changed sinyalini dinleyip günceller |

---

## Carryover from Sprint 1

| Task | Neden Taşındı | Yeni Tahmin |
|------|---------------|-------------|
| S1-10 → S2-01 | Nice to Have, Sprint 1 zamanı bitti | 1.0 gün (Must Have'e yükseltildi — Touch/Gesture MVP kritik yolu) |

---

## Risks

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| Touch/Gesture circular drag tespiti cihazdan cihaza farklılık gösterebilir | Orta | Yüksek | GUT testlerinde mock InputEvent kullan; fiziksel cihaz testini ayrıca planla |
| Customer/Order zamanlama testleri async → flaky olabilir | Orta | Orta | Sprint 1'deki FAST_BAKE_TIME + ASYNC_WAIT pattern'ını uygula |
| Upgrade Tree 3^n maliyet formülü mid-game'de dengeyi bozabilir | Orta | Yüksek | Sprint 2 sonunda sayısal simülasyon ile ilk 10 upgrade maliyetini doğrula |
| SaveLoadManager placeholder bölümleri (progression, gameplay) şema kayması riski | Düşük | Orta | S2-06'da şemayı netleştir ve sabitle; migration versiyonunu 2'ye çıkar |
| Git push proxy 403 tekrarlanabilir | Yüksek | Düşük | PAT credential store yapılandırıldı; her oturumda otomatik çalışıyor |

---

## External Dependencies

- Godot 4.6 kurulu cihaz test ortamı mevcut değil; Touch/Gesture testleri statik analiz + mock InputEvent ile yapılacak
- GUT v9.3.0+ gerekli (değişiklik yok)

---

## Definition of Done

- [x] S2-01 – S2-05 (Must Have) tamamlandı
- [x] S2-06 SaveLoadManager entegrasyonu tamamlandı
- [x] S2-07 Unlock/Condition Resolver tamamlandı
- [x] Tüm tamamlanan tasklar GDD acceptance criteria ile karşılaştırıldı
- [x] GUT testleri yazıldı; 0 failure
- [x] S1 veya S2 bug yok
- [x] `SaveLoadManager` save_version 2'ye çıkarıldı (OvenManager entegrasyonuyla şema değişti)
- [x] Upgrade Tree 3^n maliyet formülü için sayısal simülasyon belgesi oluşturuldu (`docs/balance/upgrade-tree-cost-simulation.md`)
- [x] Kod commit edildi ve push edildi
