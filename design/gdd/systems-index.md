# Ekmek Ustası — Systems Index

**Status:** In Progress
**Created:** 2026-04-03
**Updated:** 2026-04-28 (S5-04)
**Source Concept:** `design/gdd/bread-master-core-design.md`
**Total Systems:** 29
**Designed:** 29 / 29 ✅
**Implemented:** 18 / 29
**Monetization:** Rewarded Ad (IAP yok — zaman yatırımı = kazanım modeli)

---

## Overview

Ekmek Ustası, 29 sistemden oluşan bir mobil idle/clicker hibrit oyundur. Çekirdek döngüyü
(hamur yoğur → pişir → sat → upgrade al) 11 MVP sistemi destekler. Monetizasyon tamamen
Rewarded Ad üzerinden çalışır — oyuncu ne kadar oynasa o kadar reklam fırsatı bulur, ödeme
zorunluluğu yoktur. Döngüsel bağımlılık bulunmamaktadır; sistemler Foundation → Meta
katmanları arasında temiz bir sırayla tasarlanabilir.

---

## Systems Enumeration

| # | Sistem | Kategori | Öncelik | Durum | GDD | Bağımlılıklar |
|---|--------|----------|---------|-------|-----|---------------|
| 1 | Time Tracking System | Core | MVP | Designed | [time-tracking-system.md](time-tracking-system.md) | — |
| 2 | Content Database | Core | MVP | Designed | [content-database.md](content-database.md) | — |
| 3 | Settings & Preferences | Core | MVP | Designed | [settings-preferences.md](settings-preferences.md) | — |
| 4 | Economy System | Economy | MVP | Approved | [economy-system.md](economy-system.md) | Time Tracking |
| 5 | Save/Load System | Persistence | MVP | Approved | [save-load-system.md](save-load-system.md) | Time Tracking, Economy |
| 6 | Animation State Machine | Core | MVP | Approved | [animation-state-machine.md](animation-state-machine.md) | Settings |
| 7 | Audio Bus/Mixer | Audio | MVP | Approved | [audio-bus-mixer.md](audio-bus-mixer.md) | Settings |
| 8 | Touch/Gesture Input | Core | MVP | Approved | [touch-gesture-input.md](touch-gesture-input.md) | Settings |
| 9 | Oven/Baking System | Gameplay | MVP | Approved | [oven-baking-system.md](oven-baking-system.md) | Time Tracking, Economy |
| 10 | Recipe System | Progression | MVP | Designed | [recipe-system.md](recipe-system.md) | Content Database |
| 11 | Customer/Order System | Gameplay | MVP | Designed | [customer-order-system.md](customer-order-system.md) | Time Tracking, Economy, Animation |
| 12 | Upgrade Tree System | Progression | MVP | Designed | [upgrade-tree-system.md](upgrade-tree-system.md) | Economy, Content Database |
| 13 | Employee System | Gameplay | MVP | Designed | [employee-system.md](employee-system.md) | Economy, Time Tracking |
| 14 | Unlock/Condition Resolver | Core | MVP | Designed | [unlock-condition-resolver.md](unlock-condition-resolver.md) | Recipe, Upgrade Tree, Location |
| 15 | UI/HUD System | UI | MVP | Designed | [ui-hud-system.md](ui-hud-system.md) | Economy, Customer/Order, Upgrade Tree |
| 16 | Offline Production System | Gameplay | Vertical Slice | Implemented | [offline-production-system.md](offline-production-system.md) | Time Tracking, Oven/Baking, Employee |
| 17 | Location/Prestige System | Progression | Vertical Slice | Implemented | [location-prestige-system.md](location-prestige-system.md) | Recipe, Upgrade Tree, Oven/Baking |
| 18 | Collection/Dex System | Progression | Vertical Slice | Implemented | [collection-dex-system.md](collection-dex-system.md) | Recipe, Location |
| 19 | Daily Task System | Gameplay | Vertical Slice | Implemented | [daily-task-system.md](daily-task-system.md) | Time Tracking, Economy |
| 20 | Visual Progression System | UI | Vertical Slice | Implemented | [visual-progression-system.md](visual-progression-system.md) | Upgrade Tree |
| 21 | Motivation Hooks System | UI | Vertical Slice | Implemented | [motivation-hooks-system.md](motivation-hooks-system.md) | Economy, Upgrade Tree, Oven/Baking, Daily Task |
| 22 | VFX/Particle System | Core | Vertical Slice | Implemented | [vfx-particle-system.md](vfx-particle-system.md) | Animation State Machine, Economy |
| 23 | Sound & Animation System | Audio | Vertical Slice | Implemented | [sound-animation-system.md](sound-animation-system.md) | Audio Bus/Mixer, Oven/Baking |
| 24 | Notification System | UI | Vertical Slice | Implemented | [notification-system.md](notification-system.md) | Time Tracking, Offline Production |
| 25 | Ad Monetization System | Economy | Vertical Slice | Designed | [ad-monetization-system.md](ad-monetization-system.md) | Economy, Offline Production, Daily Task |
| 26 | Tutorial/Onboarding System | Meta | Vertical Slice | Implemented | [tutorial-onboarding-system.md](tutorial-onboarding-system.md) | Economy, Oven/Baking, Recipe, Customer, Upgrade, UI/HUD, Save/Load |
| 27 | Delivery System | Gameplay | Alpha | Implemented | [delivery-system.md](delivery-system.md) | Economy, Upgrade Tree, Time Tracking |
| 28 | Seasonal Events System | Gameplay | Alpha | Designed | [seasonal-events-system.md](seasonal-events-system.md) | Economy, Time Tracking, Daily Task, Recipe |
| 29 | Performance Monitoring | Meta | Alpha | Implemented | [performance-monitoring.md](performance-monitoring.md) | Tüm sistemler |

