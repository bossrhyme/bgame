# Bahçe Rüyası (Garden Dream) — Çekirdek Tasarım Belgesi

**Kategori:** Idle / Rahatlatıcı Simülasyon
**Platform:** Mobil (iOS & Android)
**Kontrol:** Tek el, dokunmatik
**Hedef Kitle:** Hay Day, Merge Garden, Cozy Grove, Vita Mahjong kitlesi

---

## 1. OYUN MEKANİĞİ

### Temel Döngü (Core Loop)

```
Tohum Ek → Sula → Büyümesini İzle → Hasat Et → Sat / Dekor → Yeni Alan Aç → Nadir Bitki Keşfet
```

**Mekanik Modeli: Hibrit Idle**
- **Kısa oturum (2 dk):** Zamanlanmış bitkiler hasat, yeni tohum, sat
- **Uzun oturum (20 dk):** Dekorasyon yerleşimi, ziyaretçi yönetimi, nadir bitki arama, mevsim hazırlığı

---

### Dakika Bazında Oturum

| Süre | Aktivite |
|------|----------|
| 0:00 | Bahçeyi aç, hazır hasatları gör (sarı parlama) |
| 0:30 | Hasat tap — meyve/sebze "fırlar" havaya |
| 1:00 | Yeni tohum ek (sürükle tarha bırak) |
| 1:30 | Sula (tap veya otomatik aktifse atla) |
| 2:00 | Ziyaretçi siparişini karşıla, altın topla |
| 3:00 | Kısa oturum biter — bitkiler büyümeye devam |
| 8:00+ | Uzun oturum: dekorasyon, nadir bitki araştırma, mevsim hazırlığı |

---

### Dokunma Mekaniği

| Eylem | Gesture | Animasyon | Ses |
|-------|---------|-----------|-----|
| Tohum ekmek | Sürükle tarha bırak | Tohum toprağa "gömülür" | Kuru toprak sesi |
| Sulama | Tap (sulama kabı ikon) | Su damlacıkları yayılır | Şarıl şarıl su sesi |
| Hasat | Tek tap olgun bitki | Meyve "fırlar" + renk patlaması | Yumuşak "pop!" |
| Dekorasyon | Uzun basış + sürükle | Obje yerleşir, titreşir | Klik sesi |
| Ziyaretçi | Tap (konuşma balonu) | Ziyaretçi sevinir, ödeme animasyonu | "Mmm!" + kasa |

**Önemli:** Hasat anı mümkün olan en tatmin edici animasyon olmalı — renk patlaması, küçük konfeti, "pop!" sesi.

---

### Bitki Yetiştirme Aşamaları

```
Tohum → Filiz (küçük) → Genç Bitki → Olgun → Hasat Hazır (parlar)
```

| Aşama | Görsel | Süre (temel) | Akselerasyonlar |
|-------|--------|--------------|-----------------|
| Tohum | Küçük tümsek | Anlık | — |
| Filiz | İnce yeşil dal | 30 dk | Gübre: 2x hız |
| Genç Bitki | Yapraklar belirdi | 1 saat | Premium sulama: 1.5x |
| Olgun | Tam boy | 2 saat | Sera: 2x hız |
| Hasat Hazır | Altın parlama + dans | — | — |

**Büyüme hızlandırıcılar:**
- Gübre: Tohum takviyesi (+50% büyüme hızı)
- Yağmur (mevsimsel): Tüm bitkiler otomatik sulanır
- Sera: Mevsimden bağımsız, 2x büyüme
- Arı kovanı: Komşu bitkiler +25% hız

---

### Mevsim Döngüsü

Her mevsim 7 gerçek gün sürer (veya 30 oyun günü — ayarlanabilir).

| Mevsim | Özel Bitkiler | Oyun Etkisi | Atmosfer |
|--------|--------------|-------------|----------|
| **İlkbahar** | Lale, çilek, bezelye | +20% tüm büyüme, yağmur sık | Açık yeşil, kiraz çiçeği |
| **Yaz** | Domates, ayçiçeği, karpuz | Sulama 2x gerekli, +50% satış fiyatı | Parlak, gölgeli ağaçlar |
| **Sonbahar** | Kabak, elma, üzüm | Hasat bonusu +30%, yaprak dökümü | Turuncu-kızıl, sıcak |
| **Kış** | Çam, nane, kış gülü | Büyüme -30% (sera hariç), kar | Beyaz, mavi-gri |

**Mevsim özel ziyaretçileri:**
- İlkbahar: Arı yetiştiricisi → arı kovanı hediye
- Yaz: Tur grubu → toplu sipariş (10 farklı ürün)
- Sonbahar: Hasat festivali → ödüllü yarışma
- Kış: Pazar ziyaretçisi → nadir tohum takas

---

### Ziyaretçi / Müşteri Sistemi

