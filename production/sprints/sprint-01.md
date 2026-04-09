# Sprint 1 — 2026-04-09 to 2026-04-23

## Sprint Goal

Core sistemleri implemente ederek oynanabilir fırın döngüsünün temelini oluştur:
hamur yoğur → fırına at → hasat et → altın kazan.

## Capacity

- Toplam gün: 10 (2 hafta, 5 gün/hafta)
- Buffer (%20): 2 gün
- Kullanılabilir: 8 gün

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S1-01 | Time Tracking System implementasyonu | godot-specialist | 0.5 | — | GDD #1 acceptance criteria geçiyor; GUT testleri yeşil |
| S1-02 | Content Registry + ilk RecipeData .tres dosyaları | godot-specialist | 1.0 | S1-01 | `ContentRegistry.get_recipe("white_bread")` doğru değer döner |
| S1-03 | Economy System implementasyonu | godot-specialist | 1.0 | S1-01 | Altın/Rozet ekleme, düşme, bakiye sorgulama GUT testleri geçiyor |
| S1-04 | Save/Load System implementasyonu | godot-specialist | 1.5 | S1-01, S1-03 | Kayıt/yükleme round-trip testi geçiyor; bozuk kayıt güvenli degrade ediyor |
| S1-05 | Oven/Baking System implementasyonu | godot-specialist | 2.0 | S1-01, S1-02, S1-03 | Hamur → pişirme → hasat döngüsü çalışıyor; timer tabanlı (_process yok) |

### Should Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S1-06 | Settings & Preferences implementasyonu | godot-specialist | 0.5 | — | Ses/müzik/titreşim ayarları kaydedilip yükleniyor |
| S1-07 | Economy GUT test suite | godot-gdscript-specialist | 0.5 | S1-03 | Min %80 coverage; tüm formüller test edilmiş |
| S1-08 | Baking GUT test suite | godot-gdscript-specialist | 0.5 | S1-05 | Pişirme süresi, kapasite, offline hesabı testleri yeşil |

### Nice to Have

| ID | Task | Agent/Owner | Est. Gün | Bağımlılıklar | Acceptance Criteria |
|----|------|-------------|----------|---------------|---------------------|
| S1-09 | Animation State Machine iskelet implementasyonu | godot-specialist | 0.5 | — | State geçişleri sinyal tabanlı çalışıyor |
| S1-10 | Touch/Gesture Input implementasyonu | godot-specialist | 0.5 | — | gesture-test prototipi mantığı src/ altına taşındı |

## Carryover from Previous Sprint

Önceki sprint yok — bu ilk sprint.

## Risks

| Risk | Olasılık | Etki | Önlem |
|------|----------|------|-------|
| Save/Load şema değişirse mevcut kayıtlar bozulabilir | Orta | Yüksek | Versiyon numarası ekle; migration utility planla |
| Godot 4.6 API farkları (bilgi kesim tarihi Ağustos 2025) | Orta | Orta | `docs/engine-reference/godot/` dokümanlarını çapraz kontrol et |
| Content Database yükleme süresi beklenenden uzun olursa | Düşük | Orta | Lazy loading fallback planla |

## External Dependencies

- Godot 4.6 kurulu cihaz test ortamı mevcut değil; testler statik analiz ile yapılacak
- GUT v9.3.0+ gerekli (teknik tercihler belgesi)

## Definition of Done

- [ ] S1-01 – S1-05 (Must Have) tamamlandı
- [ ] Tüm tamamlanan tasklar GDD acceptance criteria ile karşılaştırıldı
- [ ] GUT testleri yazıldı ve geçiyor (Should Have dahil)
- [ ] S1 veya S2 bug yok
- [ ] Kod `src/` altında doğru dizin yapısında
- [ ] GDD'den sapma varsa ilgili dokümana not eklendi
