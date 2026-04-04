# Engine Upgrade Policy — Godot

**Geçerli sürüm:** Godot 4.6 (pinned 2026-02-12)
**Son gözden geçirme:** 2026-04-04

---

## Politika

Bu proje Godot sürümünü **kasıtlı olarak sabitler.** Engine güncellemesi otomatik
değildir; her yükseltme bir ADR ile belgelenir ve açıkça onaylanır.

## Yükseltme Kriterleri

Bir engine yükseltmesi ancak **tüm** aşağıdaki koşullar sağlandığında yapılır:

1. **Gereklilik**: Hedef sürüm mevcut üretilemez bir özellik sağlıyor VEYA aktif güvenlik açığı kapatılıyor.
2. **Stabilite**: Hedef sürüm en az 30 gün `stable` kanalda kaldı.
3. **Uyumluluk**: Migration guide okundu; breaking change'ler listelendi.
4. **Test geçişi**: Tüm GUT testleri yeni sürümde yeşil.
5. **Onay**: `technical-director` onayladı, ADR oluşturuldu.

## Yükseltme Prosedürü

1. `technical-director` yeni sürümü değerlendirir → ADR taslağı yazar.
2. Breaking change listesi `lead-programmer`'a iletilir.
3. Prototip branch'te yükseltme yapılır, testler koşulur.
4. Testler yeşilse → ADR onaylanır → main branch'e merge edilir.
5. `docs/engine-reference/godot/VERSION.md` güncellenir.
6. `technical-preferences.md` engine sürümü güncellenir.

## Versiyon Atlama Yasağı

Ara sürümler atlanamaz (örn: 4.6 → 4.8 doğrudan). Her minor sürüm için ayrı
migration değerlendirmesi yapılır.

## Şu An Bilinen Gelecek Riskler

| Sürüm | Beklenen | Risk | Not |
|-------|----------|------|-----|
| Godot 4.7 | ~Mid 2026 | Orta | Henüz release notları yok |
| Godot 5.x | 2027+ | Yüksek | GDScript 3.0 breaking changes bekleniyor |