---

## Kategori Referansı

| Kategori | Bu Oyundaki Sistemler |
|----------|-----------------------|
| **Core** | Time Tracking, Content Database, Settings, Animation SM, Touch Input, Unlock Resolver, VFX |
| **Gameplay** | Oven/Baking, Customer/Order, Employee, Offline Production, Daily Task, Delivery, Seasonal Events |
| **Progression** | Recipe, Upgrade Tree, Location/Prestige, Collection/Dex |
| **Economy** | Economy System, Ad Monetization |
| **Persistence** | Save/Load System |
| **UI** | UI/HUD, Visual Progression, Motivation Hooks, Notification |
| **Audio** | Audio Bus/Mixer, Sound & Animation |
| **Meta** | Tutorial/Onboarding, Performance Monitoring |

---

## Bağımlılık Haritası (Katmanlar)

### Foundation — Bağımlılık yok (önce tasarla)
```
Time Tracking System
Content Database
Settings & Preferences
```

### Core — Foundation'a bağımlı
```
Economy System          ← Time Tracking
Save/Load System        ← Time Tracking, Economy
Animation State Machine ← Settings
Audio Bus/Mixer         ← Settings
Touch/Gesture Input     ← Settings
```

### Gameplay — Core'a bağımlı
```
Oven/Baking System          ← Time Tracking, Economy
Recipe System               ← Content Database
Customer/Order System       ← Time Tracking, Economy, Animation SM
Upgrade Tree System         ← Economy, Content Database
Employee System             ← Economy, Time Tracking
Unlock/Condition Resolver   ← Recipe, Upgrade Tree, Location (zayıf bağ)
```

### UI/HUD — Gameplay'e bağımlı
```
UI/HUD System               ← Economy, Customer/Order, Upgrade Tree
```

### Feature — Gameplay + UI'a bağımlı
```
Offline Production System   ← Time Tracking, Oven/Baking, Employee
Location/Prestige System    ← Recipe, Upgrade Tree, Oven/Baking
Collection/Dex System       ← Recipe, Location
Daily Task System           ← Time Tracking, Economy
Visual Progression System   ← Upgrade Tree
```

