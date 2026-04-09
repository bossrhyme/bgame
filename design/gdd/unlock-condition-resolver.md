# Unlock/Condition Resolver GDD

**Sistem:** #14 / 29
**Kategori:** Core — MVP
**Durum:** Draft
**Bağımlılıklar:** Recipe System, Upgrade Tree, Location/Prestige System

---

## 1. Overview

Unlock/Condition Resolver, oyundaki tüm kilit açma koşullarını merkezi olarak değerlendiren servis sistemidir. Recipe System, Upgrade Tree ve Location/Prestige System kilit koşullarını bu sisteme bildirir; Resolver bu koşulların sağlanıp sağlanmadığını oyun durumuna göre hesaplar ve ilgili sistemi sinyal ile bilgilendirir. Üç koşul tipi desteklenir: `sale_count` (belirli sayıda ekmek satılması), `location_unlocked` (bir şehrin açılması) ve `ingredient_owned` (özel malzeme edinilmesi). Resolver veri deposu değil servis katmanıdır — koşul verisini ilgili sistemden alır, oyun durumunu Economy/Recipe/Location'dan sorgular, sonucu döndürür.

## 2. Player Fantasy

**Temel his:** Oyuncu Unlock/Condition Resolver'ı hiç duymaz — ama her "yeni tarif açıldı!" anının arkasında o vardır. Koşul sağlandığı an tetiklenen bildirim, animasyon ve ses; tüm bunları zamanında, doğru şekilde ateşleyen sessiz bir motor.

**Tasarımcı perspektifi:** Tüm unlock koşulları tek bir yerde tanımlanır ve test edilir. Yeni bir koşul tipi eklemek için Recipe System veya Location System'e dokunmak gerekmez — sadece Resolver'a yeni bir tip eklenir.

**Kaçınılması gereken:** Koşul değerlendirmesinin farklı sistemlere dağılması. Her sistem kendi unlock mantığını yazarsa tutarsızlık ve test güçlüğü kaçınılmaz olur.

## 3. Detailed Rules

### Koşul Tipleri

| Tip | Açıklama | Gerekli Veri |
|-----|----------|-------------|
| `sale_count` | Belirli sayıda ekmek satılması | `target_category`, `required_count` |
| `location_unlocked` | Belirli bir şehrin açılmış olması | `required_location_id` |
| `ingredient_owned` | Belirli malzemeden en az 1 adet sahibi olunması | `required_ingredient_id` |

### Değerlendirme Akışı

1. İlgili sistem (Recipe, Location, vb.) `evaluate(condition)` çağırır
2. Resolver koşul tipine göre ilgili sistemi sorgular
3. Koşul sağlandıysa `true` döner → çağıran sistem `LOCKED → AVAILABLE` geçişini yapar
4. Resolver sinyal yayımlamaz; sadece bool döndürür — bildirim çağıran sistemin sorumluluğundadır

### AND Mantığı

- Bir içerik birden fazla koşul içeriyorsa tüm koşulların `true` olması gerekir
- `evaluate_all(conditions: Array[UnlockCondition]) → bool`

### Tetikleme Zamanlaması

- `sale_count`: Her satış sonrası ilgili tarifler için evaluate çağrılır
- `location_unlocked`: Lokasyon açılış sinyalinde ilgili tarifler için evaluate çağrılır
- `ingredient_owned`: Malzeme envantere girdiğinde ilgili tarifler için evaluate çağrılır

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
