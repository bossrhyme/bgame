# Sertifikasyon Kontrol Listesi — Ekmek Ustası / Bread Master

**Sprint:** S7-05  
**Hazırlayan:** release-manager  
**Tarih:** 2026-04-28  
**Hedef Yayın:** Sprint 8 sonu (Android önce · iOS S8 sonu veya S9)

---

## Durum Etiketleri

| Etiket | Anlam |
|--------|-------|
| ✅ Hazır | Tamamlandı, doğrulandı |
| 🔄 Devam | Çalışmalar sürüyor |
| ⏳ Bekliyor | Önkoşul tamamlanmadı |
| ❌ Yok / Yok sayılacak | Geçerli değil / Bilinçli kapsam dışı |

---

## Google Play — Android

### 1. Teknik Gereksinimler

| # | Kriter | Durum | Notlar |
|---|--------|-------|--------|
| T1 | Target API ≥ Android 14 (API 34) | ⏳ Bekliyor | Export template → Android SDK 34 hedeflenecek |
| T2 | 64-bit ARM (arm64-v8a) desteği | ⏳ Bekliyor | Godot export: arm64 seçili olmalı |
| T3 | `AndroidManifest.xml` — izinler minimum | 🔄 Devam | AdMob için INTERNET + AD_ID izni gerekli |
| T4 | App Bundle (.aab) formatı | ⏳ Bekliyor | Godot 4.6 .aab export |
| T5 | Keystore imzalama | ⏳ Bekliyor | Release keystore oluşturulacak (ASLA commit edilmez) |
| T6 | Versiyonlama: versionCode artan, versionName semver | ⏳ Bekliyor | project.godot → `config/version` |
| T7 | Uygulama başlatma ikonu (512×512 PNG) | ⏳ Bekliyor | Art Director'dan teslim bekleniyor |
| T8 | Feature graphic (1024×500 PNG) | ⏳ Bekliyor | Art Director'dan teslim bekleniyor |

### 2. İçerik Politikası

| # | Kriter | Durum | Notlar |
|---|--------|-------|--------|
| C1 | Content Rating anketi dolduruldu (IARC) | ⏳ Bekliyor | Play Console → Content Rating |
| C2 | Reklamlı uygulama beyanı ("contains ads") | ⏳ Bekliyor | Store listing → App content |
| C3 | Hedef kitle çocuk değil (13+) | ✅ Hazır | Gameplay / konu: yetişkin casual |
| C4 | Gerçek para işlemi yok (IAP yok) | ✅ Hazır | Monetizasyon: yalnızca rewarded ad |
| C5 | Yanıltıcı reklam yok | ✅ Hazır | Stub → gerçek AdMob test ID |

### 3. Gizlilik & Veri Güvenliği

| # | Kriter | Durum | Notlar |
|---|--------|-------|--------|
| D1 | Data Safety formu dolduruldu | ⏳ Bekliyor | AdMob için Advertising ID paylaşımı beyan |
| D2 | Privacy policy URL aktif | ⏳ Bekliyor | `https://bossrhyme.github.io/breadmaster/privacy` |
| D3 | GDPR uyumluluk (AB kullanıcıları) | ⏳ Bekliyor | Google UMP SDK entegrasyonu (S8) |
| D4 | Çocuk koruma — COPPA uyumluluk | ✅ Hazır | 13+ hedef; çocuk içeriği yok |

### 4. Store Listing

| # | Kriter | Durum | Notlar |
|---|--------|-------|--------|
| S1 | Başlık (≤50 karakter) | ✅ Hazır | "Ekmek Ustası — İdol Fırın Simülasyonu" (38 kar) |
| S2 | Kısa açıklama (≤80 karakter) | ✅ Hazır | 79 karakter (TR) |
| S3 | Uzun açıklama (≤4.000 karakter) | ✅ Hazır | ~1.050 karakter (TR), genişletilebilir |
| S4 | En az 2 telefon ekran görüntüsü | ⏳ Bekliyor | UI polish sonrası çekilecek |
| S5 | Kategori seçildi | ✅ Hazır | Games → Casual → Simulation |
| S6 | E-posta iletişim adresi | ⏳ Bekliyor | support@ adresi gerekli |

---

## Apple App Store — iOS

> **Not:** iOS sertifikasyonu Sprint 8 hedefidir. Aşağıdaki liste hazırlık için oluşturulmuştur.

### 1. Teknik Gereksinimler

| # | Kriter | Durum | Notlar |
|---|--------|-------|--------|
| T1 | Xcode build + IPA imzalama | ⏳ Bekliyor | Apple Developer Program hesabı gerekli |
| T2 | iOS 14.0 minimum deployment target | ⏳ Bekliyor | Godot iOS export ayarı |
| T3 | arm64 (Apple Silicon + A-serisi) desteği | ⏳ Bekliyor | Godot 4.6 varsayılan |
| T4 | App Store Connect kaydı oluşturuldu | ⏳ Bekliyor | Geliştirici hesabı: $99/yıl |
| T5 | Provisioning Profile + Signing Certificate | ⏳ Bekliyor | Distribution certificate gerekli |
| T6 | Bundle ID kayıtlı | ⏳ Bekliyor | com.bossrhyme.breadmaster |

