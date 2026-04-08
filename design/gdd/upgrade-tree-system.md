# Upgrade Tree System GDD

**Sistem:** #12 / 29
**Kategori:** Progression — MVP
**Durum:** Draft
**Bağımlılıklar:** Economy System, Content Database
**Provisional Arayüzleri Netleştirir:** CustomerConfig Resource (Sistem #11)

---

## 1. Overview

Upgrade Tree System, oyuncunun altın ve Unlu Rozet harcayarak fırınını üç kategoride geliştirdiği progression katmanıdır: **Üretim** (pişirme hızı, kapasite, otomasyon), **Müşteri** (sipariş slotu, sabır, VIP oranı) ve **Teslimat** (sipariş kapasitesi, hız). Her upgrade 1–5 seviyeye sahiptir; maliyet `base_cost × 3^(level-1)` formülüyle üstel olarak artar. Tüm upgrade verileri `UpgradeData` Resource olarak Content Database'de tanımlanır; sistem bu verileri okur, satın alma akışını yönetir, efektleri ilgili sistemlere `UpgradeConfig` Resource'ları aracılığıyla iletir ve durumu Save/Load'a kaydeder.

## 2. Player Fantasy
<!-- TBD -->

## 3. Detailed Rules
<!-- TBD -->

## 4. Formulas
<!-- TBD -->

## 5. Edge Cases
<!-- TBD -->

## 6. Dependencies
<!-- TBD -->

## 7. Tuning Knobs
<!-- TBD -->

## 8. Acceptance Criteria
<!-- TBD -->

---

### Appendix A — Upgrade Kataloğu
<!-- TBD -->

### Appendix B — CustomerConfig Bağlantısı (Provisional → Confirmed)
<!-- TBD -->
