# Ekmek Ustası (Bread Master) — Çekirdek Tasarım Belgesi

**Kategori:** Idle Simülasyon / Clicker Hibrit
**Platform:** Mobil (iOS & Android)
**Kontrol:** Tek el, dokunmatik
**Hedef Kitle:** Pizza Ready!, Idle Bakery kitlesi — her yaş, özellikle 18-45

---

## 1. OYUN MEKANİĞİ

### Temel Döngü (Core Loop)

```
Hamur Hazırla → Şekil Ver → Fırına At → Bekle → Hasat Et → Sat → Upgrade Al → Yeni Tarif Aç
```

**Dakika bazında oturum:**

| Süre | Aktivite |
|------|----------|
| 0:00 | Fırını aç, bekleyen siparişleri gör |
| 0:30 | Hazır hamurları tap ile fırına at |
| 1:00 | Yeni hamur yoğurmayı başlat (3-5 tap) |
| 2:00 | Fırından çıkan ekmekleri vitrine al |
| 3:00 | Müşteri siparişlerini karşıla, altın kazan |
| 5:00 | Upgrade menüsünü kontrol et, bir şey al |
| 7:00 | Kısa oturum biter — idle üretim devam eder |

---

### Dokunma Mekaniği (Tek El ASMR Tasarımı)

Her eylem ayrı bir dokunma hissi ve sesi olmalı:

| Eylem | Gesture | Animasyon | Ses |
|-------|---------|-----------|-----|
| Hamur yoğurma | Döngüsel sürükleme (3x) | Hamur genişleyip daralır | Yumuşak "mlap mlap" |
| Şekil verme | Uzun basış + sürükle | Hamur forma girer | Sessiz "fış" |
| Fırına at | Sürükle-bırak | Ekmek kaya gibi kayar | Demir kapı gıcırtısı |
| Hasat | Hızlı tap | Ekmek "fırlar" vitrine | "Puf!" + zil sesi |
| Vitrin satış | Müşteri tap | Para animasyonu | Kasa sesi |

**Önemli:** Hamur yoğurma döngüsü hipnotik olmalı. 3 döngüsel sürükleme yeterli — tekrarsız, tatmin edici.

---

### Tarif Sistemi

Toplam 40+ ekmek tarifi, 5 kategoride:

| Kategori | Örnekler | Açılma Seviyesi |
|----------|----------|-----------------|
| Temel | Beyaz ekmek, tam buğday, kepekli | Başlangıç |
| Dünya | Fransız baguette, Alman pretzel, Türk simidi | Sev. 5-15 |
| Özel | Çavdar, mısır ekmeği, focaccia | Sev. 15-30 |
| Tatlı | Brioche, çörek, tarçınlı rulo | Sev. 25-40 |
| Efsanevi | Altın ekmek, ejderha simidi, kristal baguette | Prestige |

**Tarif açma koşulları:**
- Belirli sayıda ekmek sat → yeni tarif araştır
- Özel malzeme topla (buğday türleri, aromatikler)
- Şehir lokasyonu açınca o şehre özgü tarifler gelir

---

### Müşteri / Sipariş Sistemi

| Müşteri Tipi | Sabır Süresi | Ödül Çarpanı | Görünüm Sıklığı |
|--------------|--------------|--------------|-----------------|
| Sabırlı müşteri | 5 dakika | 1x | Çok sık |
| Acele müşteri | 90 saniye | 1.5x | Orta |
| VIP müşteri | 3 dakika | 3x | Nadir |
| Festival müşterisi | 10 dakika | 2x toplu | Etkinlik günleri |

**Sipariş panosu:** Ekranda max 4 sipariş görünür. Zamanında teslim → tam altın. Geç teslim → %50 altın. Hiç teslim etme → müşteri kaçar, memnuniyet düşer.

---

### Offline Üretim

- Otomatik üretim fırın kapasitesine göre çalışır
- Max offline süre: **8 saat** (geç oyunda 12 saate çıkar)
- Geri dönüşte "Fırından yeni çıktı!" animasyonu ve patlama
- Premium upgrade ile offline süre uzar

---

### Özel Etkinlikler

| Etkinlik | Zaman | Özel Ekmek | Ödül |
|----------|-------|-----------|------|
| Ramazan Bayramı | Yılda 1x | Özel pide, bayram çöreği | Altın rozet |
| Yılbaşı | Aralık | Yılbaşı simidi, zencefilli ev | Kar teması |
| Sevgililer Günü | Şubat | Kalp ekmek, gül brioche | Pembe dekorasyon |
| Hasad Festivali | Ekim | Kabak ekmeği, mısır somunu | Sonbahar teması |

---

### Oturum Süresi Tasarımı

**2 Dakika Oturumu:**
- Fırından çıkanları tap ile al
- Siparişleri karşıla
- Yeni hamur başlat, git

