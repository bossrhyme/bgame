# Settings & Preferences

> **Status**: In Design
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-04
> **Implements Pillar**: Platform Comfort — "Her cihazda doğru hissettiren kontroller"

## Overview

Settings & Preferences, oyuncunun Ekmek Ustası'nı kendi cihazına ve tercihlerine göre
özelleştirdiği yapılandırma sistemidir. Ses mimarisinin üç katmanını (Müzik, SFX, Ambient)
bağımsız olarak kontrol eder; bildirim tercihlerini yönetir; pil ömrü için performans modunu
seçmeye olanak tanır; oyun dilini belirler ve gerektiğinde kayıt verisini sıfırlama imkânı
sunar. Ayarlar anında geçerli olur ve cihazda kalıcı olarak saklanır.

### Kapsam

| Grup | İçerik |
|------|--------|
| **Ses** | Müzik vol + SFX vol + Ambient vol (slider) + Mute toggle |
| **Bildirimler** | Offline üretim / Sipariş hazır / Promosyon (toggle per type) |
| **Performans** | FPS kilidi (30 / 60) + Enerji Tasarrufu modu |
| **Dil** | Türkçe / İngilizce dropdown |
| **Veri** | Kayıt Sil (onaylı dialog) |

## Player Fantasy

Ayarlar ekranı oyuncuya "bu oyun benim kurallarıma göre çalışıyor" hissini verir. Sesi tam
istediği gibi ayarlamak — ambiyansı açık, telefon zil sesini kapatmak için SFX'i kısık tutmak
— ASMR deneyimini kişiselleştirir. Bildirim tercihleri sayesinde oyuncu "hazır olduğunda
bana haber ver ama spam yapma" kontrolünü elinde tutar. Performans modu ise "bu telefonu
yorma" güvencesi verir; oyun pili tüketmeden çalışır.

## Detailed Design

### Core Rules

#### Ses

| Değişken | Tip | Varsayılan | Açıklama |
|----------|-----|------------|----------|
| `music_volume` | int 0–100 | 80 | Müzik bus volume |
| `sfx_volume` | int 0–100 | 80 | SFX bus volume |
| `ambient_volume` | int 0–100 | 70 | Ambient bus volume |
| `master_mute` | bool | false | True iken tüm çıkış sıfır; slider değerleri korunur |

- Her slider değişikliği anında `AudioServer` bus volume'una yansır (linear → log dönüşümü)
- `master_mute` açıkken slider'lar görsel olarak disabled; kapatılınca önceki değerler geri döner
- Değerler `ConfigFile` ile `user://settings.cfg` dosyasına kaydedilir

#### Bildirimler

| Değişken | Tip | Varsayılan | Açıklama |
|----------|-----|------------|----------|
| `notif_production` | bool | true | Offline üretim tamamlandığında bildirim |
| `notif_order` | bool | true | Yeni sipariş / müşteri geldiğinde bildirim |
| `notif_promo` | bool | false | Promosyon ve etkinlik bildirimleri |

- OS bildirim izni yoksa üç toggle **disabled** + "Bildirim izni gerekli — Ayarlar → Uygulama İzinleri" açıklaması gösterilir
- İlk oyun açılışında OS izin dialog'u bir kez tetiklenir; reddedilirse bir daha sorulmaz
- İzin sonradan Settings ekranından verilirse togglelar otomatik aktif olur

#### Performans

| Değişken | Tip | Varsayılan | Açıklama |
|----------|-----|------------|----------|
| `battery_saver` | bool | false | False = 60 FPS, True = 30 FPS |

- `Engine.max_fps` ile uygulanır; değişiklik anında geçerli, sahne yeniden yüklenmez

#### Dil

| Değişken | Tip | Varsayılan | Açıklama |
|----------|-----|------------|----------|
| `language` | String enum | `"tr"` | Desteklenen: `"tr"`, `"en"` |

- `TranslationServer.set_locale()` çağrısı yapılır
- Sahne yeniden yüklenmez; UI string'leri anında güncellenir

#### Veri Yönetimi

- **Kayıt Sil** butonu: Modal onay dialog'u gösterir
  - Mesaj: "Tüm ilerlemeniz silinecek ve başa dönülecek. Bu işlem geri alınamaz."
  - [Sil] → `user://` dizini temizlenir, oyun ana menüye döner
  - [İptal] → dialog kapanır, işlem yapılmaz

### States and Transitions

```
[Ayarlar Kapalı]
    ↓ oyuncu açar
[Ayarlar Ekranı — Normal]
    ↓ Kayıt Sil'e basar
[Onay Dialog]
    ↓ Sil
[Ana Menü] ← yeni kayıt
    ↓ İptal
[Ayarlar Ekranı — Normal]
```

### Interactions with Other Systems

- **AudioManager**: Ses slider değerlerini bus volume'a çevirir
- **NotificationManager**: `notif_*` toggle'larını okur, bildirim zamanlar
- **SaveSystem**: `user://settings.cfg` okuma/yazma; oyun kaydı ile ayrı dosya
- **LocalizationManager**: `language` değişkenini `TranslationServer`'a iletir

## Formulas

### Ses Volume: Slider → AudioServer Bus Volume

Slider (0–100 integer) değeri logaritmik dB ölçeğine dönüştürülür:

```gdscript
# value: int 0–100
# returns: float (dB), passed to AudioServer.set_bus_volume_db()
func slider_to_db(value: int) -> float:
    if value == 0:
        return -80.0  # pratik sessizlik
    return linear_to_db(value / 100.0)
    # linear_to_db(x) = 20 * log10(x)
```

