# Customer/Order System GDD

**Sistem:** #11 / 29
**Kategori:** Gameplay — MVP
**Durum:** Draft
**Bağımlılıklar:** Time Tracking, Economy, Animation State Machine
**Provisional Arayüz:** Upgrade Tree (CustomerConfig Resource)

---

## 1. Overview

Ekmek Ustası'nın Customer/Order System'i, oyuncunun fırın vitrininde eş zamanlı olarak max 4 aktif sipariş yönettiği, zaman baskılı bir istek-karşılama döngüsüdür. Dört müşteri tipi (Sabırlı, Acele, VIP, Festival) farklı sabır süreleri ve ödül çarpanlarıyla sahneye girer. Zamanında teslim tam altın, geç teslim %50 altın, teslim edilemeyen sipariş müşteri kaçışı ve memnuniyet cezası üretir. Sistem, Time Tracking üzerinden sabır sayaçlarını yönetir; Economy üzerinden altın öder; Upgrade Tree'den aldığı CustomerConfig Resource ile kapasite, sabır ve spawn parametrelerini günceller.

## 2. Player Fantasy

**Temel his:** "Vitrin dolduğunda fırın yaşıyor." — Sipariş panosunda dört baloncuk birden beklerken oyuncu hangisini önce karşılayacağını seçer; doğru seçim üst üste altın yağdırır, yanlış sıralama müşteri kaybettirir. VIP geldiğinde ekran hafifçe titrer, müzik yükselir — "bu siparişi kaçırma" hissi baskı değil heyecan olarak hissedilir.

**Kaçınılması gereken:** Sipariş baskısının ceza odaklı hissettirmesi. Kaçırılan her müşteri küçük bir hayal kırıklığı olmalı, oyun sonu değil.

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

### Appendix A — CustomerConfig Resource (Provisional)
<!-- TBD — Upgrade Tree arayüzü -->
