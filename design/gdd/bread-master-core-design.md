# Ekmek Ustası (Bread Master) — Çekirdek Tasarım Belgesi

**Kategori:** Idle Simülasyon / Clicker Hibrit
**Platform:** Mobil (iOS & Android)
**Kontrol:** Tek el, dokunmatik
**Hedef Kitle:** Pizza Ready!, Idle Bakery kitlesi — her yaş, özellikle 18-45

---

## OVERVIEW

Ekmek Ustası, oyuncunun küçük bir Anadolu köy fırınından başlayarak Paris ve Tokyo'ya uzanan bir ekmek imparatorluğu kurduğu idle simülasyon/clicker hibrit mobil oyundur. Tek el, ASMR odaklı dokunmatik mekanikler üzerine kurulu tatmin edici üretim döngüsü; offline ilerleme, derinlikli upgrade ağacı ve 60+ ekmeğin yer aldığı dünya koleksiyonu ile 18-45 yaş kitlesine hitap eder. Oyuncunun aktif olduğu her 2-7 dakika anlamlıdır; geri döndüğünde fırın onu bekliyor olur.

---

## PLAYER FANTASY

**Temel his:** "Sabahın erkeninde fırını ilk açan usta." — Hamur ellerin altında şekillenir, fırının ısısı neredeyse hissedilir, müşterinin yüzündeki memnuniyet görülür. Oyuncu kontrol sahibi, üretken ve büyüyen bir şeyin mimarı hisseder.

**İkincil his:** Koleksiyon tatmini — dünyanın her köşesinden bir ekmeği öğrenmek, denemek, rafına yerleştirmek. Her yeni şehir bir keşif, her yeni tarif bir gurur.

**Kaçınılması gereken:** Ezici bekleme, boş ekran, "neden tıklıyorum" hissi. Her tap bir şeyi ilerletmeli.

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
| Fırın Sıcaklığı | +10% hız | +25% hız | +50% hız | +80% hız | +120% hız | 50/150/450/1k/3k |
| Fırın Kapasitesi | 2 ekmek | 4 ekmek | 6 ekmek | 8 ekmek | 12 ekmek | 100/300/900/2k/5k |
| Hamur Kalitesi | +5% değer | +15% | +30% | +50% | +75% | 75/200/675/1.5k/4k |
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
  > **Politika:** Unlu Rozet yalnızca oyun içi kazanılır (günlük görevler, koleksiyon
  > tamamlama, rewarded reklam izleme). Gerçek parayla satın alma yolu yoktur. (→ ADR-0002)

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

### Reklam Monetizasyonu (Rewarded Ad Noktaları)

> ADR-0002: Monetizasyon yalnızca rewarded (isteğe bağlı) reklamlardır. IAP yoktur.
> Fill rate = 0 durumunda reklam butonu gizlenir — oyuncu hiçbir zaman engellenmez.

| Reklam Noktası | Teklif | Günlük Limit |
|---|---|---|
| Offline dönüşü | 2× üretim cap (8s → 16s, o oturum için 1 kez) | 1 |
| Günlük görev tamamlama | Rozet ödülünü 2× al | 3 |
| Fırın kapasitesi dolu | Anında pişir (bekleme süresi atla) | 2 |
| VIP müşteri gelişi | VIP süresini 10 dakika uzat | 3 |
| Çoklu lokasyon açılışı | 3. lokasyondan itibaren %20 altın indirimi | 1 |

**Toplam günlük reklam limiti:** 10 izleme/gün (tüm noktalar dahil)

**Rozet kazanım oranı (reklamdan):**
- Günlük görev reklamı: +50 Rozet bonus (günlük görev ödülüne ek)
- Diğer noktalar: Rozet vermez, altın/süre avantajı sağlar

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

---

## 4. FORMÜLLER

### Offline Üretim

```
items_produced = floor(min(offline_seconds, cap_seconds) / bake_time_seconds) * oven_capacity
```

| Değişken | Açıklama | Örnek |
|----------|----------|-------|
| `offline_seconds` | Geçen gerçek süre (sn) | 36.000 (10 saat) |
| `cap_seconds` | Max offline süre (sn) | 28.800 (8 saat) |
| `bake_time_seconds` | Bir tur pişirme süresi | 120 sn |
| `oven_capacity` | Fırın kapasitesi (ekmek/tur) | 4 |

**Örnek:** 10 saat offline, 4 kapasiteli fırın, 2 dk pişirme →
`floor(min(36000, 28800) / 120) * 4 = floor(240) * 4 = 960 ekmek`

> **Cap büyüme kuralı:** `cap_seconds` sabit değil; oyun ilerledikçe artar.
> Erken oyun (Sev. 1–15): 28.800 sn (8 saat). Geç oyun (Sev. 40+): 43.200 sn (12 saat).
> Büyüme mekanizması (lokasyon açma veya özel upgrade) Offline Production GDD'sinde tanımlanacak.
> `offline_cap_late_game` tuning knob'u bu değeri kontrol eder (→ Bölüm 5).