**20 Dakika Oturumu:**
- Tüm yukarıdakiler +
- Yeni tarif araştır
- Çalışan yönetimi
- Şehir genişleme planlaması
- Koleksiyon gözden geçir

---

## 2. ÇEVRE TASARIMI

### Fırın Bölgeleri

```
[HAMUR TEZGAHI] [FIRIN ÜNİTESİ] [VİTRİN] [KASA]
      ↓               ↓             ↓        ↓
  Hazırlık         Pişirme       Teşhir    Satış
      ↓
 [DEPO / MALZEME]
      ↓
 [TESLİMAT ALANI]
```

Her bölge ayrı upgrade alır ve görsel olarak dönüşür.

---

### Şehir / Lokasyon Seti (Prestige Sistemi)

Sıfırlama yok — her şehirde yeni fırın açılır, eskiler üretmeye devam eder.

| Sıra | Lokasyon | Tema | Özel Tarif | Açılış Koşulu |
|------|----------|------|-----------|---------------|
| 1 | Anadolu Köyü | Sıcak, ahşap, tandır | Köy ekmeği, pide | Başlangıç |
| 2 | Kasaba Pastanesi | Pastel, vintage | Poğaça, simit | 500 ekmek sat |
| 3 | Şehir Butiği | Modern, minimalist | Sourdough, ciabatta | 5.000 altın + Sev.10 |
| 4 | Havalimanı Mağazası | Cam, beyaz, steril | Uluslararası karışım | Sev. 20 |
| 5 | Paris Butiği | Art deco, altın | Baguette, croissant | Sev. 35 |
| 6 | Tokyo Fırını | Japon minimal | Melonpan, shokupan | Sev. 50 |

---

### Görsel Dil ve Renk Paleti

**Genel Atmosfer:** Sıcak, güvenli, "büyükannenin mutfağı" hissi

| Lokasyon | Ana Renk | Vurgu | Işık |
|----------|----------|-------|------|
| Köy Fırını | Turuncu-krem | Kahverengi ahşap | Gün batımı sarısı |
| Kasaba Pastanesi | Pembe-krem | Pastel yeşil | Yumuşak beyaz |
| Şehir Butiği | Bej-gri | Bakır aksesuarlar | Soğuk-sıcak karışık |
| Paris Butiği | Krem-altın | Bordo | Bohem yumuşak |
| Tokyo Fırını | Beyaz-krem | Pastel mavi | Doğal gün ışığı |

---

### Animasyon Rehberi

**Hamur Kabarma (En Önemli Animasyon):**
- Başlangıç: Küçük, mat, yoğun top
- Orta: Yavaş şişme, yüzey parlaklaşır
- Tamamlanma: "Nefes alır" gibi hafif titreyerek durur
- Süre: 8-12 saniye

**Fırından Çıkma:**
- Fırın kapısı açılır (1 saniye)
- Buhar çıkar (parçacık efekti)
- Ekmek altın-kahverengi renkte parlar
- Vitrine "kayar" (arc hareketi)

**Para Animasyonu:**
- Altın coinler ekmekten "fışkırır"
- Havada dönerek sayaca gider
- Sayaç "sayar" (tatmin edici ses)

---

### Ses Tasarımı

**Ambient Katmanlar (her zaman çalışır):**
1. Fırın hışırtısı (düşük, sürekli)
2. Uzak kasaba sesi (kuş, rüzgar)
3. Yumuşak cazz/akustik müzik (70 BPM)

**Eylem Sesleri:**
| Eylem | Ses |
|-------|-----|
| Hamur yoğurma | Islak, yumuşak "mlap" |
| Fırın kapısı | Ağır demir "krank" |
| Ekmek çıkışı | Hava püskürtme "fış" |
| Hasat tap | Kuru, tatmin edici "tok" |
| Para | Bozuk para sesi + ding |
| Müşteri memnuniyeti | Yumuşak "mmm!" sesi |

---

## 3. GELİŞTİRME SİSTEMİ

### Fırın Upgrade Ağacı

#### A) Üretim Upgrades

| Upgrade | Sev.1 | Sev.2 | Sev.3 | Sev.4 | Sev.5 | Maliyet (Altın) |
|---------|-------|-------|-------|-------|-------|-----------------|
| Fırın Sıcaklığı | +10% hız | +25% hız | +50% hız | +80% hız | +120% hız | 50/150/400/1k/3k |
| Fırın Kapasitesi | 2 ekmek | 4 ekmek | 6 ekmek | 8 ekmek | 12 ekmek | 100/300/800/2k/5k |
| Hamur Kalitesi | +5% değer | +15% | +30% | +50% | +75% | 75/200/600/1.5k/4k |
| Otomatik Hamur | Manuel | Yarı-otomatik | Tam otomatik | Hızlı oto | Süper oto | — /500/2k/6k/15k |
| Malzeme Deposu | 10 birim | 25 birim | 50 birim | 100 birim | Sınırsız | 80/250/700/2k/— |

#### B) Müşteri Upgrades

