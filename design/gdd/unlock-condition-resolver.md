# Unlock/Condition Resolver GDD

**Sistem:** #14 / 29
**Kategori:** Core — MVP
**Durum:** Draft
**Bağımlılıklar:** Recipe System, Upgrade Tree, Location/Prestige System

---

## 1. Overview

Unlock/Condition Resolver, oyundaki tüm kilit açma koşullarını merkezi olarak değerlendiren servis sistemidir. Recipe System, Upgrade Tree ve Location/Prestige System kilit koşullarını bu sisteme bildirir; Resolver bu koşulların sağlanıp sağlanmadığını oyun durumuna göre hesaplar ve ilgili sistemi sinyal ile bilgilendirir. Üç koşul tipi desteklenir: `sale_count` (belirli sayıda ekmek satılması), `location_unlocked` (bir şehrin açılması) ve `ingredient_owned` (özel malzeme edinilmesi). Resolver veri deposu değil servis katmanıdır — koşul verisini ilgili sistemden alır, oyun durumunu Economy/Recipe/Location'dan sorgular, sonucu döndürür.

## 2. Player Fantasy
<!-- TBD -->

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
