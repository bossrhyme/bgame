# Seasonal Events System GDD

**Sistem:** #28 / 29
**Kategori:** Gameplay — Alpha
**Durum:** Designed
**Bağımlılıklar:** Economy System (#4), Time Tracking System (#1), Daily Task System (#19), Recipe System (#10)

---

## 1. Overview

Seasonal Events System, gerçek takvime bağlı sınırlı süreli etkinlikler sunar. Etkinlikler oyunun ana döngüsünü kesmeden oynamayı zenginleştirir: gold kazanım bonusu, sınırlı süreli özel tarif görevleri ve koleksiyon odası rozeti. Türkiye ve global takvime uygun etkinlikler planlanmıştır. Anti-FOMO felsefesi: etkinlik sona erdiğinde oyuncu yalnızca bonus kaybeder, sıradan ilerleme hiçbir zaman kilitlenmez.

## 2. Player Fantasy

**Temel his:** "Ramazan'da fırın kokar mis gibi." — Bayram döneminde fırında simit üretimi double kazanç sağlıyor. Oyuncu gündelik döngüsünü devam ettirirken tatil havası hissediyor.

**İkincil his:** "Özel tarif sezonda geliyor." — Yılda birkaç kez açılan etkinlik tarifleri koleksiyon sayfasına özgün bir rozet ekler. "Ben Ramazan 2026'daydım" hissi.

**Kaçınılması gereken:** FOMO (Fear of Missing Out). Etkinlik ödülleri güzel ama gerekli değil. Geçirilmiş etkinlikler nedeniyle oyunun ana ilerlemesi engellenmez. Etkinlik tarifleri kalıcı koleksiyona eklenirken etkinlik bonusları sadece o süre geçerlidir.

## 3. Detailed Rules

### 3.1 Etkinlik Yapısı

Her etkinlik şu alanlara sahiptir:

| Alan | Tip | Açıklama |
|------|-----|----------|
| `event_id` | StringName | Benzersiz kimlik (örn: `&"ramazan_2026"`) |
| `start_unix` | int | Başlangıç UTC timestamp |
| `end_unix` | int | Bitiş UTC timestamp |
| `gold_bonus_multiplier` | float | Tüm gold kazanımına çarpan (1.0 = bonus yok) |
| `event_tasks` | Array[StringName] | Etkinliğe özel görev şablonları (DailyTaskSystem havuzuna eklenir) |
| `event_recipe_id` | StringName | Bu etkinlikte açılabilir tarif (boş ise yok) |
| `rozet_reward` | int | Tüm etkinlik görevleri tamamlanınca verilen rozet |

### 3.2 Etkinlik Türleri

| ID | Gerçek Etkinlik | Tarih Aralığı | Bonus |
|----|----------------|--------------|-------|
| `ramazan` | Ramazan (değişken) | 29-30 gün | Gold × 1.5; simit görevi × 2 |
| `eid_al_fitr` | Ramazan Bayramı | 3 gün | Gold × 2.0; özel kalıbı tarifi |
| `eid_al_adha` | Kurban Bayramı | 4 gün | Gold × 2.0; çörek tarifi |
| `new_year` | Yeni Yıl | 3 gün (31 Ara – 2 Oca) | Gold × 1.5; galeta görevi |
| `republic_day` | Cumhuriyet Bayramı | 1 gün (29 Eki) | Gold × 1.25; baget tarifi |

### 3.3 Etkinlik Aktifken Davranış

- `economy.earn_gold(amount)` her çağrısından önce `amount × gold_bonus_multiplier` uygulanır.
- Uygulamayı EconomySystem değil EventsSystem yapar: `EventsSystem.apply_gold_bonus(raw_amount) → final_amount`; Economy bu değeri alır.
- Etkinlik görevleri DailyTaskSystem'ın günlük pool'una eklenir; `TASKS_PER_DAY` aşılmaz — etkinlik görevi standart görevin YERINI ALIR (yenisini eklemez).
- Etkinlik tarifleri RecipeManager üzerinden kilit açılır; etkinlik bitince tarif KORUNUR (kalıcı koleksiyon).

### 3.4 Etkinlik Sona Erince

- `gold_bonus_multiplier` kaldırılır.
- Etkinlik görevleri pool'dan çıkar; günlük görev reset'inde normal havuza döner.
- Etkinlik rozeti o gün talep edilmemişse kalıcı olarak kaybolur (kasıtlı FOMO hafifletme: rozet miktarı sembolik tutulur).

### 3.5 Anti-FOMO Kuralları

1. Etkinlik ödülleri (rozet, bonus gold) ana ilerlemeyi UNLEME için kullanılmaz.
2. Etkinlik tarifleri koleksiyona katkı sağlar ama oyun ilerlemesi için zorunlu değildir.
3. Bildirim: Etkinlik başlangıcında `NotificationManager` üzerinden INFO bildirimi gönderilir; baskı yoktur.
4. Etkinlik olmayan dönemde oyuncu etkinlik UI'ı görmez — boşluk hissi yoktur.

## 4. Formulas

### F-1: Bonus Gold Uygulaması

```
final_gold = raw_gold × active_event_multiplier
```

`active_event_multiplier` = aktif etkinliklerin çarpanlarının çarpımı

Birden fazla etkinlik aynı anda aktifse (olası ama nadir):
```
combined_multiplier = product(e.gold_bonus_multiplier for e in active_events)
```

Örnek: Ramazan (×1.5) ve Cumhuriyet Bayramı (×1.25) aynı günde → `1.5 × 1.25 = 1.875×`

### F-2: Etkinlik Aktiflik Kontrolü

```
is_active(event_id) ←
    current_unix >= event.start_unix AND current_unix < event.end_unix
```

UTC timestamp kullanılır; saat dilimi dönüşümü yok.

### F-3: Günlük Görev Havuzu Değiştirme

```
effective_pool = standard_pool + event_tasks - replaced_standard_tasks
```

Etkinlik görevi sayısı: `min(len(event_tasks), TASKS_PER_DAY)`. Etkinlik görevi EASY/MEDIUM/HARD zorluk sınıfında standart görevin yerini alır.

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| İki etkinlik aynı anda aktif | Çarpanlar çarpılır (F-1); görev pool birleşmez — üst limit TASKS_PER_DAY |
| Etkinlik sırasında uygulama kapalı | Offline gold bonus alınmaz (OfflineProductionSystem ayrı hesaplar; etkinlik bonusu offline üretim formulüne eklenmez — kasıtlı) |
| Etkinlik bitiş saatinde uygulama açık | `is_active()` false döner; hemen kaldırılır |
| Etkinlik rozeti 0 kaldıysa | 0 rozet kazanımı EconomySystem'a gönderilmez (no-op) |
| Tarih sunucu/istemci uyuşmazlığı | UTC saati cihazdan alınır; oyun sunucusu yok; clock skew riski düşük |
| Etkinlik haberi yoksa (ContentRegistry'de tanımlı değilse) | push_warning; etkinlik sessizce atlanır |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Economy System (#4)** | `earn_gold()` — bonus öncesi filtreleme; `earn_rozet()` — tamamlama bonusu |
| **Time Tracking System (#1)** | Unix timestamp — `is_active()` kontrolü |
| **Daily Task System (#19)** | Etkinlik görev şablonlarını pool'a ekleme |
| **Recipe System (#10)** | Etkinlik tarifleri `unlock_recipe()` ile açılır |
| **Notification System (#24)** | Etkinlik başlangıç/bitiş bildirimleri (INFO) |

## 7. Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Etki |
|-----------|-----------|----------------|------|
| `gold_bonus_multiplier` (normal) | 1.5 | [1.1, 3.0] | Düşük → değersiz; yüksek → ekonomi dengesi bozulur |
| `gold_bonus_multiplier` (bayram) | 2.0 | [1.5, 4.0] | Kısa özel bayram için daha agresif bonus |
| Etkinlik süresi | etkinliğe göre | [1, 30] gün | Kısa → FOMO artar; uzun → bayat hissedilir |
| `rozet_reward` (tamamlama) | 5–15 | [1, 50] | Sembolik tutulmalı; ana ilerlemeyi etkilememeli |

## 8. Acceptance Criteria

- [ ] `is_active(event_id)` UTC timestamp kontrolü doğru çalışıyor
- [ ] Aktif etkinlikte gold kazanımı F-1 çarpanıyla doğru uygulanıyor
- [ ] İki etkinlik aynı anda aktifse çarpanlar çarpılıyor
- [ ] Etkinlik tarifleri bitince koleksiyonda korunuyor (kalıcı)
- [ ] Etkinlik görevi DailyTaskSystem pool'a eklendi; TASKS_PER_DAY aşılmadı
- [ ] Anti-FOMO: etkinlik rozeti ana unlock'u bloklamıyor
- [ ] Offline üretim etkinlik bonus almıyor (kasıtlı — GDD §Edge Cases)
- [ ] Etkinlik bitiş anında multiplier kaldırıldı
- [ ] NotificationManager: etkinlik başlarken INFO bildirimi gönderildi
- [ ] GUT testleri: F-1 bonus, F-2 aktiflik kontrolü, çoklu etkinlik, edge case tarih sınırı