| Upgrade | Etki | Maliyet |
|---------|------|---------|
| Vitrin Genişliği | +2 müşteri kapasitesi | 200 / 600 / 1.5k |
| Müşteri Memnuniyeti | Sabır +20% | 300 / 900 / 2.5k |
| VIP Lounge | VIP müşteri +50% sık | 1.000 Rozet |
| Sadakat Kartı | Tekrar müşteri +30% gelir | 2.000 |

#### C) Teslimat Upgrades

| Upgrade | Kapasite | Hız | Maliyet |
|---------|----------|-----|---------|
| Yaya Teslimat | 1 sipariş | Yavaş | Başlangıç |
| Bisiklet | 2 sipariş | Orta | 500 |
| Scooter | 3 sipariş | Hızlı | 2.000 |
| Van | 5 sipariş | Çok hızlı | 8.000 |
| Drone | 10 sipariş | Anlık | 25.000 |

---

### Çalışan Sistemi

| Çalışan | Görevi | Maliyet/Gün | Upgrade Etkisi |
|---------|--------|-------------|----------------|
| Hamurcu Yardımcısı | Hamur yoğurma otomatize | 50 altın/gün | Hız +25% her seviye |
| Fırın Ustası | Pişirme kalitesi +10% | 80 altın/gün | Kalite +15% |
| Kasiyer | Müşteri kuyruğu +2 | 40 altın/gün | Sabır +10% |
| Teslimatçı | Sipariş kapasitesi +2 | 60 altın/gün | Hız +20% |

---

### Ekonomi Dengesi (Sayısal Örnek)

**Para Birimleri:**
- **Altın:** Günlük harcama — upgrade, çalışan maaşı, malzeme
- **Unlu Rozet:** Premium — VIP upgrade, dekorasyon, şehir açma hızlandırma

**Erken Oyun (Sev. 1-10):**
```
Beyaz ekmek satışı: 10 altın/adet
Günlük üretim: 50 ekmek = 500 altın
Günlük harcama: 200-300 altın (upgrade)
Net birikim: 200-300 altın/gün
```

**Orta Oyun (Sev. 20-35):**
```
Baguette satışı: 85 altın/adet
Günlük üretim: 200 ekmek = 17.000 altın
İki fırın (köy + kasaba) = 28.000 altın/gün
Upgrade maliyeti: 5.000-15.000 altın
```

**Geç Oyun (Sev. 50+):**
```
Paris butiği özel ekmek: 500+ altın/adet
6 şehir aktif = 200.000+ altın/gün
Efsanevi ekmekler: 2.000-10.000 altın/adet
```

---

### Koleksiyon Sistemi

**Dünya Ekmek Ansiklopedisi:** 60+ ekmek, ülke bazında gruplandırılmış.

| Ülke | Ekmek | Nasıl Açılır? |
|------|-------|---------------|
| Türkiye | Simit, pide, bazlama, katmer | Köy fırını Sev.3 |
| Fransa | Baguette, croissant, brioche | Paris lokasyonu |
| Almanya | Pretzel, roggenbrot, pumpernickel | Sev.30 |
| Japonya | Shokupan, melonpan, curry pan | Tokyo lokasyonu |
| İtalya | Focaccia, ciabatta, grissini | Sev.25 |
| Meksika | Tortilla, pan dulce, bolillo | Festival etkinliği |

**Koleksiyon Tamamlama Ödülleri:**
- Türkiye seti: Özel Osmanlı fırın dekorasyonu
- Fransa seti: Paris vitrini teması
- Tüm dünya: "Dünya Ekmek Şampiyonu" unvanı + 50.000 altın

---

### Görsel Progression

| Aşama | Fırın Görünümü | Zemin | Dekorasyon |
|-------|----------------|-------|------------|
| Başlangıç | Eski ahşap, çatlak | Toprak |Çıplak duvarlar |
| Sev. 10 | Sıva yapılmış, temiz | Taş | Raflar, bitkiler |
| Sev. 25 | Boyalı, vitrin | Ahşap parke | Tablolar, lambalar |
| Sev. 40 | Modern dokunuşlar | Seramik | Neon tabelalar |
| Sev. 50 | Premium butik | Mermer | Avize, vitraylı pencere |

---

### Motivasyon Kancaları

Her ekranda en az 2 "bir sonraki hedef" görünür:

1. **İlerleme çubuğu** — "Bir sonraki upgrade'e 340 altın kaldı"
2. **Tarif kilidi** — Vitrin köşesinde bulanık tarif: "120 ekmek sat, açılıyor!"
3. **Şehir önizlemesi** — Harita ekranında kilitli şehir görünür, koşul yazıyor
4. **Koleksiyon boşluğu** — Ansiklopedide boş siluet: "?"
5. **Müşteri balonu** — "Seninle tanışmak istiyorum... daha iyi bir vitrine ihtiyacın var"
6. **Günlük görev** — "Bugün 30 simit sat → 500 Rozet"
