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

### Sipariş Panosu

- Ekranda aynı anda max **4 aktif sipariş** görünür (`max_active_orders = 4`)
- 4 slot doluyken yeni müşteri gelmez; slot açılınca spawn tetiklenir

### Müşteri Tipleri

| Tip | Sabır Süresi | Ödül Çarpanı | Spawn Ağırlığı |
|-----|-------------|-------------|----------------|
| Sabırlı | 5 dak. | 1.0x | 60% |
| Acele | 90 sn | 1.5x | 25% |
| VIP | 3 dak. | 3.0x | 5% |
| Festival | 10 dak. | 2.0x (toplu) | Yalnızca etkinlik günü |

### Teslim Sonuçları

- Sabır süresi dolmadan teslim → **tam altın**
- Sabır süresi dolmuş, sipariş hâlâ teslim edilmemişse **10 sn grace süresi** başlar → bu sürede teslim edilirse **%50 altın**
- Grace süresi de geçerse → müşteri kaçar, **memnuniyet −1** (max 10, min 0)

### Müşteri Memnuniyeti

- Başlangıç: 10/10
- Her kaçan müşteri: −1
- Her 5 başarılı teslim: +1 (max 10'a kadar)
- Memnuniyet ≤ 5 → spawn hızı %20 yavaşlar
- Memnuniyet = 0 → yeni müşteri gelmez (fırın "kötü ünlü" durumu)

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
