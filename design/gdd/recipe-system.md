# Recipe System

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-04
> **Implements Pillar**: Progression — "Her yeni tarif bir keşif, her yeni şehir bir gurur"

## Overview

Recipe System, Ekmek Ustası'ndaki 40+ ekmeğin tüm statik verilerini — pişirme süresi, altın
değeri, kategori, kilit koşulları ve gereken özel malzemeler — tanımlayan ve yöneten progression
sistemidir. Her tarif bir `RecipeData` resource'udur (`ContentDatabase` şeması); Recipe System bu
verilerin üstüne **unlock durumunu** (kilitli / açık / araştırılabilir) ve **malzeme stoğunu**
(özel malzemelerin kaç adet sahip olunduğunu) ekler. Tarif kilitleri üç yoldan açılır: belirli
sayıda ekmek satmak, gerekli lokasyonu açmak veya özel bir malzeme toplamak. Hangi tariflerin
kilidinin açılma koşulunun sağlandığını değerlendirmek `Unlock/Condition Resolver (D-14)`
sorumluluğundadır; bu sistem yalnızca "bu tarifin koşulları neler" verisini sağlar.

## Player Fantasy

Yeni bir tarif açıldığında ekran bir an durur — küçük bir "keşif" animasyonu, tarifin adı ve
görseli. "Fransız Baguette." Şimdiye kadar yaptığın her şeyin ötesinde bir şey. Onu ilk kez
fırına attığında biraz daha dikkatli izlersin. Hasatta altın öncekinden fazla. Bu duygu — yeni
bir şeyi öğrenmek, onu rafına koymak, koleksiyonunda görmek — oyunun ikincil döngüsünü ayakta
tutar. Malzeme toplamak da bu hissin parçası: belirli bir malzemeyi bulunca "artık o tarifi
yapabilirim" düşüncesi kapıyı açar. Recipe System, oyuncunun "daha fazlası var" güdüsünü canlı
tutar; her yeni lokasyon beraberinde yeni tarifler getirir, her yeni tarif yeni bir gurur
noktası olur.

## Detailed Rules

### Core Rules

1. Her tarif bir `RecipeData` resource'udur; tüm statik veriler bu resource içinde tanımlanır.
2. Tarif durumu üç değerden birini alır: `LOCKED` (koşul sağlanmamış), `AVAILABLE` (koşul
   sağlandı, henüz açılmadı), `UNLOCKED` (oyuncu açtı ve kullanabilir).
3. `AVAILABLE` → `UNLOCKED` geçişi yalnızca oyuncunun onayıyla gerçekleşir (tarif açma ekranı).
4. Bir tarif bir kez açıldıktan sonra kilitlenemez (kalıcı progression).
5. Birden fazla unlock koşulu bir arada kullanılabilir; tüm koşullar AND mantığıyla değerlendirilir.
6. Koşul değerlendirmesi `UnlockConditionResolver (D-14)` tarafından yapılır; bu sistem yalnızca
   koşul verisini sağlar, değerlendirmez.

### Recipe Categories

Her kategori bir lokasyona ve ekmek kültürüne karşılık gelir. Toplam 5 kategori:

| Kategori ID | Görünen Ad    | Bağlı Lokasyon | Tier Aralığı | Tarif Sayısı |
|-------------|---------------|----------------|--------------|--------------|
| `basic`     | Temel Ekmekler| Başlangıç      | 1            | 6            |
| `wheat`     | Tam Buğday    | İç Anadolu     | 2            | 8            |
| `sweet`     | Tatlı & Özel  | İstanbul       | 2–3          | 8            |
| `french`    | Fransız       | Paris          | 3            | 10           |
| `italian`   | İtalyan       | Roma           | 4            | 8            |

