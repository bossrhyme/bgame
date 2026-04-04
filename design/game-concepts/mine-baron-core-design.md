# Maden Baronu (Mine Baron) — Çekirdek Tasarım Belgesi

**Kategori:** Idle Simülasyon / Tycoon
**Platform:** Mobil (iOS & Android)
**Kontrol:** Tek el, dokunmatik
**Hedef Kitle:** Idle Miner Tycoon, Deep Town, Mr. Mine kitlesi

---

## 1. OYUN MEKANİĞİ

### Temel Döngü (Core Loop)

```
Kaz → Cevher Topla → Taşı → Erit → Sat → Upgrade Al → Daha Derine İn → Yeni Katman Aç
```

**Dakika bazında oturum:**

| Süre | Aktivite |
|------|----------|
| 0:00 | Madeni aç, bekleyen cevherleri gör |
| 0:30 | Taşıma bantını hızlandır (tap) |
| 1:00 | Depo doluysa sat, altın topla |
| 2:00 | Bir upgrade al (kazma, bant, fırın) |
| 3:00 | Yeni katman kilit koşulunu kontrol et |
| 5:00 | Kısa oturum biter — otomatik madencilik devam eder |
| 20:00 | Uzun oturum: yeni bölge keşfi, ekip yönetimi, nadir mineral avı |

---

### Dokunma Mekaniği (Tek El)

| Eylem | Gesture | Animasyon | Ses |
|-------|---------|-----------|-----|
| Manuel kazma | Hızlı tap (blok başına) | Kaya parçalanır, ışık saçar | "Çakrak!" darbe sesi |
| Taşıma hızlandır | Uzun basış | Bant hızlanır, titreşir | Motor uğultusu |
| Toplama | Tap (cevher üstüne) | Cevher "emilir" sayaca | "Ding!" manyetik ses |
| Satış | Kaydır (depoda) | Para yağmuru | Kasa sesi + "ka-ching!" |
| Upgrade | Tap + onay | Tesis parlar, büyür | Mekanik "tık-tık-tık" |

**Manuel kazma bonusu:** Oyuncu elle kazdığında otomatikten 3x hızlı → kısa oturumda aktif oyuncuyu ödüllendirir.

---

### Kaynak Sistemi

**3 Katmanlı Kaynak Zinciri:**

```
Ham Cevher → Eritme → Saf Metal → Satış / Üretimde Kullan
```

| Kaynak | Elde Etme | Kullanım |
|--------|-----------|----------|
| Taş | Her katmanda | Temel yapı materyali |
| Demir Cevheri | Katman 1-5 | Ekipman üretimi |
| Bakır | Katman 3-8 | Elektrik sistemleri |
| Altın Cevheri | Katman 7-15 | Satış + premium upgrade |
| Gümüş | Katman 10-20 | Özel araçlar |
| Elmas | Katman 20+ | Nadir upgrade, prestij |
| Kristal | Gizli katmanlar | Prestige para birimi |

**İki Para Birimi:**
- **Altın:** Günlük upgrade, işçi maaşı, ekipman
- **Kristal:** Prestige, nadir derinlik açma, kozmetik

---

### Offline Üretim

- Otomatik kazıcılar çalışır, taşıma bantları dolar
- Max offline süre: **6 saat** (geç oyunda 10 saate çıkar)
- Geri dönüşte: "X saat boyunca X ton cevher toplandı!" + depo dolu animasyonu
- Depo dolunca üretim durur → geri dönme motivasyonu

---

### Oturum Süresi Tasarımı

**2 Dakika Oturumu:**
- Depoyu boşalt (sat)
- Manuel birkaç kazma (bonus)
- Bir küçük upgrade al, git

**20 Dakika Oturumu:**
- Tüm yukarıdakiler +
- Yeni katman kilit koşulu araştır
- Nadir mineral avı (özel kazı noktaları)
- İşçi kadrosu yönetimi
- Prestige hesaplaması

---

## 2. ÇEVRE TASARIMI

### Yer Altı Katman Sistemi

Her katman ayrı bir biyom — farklı renk, müzik, tehdit ve ödül:

| Katman | Derinlik | Biyom Adı | Renk Paleti | Özel Cevher | Atmosfer |
|--------|----------|-----------|-------------|-------------|----------|
| 1-3 | 0-30m | Toprak & Kil | Kahverengi, bej | Taş, kil | Sıradan, açık |
| 4-8 | 30-80m | Taş Katmanı | Gri, koyu gri | Demir, bakır | Serin, nemli |
| 9-15 | 80-150m | Granit Derinliği | Koyu gri, mor | Altın, gümüş | Soğuk, yankılı |
| 16-22 | 150-250m | Kızgın Kayaç | Kırmızı-turuncu | Rubiler, obsidyen | Sıcak, titreşimli |
| 23-30 | 250-400m | Kristal Mağarası | Mavi-mor, parlak | Elmas, kristaller | Büyülü, sessiz |
| 31-40 | 400-600m | Jeothermal Alan | Sarı, lav kırmızısı | Nadir elementler | Tehlikeli, heyecanlı |
| 41+ | 600m+ | Gizemli Derinlik | Siyah, neon | Efsanevi mineraller | Bilinmez, mistik |