---

### Upgrade Maliyet Ölçekleme

```
cost(n) = base_cost * 3^(n-1)
```

| n (seviye) | base_cost = 50 | base_cost = 100 |
|------------|----------------|-----------------|
| 1 | 50 | 100 |
| 2 | 150 | 300 |
| 3 | 450 | 900 |
| 4 | 1.350 | 2.700 |
| 5 | 4.050 | 8.100 |

---

### Müşteri Memnuniyeti Azalması

```
satisfaction_loss = (elapsed_ms / patience_ms) * 100
final_gold = base_gold * max(0.5, 1 - satisfaction_loss / 100)
```

| Değişken | Açıklama | Aralık |
|----------|----------|--------|
| `elapsed_ms` | Müşteri sahneye girip sipariş verdiği andan geçen süre (ms) — sipariş **verildiği** an sıfırlanır | [0, patience_ms] |
| `patience_ms` | `CustomerTypeData.patience_seconds × 1000` | [90000, 600000] |
| `satisfaction_loss` | Yüzde memnuniyet kaybı | [0.0, 100.0] |
| `final_gold` | Teslim edilen altın miktarı; min %50 oranı korunur | [base_gold × 0.5, base_gold] |

- Tam zamanında teslim (satisfaction_loss = 0) → `base_gold * 1.0`
- Yarı sürede teslim edilmemiş (satisfaction_loss = 50) → `base_gold * 0.75`
- Süre dolmuş (satisfaction_loss = 100) → müşteri kaçar, altın yok

---

### Tarif Değeri Ölçekleme

```
recipe_value = base_value * (1 + quality_bonus) * location_multiplier
```

| Değişken | Kaynak | Örnek |
|----------|--------|-------|
| `base_value` | Tarif tablosundan | 85 altın (baguette) |
| `quality_bonus` | Hamur Kalitesi upgrade toplamı | 0.30 (+30%) |
| `location_multiplier` | Aktif lokasyon çarpanı | 1.5 (Paris) |

---

## 5. TUNING KNOBS

Aşağıdaki değerler oynanabilirlik testlerine göre ayarlanabilir. Güvenli aralıkların dışına çıkmak oyun dengesini bozar.

| Değer | Varsayılan | Güvenli Aralık | Etki |
|-------|-----------|----------------|------|
| `bake_time_base` | 120 sn | 60–300 sn | Çok düşük → oyuncu tıklamaya yetişemez; çok yüksek → bekleme can sıkar |
| `offline_cap_hours` | 8 saat | 6–16 saat | Düşük → sık açmak zorunda kalır; yüksek → geri dönme motivasyonu azalır |
| `offline_cap_late_game` | 12 saat | 10–20 saat | Geç oyun premium hissi için |
| `patience_base_seconds` | 300 sn | 90–600 sn | Çok düşük → stres; çok yüksek → gerginlik yok |
| `vip_spawn_rate` | %5 | %2–%15 | Yüksek → VIP özelliği anlamsızlaşır |
| `upgrade_cost_exponent` | 3.0 | 2.5–4.0 | Düşük → erken maxlanır; yüksek → ilerlemek imkansız hissettirilebilir |
| `location_multiplier_step` | +0.5 | +0.3–+0.8 | Her şehirde gelir artışı hissi |
| `daily_task_reward_rozet` | 500 | 200–1.000 | Premium para dengesini etkiler |
| `recipe_unlock_threshold` | Tarife özgü | ±%20 | Tarif açma hızı akışını belirler |

---

## 6. EDGE CASES

