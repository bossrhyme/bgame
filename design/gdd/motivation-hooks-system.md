# Motivation Hooks System GDD

**Sistem:** #21 / 29
**Kategori:** UI — Vertical Slice
**Durum:** Designed
**Bağımlılıklar:** Economy System (#4), Upgrade Tree System (#12), Oven/Baking System (#5), Daily Task System (#19), Notification System (#24)

---

## 1. Overview

Motivation Hooks System, oyuncunun oyuna geri dönmesi ve ilerlemeye devam etmesi için ince görsel ve bildirim tetikleyicileri üretir. Üç kanca sağlar: (1) "N altın daha" — en ucuz upgrade'e ne kadar kaldığını gösterir; (2) "Vitrin dolmak üzere" — fırın kapasitesi %80'i geçince hasat hatırlatması; (3) Oturum boşta kalma kancası iskelet yapısı — 20 dakika etkileşim yoksa sinyal yayar.

## 2. Player Fantasy

**Temel his:** "Az kaldı!" — Altın sayacı 40 altın daha gelince upgrade'e ulaşacağını gösteriyor. Oyuncu birkaç ekstra satış yapıp upgrade alıyor. Bu döngü oyuncuyu yerinde tutar.

**İkincil his:** "Hasat zamanı!" — Fırında yer kalmak üzere uyarısı oyuncuyu belirli aralıklarla aktif kılar. Pasif gelir beklemek yerine doğru anda hasat yapma motivasyonu.

**Kaçınılması gereken:** Spam. Aynı kanca aynı oturumda 3'ten fazla kez tetiklenmez. Bildirimler NotificationManager üzerinden geçer, deduplication koruması aktif.

## 3. Detailed Rules

### Kanca 1: Yakın Upgrade (near_upgrade)

- Economy.gold_changed her tetiklendiğinde kontrol edilir.
- UpgradeTree'deki tüm upgrade'ler taranır; en düşük maliyetli maxlenmemiş upgrade bulunur.
- `(next_cost - current_gold) <= NEAR_UPGRADE_THRESHOLD` ise sinyal yayılır.
- Bildirim: LOW öncelik (spam olmaması için LOW seçildi).

### Kanca 2: Vitrin/Fırın Kapasitesi (oven_nearly_full)

- OvenManager.bake_started her tetiklendiğinde kontrol edilir.
- `used_slots / total_slots >= OVEN_FULL_RATIO` ise sinyal yayılır.
- Bildirim: LOW öncelik.

### Kanca 3: Günlük Görev Yakın Tamamlanma (daily_task_near_completion)

- DailyTaskSystem.task_completed her tetiklendiğinde kontrol edilir.
- Kalan tamamlanmamış görev sayısı = 1 ise sinyal yayılır.
- Bildirim: INFO öncelik.

### Kanca 4: Oturum Boşta Kalma (session_idle) — İskelet

- `IDLE_TIMEOUT_SEC` (varsayılan 1200s = 20 dakika) aşılınca `session_idle` sinyali yayılır.
- S4'te yalnızca sinyal iskelet; gerçek platform push notification S5'e ertelendi.
- SceneTreeTimer ile ölçülür (ADR-0003 uyumu); her altın kazanımda sıfırlanır.

## 4. Formulas

### F-1: Yakın Upgrade Eşiği

```
near_upgrade ← (cheapest_non_maxed_cost - current_gold) <= NEAR_UPGRADE_THRESHOLD
```

`NEAR_UPGRADE_THRESHOLD = 50` (güvenli aralık: [10, 200])

### F-2: Fırın Doluluk Oranı

```
oven_nearly_full ← (busy_slots / active_slots) >= OVEN_FULL_RATIO
```

`OVEN_FULL_RATIO = 0.8` (güvenli aralık: [0.5, 1.0])

### F-3: Boşta Kalma Süresi

```
idle_trigger ← session_elapsed_without_gold_change >= IDLE_TIMEOUT_SEC
```

`IDLE_TIMEOUT_SEC = 1200.0` (güvenli aralık: [300, 3600])

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Tüm upgrade'ler maxlenirse | near_upgrade asla tetiklenmez |
| UpgradeTree null ise | push_warning; kanca devre dışı |
| Fırın slot sayısı 0 ise | Bölme sıfırı önlenir; oven_nearly_full tetiklenmez |
| DailyTaskSystem null ise | push_warning; kanca devre dışı |
| NotificationManager null ise | Sinyal yayılır ama bildirim gönderilmez |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Economy System (#4)** | `gold_changed` sinyali — near_upgrade kontrolü |
| **Upgrade Tree System (#12)** | `get_next_cost()` — en ucuz upgrade hesabı |
| **Oven/Baking System (#5)** | `bake_started` sinyali — oven doluluk kontrolü |
| **Daily Task System (#19)** | `task_completed` sinyali — görev yakın tamamlama |
| **Notification System (#24)** | `queue_notification()` — oyuncuya bildirim gönderme |

## 7. Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Etki |
|-----------|-----------|----------------|------|
| `NEAR_UPGRADE_THRESHOLD` | 50 | [10, 200] | Düşük → çok az bildirim; yüksek → sürekli bildirim |
| `OVEN_FULL_RATIO` | 0.8 | [0.5, 1.0] | Düşük → çok erken uyarı |
| `IDLE_TIMEOUT_SEC` | 1200.0 | [300, 3600] | Platform push push bildirim penceresi |

## 8. Acceptance Criteria

- [ ] Gold, upgrade maliyetine 50 altın kaldığında `near_upgrade` sinyali yayılıyor
- [ ] Tüm upgrade'ler maxlenince `near_upgrade` tetiklenmiyor
- [ ] Fırın slotları %80 dolduğunda `oven_nearly_full` sinyali yayılıyor
- [ ] Son görev tamamlanınca (kalan=1) `daily_task_near_completion` yayılıyor
- [ ] `session_idle` sinyali (iskelet) tanımlı; GUT testinde elle tetiklenebiliyor
- [ ] NotificationManager bağlantısı: near_upgrade → LOW, oven_nearly_full → LOW
- [ ] GUT testleri: eşik hesabı, null guard, sinyal yayımı