---

### Görsel Dil

**Her katman için görsel kural:**
- Duvar dokusu değişir (kil → taş → granit → kristal)
- Arka plan aydınlatması katmana özgü (güneş ışığı → maden lambası → kristal parıltısı → lav ışığı)
- Parçacık efektleri: kil tozu → taş kıvılcımı → kristal tozu → lav zerreleri

**Işık Tasarımı:**
| Katman | Işık Kaynağı | Renk Sıcaklığı |
|--------|--------------|----------------|
| Üst | Doğal gün ışığı | Sıcak sarı |
| Orta | Maden lambaları | Soğuk beyaz |
| Derin | Kristal parıltısı | Mavi-mor |
| Çok derin | Lav ve maden ekipmanı | Turuncu-kırmızı |

---

### Animasyon Rehberi

**Kazma Animasyonu:**
- Manuel tap: Kaya bloğu çatlak çizgileri → patlar → cevher parçaları "fışkırır"
- Her darbe için mikro-sarsıntı (kamera shake 0.1 saniye)
- Cevher parçaları depo sayacına doğru uçar

**Taşıma Bandı:**
- Devamlı hareket, hız upgrade ile görsel olarak artar
- Bant üzerindeki cevher parçaları sallanır
- Tıkanma durumunda kırmızı titreme efekti

**Eritme Fırını:**
- Cevher içeri girer, sıvı metal çıkar
- Parlak turuncu akma animasyonu
- Buhar parçacıkları

**Yeni Katman Açılışı (En Önemli An):**
- Dinamit patlaması + kamera sarsıntısı
- Aşağıya inen kamera hareketiyle yeni biyom ortaya çıkar
- Özel müzik jingle
- "YENİ KATMAN AÇILDı!" splash ekranı

---

### Ses Tasarımı

**Ambient Katmanlar (derinliğe göre değişir):**

| Katman | Ambient Ses |
|--------|-------------|
| 0-30m | Rüzgar, kuş sesleri |
| 30-80m | Damlayan su, uzak yankı |
| 80-150m | Derin uğultu, metal sesi |
| 150-250m | Volkanik hışırtı, kristal titreşimi |
| 250m+ | Mistik, derin, hafif tınlama |

**Eylem Sesleri:**
| Eylem | Ses |
|-------|-----|
| Manuel kazma | Metalik "çak!" + taş parçalanma |
| Otomatik kazıcı | Ritmik "tuk-tuk-tuk" |
| Cevher toplama | Manyetik "vızz" + ding |
| Bant hareketi | Motor uğultusu (hıza göre değişir) |
| Eritme | "Çıkır çıkır" + sıvı sesi |
| Satış | Bozuk para + kasa dinglemesi |
| Yeni katman | Patlama + "BOOM!" + jingle |

---

## 3. GELİŞTİRME SİSTEMİ

### Upgrade Ağacı

#### A) Kazma Ekipmanı

| Alet | Kazma Hızı | Katman Kısıtı | Maliyet |
|------|-----------|---------------|---------|
| Tahta Kazma | 1x | Katman 1-3 | Başlangıç |
| Demir Kazma | 2x | Katman 1-8 | 200 altın |
| Çelik Kazma | 4x | Katman 1-15 | 1.500 altın |
| Titanyum Kazma | 8x | Katman 1-25 | 8.000 altın |
| Elmas Uçlu | 15x | Tüm katmanlar | 35.000 altın |
| Lazer Kesici | 30x | Tüm katmanlar | 100 kristal |
| Kuantum Delici | 60x | Tüm katmanlar | 500 kristal |

#### B) Taşıma Sistemi

| Upgrade | Kapasite | Hız | Maliyet |
|---------|----------|-----|---------|
| El arabası | 20 birim | 1x | Başlangıç |
| Küçük bant | 50 birim | 1.5x | 500 altın |
| Geniş bant | 120 birim | 2x | 2.000 altın |
| Çift bant | 250 birim | 3x | 10.000 altın |
| Manyetik ray | 500 birim | 5x | 50.000 altın |
| Teletransport | Sınırsız | 10x | 1.000 kristal |

#### C) Eritme Tesisi

| Fırın | Kapasite/dk | Kalite Bonusu | Maliyet |
|-------|-------------|---------------|---------|
| Temel Fırın | 10 birim | — | 300 altın |
| Gelişmiş Fırın | 25 birim | +10% değer | 1.500 altın |
| Endüstriyel | 60 birim | +25% değer | 8.000 altın |
| Elektrikli | 120 birim | +50% değer | 30.000 altın |
| Plazma | 300 birim | +100% değer | 2.000 kristal |