### 2. App Store Review Guidelines

| # | Kriter | Durum | Notlar |
|---|--------|-------|--------|
| R1 | Çökmesiz build (TestFlight doğrulaması) | ⏳ Bekliyor | Fiziksel iPhone test cihazı gerekli |
| R2 | Reklam yüklenemezse graceful fallback | ✅ Hazır | `notify_ad_failed()` → devam et |
| R3 | Gerçek para talep etmiyor (IAP yoksa SKStoreProductViewController yok) | ✅ Hazır | |
| R4 | App sadece beyan edilen işlevi yapıyor | ✅ Hazır | Fırın simülasyonu, net kapsam |
| R5 | Arka plan işleme talep etmiyor | ✅ Hazır | Offline üretim → zaman damgası farkı |
| R6 | Push notification kullanmıyor | ✅ Hazır | Bildirim sistemi yok |
| R7 | Kullanıcı verisini açıkça toplamıyor | ✅ Hazır | Yalnızca AdMob Advertising ID |

### 3. Gizlilik

| # | Kriter | Durum | Notlar |
|---|--------|-------|--------|
| P1 | Privacy Nutrition Label dolduruldu | ⏳ Bekliyor | App Store Connect → Privacy |
| P2 | Advertising Data beyanı (AdMob için) | ⏳ Bekliyor | Identifier → Advertising Data: Used |
| P3 | Privacy policy URL aktif | ⏳ Bekliyor | Aynı URL — Google Play ile ortak |
| P4 | ATT (App Tracking Transparency) | ⏳ Bekliyor | iOS 14.5+ → `AppTrackingTransparency.requestTrackingAuthorization()` — S8 |

### 4. Store Listing

| # | Kriter | Durum | Notlar |
|---|--------|-------|--------|
| S1 | Başlık (≤30 karakter) | ✅ Hazır | "Ekmek Ustası" (12 kar) veya "Bread Master" (12 kar) |
| S2 | Alt başlık (≤30 karakter) | ⏳ Bekliyor | "İdol Fırın Simülasyonu" / "Idle Bakery Simulation" |
| S3 | Açıklama (≤4.000 karakter) | ✅ Hazır | ~1.020 karakter (EN) |
| S4 | Anahtar kelimeler (≤100 karakter) | ✅ Hazır | `bakery,bread,idle,simulation,...` |
| S5 | En az 3 iPhone ekran görüntüsü (6.5" veya 6.7") | ⏳ Bekliyor | UI polish sonrası |
| S6 | iPad ekran görüntüsü | ⏳ Bekliyor | 12.9" iPadPro boyutu |
| S7 | Destek URL | ⏳ Bekliyor | support@ veya GitHub Issues |
| S8 | Pazarlama URL (opsiyonel) | ❌ Yok | — |

---

## Ortak Gereksinimler

| # | Kriter | Durum | Notlar |
|---|--------|-------|--------|
| O1 | AdMob App ID kayıtlı + gerçek ID alındı | ⏳ Bekliyor | Gerçek ID → environment variable; ASLA commit edilmez |
| O2 | AdMob hesabı ödeme bilgisi tamamlandı | ⏳ Bekliyor | AdMob Console |
| O3 | Privacy policy hosting | ⏳ Bekliyor | GitHub Pages önerisi |
| O4 | Support e-posta aktif | ⏳ Bekliyor | support@bossrhyme.com veya benzeri |
| O5 | İkon varlıkları hazır (tüm boyutlar) | ⏳ Bekliyor | Art Director teslim |
| O6 | Feature graphic / Banner hazır | ⏳ Bekliyor | Art Director teslim |
| O7 | Versiyon: 1.0.0 (ilk yayın) | 🔄 Devam | project.godot versiyonlama |
| O8 | Crash-free rate ≥ %99 (ilk 30 gün hedefi) | ⏳ Bekliyor | Firebase Crashlytics (S8 opsiyonel) |

---

## Kritik Yol — Android Yayını (Sprint 8 Hedefi)

```
T1 Android API 34 target  →  T2 arm64  →  T5 Keystore
          ↓
     T3 Manifest izinler  →  D1 Data Safety formu
          ↓
     D2 Privacy policy hosting  →  S4 Ekran görüntüleri
          ↓
          D3 GDPR UMP SDK (S8)
          ↓
     İlk internal test track yüklemesi
          ↓
     Açık test → Kapalı test → Üretim
```

---

## Sprint 8 Devir Listesi (Carryover)

- [ ] T1–T8 Android teknik hazırlık
- [ ] D1–D3 Veri güvenliği beyanları
- [ ] O1 Gerçek AdMob ID alımı + environment config
- [ ] O3 Privacy policy yayınlanması
- [ ] Ekran görüntüsü çekimi (UI polish sonrası)
- [ ] İlk internal build yüklemesi (Google Play internal testing)
- [ ] iOS ATT entegrasyonu (P4)
- [ ] Tüm ⏳ bekleyen maddelerin tamamlanması
