# UI/HUD System GDD

**Sistem:** #15 / 29
**Kategori:** UI — MVP
**Durum:** Draft
**Bağımlılıklar:** Economy System, Customer/Order System, Upgrade Tree System

---

## 1. Overview

UI/HUD System, oyuncunun tüm oyun durumunu tek bakışta okuyabildiği ekran katmanını yönetir. Dört ana bileşen vardır: **Kaynak Çubuğu** (altın ve Rozet bakiyesi), **Sipariş Panosu** (max 4 aktif sipariş kartı, sabır sayaçları), **Hızlı Erişim Menüsü** (upgrade, çalışan, tarif koleksiyonu butonları) ve **Bildirim Katmanı** (yeni tarif açıldı, grev uyarısı, memnuniyet düşüşü). Tüm UI Godot `CanvasLayer` üzerinde çalışır; max 4 CanvasLayer kuralına uyulur. Oyun verisine doğrudan erişmez — Economy, Customer/Order ve Upgrade Tree sistemlerinden sinyal alır.

## 2. Player Fantasy

**Temel his:** "Her şey gözümün önünde." — Altın sayacı tıklarken artar, sipariş kartlarındaki sabır çubukları yavaşça azalır, VIP gelince kart parlayarak öne çıkar. Oyuncu ekrana bakmak zorunda hissetmez ama baktığında her şey orada, net ve okunabilir.

**İkincil his:** Temizlik. Mobil ekranda gereksiz hiçbir element yoktur — 4 sipariş kartı, bakiye, 3 buton. Fazlası dikkat dağıtır.

**Kaçınılması gereken:** Bilgi kirliliği. HUD, oyunun önüne geçmemelidir; fırın animasyonları ve müşteri hareketleri görünür kalmalıdır.

## 3. Detailed Rules

### CanvasLayer Mimarisi

| Katman | CanvasLayer | İçerik |
|--------|------------|--------|
| HUD | 1 | Kaynak çubuğu, sipariş panosu, hızlı erişim menüsü |
| VFX | 2 | Para animasyonu, unlock efektleri |
| Notification | 3 | Toast mesajları, uyarı banner'ları |
| Debug | 4 | Yalnızca geliştirme modunda görünür |

### Kaynak Çubuğu

- Sol üst köşe: Altın ikonu + animasyonlu sayaç
- Sağ üst köşe: Rozet ikonu + sayaç
- Değer değiştiğinde sayaç 0.3 sn'de animasyonlu artar/azalır

### Sipariş Panosu

- Alt bölge: 4 kart yatay dizilir
- Her kart: tarif ikonu, müşteri tipi göstergesi, sabır progress bar
- VIP kartı: altın çerçeve + hafif titreşim efekti
- Boş slot: soluk "+" ikonu

### Hızlı Erişim Menüsü

- Sağ kenar: dikey 3 buton (Upgrade, Çalışan, Koleksiyon)
- Buton üzerinde badge: okunmamış bildirim sayısı

### Bildirim Katmanı

- Toast: ekran üstünden kayar, 3 sn görünür, otomatik kaybolur
- Öncelik sırası: grev uyarısı > yeni tarif > memnuniyet düşüşü > genel bilgi

## 4. Formulas

UI sistemi matematiksel formül içermez. Animasyon parametreleri:

### Sayaç Animasyonu

```
# Altın/Rozet değeri değiştiğinde:
display_value → target_value (0.3 sn, ease_out)
```

### Sabır Progress Bar

```
fill_ratio = remaining_patience / total_patience
# Grace süresinde fill_ratio kırmızıya döner (threshold: 0.0)
```

### Toast Yaşam Döngüsü

```
slide_in: 0.2 sn → görünür: 3.0 sn → fade_out: 0.3 sn
```

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| 4 sipariş kartı doluyken yeni sipariş gelirse | 5. kart oluşturulmaz; pano max 4 kartla sabit kalır |
| Aynı anda birden fazla toast tetiklenirse | Kuyruk sistemi: öncelik sırasına göre birer birer gösterilir |
| Altın hızla artıp azalırsa (çoklu işlem) | Sayaç animasyonu son hedef değere atlar; aradaki değerleri atlar |
| VIP ve normal sipariş aynı anda gelirse | VIP kartı soldan ilk konuma yerleşir; diğerleri sağa kayar |
| Bildirim katmanı çok sayıda toast biriktirirse | Max 3 toast kuyruğu; fazlası düşürülür, log'a yazılır |
| Oyun arka plana alınıp dönüldüğünde sabır barları güncellenirse | Geri dönüşte tüm kartlar Time Tracking'den alınan gerçek değerle yeniden çizilir |
| Rozet sayacı 0'ın altına düşmeye çalışırsa | Economy engeller; UI 0 gösterir, negatife düşmez |

## 6. Dependencies
<!-- TBD -->

## 7. Tuning Knobs
<!-- TBD -->

## 8. Acceptance Criteria
<!-- TBD -->
