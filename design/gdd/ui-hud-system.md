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
