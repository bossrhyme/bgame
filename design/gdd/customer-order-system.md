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

### Sipariş Altın Hesabı

```
base_gold = recipe.base_price × customer.reward_multiplier
final_gold = base_gold × delivery_modifier × satisfaction_bonus
```

| Değişken | Açıklama |
|----------|----------|
| `delivery_modifier` | Zamanında: 1.0 / Grace süresi: 0.5 |
| `satisfaction_bonus` | memnuniyet 8-10 → 1.1x, 5-7 → 1.0x, 1-4 → 0.9x |

### Spawn Aralığı

```
spawn_interval = base_spawn_interval × spawn_speed_modifier
spawn_speed_modifier = 1.0  (memnuniyet > 5)
spawn_speed_modifier = 1.25 (memnuniyet ≤ 5)  ← yavaşlama
spawn_speed_modifier = ∞    (memnuniyet = 0)  ← durdurulmuş
```

### Sabır Sayacı

```
remaining_patience = (customer.patience_base × patience_multiplier) - elapsed_time
```

`patience_multiplier` → CustomerConfig Resource'dan gelir (Upgrade Tree provisional arayüzü)

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Oyun arka plana alınır, sabır sayacı devam eder mi? | Evet — Time Tracking üzerinden gerçek geçen süre hesaplanır; geri dönüşte sipariş zaten dolmuş olabilir |
| Oyuncu geri döndüğünde grace süresi dolmuş sipariş | Müşteri anında kaçmış sayılır, memnuniyet cezası uygulanır |
| Aynı anda 4 slot dolu, VIP gelirse | VIP spawn edilmez; slot açılınca normal spawn havuzuna girer (VIP önceliği yoktur) |
| Festival müşterisi etkinlik sona ererken sahne değişirse | Mevcut Festival siparişi tamamlanabilir, yeni Festival müşterisi spawn edilmez |
| Memnuniyet 0'dan negatife düşemez | Floor = 0, tavan = 10 |
| Aynı tarif için birden fazla aktif sipariş | İzin verilir — oyuncu stok yönetimi yapmalı |
| Vitrin stoğu yok ama sipariş var | Sipariş panosunda "stok yok" göstergesi çıkar; sabır sayacı durmaz |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Time Tracking System** (#1) | Sabır sayacı ve grace süresi için `Time.get_unix_time_from_system()` |
| **Economy System** (#4) | `final_gold` hesabı ve altın ödeme işlemi |
| **Animation State Machine** (#6) | Müşteri gelişi, bekleme, kaçış ve memnuniyet animasyonları |
| **Content Database** (#2) | Tarif `base_price` değerlerinin okunması |
| **Upgrade Tree System** (#12) *(provisional)* | `CustomerConfig` Resource üzerinden `patience_multiplier`, `max_active_orders`, `vip_spawn_rate`, `repeat_customer_gold_bonus` |
| **Seasonal Events System** (#28) | Festival müşteri tipi aktif/pasif durumu |

## 7. Tuning Knobs
<!-- TBD -->

## 8. Acceptance Criteria
<!-- TBD -->

---

### Appendix A — CustomerConfig Resource (Provisional)
<!-- TBD — Upgrade Tree arayüzü -->