| # | Durum | Beklenen Davranış |
|---|-------|-------------------|
| 1 | Depo kapasitesi doldu, yeni ekmek pişti | Üretim durur; ekranda "Depo dolu — sat!" uyarısı göster |
| 2 | Oyuncu 8 saatten fazla offline kaldı (örn. 20 saat) | Cap uygulanır: `min(20h, 8h)` = 8 saat üretim hesaplanır, fazlası kaybolur |
| 3 | Müşteri süresi doldu, sipariş iptal oldu | Sipariş panodan kalkar; memnuniyet -10; altın düşmez |
| 4 | 4 sipariş panosu doluyken yeni müşteri geldi | Yeni müşteri bekleme alanında bekler; 5. slot açık değilse geri döner |
| 5 | VIP müşteri geldi ama ürün stokta yok | VIP "yarın gelirim" balonu gösterir; spawner 30 dk sonar tekrar dener |
| 6 | Aynı tarifi tekrar tekrar sat koşulunu sağladı | Kilit açma tetiklenir sadece bir kez; fazla satış normal altın olarak sayılır |
| 7 | Lokasyon açıldı ama kaynak yetersizleşti | Eski lokasyonlar çalışmaya devam eder; yeni lokasyonda başlangıç ekipmanı verilir |
| 8 | Çalışan günlük maaşı ödenemedi (altın yetersiz) | Çalışan "greve çıkar" — efekt devre dışı kalır; ödeme yapılınca devam eder |
| 9 | Oyuncu tüm upgrade'leri maxladı | Son upgrade "maxlandı" rozeti alır; yeni şehir veya prestige seçeneği önerilir |
| 10 | Festival müşterisi etkinlik dışında tetiklendi | Etkinlik dışı festival müşterisi spawn edilmez; normal müşteri kuyruğu devam eder |
| 11 | Koleksiyon %100 tamamlandı | "Dünya Ekmek Şampiyonu" unvanı + 50.000 altın + özel animasyon tetiklenir |
| 12 | Otomatik hamur upgrade aktifken oyuncu da manuel yoğurdu | Her ikisi paralel çalışır; manuel yoğurma bonusu (%3x hız) ek olarak uygulanır |
| 13 | Rozet (premium para) harcamak için yetersiz bakiye | İşlem engellenir; "Yeterli Rozet yok" tostu gösterilir |
| 14 | Günlük görev süresi doldu ama tamamlanmadı | Görev sıfırlanır, ödül verilmez; yeni görev ertesi güne atanır |
| 15 | Ağ bağlantısı kesildi (eğer sunucu senkronizasyonu varsa) | Lokal offline mod devreye girer; bağlantı gelince senkronize edilir |

---

## 7. BAĞIMLILIKLAR (DEPENDENCIES)

```
Lokasyon Sistemi
    └── Tarif Sistemi (lokasyon yeni tarifler açar)
    └── Görsel Progression (lokasyon fırın görünümünü değiştirir)

Upgrade Ağacı
    ├── Offline Üretim (kapasite + süre upgradeten gelir)
    ├── Müşteri Sistemi (vitrin genişliği, sabır bonusu)
    └── Teslimat Sistemi (sipariş kapasitesi)

Çalışan Sistemi
    └── Ekonomi Dengesi (günlük maaş = altın tüketimi)
    └── Üretim Hızı (hamurcu, fırın ustası etkileri)

Koleksiyon Sistemi
    └── Tarif Sistemi (her tarif bir koleksiyon girişi)
    └── Lokasyon Sistemi (bazı tarifler lokasyona bağlı)
    └── Sezonsal Etkinlikler (festival tarifleri koleksiyona girer)

Ekonomi (Altın + Rozet)
    └── Tüm upgrade maliyetleri
    └── Çalışan maaşları
    └── Lokasyon açma maliyetleri
    └── Rozet: VIP Lounge, dekorasyon, offline süre uzatma
```

---

## 8. ACCEPTANCE CRITERIA

### Temel Döngü
- [ ] Oyuncu hamur yoğurma gesturunu 3 kez yapınca hamur "hazır" durumuna geçer
- [ ] Hazır hamur fırına sürüklenince pişirme zamanlayıcısı başlar
- [ ] Zamanlayıcı bitince ekmek vitrine taşınabilir hale gelir
- [ ] Müşteri tap'ında altın animasyonu oynar ve sayaç artar

### Offline Üretim
- [ ] Uygulama kapatılıp 1 saat sonra açılınca doğru miktarda ekmek üretilmiş olur
- [ ] 8 saatten uzun offline kalınca cap aşılmaz, fazla üretim olmaz
- [ ] Geri dönüş animasyonu "X ekmek hazır!" mesajıyla tetiklenir

### Upgrade Sistemi
- [ ] Her upgrade seviyesinde maliyet `base * 3^(n-1)` formülüyle eşleşir
- [ ] Max seviyeye ulaşan upgrade "maxlandı" göstergesine geçer
- [ ] Upgrade efekti anında aktif olur (pişirme hızı, kapasite vs.)

### Müşteri Sistemi
- [ ] Süresi dolan sipariş panodan kaybolur ve memnuniyet düşer
- [ ] VIP müşteri spawn oranı upgrade öncesi %5, VIP Lounge sonrası %7.5 civarındadır
- [ ] Geç teslimatta altın %50 indirimle teslim edilir

### Lokasyon Sistemi
- [ ] Yeni lokasyon açılınca eski lokasyon üretmeye devam eder
- [ ] Yeni lokasyona özgü tarifler tarif listesinde görünür hale gelir
- [ ] Lokasyon açılış koşulu (altın + seviye) tam karşılanmadan buton aktif olmaz

### Ekonomi
- [ ] Günlük çalışan maaşları her gerçek gün düşülür
- [ ] Altın yetersizse çalışan efekti devre dışı kalır, UI bunu gösterir
- [ ] Rozet harcaması onay ekranı olmadan gerçekleşmez