### Presentation — Feature'a bağımlı
```
Motivation Hooks System     ← UI/HUD, Progression sistemleri
VFX/Particle System         ← Animation SM, Economy
Sound & Animation System    ← Audio Bus/Mixer, Oven/Baking
Notification System         ← Time Tracking, Offline Production
Ad Monetization System      ← Economy, UI/HUD
```

### Meta — Tümüne bağımlı
```
Tutorial/Onboarding System  ← Tüm MVP sistemleri
Delivery System             ← Upgrade Tree
Seasonal Events System      ← Customer/Order, Time Tracking
Performance Monitoring      ← Tüm sistemler
```

### Döngüsel Bağımlılıklar
**Yok.** Bağımlılık grafiği döngüsüzdür (acyclic). Temiz tasarım sırası mümkün.

---

## Öncelik Seviyeleri

### MVP — Çalışan 2 dakikalık oturum hedefi (11 sistem)
> Bu 11 sistem tasarlanmadan ve implemente edilmeden prototip test edilemez.

| Sıra | Sistem | Neden MVP |
|------|--------|-----------|
| 1 | Time Tracking System | Her zaman bazlı mekaniğin temeli |
| 2 | Content Database | Tarif/upgrade tanımları data-driven olmalı |
| 3 | Settings & Preferences | Ses/animasyon kontrolü temel kalite |
| 4 | Economy System | Altın akışı olmadan hiçbir şey çalışmaz |
| 5 | Save/Load System | Kalıcılık olmadan playtest edilemez |
| 6 | Touch/Gesture Input | Circular drag — ASMR hissi buradan gelir |
| 7 | Oven/Baking System | Çekirdek üretim döngüsü |
| 8 | Recipe System | Ne üretileceğini tanımlar |
| 9 | Customer/Order System | Gelir akışı ve "satış" tatmini |
| 10 | Upgrade Tree System | İlerleme hissi için şart |
| 11 | UI/HUD System | Sayılar görünmeden oynamak mümkün değil |

### Vertical Slice — Tam polislenmiş 20 dakikalık oturum (14 sistem)
Offline Production, Location (2 şehir), Collection, Daily Task, Visual Progression,
Motivation Hooks, VFX, Sound & Animation, Notification, **Ad Monetization**, Tutorial,
Unlock/Condition Resolver, Employee System, Animation State Machine

### Alpha — Tam mekanik kapsam (3 sistem)
Delivery System, Seasonal Events System, Performance Monitoring

---

## Önerilen Tasarım Sırası

| Sıra | Sistem | Tier | Tahmini Efor |
|------|--------|------|--------------|
| 1 | Time Tracking System | MVP | S |
| 2 | Content Database | MVP | M |
| 3 | Settings & Preferences | MVP | S |
| 4 | Economy System | MVP | M |
| 5 | Save/Load System | MVP | M |
| 6 | Animation State Machine | MVP | M |
| 7 | Audio Bus/Mixer | MVP | M |
| 8 | Touch/Gesture Input | MVP | M |
| 9 | Oven/Baking System | MVP | M |
| 10 | Recipe System | MVP | M |
| 11 | Customer/Order System | MVP | M |
| 12 | Upgrade Tree System | MVP | M |
| 13 | Employee System | MVP | M |
| 14 | Unlock/Condition Resolver | MVP | S |
| 15 | UI/HUD System | MVP | M |
| 16 | Offline Production System | VS | M |
| 17 | Location/Prestige System | VS | M |
| 18 | Collection/Dex System | VS | M |
| 19 | Daily Task System | VS | M |
| 20 | Visual Progression System | VS | S |
| 21 | Motivation Hooks System | VS | M |
| 22 | VFX/Particle System | VS | M |
| 23 | Sound & Animation System | VS | M |
| 24 | Notification System | VS | M |
| 25 | Ad Monetization System | VS | M |
| 26 | Tutorial/Onboarding System | VS | L |
| 27 | Delivery System | Alpha | S |
| 28 | Seasonal Events System | Alpha | M |
| 29 | Performance Monitoring | Alpha | S |