| Ziyaretçi | Talep | Ödül | Sıklık |
|-----------|-------|------|--------|
| Komşu | 1-2 ürün, düşük miktar | 50-200 altın | Çok sık |
| Aşçı | Tarife özel 3-5 ürün | 300-800 altın | Sık |
| Botanik Meraklısı | Nadir bitki görmek ister | 500 altın + tohum | Nadir |
| Festival Alıcısı | Büyük toplu sipariş | 2.000+ altın | Mevsimlik |
| Arkeolog Botanist | Efsanevi bitki | 5.000 altın + koleksiyon | Çok nadir |

---

### Offline Büyüme

- Bitkiler gerçek zamanda büyür — oyun kapalıyken de
- Max offline büyüme: **8 saat** (premium ile 16 saat)
- Geri dönüşte: "X saat boyunca bahçen büyüdü!" + altın konfeti
- Sulanmamış bitkiler büyümez — geri dönme motivasyonu

---

## 2. ÇEVRE TASARIMI

### Bahçe Bölgeleri

Her bölge ayrı tema, ayrı bitki seti, ayrı dekorasyon stili:

| Bölge | Tema | Özel Bitkiler | Açılış Koşulu |
|-------|------|---------------|---------------|
| **Sebze Tarhı** | Klasik mutfak bahçesi | Domates, havuç, biber | Başlangıç |
| **Çiçek Bahçesi** | Renkli, romantik | Lale, gül, lavanta | 50 hasat |
| **Meyve Bahçesi** | Gölgeli, sakin | Elma, kiraz, limon | Sev. 5 |
| **Mini Gölet** | Su, kurbağalar | Nilüfer, su nanesi | Sev. 8 |
| **Sera** | Cam, tropikal | Orkide, ananas, muz | Sev. 12 |
| **Kelebek Bahçesi** | Hafif, büyülü | Yasemin, nane, papatya | Sev. 18 |
| **Meyve Ormanı** | Serin, gölgeli | Dut, incir, fındık | Sev. 25 |
| **Gizli Bahçe** | Mistik, eski | Efsanevi bitkiler | Koleksiyon %80 |

---

### Görsel Dil

**Ana Atmosfer:** "Büyükannenin taze bahçesi" — sıcak, organik, huzurlu

| Mevsim | Renk Paleti | Işık | Partikül |
|--------|-------------|------|---------|
| İlkbahar | Taze yeşil, pembe, bej | Altın sabah ışığı | Çiçek yaprakları |
| Yaz | Canlı yeşil, sarı, turuncu | Parlak öğle güneşi | Uçan böcekler |
| Sonbahar | Turuncu, kızıl, kahverengi | Sıcak günbatımı | Dökülen yapraklar |
| Kış | Beyaz, buz mavisi, gri | Yumuşak bulutlu | Kar taneleri |

**Kamera:** Hafif izometrik / üstten bakış. Bahçe büyüdükçe zoom-out seçeneği.

---

### Animasyon Rehberi

**Büyüme Animasyonu (En Önemli):**
- Her aşama geçişinde küçük "pop" ve renk parlaması
- Hasat hazır olunca bitki yavaşça sallanır (çağrıyor!)
- Hasat tap'ında meyve/çiçek havaya fırlar, konfeti

**Çevre Animasyonları:**
| Öğe | Animasyon |
|-----|-----------|
| Rüzgar | Tüm yapraklar ve çiçekler senkron sallanır |
| Arılar | Çiçekler arasında zigzag uçuş |
| Kelebekler | Kanat çırpma + rastgele uçuş yolu |
| Gölet | Su yüzeyi dalgalanması, balık atlayışı |
| Yağmur | Damlacıklar bitkiye çarpar, sıçrar |
| Kar | Yavaş süzülme, birikim animasyonu |

---

### Ses Tasarımı

**Ambient Katmanlar (sürekli, mevsime göre):**

| Mevsim | Ambient |
|--------|---------|
| İlkbahar | Kuş cıvıltısı, hafif rüzgar, uzak çan |
| Yaz | Cırcır böceği, arı vızıltısı, yaprak hışırtısı |
| Sonbahar | Yaprak çıtırtısı, uzak ördek sesi, rüzgar |
| Kış | Derin sessizlik, uzak kar fırtınası, ateş |

**Eylem Sesleri:**
| Eylem | Ses |
|-------|-----|
| Tohum ekmek | Kuru toprak + küçük "tık" |
| Sulama | Şarıl şarıl + damlama |
| Büyüme pop | Yumuşak "boing!" |
| Hasat | "Pop!" + konfeti sesi |
| Ziyaretçi para | Bozuk para şıkırtısı |
| Dekorasyon yerleşim | Tatmin edici "klik" |

**Müzik:** Akustik gitar + hafif piyano, 60-75 BPM. Mevsime göre ton değişir (ilkbahar neşeli, kış sakin).

---

## 3. GELİŞTİRME SİSTEMİ

### Para Birimleri

- **Altın:** Günlük harcama — sulama sistemi, gübre, dekorasyon
- **Tohum Puanı:** Premium — nadir tohum, özel dekorasyon, bölge açma hızlandırma

---

### Sulama Sistemi Upgrade Ağacı

