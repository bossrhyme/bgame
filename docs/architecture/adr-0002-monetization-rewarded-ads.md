# ADR-0002 — Monetizasyon: Rewarded Ad (IAP Yok)

**Status:** Accepted
**Date:** 2026-04-03
**Deciders:** Proje sahibi

---

## Context

Ekmek Ustası gelir elde etmesi gereken bir mobil oyundur. Monetizasyon modeli
hem gelir üretmeli hem de "zaman yatıranın kazandığı" oyuncu deneyimiyle çelişmemeli.
Oyunun tasarım felsefesi: ne kadar oynayan, o kadar kazanır.

## Problem

Gelir modeli nasıl olmalı?
- Oyuncu ödeme yapmak zorunda kalmamalı
- Agresif reklam oyun deneyimini bozmamalı
- Gelir, oynanış süresine paralel artmalı

## Kısıtlar

- IAP (In-App Purchase) yok — Rozet satışı yok
- Zorla gösterilen reklam yok (interstitial, banner)
- ASMR atmosferi bozulmamalı
- Günde max 5 reklam fırsatı (kullanıcı yorgunluğu eşiği)

## Karar

**Rewarded Ad (Ödüllü Reklam) modeli** — tek gelir kaynağı.

Oyuncu gönüllü olarak reklam izler, somut oyun içi ödül alır:

| Yerleşim | Teklif | Değer |
|----------|--------|-------|
| Offline dönüşü | Üretimi 2x'e çıkar (8→16 saat) | Yüksek — oyuncu zaten heyecanlı |
| Günlük giriş | Günlük bonusu 3x al | Orta — düşük direnç |
| Fırın dolusu | Anında pişir | Orta — bekleme kaçınma |
| VIP müşteri | VIP'i 10 dk uzat | Orta — kaybetmeme psikolojisi |
| Günlük görev | Rozet ödülünü 2x al | Düşük — ek motivasyon |

**Rozet (Premium Para) Kazanma Kaynakları:**
- Günlük görevler tamamlama
- Koleksiyon tamamlama ödülleri
- Sezonsal etkinlik ödülleri
- Rewarded Ad izleme

## Değerlendirilen Alternatifler

| Model | Artı | Eksi | Eleme Gerekçesi |
|-------|------|------|-----------------|
| **Rewarded Ad** ✓ | Kullanıcı dostu, yüksek eCPM, gönüllü | SDK bağımlılığı | — Seçildi |
| IAP (Rozet satışı) | Yüksek gelir/kullanıcı | Pay-to-win riski, tasarım felsefesiyle çelişir | Tasarım kararıyla uyumsuz |
| Interstitial Ad | Kolay entegrasyon | Zorla gösterim, UX bozucu, ASMR atmosferi mahveder | UX kabul edilemez |
| Banner Ad | Sürekli gelir | Görsel kirlilik, düşük eCPM, atmosfer bozucu | Kabul edilemez |
| Ücretli Oyun | Sıfır reklam | Düşük indirme, mobilde zor | Keşfedilebilirlik riski |

## Sonuçlar

**Olumlu:**
- Oyuncu deneyimi korunur — reklam asla zorla değil
- "Oynayan kazanır" felsefesiyle tam uyum
- Rewarded Ad eCPM genellikle banner/interstitial'ın 5-10x üstünde
- Daha uzun oturum → daha fazla reklam fırsatı → daha fazla gelir

**Olumsuz / Riskler:**
- Rewarded Ad SDK entegrasyonu gerekli (AdMob veya ironSource)
- Düşük oynayan kullanıcıdan az gelir
- Reklam envanteri her zaman dolu olmayabilir (fill rate sorunu)

## Teknik Gereksinimler

- Ad Monetization System → Vertical Slice aşamasında entegre edilecek
- Önerilen SDK: Google AdMob (iOS/Android çapraz platform, Godot eklentisi mevcut)
- Günlük reklam limiti: kullanıcı başına max 5 rewarded ad fırsatı göster
- Reklam yoksa (fill rate 0): teklif UI'ı gizle, hata gösterme

## Doğrulama Kriterleri

- [ ] Reklam izledikten sonra ödül doğru şekilde verildi
- [ ] Reklam reddetme / kapatma durumunda ödül verilmedi
- [ ] Günlük 5 reklam limitine ulaşıldığında fırsat UI'ı gizlendi
- [ ] Reklam envanteri boş (fill rate 0) durumunda graceful fallback çalışıyor

## İlgili Kararlar

- ADR-0001: Engine seçimi (Godot — AdMob Godot eklentisi uyumluluğu)