> **Efor Ölçeği:** S = Küçük (1-2 oturum), M = Orta (2-4 oturum), L = Büyük (4+ oturum)

---

## Yüksek Riskli Sistemler

| Sistem | Risk | Erken Aksiyon |
|--------|------|---------------|
| **Touch/Gesture Input** | Circular drag tespiti mobilde cihazdan cihaza farklılık gösterebilir | MVP başında telefonda prototip test et |
| **Offline Production System** | Cap dengesi: çok kısa → baskı, çok uzun → geri dönme motivasyonu azalır | 6h / 8h / 12h seçeneklerini alpha'da A/B test et |
| **Upgrade Cost Curve (3^n)** | İlerleme çok hızlı veya çok yavaş hissettirirse tüm ekonomi bozulur | Erken playtest ile efor/ödül döngüsünü doğrula |
| **Location/Prestige System** | 6 aktif lokasyon → bellek ve FPS bütçesi aşılabilir | Lokasyon geçişini prototipte profil et, min-spec cihazda test et |
| **Employee Automation Scaling** | Çalışanlar çok güçlenirse aktif tıklama anlamsızlaşır | Aktif/pasif gelir oranını playtestte ölç |

---

## İlerleme Takibi

| Tier | Toplam | Tasarlandı | Implemente Edildi |
|------|--------|-----------|-------------------|
| MVP | 15 | 15 ✅ | 15 ✅ |
| Vertical Slice | 11 | 11 ✅ | 10 |
| Alpha | 3 | 3 ✅ | 2 |
| **Toplam** | **29** | **29 ✅** | **27** |

**Sprint 3 (2026-05-08 – 2026-05-21) ilerleme:**
- S3-01 Offline Production System ✅ (impl + GUT)
- S3-02 Daily Task System ✅ (impl + GUT)
- S3-03 Notification System ✅ (impl + GUT)
- S3-04 Visual Progression System ✅ (impl + GUT)
- S3-05 VFX/Particle System ✅ (impl + GUT)
- S3-06 Location/Prestige System ✅ (GDD tasarım)
- S3-07 Sound & Animation System ✅ (impl iskeleti)
- S3-08 Systems Index güncelleme ✅

**Sprint 4 (2026-05-22 – 2026-06-04) ilerleme:**
- S4-01 Location/Prestige System ✅ (impl + GUT, 32 test)
- S4-02 Collection/Dex System ✅ (GDD + impl + GUT, 22 test)
- S4-03 Motivation Hooks System ✅ (GDD + impl + GUT, 12 test)
- S4-04 Ad Monetization System ✅ (GDD tasarım)
- S4-05 Tutorial/Onboarding System ✅ (GDD tasarım)
- S4-06 Delivery System ✅ (GDD tasarım)

**Sprint 5 (2026-06-05 – 2026-06-18) ilerleme:**
- S5-01 Tutorial/Onboarding System ✅ (impl + 28 GUT testi)
- S5-02 Delivery System ✅ (impl + 30 GUT testi)
- S5-03 Seasonal Events System ✅ (GDD tasarım)
- S5-04 Performance Monitoring ✅ (GDD + iskelet impl)

> **Not:** GDD yazımı `/design-system [sistem-adı]` komutuyla başlatılır.
> Her sistem tasarlandığında bu tablodaki durum güncellenir.

---

## Sonraki Adımlar (Sprint 6+)

- [ ] Ad Monetization System iskelet impl (SDK bağımsız stub)
- [ ] Seasonal Events System impl
- [ ] Ad Monetization System impl (AdMob SDK entegrasyonu)
- [ ] Playtest: ekonomi dengesi, lokasyon koşulları, upgrade curve
- [ ] Performance Monitoring: gerçek cihaz profili (min-spec Android)
