# Sprint 3 — 2026-05-08 to 2026-05-21

## Sprint Goal

Vertical Slice aşamasını başlat: Offline Production ve Daily Task sistemleriyle oyuncuyu
geri getiren çekici döngüyü kur; Notification ve Visual Progression ile MVP döngüsünü
görsel/etkileşimsel olarak tamamla.

## Capacity

- Toplam gün: 10 (2 hafta, 5 gün/hafta)
- Buffer (%20): 2 gün
- Kullanılabilir: 8 gün

## Velocity Referansı

| Sprint | Planlanan | Tamamlanan | Oran |
|--------|-----------|------------|------|
| Sprint 1 | 10 task | 9 task | %90 |
| Sprint 2 | 9 task | 9 task | %100 |
| **Sprint 3 Hedef** | **9 task** | — | — |

---

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S3-01 | Offline Production System — GDD + impl | godot-specialist | 2.0 | OvenManager ✅, TimeManager ✅, EmployeeManager ✅ | `apply_offline()` offline süreyi 8h cap ile fırına uygular; Employee efektleri dahil; unix manipülasyon koruması çalışıyor; GUT testleri yeşil |
| S3-02 | Daily Task System — GDD + impl | godot-specialist | 1.0 | TimeManager ✅, Economy ✅ | Günlük 3 görev üretiliyor; tamamlanınca ödül economy'ye yansıyor; TimeManager.get_elapsed_days() ile sıfırlama; GUT testleri yeşil |
| S3-03 | Notification System — GDD + impl | godot-specialist | 0.5 | HUDManager ✅ (S2-09) | In-app toast: grev uyarısı, yeni tarif, memnuniyet düşüşü; öncelik sıralama çalışıyor; GUT testleri yeşil |

### Should Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S3-04 | Visual Progression System — GDD + impl | godot-specialist | 1.0 | UpgradeTree ✅ | Upgrade seviyesi değişince sinyal yayılıyor; downstream sistemler sinyale bağlanıp görsel güncelleme yapabiliyor; GUT testleri yeşil |
| S3-05 | VFX/Particle System — GDD + impl | godot-specialist | 1.0 | Economy ✅, AnimationManager ✅ | Coin kazanma VFX tetikliyor; unlock efekti patikli; battery_saver aktifken VFX devre dışı; GUT testleri yeşil |
| S3-06 | Location/Prestige System — GDD tasarımı (impl yok) | godot-specialist | 1.5 | Recipe ✅, UpgradeTree ✅ | 8 bölümlü GDD tamamlandı; lokasyon geçiş formülü, prestij sıfırlama kuralları, 2. şehir açma koşulları tanımlandı |

### Nice to Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S3-07 | Sound & Animation System — GDD + impl iskeleti | godot-specialist | 0.5 | AudioManager ✅, AnimationManager ✅ | Gameplay event'leri (bread_baked, customer_served) AudioManager.play_sfx() çağrısına bağlandı |
| S3-08 | Systems Index güncelleme (MVP tamamlanma yansıması) | godot-specialist | 0.5 | Tüm S2 task'ları ✅ | systems-index.md'de MVP 15/15 implement olarak işaretlendi; Vertical Slice ilerleme takibi güncellendi |

---

## Carryover from Sprint 2

Yok. Sprint 2 tüm task'larla (%100) kapandı.

---

## Risks

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| Offline Production offline cap dengesi (8h) yanlış hissettirirse | Orta | Yüksek | GDD'de 6h/8h/12h varyantlarını belgele; sprint içi playtest simülasyonu ekle |
| VFX GPU particle limit — mobil mid-range | Orta | Orta | GPUParticles2D yerine CPUParticles2D ile başla; profil sonrası geçiş kararı ver |
| Location GDD tasarımı prestige loop dengesini bozabilir | Orta | Yüksek | GDD taslağı tamamlanır tamamlanmaz /design-review ile incelemeye gönder; uygulamaya geçme |
| Daily Task üretim algoritması tekrar içerik üretirse | Düşük | Orta | Task havuzu min 15 entry; seed bazlı shuffle; son 3 günün görevlerini hariç tut |
| Git push proxy 403 tekrarlanabilir | Yüksek | Düşük | PAT her oturumda hazır tutulacak; push başarısızlıkta 4× backoff |

---

## External Dependencies

- Godot 4.6 GPUParticles2D mobile davranışı belgelenmemiş — CPUParticles2D ile başla, gerçek cihaz testini S3 sonrası planla
- Location/Prestige prestige loop için playtest verisi gerekecek — S3'te GDD yazılır, S4'te impl

---

## Definition of Done

- [ ] S3-01 – S3-03 (Must Have) tamamlandı
- [ ] Tüm tamamlanan task'lar GDD acceptance criteria ile karşılaştırıldı
- [ ] GUT testleri yazıldı; 0 failure
- [ ] ADR-0003 ihlali yok (offline hesap `_process()` dışında yapılıyor)
- [ ] Offline Production 8h senaryosu GUT testi geçiyor
- [ ] Location/Prestige GDD 8 bölümü tamamlandı ve `/design-review` onayından geçti
- [ ] systems-index.md MVP completion yansıtılıyor
- [ ] Kod commit edildi ve push edildi
