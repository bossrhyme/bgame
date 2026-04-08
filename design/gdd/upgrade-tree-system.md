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

**Temel his:** "Bir sonraki upgrade'e 340 altın kaldı." — Sayaç gözünün önünde tıkıyor, fırından para akıyor, hedef yaklaşıyor. Upgrade satın alındığında fırın görsel olarak değişir: fırın kapısı yeni bir renk alır, vitrin genişler, yeni bir raf belirir. Oyuncu "büyüttüm" hissini somut görür.

**İkincil his:** Seçim tatmini. Upgrade menüsünü açtığında üç yol var — daha hızlı üretim mi, daha fazla müşteri mi, teslimat mı? Her seçim farklı bir stratejiyi destekler; yanlış seçim yok, ama akıllı seçim var.

**Kaçınılması gereken:** "Hangi upgrade daha iyi?" belirsizliği. Her upgrade'in etkisi satın alma öncesi açıkça gösterilmeli.

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
