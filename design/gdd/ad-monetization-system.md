# Ad Monetization System GDD

**Sistem:** #25 / 29
**Kategori:** Monetization — Vertical Slice
**Durum:** Designed
**Bağımlılıklar:** Economy System (#4), Offline Production System (#7), Daily Task System (#19), Notification System (#24)

---

## 1. Overview

Ad Monetization System, oyuncunun gönüllü olarak rewarded reklam izlemesi karşılığında somut oyun içi ödüller almasını sağlar. Sistem Google AdMob SDK üzerinde çalışır; hiçbir reklam zorla gösterilmez. Beş yerleşim noktası (placement) tanımlıdır: offline dönüşü 2×, günlük giriş 3×, anında pişirme, VIP uzatma ve rozet ödülü 2×. Her yerleşim bağımsız cooldown ve günlük kota yönetir; reklam envanteri dolmadığında (fill rate = 0) teklif UI'ı gizlenir, oyuncu akışı engellenmez.

## 2. Player Fantasy

**Temel his:** "Ödüllendirici seçim" — Oyuncu offline dönerken "8 saatlik üretimini 16 saate çıkarmak ister misin?" sorusuyla karşılaşır. Reklam izlemek kendi kararı; izlemezse oyun normale devam eder. Reklam izleme cezası yoktur, ödülü önemsiz değildir.

**İkincil his:** "Fırsat penceresi" — VIP müşteri uzatma veya anında pişirme teklifleri anlık karar gerektiren mikro-anlar yaratır. Oyuncu "şu an değer" diye karar verir.

**Kaçınılması gereken:** Reklam yorgunluğu. Günlük kota ve cooldown mekanizmaları oyuncuya aşırı teklif sunulmasını engeller. Reklam yoksa buton kaybolur — hiçbir hata mesajı gösterilmez.

## 3. Detailed Rules

### 3.1 Yerleşim Noktaları (Placement)

| ID | Tetikleyici | Teklif | Ödül |
|----|------------|--------|------|
| `offline_boost` | Offline dönüş ekranı açıldığında | Üretimi 2× yap | Offline süresi 8h → 16h |
| `daily_bonus` | Günlük giriş bonusu talep edilirken | 3× al | Bonus × 3 |
| `instant_bake` | Fırın pişirme tamamlandığında | Anında pişir | Kalan süre = 0 |
| `vip_extend` | VIP müşteri geldiğinde | 10 dk uzat | VIP penceresi +10 dk |
| `task_double` | Günlük görev ödülü talep edilirken | Rozeti 2× al | Rozet ödülü × 2 |

### 3.2 Cooldown Kuralları

- Her yerleşimin kendi cooldown sayacı vardır.
- Aynı yerleşimde iki reklam arası minimum `PLACEMENT_COOLDOWN_SEC` = 300 saniye (5 dakika).
- Cooldown aktifken o yerleşimin teklif UI elemanı gizlenir (disabled değil, gizlenir).

### 3.3 Günlük Kota

- `DAILY_AD_LIMIT` = 10 — kullanıcı başına günde max izlenebilecek reklam sayısı.
- Günlük kota dolduğunda TÜM yerleşim teklifleri gizlenir.
- Kota gün değişiminde (midnight UTC) sıfırlanır.

### 3.4 Fill Rate = 0 Davranışı

- AdMob SDK `ad_failed_to_load` çağrısı yaptığında o yerleşim UI'ı gizlenir.
- Oyuncuya hata mesajı gösterilmez.
- Diğer yerleşimler etkilenmez — her yerleşim bağımsız yüklenir.

### 3.5 Ödül Güvenliği

- Ödül yalnızca `ad_rewarded` callback'i geldiğinde verilir.
- `ad_closed` (reklam kapatıldı ama ödül gelmedi) → ödül verilmez.
- Ödül verme `EconomySystem` ve `DailyTaskSystem` public API'larına delege edilir; AdMonetizationSystem asla gold/rozet değerini doğrudan yazmaz.

### 3.6 Rozet (Premium Para) Entegrasyonu

- `task_double` yerleşimi rozeti 2× verir: `economy.earn_rozet(base_reward)`
- Rozet kazanımları Economy System üzerinden geçer; kayıt audit trail'inde izlenir.

## 4. Formulas

### F-1: Offline Boost

```
boosted_offline_gold = offline_gold × OFFLINE_BOOST_MULTIPLIER
```

`OFFLINE_BOOST_MULTIPLIER = 2.0` (güvenli aralık: [1.5, 3.0])

Uygulama: OfflineProductionSystem hesapladıktan sonra AdMonetizationSystem
`apply_offline_boost()` çağrısıyla gold'u 2× günceller. OfflineProductionSystem
zaten hesaplamış olan değeri TEKRAR hesaplamaz; çarpma Economy.earn_gold() üzerinden yapılır.

### F-2: Daily Bonus Boost

```
final_bonus_gold = daily_login_bonus × DAILY_BONUS_MULTIPLIER
```

`DAILY_BONUS_MULTIPLIER = 3.0` (güvenli aralık: [2.0, 5.0])

### F-3: Task Reward Double

```
final_rozet = base_task_reward_rozet × TASK_REWARD_MULTIPLIER
```

`TASK_REWARD_MULTIPLIER = 2.0` (sabit; rozet hassas para birimi)

### F-4: Günlük Kota Kontrolü

```
can_show(placement_id) ←
    daily_ads_watched < DAILY_AD_LIMIT
    AND (current_time - last_ad_time[placement_id]) >= PLACEMENT_COOLDOWN_SEC
    AND ad_available[placement_id] == true
```

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Reklam yüklenemedi (fill rate 0) | Teklif buton gizlenir, oyun normale devam |
| Reklam izlendi ama callback gelmedi (network kopması) | Ödül verilmez; UI'ı normale döndür |
| Günlük kota doldu | Tüm teklif UI'ları gizlenir, günün sonuna kadar görünmez |
| Cooldown aktif | Sadece o yerleşim gizlenir, diğerleri etkilenmez |
| Oyuncu reklamı kapatır (skip/close) ödül kazanmadan | `ad_closed` gelir, ödül verilmez |
| `offline_boost` çift çağrılırsa | İdempotency: zaten boost uygulandıysa ikinci çağrı no-op |
| VIP müşteri ayrıldıktan sonra `vip_extend` tetiklenirse | Extend teklifi yalnızca VIP aktifken gösterilir |
| DailyTaskSystem null | `task_double` teklifi gizlenir; push_warning |
| Economy null | Ödül verilmez; push_error; callback başarı=false döner |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Economy System (#4)** | `earn_gold()`, `earn_rozet()` — ödül uygulama |
| **Offline Production System (#7)** | `get_pending_offline_gold()` — offline boost hesabı |
| **Daily Task System (#19)** | `claim_reward()` üzerine rozet 2× uygulama |
| **Notification System (#24)** | Ödül bildirimi (INFO öncelik) |
| **AdMob SDK** | `load_rewarded_ad()`, `show_rewarded_ad()`, callback sinyalleri |

## 7. Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Etki |
|-----------|-----------|----------------|------|
| `DAILY_AD_LIMIT` | 10 | [3, 20] | Düşük → az gelir; yüksek → kullanıcı yorgunluğu |
| `PLACEMENT_COOLDOWN_SEC` | 300 | [60, 900] | Düşük → aynı yerleşim spam; yüksek → az fırsat |
| `OFFLINE_BOOST_MULTIPLIER` | 2.0 | [1.5, 3.0] | Yüksek → offline ekonomi dengesi bozulur |
| `DAILY_BONUS_MULTIPLIER` | 3.0 | [2.0, 5.0] | Günlük giriş değeri |
| `TASK_REWARD_MULTIPLIER` | 2.0 | sabit | Rozet hassas — değiştirme |

## 8. Acceptance Criteria

- [ ] Reklam izlendikten sonra (`ad_rewarded`) ödül doğru şekilde verildi
- [ ] Reklam kapatıldığında (`ad_closed`, ödülsüz) ödül verilmedi
- [ ] Günlük 10 reklam limitine ulaşıldığında tüm teklif UI'ları gizlendi
- [ ] Fill rate = 0 durumunda graceful fallback: buton gizlendi, hata mesajı yok
- [ ] Cooldown aktifken aynı yerleşim tekrar teklif etmedi
- [ ] `offline_boost`: OfflineProductionSystem'den gelen gold × 2 doğru uygulandı
- [ ] `task_double`: rozet ödülü × 2 doğru uygulandı
- [ ] Reklam yerleşimleri bağımsız — bir yerleşimin fill hatası diğerlerini etkilemedi
- [ ] Ödül verme Economy/DailyTask public API'larından geçti, doğrudan yazma yok
- [ ] GUT testleri: F-1 offline boost, F-3 task double, günlük kota, cooldown, null guard
