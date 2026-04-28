# Notification System GDD

**Sistem:** #24 / 29
**Kategori:** UI — Vertical Slice
**Durum:** Designed
**Bağımlılıklar:** UI/HUD System (#15), Employee System (#13), Daily Task System (#19), Customer/Order System (#11)

---

## 1. Overview

Notification System, oyun olaylarını oyuncuya toast mesajı olarak iletir. Dört öncelik seviyesi vardır: HIGH (grev uyarısı), MEDIUM (memnuniyet düşüşü), LOW (yeni tarif), INFO (genel bilgi). Aynı anda yalnızca bir toast gösterilir; geri kalanlar öncelik sıralamalı kuyrukta bekler. Yüksek öncelikli yeni mesaj geldiğinde kuyruğun başına eklenir. Tüm notification mantığı `NotificationManager` sınıfında tutulur; görsel sunum HUDManager üzerinden yapılır.

## 2. Player Fantasy

**Temel his:** "Önemli bir şey oluyor." — Grev uyarısı kırmızı banner ile ekranda belirir, oyuncu durumu hemen anlar. Tarif açılması ise yeşil toast ile gelir: "Yeni tarif: Simit!" Görsel dil önceliği iletir — renk, animasyon, ses.

**İkincil his:** Gürültüsüz bilgilendirme. INFO mesajları 3 saniye görünür kaybolur; oyuncu fark etmeyebilir ama bir şey kaçırmaz. HIGH mesajlar ise kapatılana kadar kalmaz — tam okunur önce kaybolur, oyunu bloke etmez.

**Kaçınılması gereken:** Toast yağmuru. Aynı saniye içinde 5 bildirim gelirse kullanıcıyı bunaltır. Aynı tipteki bildirimler 5 saniye içinde tekrar gösterilmez (deduplication).

## 3. Detailed Rules

### Öncelik Sıralaması

| Öncelik | Renk (öneri) | Kaynak olaylar |
|---------|-------------|----------------|
| HIGH | Kırmızı | `EmployeeManager.strike_started` |
| MEDIUM | Turuncu | `CustomerOrderSystem.satisfaction_changed` (≤ 3) |
| LOW | Yeşil | `DailyTaskSystem.task_completed`, yeni tarif açıldı |
| INFO | Beyaz/gri | Genel bilgi, günlük bonus |

### Kuyruk Davranışı

- Mevcut toast gösterilirken gelen yeni mesaj kuyruğa eklenir
- HIGH mesaj her zaman kuyruğun başına geçer (diğer HIGH'ların arkasına)
- INFO mesaj kuyruğun sonuna eklenir
- Deduplication: aynı mesaj 5 saniye içinde tekrar gösterilmez

### Toast Yaşam Döngüsü (GDD UI/HUD §4'ten alındı)

```
slide_in: 0.2s → visible: 3.0s → fade_out: 0.3s → sonraki toast
```

### Otomatik Sinyal Bağlantısı

`_ready()` içinde ilgili autoload sinyallerine bağlanır. Bağlanılamayan sistemler (null) yoksayılır, uyarı basılır.

## 4. Formulas

Notification sistem matematiksel formül içermez.

### Deduplication penceresi

```
can_show = (current_time - last_shown_time[message]) >= DEDUP_WINDOW_SEC
```

`DEDUP_WINDOW_SEC = 5.0`

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Kuyruk 10'dan fazla mesaj içerirse | En eski INFO/LOW mesajlar silinir; HIGH/MEDIUM korunur |
| Grev sırasında ikinci grev sinyali gelirse | Deduplication ile yoksayılır (5s pencere) |
| Boş mesaj string'i | push_warning + yoksayılır; gösterilmez |
| Toast gösterilirken SceneTree yok | push_warning; timer oluşturulamaz; toast_active false'a resetlenir |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **UI/HUD System (#15)** | `HUDManager.show_notification()` toast'ı görüntüler |
| **Employee System (#13)** | `strike_started` → HIGH bildirim |
| **Daily Task System (#19)** | `task_completed` → LOW bildirim; `all_tasks_completed` → INFO bonus |
| **Customer/Order System (#11)** | `satisfaction_changed` (≤3) → MEDIUM bildirim |

## 7. Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Etki |
|-----------|-----------|----------------|------|
| `TOAST_VISIBLE_SEC` | 3.0 | [1.5, 6.0] | Kısa → hızlı kayboluyor; uzun → ekranı kaplıyor |
| `DEDUP_WINDOW_SEC` | 5.0 | [3.0, 30.0] | Kısa → tekrar mesaj çok; uzun → acil durum mesajı gecikmeli |
| `MAX_QUEUE_SIZE` | 10 | [5, 20] | Küçük → eski mesajlar erken silinir |

## 8. Acceptance Criteria

- [ ] HIGH mesaj MEDIUM/LOW/INFO mesajların önüne geçiyor
- [ ] Aynı mesaj 5 saniye içinde tekrar gösterilmiyor (deduplication)
- [ ] `strike_started` → HIGH toast otomatik üretiliyor
- [ ] `satisfaction_changed(2)` → MEDIUM toast otomatik üretiliyor
- [ ] `task_completed` → LOW toast otomatik üretiliyor
- [ ] Kuyruk 10'u aşınca eski INFO/LOW silinir, HIGH/MEDIUM korunur
- [ ] GUT testleri: öncelik sıralaması, deduplication, sinyal bağlantısı