| Seviye | Sistem | Kapasite | Otomasyon | Maliyet |
|--------|--------|----------|-----------|---------|
| 1 | El kabı | 3 bitki/tap | Manuel | Başlangıç |
| 2 | Kova | 6 bitki/tap | Manuel | 200 altın |
| 3 | Hortum | 12 bitki/tap | Yarı-oto | 800 altın |
| 4 | Sprinkler | Bölge bazlı | Otomatik | 3.000 altın |
| 5 | Drip sistemi | Tüm bahçe | Tam oto + sensörlü | 12.000 altın |

---

### Gübre / Toprak Upgrade

| Gübre | Etki | Maliyet |
|-------|------|---------|
| Organik gübre | +25% büyüme hızı | 50 altın/kullanım |
| Kompost | +50% büyüme hızı | 150 altın/kullanım |
| Mineral takviye | +75% hız + +30% değer | 500 altın/kullanım |
| Sihirli toprak | 2x hız + nadir bitki şansı | 50 Tohum Puanı |

---

### Bahçe Bölgesi Upgrade

Her bölgenin içinde de upgrade var:

| Bölge | Upgrade | Etki | Maliyet |
|-------|---------|------|---------|
| Sebze Tarhı | Tarh genişliği | +2 slot her sev. | 300 / 900 / 2.5k |
| Çiçek Bahçesi | Çiçek çeşidi | Yeni türler açılır | 500 / 1.5k / 4k |
| Meyve Bahçesi | Ağaç büyüklüğü | +50% hasat miktarı | 1k / 3k / 8k |
| Gölet | Su temizliği | Nadir su bitkileri | 2k / 6k |
| Sera | Sıcaklık kontrolü | Tüm mevsimlerde çalışır | 5k / 15k |

---

### Koleksiyon Sistemi: Bitki Ansiklopedisi

**120 bitki**, 8 kategoride:

| Kategori | Örnek Bitkiler | Adet | Tamamlama Ödülü |
|----------|----------------|------|-----------------|
| Sebzeler | Domates, havuç, pırasa, enginar | 20 | Aşçı ziyaretçi bonusu |
| Çiçekler | Lale, orkide, kamelya, yaban gülü | 25 | Kelebek bahçesi teması |
| Meyveler | Elma, kiraz, dut, kivi | 18 | Meyve ormanı açılır |
| Su Bitkileri | Nilüfer, su nanesi, zambak | 10 | Gölet genişlemesi |
| Tropikal | Muz, ananas, mango, papaya | 12 | Sera özel ışıklandırma |
| Aromatik | Lavanta, nane, biberiye | 10 | Arı kovanı bonusu |
| Nadir | Gece çiçeği, buz çiçeği, ateş lalesi | 15 | Gizli bahçe açılır |
| Efsanevi | Ölümsüz gül, gökkuşağı menekşe | 10 | "Bahçe Efsanesi" unvanı |

---

### Ekonomi Dengesi

**Erken Oyun (Sev. 1-10):**
```
Domates satışı: 20 altın/adet
Günlük hasat: 30 adet = 600 altın
Sulama maliyeti: 50 altın
Net birikim: 550 altın/gün
Ziyaretçi ek gelir: 200-500 altın
```

**Orta Oyun (Sev. 15-30):**
```
Nadir çiçek: 200 altın/adet
3 bölge aktif: 8.000-15.000 altın/gün
Mevsim bonusu: +30-50%
Festival geliri: 5.000 altın/mevsim
```

**Geç Oyun (Sev. 35+):**
```
Efsanevi bitki: 2.000-10.000 altın/adet
Tüm bölgeler: 80.000-200.000 altın/gün
Tohum Puanı üretimi: 10-30/gün
```

---

### Görsel Progression (Bahçenin Dönüşümü)

| Aşama | Durum | Görsel |
|-------|-------|--------|
| Başlangıç | 3 küçük tarh, çıplak toprak | Gri-kahverengi, ot yok |
| Sev. 5 | Sebze + çiçek tarhı | Yeşillik, küçük renkler |
| Sev. 15 | 4 bölge, gölet | Hareketli, renkli, böcekler |
| Sev. 30 | Sera + kelebek bahçesi | Zengin, katmanlı, büyülü |
| Sev. 50 | Tüm bölgeler, gizli bahçe | Nefes kesici, efsanevi atmosfer |

---

### Motivasyon Kancaları

Her an "bir sonraki şey" görünür:

1. **Büyüme zamanlayıcı** — "Domatesler 45 dakika sonra hazır" bildirimi
2. **Yeni bölge kilitli** — Haritada sisin arkasında sera: "12. seviyede açılır"
3. **Koleksiyon boşluğu** — Ansiklopedide siluet: "Sonbahar mevsiminde bulunur"
4. **Ziyaretçi balonu** — "Yakında özel bir misafir geliyor..." (3 saat sayaç)
5. **Mevsim geçiş sayacı** — "Yaza 2 gün kaldı — ayçiçeğini hazırla!"
6. **Günlük görev** — "Bugün 5 farklı çiçek topla → 300 Tohum Puanı"
7. **Komşu bahçesi** — Arkadaş bahçeleri önizlemesi → "Onların da olmayan nane bitkisi sende var!"