**Toplam: 40 tarif** (tuning knobs'ta genişletilebilir)

Her `RecipeData` şu alanları içerir:

```
id: StringName            # "baguette_classic"
display_name: String      # "Klasik Baguette"
category: StringName      # "french"
tier: int                 # 1–4
base_bake_time: float     # saniye cinsinden
base_gold_value: float    # formülden türer veya override edilir
unlock_conditions: Array[UnlockCondition]
required_ingredient: StringName  # "" ise gerekmez
ingredient_cost: int      # kaç adet malzeme harcanır
```

### Unlock Conditions

Üç unlock koşulu tipi desteklenir. Her tarif bunlardan birini veya birden fazlasını kullanabilir.

#### Tip 1 — Satış Sayısı (`sale_count`)
Oyuncu herhangi bir tariften veya belirli bir kategoriden X adet satar.

```
condition_type: "sale_count"
target_category: StringName  # "" ise herhangi tarif
required_count: int
```

#### Tip 2 — Lokasyon Açma (`location_unlocked`)
Oyuncu belirli bir şehri/lokasyonu açar (D-17 bağlantısı).

```
condition_type: "location_unlocked"
required_location_id: StringName
```

#### Tip 3 — Özel Malzeme (`ingredient_owned`)
Oyuncu belirli bir özel malzemeden en az 1 adet edinir.

```
condition_type: "ingredient_owned"
required_ingredient_id: StringName
```

**Malzeme Kazanma Yolu:** Özel malzemeler reklam izleme (rewarded ad) veya günlük görev
tamamlama ile kazanılır. Malzeme düşürme loot tablosu `ContentDatabase` altında yönetilir.

### Interactions with Other Systems

| Sistem | Etkileşim Yönü | Açıklama |
|--------|----------------|----------|
| Unlock/Condition Resolver (D-14) | → | Koşul verisi sağlar; D-14 değerlendirir |
| Baking System (D-09) | ← | Açık tariflerin `base_bake_time` değerini sorgular |
| Gold/Economy System (D-05) | ← | Açık tariflerin `gold_value` değerini sorgular |
| Location System (D-17) | ← | Lokasyon açılınca D-14 üzerinden koşul tetikler |
| Ad/Reward System (D-22) | ← | Malzeme ödülü RecipeSystem'e iletilir |
| Daily Quest System (D-23) | ← | Görev tamamlama malzeme ödülü verebilir |
| ContentDatabase | → | Tüm `RecipeData` resource'ları buradan yüklenir |

## Formulas

### Tarif Altın Değeri

```
gold_value = base_gold_value * (1 + tier * 0.5)
```

| Değişken         | Tip   | Açıklama                                          |
|------------------|-------|---------------------------------------------------|
| `base_gold_value`| float | RecipeData içinde tanımlanan ham altın değeri      |
| `tier`           | int   | 1–4 arası; RecipeData içinde tanımlı               |

**Örnekler:**

| Tarif               | base_gold | tier | gold_value |
|---------------------|-----------|------|------------|
| Beyaz Ekmek         | 10        | 1    | 15         |
| Tam Buğday Somun    | 10        | 2    | 20         |
| Croissant           | 10        | 3    | 25         |
| Focaccia            | 10        | 4    | 30         |

> `base_gold_value` RecipeData içinde override edilebilir. Formül override yoksa uygulanır.

### Pişirme Süresi

Pişirme süresi formüle dayanmaz; her tarifin `base_bake_time` değeri doğrudan RecipeData'da
tanımlıdır. Tuning sırasında manuel ayarlanır.

### Malzeme Kazanım Olasılığı

Malzeme drop oranları `ContentDatabase/ingredients_loot_table.tres` içinde tanımlanır.
Bu GDD kapsamı dışında; Ad/Reward System (D-22) ve Daily Quest System (D-23) GDD'leri
detaylandırır.

## Edge Cases

| Durum | Çözüm |
|-------|-------|
| Oyuncu lokasyonu açar ama AVAILABLE tarifi fark etmez | Badge/bildirim UI'da gösterilir; oyuncu geçmişteki AVAILABLE tarifleri cookbook'tan bulabilir |
| Malzeme bir tarif için harcandıktan sonra unlock koşulu yeniden sağlanamıyorsa | Malzeme koşulu "en az 1 sahip ol" şeklindedir; tarifi açtıktan sonra malzeme düşer, koşul tekrar aranmaz |
| Aynı malzeme birden fazla tarif için gerekiyorsa | Her tarif bağımsız değerlendirilir; malzeme stack'lenir (max stok: tuning knob) |
| Koşul türlerinden biri eksik/null ise | Resource yükleme sırasında doğrulanır; eksik koşul hata loglar ve tarif LOCKED kalır |
| İleride yeni koşul tipi eklenirse | `UnlockCondition` base resource'u extend edilir; mevcut tarifler etkilenmez |
| 40+ tarif koleksiyon ekranında performans | Tarif listesi lazy yüklenir; sadece görünen kartlar render edilir |

## Dependencies

| Sistem | Bağımlılık Türü | Açıklama |
|--------|-----------------|----------|
| ContentDatabase | Zorunlu | Tüm RecipeData resource'larını sağlar |
| Unlock/Condition Resolver (D-14) | Zorunlu | Koşulları değerlendirir; bu sistem olmadan unlock tetiklenemez |
| Baking System (D-09) | Tüketici | Pişirme süresi ve tarif geçerliliği sorgular |
| Gold/Economy System (D-05) | Tüketici | Altın değeri sorgular |
| Location System (D-17) | Bağımlı | Lokasyon açılma event'i koşul değerlendirmesini tetikler |
| Ad/Reward System (D-22) | Bağımlı | Malzeme ödüllerini iletir |
| Daily Quest System (D-23) | Bağımlı | Malzeme ödülü verebilir |

## Tuning Knobs

| Parametre | Varsayılan | Açıklama |
|-----------|------------|----------|
| `total_recipe_count` | 40 | Toplam tarif sayısı; yeni kategori eklenebilir |
| `tier_gold_multiplier` | 0.5 | Her tier başına altın artış çarpanı |
| `max_ingredient_stack` | 10 | Bir malzemeden maksimum stok |
| `sale_count_thresholds` | [50, 100, 200, 500] | Satış koşullu unlock'larda referans eşikler |
| `ingredient_drop_rates` | ingredients_loot_table.tres | Malzeme drop olasılıkları (D-22/D-23) |
| `unlock_notification_duration` | 3.0s | "Yeni tarif açıldı" animasyon süresi |

## Visual/Audio Requirements

- **Unlock animasyonu**: Yeni tarif açıldığında kısa "keşif" animasyonu — ekmek görseli belirir,
  isim fade-in, altın ve pişirme süresi gösterilir.
- **Malzeme ikonu**: Her özel malzemenin benzersiz ikonu olmalı; `assets/art/ingredients/` altında.
- **Ses**: Unlock anında özel bir "ding" sesi (Audio Bus: SFX). Animasyon tamamlanınca oyun devam eder.
- **AVAILABLE badge**: Tarif koleksiyon ekranında açılabilir tariflere küçük parlayan badge.

## UI Requirements

- **Tarif Koleksiyonu Ekranı**: 5 kategoriye ayrılmış grid; LOCKED tarifler gri/kilitli görünür.
- **Unlock Koşulu Gösterimi**: LOCKED tarifin üzerine dokunulunca koşul bilgisi görünür
  (örn. "Paris'i aç" veya "50 Beyaz Ekmek sat").
- **Malzeme Envanteri**: Ayrı panel veya koleksiyon ekranında alt bar; mevcut stok gösterilir.
- **Unlock Onay Ekranı**: AVAILABLE tarife dokunulunca onay istenir; malzeme gerekiyorsa
  "1 Yaban Mersini harcayacaksın" uyarısı çıkar.

## Acceptance Criteria

- [ ] 40 tarif ContentDatabase'de `RecipeData` resource olarak tanımlanmış
- [ ] Her tarif 5 kategoriden birine ait; kategori ID tutarlı
- [ ] `gold_value = base_gold_value * (1 + tier * 0.5)` formülü tüm tariflerde doğru çalışıyor
- [ ] 3 koşul tipi (sale_count, location_unlocked, ingredient_owned) unlock flow'unu tetikliyor
- [ ] Koşul karşılandığında tarif `AVAILABLE`'a geçiyor, oyuncu onayı olmadan `UNLOCKED` olmuyor
- [ ] Malzeme reklam/günlük görev ödülü olarak envantere düşüyor
- [ ] Malzeme gerekli tarifte harcama onayı alınıyor
- [ ] Unlock animasyonu ve ses tetikleniyor
- [ ] Koleksiyon ekranı 40 tarifi kategorilere göre listeliyor; LOCKED/AVAILABLE/UNLOCKED durumları görsel olarak ayrışıyor
- [ ] GUT testleri: `gold_value` formülü, koşul AND mantığı, malzeme stok limiti

## Open Questions

- D-14 (Unlock/Condition Resolver) GDD'si yazılmadı — bu sistemden önce yazılmalı mı, yoksa
  bu GDD referans olarak yeterli mi?
- `sale_count` koşulunda sayım kapsamı: "tüm satışlar toplamı" mı yoksa "o kategoriden satışlar"
  mı? Şu an iki seçenek de destekleniyor (`target_category: ""` ise hepsi sayılır).
- Malzeme envanteri cap (max 10) balance açısından yeterli mi? D-22/D-23 GDD'leri yazılmadan
  kesin karar verilemez.
