# Daily Task System GDD

**Sistem:** #19 / 29
**Kategori:** Gameplay — Vertical Slice
**Durum:** Designed
**Bağımlılıklar:** Time Tracking System (#1), Economy System (#4), Save/Load System (#5)

---

## 1. Overview

Daily Task System, her gün yenilenen 3 görev üretir. Görevler RecordProgress API'si üzerinden tamamlanır; tamamlanan görevler altın veya Rozet ödülü verir. Günlük sıfırlama SaveLoadManager açılış akışında `check_daily_reset(elapsed_days)` çağrısıyla gerçekleşir; uygulama açık değilken geçen günler de işlenir. Görev üretimi gün sayısından türetilen deterministik bir seed ile yapılır — aynı güne bakan iki cihaz aynı görevleri görür. Görev havuzu minimum 15 şablon içerir; son 3 günün görevleri hariç tutularak tekrar önlenir.

## 2. Player Fantasy

**Temel his:** "Bugün ne yapmalıyım?" — Sabah uygulamayı açan oyuncu üç net hedef görür: "150 ekmek sat", "3 sipariş tamamla", "500 altın harca". Bunlar kılavuz gibi davranır: hedefsiz tıklamak yerine strateji kurulur. Günlük bonusu toplayıp kapamak küçük ama tatmin edici bir döngü yaratır.

**İkincil his:** Tamamlama tatmini. Üç görevin üçü de tamamlandıktan sonra "Tüm görevler tamamlandı!" ekranı ile günlük bonus verilir. Görev çubuğu %100'e ulaşınca parlayan animasyon bu his için kritik.

**Kaçınılması gereken:** Zorla geri getirme baskısı. Görevleri tamamlamak zorunlu değil; sıfırlanmış görevler için pişmanlık hissi yaratılmamalıdır. Tamamlanmamış görevler silinir, ceza yoktur.

## 3. Detailed Rules

### Görev Akışı

1. Uygulama açılır → `check_daily_reset(elapsed_days)` çağrılır
2. `elapsed_days >= 1` ise görevler yenilenir; tamamlanmamışlar silinir, ödüller kaybolur
3. Oyuncu görev ilerlemesini `record_progress(type, amount)` ile günceller
4. Görev hedefine ulaşılınca `task_completed` sinyali yayılır; ödül claim edilebilir
5. 3/3 tamamlanınca `all_tasks_completed` sinyali yayılır; günlük bonus economy'ye eklenir

### Görev Tipleri

| Tip | Açıklama | Varsayılan Hedef |
|-----|----------|-----------------|
| `SELL_BREAD` | X ekmek sat | 50 / 100 / 200 |
| `BAKE_COMPLETE` | X pişirme döngüsü tamamla | 5 / 10 / 20 |
| `SERVE_CUSTOMER` | X müşteriyi zamanında teslim et | 3 / 5 / 10 |
| `EARN_GOLD` | X altın kazan | 200 / 500 / 1000 |
| `SPEND_GOLD` | X altın harca (upgrade veya çalışan) | 150 / 300 / 600 |

### Günlük Sıfırlama

- `elapsed_days >= 1` → görevler yenilenir
- `elapsed_days >= 2` → birden fazla gün geçmiş; görevler yine de yenilenir, atlanan günler için tamamlanmamış görevler kaybolur (ceza yoktur)
- Sıfırlama sonrası `last_reset_unix` güncellenir

### Deterministik Üretim

```
day_number  = unix_timestamp / 86400  (tam gün sayısı)
task_seed   = day_number % 1_000_000  (taşma koruması)
```

Seed ile görev havuzundan 3 benzersiz şablon seçilir. Son 3 günün şablonları havuzdan geçici olarak çıkarılır. Şablon havuzu minimum 15 entry içerdiğinde hiçbir zaman 3'ten az seçenek kalmaz.

### Ödül Talebi

- Tamamlanan görevin ödülü `claim_reward(task_id)` ile alınır
- İki kez claim edilemez (`reward_claimed` flag'i)
- Gün sıfırlanmadan önce claim edilmezse ödül kaybolur

## 4. Formulas

### Günlük Bonus (F-1)

```
daily_bonus_gold = sum(task.reward_gold for completed task) × 1.5
```

Tüm 3 görev tamamlandıktan sonra `all_tasks_completed` sinyaliyle ödülün %50 fazlası Economy'ye eklenir.

### Görev Hedef Ölçeği (F-2)

```
target = base_target × difficulty_multiplier[tier]
```

| Zorluk | Çarpan | Ödül (altın) |
|--------|--------|-------------|
| EASY | 1.0 | 50 |
| MEDIUM | 2.0 | 100 |
| HARD | 4.0 | 200 |

Her gün 1 EASY + 1 MEDIUM + 1 HARD görev üretilir.

### Örnek Hesap

Bugünün görevi: SELL_BREAD/HARD (hedef = 200 × 1.0 = 200, ödül = 200 altın)  
Tüm görevler tamamlanırsa: `(50 + 100 + 200) × 1.5 = 525 altın` bonus.

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Uygulama 3 gün açılmaz | `elapsed_days = 3`; yeni görevler üretilir; tamamlanmamış eskiler kaybolur, ceza yok |
| Görev havuzu 15'ten az entry | push_warning; seed modülasyonu yine de çalışır; tekrar olabilir |
| `record_progress` görev tamamlandıktan sonra çağrılır | İlerleme sınırda tutulur; `task_completed` tekrar yayılmaz |
| Aynı gün `claim_reward` iki kez çağrılır | `reward_claimed = true` kontrolü; Economy'den ikinci ödeme yapılmaz |
| Görev yokken `claim_reward(id)` çağrılır | push_warning + false döner; çökme yok |
| Economy null iken ödül claim edilirse | push_error; görev tamamlandı işaretlenir, ödül verilmez |
| Günlük bonus `all_tasks_completed` emit edilirken Economy null | push_error; sinyal yayılır ama bonus eklenmez |

## 6. Dependencies

| Sistem | Kullanım | Yön |
|--------|----------|-----|
| **Time Tracking System (#1)** | `get_elapsed_days(last_reset_unix)` → sıfırlama kontrolü | Bu sistem → TimeManager |
| **Economy System (#4)** | `earn_gold()` / `earn_rozet()` → ödül ödemesi | Bu sistem → Economy |
| **Save/Load System (#5)** | Mevcut görevler, ilerleme ve `last_reset_unix` kaydedilir | SaveLoadManager ↔ Bu sistem |

**Ters bağımlılıklar:**
- Time Tracking System GDD §6'ya not: "Daily Task System sıfırlama için get_elapsed_days() kullanır"
- Economy System GDD §6'ya not: "Daily Task System görev ödülleri için earn_gold() çağırır"

## 7. Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Etki |
|-----------|-----------|----------------|------|
| `TASKS_PER_DAY` | 3 | [2, 5] | Düşük → kolay tüketim; yüksek → yorucu |
| `DAILY_BONUS_MULTIPLIER` | 1.5 | [1.0, 3.0] | Düşük → tamamlama teşviki azalır; yüksek → zorunlu hissettirir |
| `easy_reward` | 50 altın | [20, 100] | Erken oyun altın dengesi |
| `medium_reward` | 100 altın | [50, 200] | |
| `hard_reward` | 200 altın | [100, 500] | |
| `history_exclusion_days` | 3 | [1, 7] | Yüksek → tekrar azalır; çok yüksek → havuz tükenir |

## 8. Acceptance Criteria

- [ ] Her gün deterministik olarak 3 görev (1E+1M+1H) üretiliyor
- [ ] `record_progress(type, amount)` doğru göreve ilerleme ekliyor
- [ ] Hedef aşılınca `task_completed` sinyali yayılıyor; aşırı progress hedefte sabitleniyor
- [ ] `claim_reward(id)` Economy'ye ödülü ekliyor; ikinci çağrı no-op
- [ ] 3/3 tamamlanınca `all_tasks_completed` + %50 bonus Economy'ye ekleniyor
- [ ] `elapsed_days >= 1` → görevler yenileniyor; tamamlanmamışlar siliniyor
- [ ] GUT testleri: üretim deterministizmi, ilerleme, claim, günlük sıfırlama, bonus hesabı
