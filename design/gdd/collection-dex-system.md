# Collection/Dex System GDD

**Sistem:** #18 / 29
**Kategori:** Progression — Vertical Slice
**Durum:** Designed
**Bağımlılıklar:** Recipe System (#10), Location/Prestige System (#17), Content Database (#2)

---

## 1. Overview

Collection/Dex System, oyuncunun açtığı tarifleri takip eden ve tamamlanma ilerleme bilgisi sunan koleksiyon katmanıdır. Her tarif açıldığında koleksiyona eklenir; kategori bazlı tamamlanma yüzdesi hesaplanır. Tüm kategori tarifleri toplandığında `category_completed` sinyali yayılır ve oyuncu bildirim alır. Sistem veri tutmaz — kayıt yalnızca açılan tariflerin ID listesinden ibarettir; diğer her şey ContentRegistry'den anlık hesaplanır.

## 2. Player Fantasy

**Temel his:** "Koleksiyon tamamlandı!" — "Temel Ekmekler" kategorisindeki son tarifi açtığında ekrana özel bir kutlama bildirimi geliyor. Oyuncu bir seti tamamlamanın tatminini yaşıyor.

**İkincil his:** İlerleme görünürlüğü. "4/6 temel tarif" ifadesi, oyuncunun ne kadar kaldığını her zaman görmesini sağlar. Sradaki tarif açılımı motivasyonunu canlı tutar.

**Kaçınılması gereken:** "Neden topladım?" sorusu. Koleksiyonun anlamı olmak zorunda değil — sadece görünür olması yeterli. Bonus, tamamlanma hissini pekiştirmek içindir, zorlamak değil.

## 3. Detailed Rules

### Koleksiyon Mantığı

- `RecipeManager.recipe_unlocked(recipe_id)` sinyali dinlenir.
- Açılan recipe_id koleksiyona eklenir (ikinci kez eklenmez).
- Her eklemede ilgili kategorinin tamamlanma durumu kontrol edilir.
- Kategori tamamlanırsa `category_completed` sinyali yayılır (bir kez).
- Tüm tarif açılırsa `all_recipes_collected` sinyali yayılır (bir kez).

### Tamamlanma Hesabı

```
category_completion = collected_in_category / total_in_category
total_completion    = total_collected / total_recipes
```

ContentRegistry'deki `get_all_recipes()` gerçek tarif sayısını verir.

### Kategori Tamamlanma Bonusu

Kategori tamamlanınca `NotificationManager` üzerinden INFO bildirimi gönderilir:
> "Tüm [KategoriAdı] tarifleri toplandı!"

Altın bonusu yoktur — tamamlanma hissi ödüldür.

## 4. Formulas

### F-1: Kategori Tamamlanma

```
category_completion(C) = |collected ∩ recipes_in(C)| / |recipes_in(C)|
```

Değer aralığı: [0.0, 1.0]. Boş kategori → 0.0.

### F-2: Genel Tamamlanma

```
total_completion = |collected| / |all_recipes|
```

ContentRegistry yoksa → 0.0 güvenli varsayılan.

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| ContentRegistry null ise | completion = 0.0; push_warning |
| Aynı recipe_id iki kez gelirse | İkincisi yoksayılır; sinyal tekrar yayılmaz |
| Prestij sırasında tarifler sıfırlanırsa | Koleksiyon korunur (prestij sonrası yeniden açma güdüsü) |
| Boş kategori (0 tarif) | completion = 0.0; category_completed sinyali yayılmaz |

### Prestij Notu

GDD Location/Prestige §3 Kural 4'te belirtildiği üzere tarifler `reset_all_to_locked()` ile sıfırlanır; ancak CollectionDexSystem kendi `_collected` setini **sıfırlamaz**. Koleksiyon tarihsel bir kayıttır — prestijden etkilenmez.

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Recipe System (#10)** | `recipe_unlocked` sinyali + ContentRegistry üzerinden tarif listesi |
| **Content Database (#2)** | `get_all_recipes()` — toplam tarif sayısı ve kategori bilgisi |
| **Location/Prestige System (#17)** | Prestij koleksiyonu sıfırlamaz (bağımlılık yok; tasarım notu) |

## 7. Tuning Knobs

| Parametre | Değer | Notlar |
|-----------|-------|--------|
| Kategori tamamlanma bildirimi | INFO | NotificationManager.Priority.INFO; değiştirilebilir |
| Tüm tarif tamamlanma bildirimi | INFO | Aynı kanal |

## 8. Acceptance Criteria

- [ ] Tarif açılınca `collection_updated` sinyali yayılıyor
- [ ] `get_category_completion(BASIC)` doğru 0.0–1.0 değer döndürüyor
- [ ] Kategorideki son tarif açılınca `category_completed` sinyali bir kez yayılıyor
- [ ] Tüm tarifler toplandığında `all_recipes_collected` sinyali yayılıyor
- [ ] Prestij sonrası koleksiyon korunuyor (sıfırlanmıyor)
- [ ] Aynı recipe_id iki kez geldiğinde sinyal tekrar yayılmıyor
- [ ] GUT testleri: completion hesabı, sinyal yayımı, serialize/deserialize