| Slider | linear | dB |
|--------|--------|----|
| 100 | 1.00 | 0 dB |
| 80 | 0.80 | −1.9 dB |
| 50 | 0.50 | −6.0 dB |
| 20 | 0.20 | −14.0 dB |
| 0 | — | −80 dB (sessiz) |

Diğer ayar grupları (bildirimler, performans, dil, veri) boolean/enum değerler içerir; matematiksel formül gerektirmez.

## Edge Cases

| Durum | Davranış |
|-------|----------|
| `settings.cfg` bozuk / eksik | Tüm değerler varsayılanlara döner; kullanıcıya bildirim yok |
| OS bildirim izni reddedildikten sonra uygulama içinden tekrar açılırsa | Toggle'lar disabled kalır; OS Ayarlar'a yönlendirme linki gösterilir |
| Dil değiştirildiğinde açık modal/dialog varsa | Dialog kapanmaz; string'ler dialog'da da anında güncellenir |
| `battery_saver` açıkken cihaz şarj edilmeye başlanırsa | FPS otomatik değişmez; ayar elle değiştirilmeli |
| `master_mute` açıkken slider değeri kaydedilirse | Slider değeri `settings.cfg`'ye yazılır; mute durumu korunur |
| Kayıt Sil dialog'unda uygulama arka plana alınırsa | Dialog açık kalır; geri dönünce kullanıcı seçimini tamamlayabilir |
| Desteklenmeyen locale `settings.cfg`'de bulunursa | Varsayılan `"tr"` kullanılır, hata loglanır |

## Dependencies

| Sistem | Bağımlılık Tipi | Notlar |
|--------|-----------------|--------|
| **AudioManager** | Çıkış | Bus volume_db değerlerini ayarlar |
| **NotificationManager** | Çıkış | `notif_*` toggle'larını okur |
| **SaveSystem** | Çift Yönlü | `user://settings.cfg` oku/yaz; oyun kaydından bağımsız dosya |
| **LocalizationManager** | Çıkış | `language` locale'ini `TranslationServer`'a iletir |
| **OS / Platform Layer** | Çıkış | Bildirim izni sorma, `Engine.max_fps` ayarlama |
| **UI Framework** | Giriş | Settings ekranı Godot Control node'ları ile render edilir |

## Tuning Knobs

| Parametre | Mevcut Değer | Açıklama |
|-----------|--------------|----------|
| `DEFAULT_MUSIC_VOLUME` | 80 | Müzik slider varsayılanı |
| `DEFAULT_SFX_VOLUME` | 80 | SFX slider varsayılanı |
| `DEFAULT_AMBIENT_VOLUME` | 70 | Ambient slider varsayılanı |
| `SILENCE_DB` | −80.0 dB | Slider=0 için dB değeri |
| `DEFAULT_BATTERY_SAVER` | false (60 FPS) | Performans modu varsayılanı |
| `DEFAULT_LANGUAGE` | `"tr"` | İlk açılış dili |
| `DEFAULT_NOTIF_PRODUCTION` | true | Offline üretim bildirimi varsayılanı |
| `DEFAULT_NOTIF_ORDER` | true | Sipariş bildirimi varsayılanı |
| `DEFAULT_NOTIF_PROMO` | false | Promosyon bildirimi varsayılanı |

## Visual/Audio Requirements

- Settings ekranı oyunun genel ASMR estetik diline uygun; sıcak, temiz, minimal
- Slider UI'ı parmak dostu: minimum dokunma alanı 44×44 px
- Mute toggle ikonla desteklenir (hoparlör simgesi)
- Disabled toggle'lar grayed-out; tıklanamaz

## UI Requirements

- Tek kaydırılabilir liste ekranı (ScrollContainer)
- Gruplar başlıklı bölümlerle ayrılır (Ses / Bildirimler / Performans / Dil / Veri)
- Slider değişikliği anında önizleme sesi çalar (SFX grubunda kısa ses, Ambient'te ambiyans loop)
- "Kayıt Sil" butonu kırmızı/tehlike rengi; grubun en altında, diğer butonlardan ayrı

## Acceptance Criteria

- [ ] Müzik slider 0–100 arası ayarlandığında AudioServer Müzik bus'ı doğru dB değerine geçer
- [ ] SFX ve Ambient slider'ları bağımsız çalışır; birini değiştirmek diğerini etkilemez
- [ ] `master_mute` açıkken slider'lar görsel disabled; kapatılınca önceki değerler geri gelir
- [ ] `settings.cfg` her slider değişikliğinde kaydedilir; oyun kapatılıp açıldığında değerler korunur
- [ ] OS bildirim izni yoksa bildirim toggle'ları disabled + açıklama mesajı görünür
- [ ] `battery_saver=true` iken `Engine.max_fps == 30`, `false` iken `== 60`
- [ ] Dil Türkçe → İngilizce değiştirildiğinde tüm UI string'leri sahne yeniden yüklenmeden güncellenir
- [ ] Kayıt Sil → dialog açılır → [Sil] → `user://` temizlenir → ana menüye yönlendirilir
- [ ] Kayıt Sil → dialog açılır → [İptal] → hiçbir şey değişmez
- [ ] Bozuk `settings.cfg` ile açılışta varsayılan değerler yüklenir, crash olmaz

## Open Questions

- Bulut senkronizasyonu ilerleyen aşamada eklenecek mi? (Şu an kapsam dışı — ayrı ADR gerektirir)
- Dil seçimi için OS locale'inden otomatik tespit yapılacak mı? (İlk sürümde manuel seçim)
- `settings.cfg` şifrelenecek mi? (Cheating riski düşük; şimdilik düz metin)