#### D) Depo Kapasitesi

| Seviye | Kapasite | Maliyet |
|--------|----------|---------|
| 1 | 200 birim | Başlangıç |
| 2 | 500 birim | 400 altın |
| 3 | 1.200 birim | 2.000 altın |
| 4 | 3.000 birim | 10.000 altın |
| 5 | 10.000 birim | 50.000 altın |
| 6 | Sınırsız | 5.000 kristal |

---

### İşçi Kadrosu

| İşçi | Görevi | Günlük Maliyet | Upgrade Etkisi |
|------|--------|----------------|----------------|
| Madenci | Otomatik kazma +1 blok/sn | 100 altın | Her sev: +50% hız |
| Bant Operatörü | Bant verimliliği +20% | 80 altın | Her sev: +15% verim |
| Eritme Ustası | Erime kalitesi +10% | 120 altın | Her sev: +10% değer |
| Jeolog | Nadir mineral şansı +5% | 200 altın | Her sev: +5% şans |
| Güvenlik Şefi | Ekipman arıza riski -50% | 60 altın | Her sev: -10% risk |

---

### Katman Açma Koşulları

| Katman Grubu | Açılma Koşulu |
|--------------|---------------|
| 1-3 (Toprak) | Başlangıç |
| 4-8 (Taş) | 1.000 ton taş + Demir kazma |
| 9-15 (Granit) | 5.000 ton demir cevheri + Çelik kazma + Sev.5 bant |
| 16-22 (Kızgın) | 20.000 ton + Endüstriyel fırın + 3 jeolog |
| 23-30 (Kristal) | 100 kristal + Elmas kazma + Sev.4 depo |
| 31-40 (Jeothermal) | 1.000 kristal + Plazma fırın |
| 41+ (Gizemli) | Tam prestige + tüm önceki katmanlar tamamlandı |

---

### Ekonomi Dengesi

**Erken Oyun (Katman 1-5):**
```
Demir cevheri satışı: 5 altın/birim
Saatlik üretim: 200 birim = 1.000 altın
Upgrade maliyeti: 200-500 altın
Net birikim: 500-800 altın/saat
```

**Orta Oyun (Katman 10-20):**
```
Altın cevheri: 80 altın/birim
Saatlik üretim: 500 birim = 40.000 altın
Maaş gideri: 5.000 altın/saat
Net birikim: 35.000 altın/saat
```

**Geç Oyun (Katman 25+):**
```
Elmas: 500 altın/birim + kristal üretimi
Tüm katmanlar paralel = 500.000+ altın/saat
Kristal üretimi: 10-50 kristal/gün
```

---

### Nadir Mineral Sistemi

Her katmanda "özel kazı noktaları" rastgele belirir:
- **Gizli Damar:** 5x cevher yoğunluğu, 60 saniye aktif
- **Jeo-kristal Bölgesi:** Kristal para birimi üretir
- **Fosil Kalıntısı:** Koleksiyon öğesi → müzeye sat

**Nadir Mineral Şansları:**

| Mineral | Temel Şans | Jeolog ile |
|---------|-----------|-----------|
| Yakut | %2 | %4 |
| Zümrüt | %1 | %2 |
| Elmas | %0.5 | %1 |
| Efsanevi Kristal | %0.1 | %0.3 |

---

### Görsel Progression

| Aşama | Madencinin Görünümü | Üs Görünümü | Atmosfer |
|-------|---------------------|-------------|----------|
| Başlangıç | Çıplak el, eski kazma | Küçük ahşap kulübe | Güneşli çayır |
| Katman 5 | İş elbisesi, demir kazma | Küçük ofis binası | Toz, sanayi |
| Katman 15 | Maden kıyafeti, kask | Beton tesis | Gece, ışıklı |
| Katman 25 | Hi-tech kıyafet | Modern fabrika | Neon, gelecek |
| Katman 40+ | Exo-suit | Mega kompleks | Sci-fi, devasa |

---

### Motivasyon Kancaları

1. **Derinlik sayacı** — Ekran kenarında "−127m" her zaman görünür, aşağı çeker
2. **Bir sonraki katman önizlemesi** — Kazma alanının dibinde yeni biyom rengi sızar
3. **Nadir mineral bildirimi** — "Jeologunuz yakında bir şey hissetti..." balonu
4. **Katman rekoru** — "Bu aydaki en derin: −89m. Rekorunu kır!"
5. **Günlük görev** — "Bugün 500 ton demir çıkar → 2.000 altın bonus"
6. **İşçi memnuniyeti** — "Kazıcıların daha iyi ekipman istiyor" balonu
7. **Fosil koleksiyon boşluğu** — Müzede siluet: "Katman 12'de bulunur..."
