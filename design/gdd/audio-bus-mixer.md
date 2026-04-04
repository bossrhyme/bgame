# Audio Bus/Mixer

> **Status**: Draft Complete
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-04
> **Implements Pillar**: ASMR & Tactile Feel — "Her eylem ayrı bir ses olmalı"

## Overview

Audio Bus/Mixer, Ekmek Ustası'nın tüm ses çıkışını dört bus üzerinden yöneten altyapı
sistemidir: **Master** (genel çıkış), **Müzik** (arka plan caz/akustik döngüsü), **SFX**
(gameplay eylemleri — hamur, fırın, hasat, para), **Ambient** (fırın hışırtısı + kasaba
sesi). Sistem,
`Settings`'ten gelen slider değerlerini Godot `AudioServer` bus'larına uygular; `master_mute`
bayrağıyla tüm çıkışı anlık susturur. `Sound & Animation System`'ın ses oynatma çağrılarına
hazır bir yönlendirme altyapısı sağlar.

## Player Fantasy

Audio Bus/Mixer oyuncunun doğrudan görmediği ama her saniye hissettiği bir sistemdir.
Doğru çalıştığında şunu hisseder: *"Bu fırın gerçek — hamurun sesi, fırının hışırtısı,
kasanın tıkırtısı... her şey yerinde."* ASMR deneyiminin temeli ses katmanlamasıdır:

- **Ambient döngüler:** Fırın ısısı ve kasaba hayatı, oyuncu hiçbir şey yapmasa bile
  orada olduğunu hissettirir. Kapatılınca oyun "boş" hisseder.
- **Eylem sesleri:** Her tap'ın kendine özgü, kısa ve tatmin edici bir sesi var.
  Hamur yoğurmanın "mlap mlap"ı, ekmeğin "tok" sesi, paranın "ding"i —
  doğru ayarlandığında oyuncu bunları duymak için tap yapar.
- **Müzik:** 70 BPM caz/akustik loop, arka planda asla önü kapatmaz; zemin oluşturur.
- **Kişiselleştirme:** Telefon zil sesiyle çalışan birinin SFX'i kapatıp ambiyansı
  açık tutması, oyunu "kendi fırınına" dönüştürür.

## Detailed Design

### Core Rules

1. **4 AudioServer bus.** Godot `AudioServer`'da 4 bus tanımlanır: `Master` (tüm çıkış),
   `Music`, `SFX`, `Ambient`. Her bus `Master`'a route edilir.
2. **`AudioManager` autoload.** Bus yönetiminin tek sahibi. Settings sinyallerini dinler,
   bus volume'larını uygular. `Sound & Animation System` ses çalma isteklerini buraya gönderir.
3. **Settings bağlantısı.** `SettingsManager.audio_changed(music, sfx, ambient, mute)` sinyali
   ile bus'lar güncellenir. `AudioManager` doğrudan `settings.cfg` okumaz.
4. **Slider → dB dönüşümü.** Settings GDD formülü aynen uygulanır:
   `linear_to_db(value / 100.0)`; `value == 0` → `-80.0 dB`. (Formül Settings GDD'ye aittir —
   `design/gdd/settings-preferences.md` Formulas bölümü.)
5. **`master_mute`.** `true` olduğunda `Master` bus volume → `-80.0 dB`. Slider değerleri
   değişmez; mute kaldırılınca önceki bus değerleri geri yüklenir.
6. **`battery_saver` modu.** `Ambient` bus `-80.0 dB`'e çekilir (sessizleşir). `Music` ve
   `SFX` çalışmaya devam eder. `Settings`'ten `battery_saver_changed(bool)` sinyaliyle tetiklenir.
7. **Ses çalma API.**
   - `AudioManager.play_sfx(stream: AudioStream, bus: String = "SFX", priority: int = SFX_PRIORITY_MEDIUM)` —
     tek kullanımlık `AudioStreamPlayer` node oluşturur; `pitch_scale` ±`SFX_PITCH_RANGE`
     rastgele ayarlanır; belirtilen bus'a route edilir; `finished` sinyalinde `queue_free`.
   - `AudioManager.play_music(stream: AudioStream)` — `Music` bus'ta döngüsel çalar. Aktif
     müzik varsa `MUSIC_CROSSFADE_SEC` süresinde crossfade.
   - `AudioManager.play_ambient(stream: AudioStream, layer_id: int)` — max 3 eşzamanlı
     ambient katman; `layer_id` (0–2) ile bağımsız kontrol:
     - Layer 0: Fırın ısısı (her zaman aktif; lokasyona göre değişmez)
     - Layer 1: Dış ortam (kasaba, şehir, Paris sokağı — lokasyona göre değişir; OQ-02)
     - Layer 2: Özel olay ambient'i (VIP müşteri, yoğun servis, festif dönem — opsiyonel)
   - `AudioManager.stop_ambient(layer_id: int)` — belirli ambient katmanı durdurur.
8. **ADR-0003 uyumu.** `_process()` içinde ses durumu sorgulanmaz veya değiştirilmez;
   tüm güncellemeler sinyal-tetiklemeli.
9. **SFX varyant stratejisi.** Tekrarlayan aksiyonlar (hamur yoğurma, coin) için tek dosya
   yerine `AudioStreamRandomizer` resource kullanılır. Her tekrarlayan SFX için min.
   `SFX_VARIANT_MIN` adet varyant asset üretilir. Godot 4.x `AudioStreamRandomizer`, her
   çalışta listeden rastgele bir stream seçer — "machine gun effect" önlenir.
   `play_sfx(stream, bus)` API değişmez; randomizer stream'in kendisi bir `AudioStream`'dir.
10. **Pitch variation.** `play_sfx` çağrısında `AudioStreamPlayer.pitch_scale` rastgele
    `[1.0 - SFX_PITCH_RANGE, 1.0 + SFX_PITCH_RANGE]` aralığında ayarlanır. Aynı sesi her
    defasında biraz farklı duyurur; ASMR tekrar yorgunluğunu azaltır.
11. **SFX öncelik sistemi.** `SFX_POLYPHONY_LIMIT` dolunca kesilecek node, öncelik tieriyle
    belirlenir:
    - **HIGH:** Hasat tok, para ding, upgrade unlock, tarif açma — asla kesilmez
    - **MEDIUM:** Müşteri sesleri, kapı gıcırtısı — yalnızca HIGH için yer açılır
    - **LOW:** Tekrarlayan hamur yoğurma, coin shower tekrarları — ilk kesilecek
    `play_sfx(stream, bus, priority: int = SFX_PRIORITY_MEDIUM)` API'ye üçüncü parametre eklenir.

---

### Bus Mimarisi

```
AudioServer
└── Master        ← master_mute / genel çıkış
    ├── Music     ← music_volume slider (0–100 → dB)
    ├── SFX       ← sfx_volume slider (0–100 → dB)
    └── Ambient   ← ambient_volume slider; battery_saver modunda −80 dB
```

---

### Interactions with Other Systems

| Sistem | ABM'ye Verdiği | ABM'den Aldığı | Arayüz |
|--------|---------------|----------------|--------|
| **Settings & Preferences** | `audio_changed(music: int, sfx: int, ambient: int, mute: bool)` | — | Sinyal |
| **Settings & Preferences** | `battery_saver_changed(value: bool)` | — | Sinyal |
| **Sound & Animation System** *(provisional)* | `play_sfx(stream, bus)` çağrısı | — | `AudioManager` API |
| **Animation State Machine** | `play_sfx` track event callback'leri (dolaylı) | — | ASM GDD `animation-state-machine.md` Ses Eşleştirme tablosu |

## Formulas

ABM'nin temel slider→dB formülü Settings GDD'de tanımlanmıştır; burada referans verilir.

### F-1: Slider → dB (Settings GDD Referansı)

```gdscript
# Kaynak: design/gdd/settings-preferences.md — Formulas bölümü
func slider_to_db(value: int) -> float:
    if value == 0:
        return -80.0   # pratik sessizlik
    return linear_to_db(value / 100.0)
    # linear_to_db(x) = 20 * log10(x)
```

### F-2: Müzik Crossfade (Tween ile)

```gdscript
# t: Tween içindeki geçen süre (sn)
fade_out_volume = lerp(current_db, -80.0, t / MUSIC_CROSSFADE_SEC)
fade_in_volume  = lerp(-80.0, target_db, t / MUSIC_CROSSFADE_SEC)
```

Crossfade `Tween` ile uygulanır — `_process()` yasağı (ADR-0003).

### F-3: Ambient Katman Zarf (Attack / Release)

```gdscript
# attack: katman başladığında fade-in
volume = lerp(-80.0, target_db, t / AMBIENT_ATTACK_SEC)

# release: stop_ambient() veya battery_saver geçişinde fade-out
volume = lerp(current_db, -80.0, t / AMBIENT_RELEASE_SEC)
```

## Edge Cases

| # | Durum | Beklenen Davranış |
|---|-------|-------------------|
| 1 | `master_mute` açıkken slider değiştirilirse | Bus volume değişmez; değer `settings.cfg`'ye kaydedilir; mute kaldırılınca yeni değer uygulanır |
| 2 | `battery_saver=true` iken `play_ambient()` çağrılırsa | Çağrı kabul edilir; ambient bus `-80.0 dB`'de olduğundan ses duyulmaz; `battery_saver=false` olunca katman devreye girer |
| 3 | 3 ambient katman doluyken 4. `play_ambient()` çağrılırsa | `push_error` ile log; çağrı yoksayılır |
| 4 | Crossfade sırasında yeni `play_music()` çağrılırsa | Devam eden Tween iptal edilir; yeni crossfade başlar — önceki hedef atlanır |
| 5 | Uygulama arka plana alınırsa | `ApplicationPaused` sinyalinde `Master` bus `-80.0 dB`; öne gelince eski değer restore edilir |
| 6 | `AudioStream` null geçilirse | `push_error` ile log; ilgili `play_*` çağrısı yoksayılır |
| 7 | Tüm slider'lar 0 + `master_mute = false` | Tüm bus'lar `-80.0 dB` — sessizlik. Geçerli durum; `master_mute` bayrağına gerek yok |
| 8 | `play_sfx` çok hızlı ardışık çağrılırsa | Öncelik sırasına göre: LOW öncelikli node'lar önce kesilir; HIGH öncelikli node'lar limit dışında tutulur (her zaman çalar) |

## Dependencies

### Upstream — ABM'ye Veri Sağlayan Sistemler

| Sistem | Bağımlılık Tipi | Arayüz | Notlar |
|--------|-----------------|--------|--------|
| **Settings & Preferences** | Hard | `SettingsManager.audio_changed(music: int, sfx: int, ambient: int, mute: bool)` | Bu sinyal gelmeden bus volume güncellenmez |
| **Settings & Preferences** | Hard | `SettingsManager.battery_saver_changed(value: bool)` | Ambient bus sessizleştirme tetikleyicisi |
| **Save/Load System** | Soft (dolaylı) | Settings değerleri `user://settings.cfg`'den yüklenir; ABM bunu doğrudan okumaz — Settings katmanı araya girer | ABM kayıt sistemine doğrudan bağımlı değil |

### Downstream — ABM'nin API Sağladığı Sistemler

| Sistem | Bağımlılık Tipi | Arayüz | Notlar |
|--------|-----------------|--------|--------|
| **Sound & Animation System** *(provisional)* | Soft | `AudioManager.play_sfx(stream, bus)`, `play_music(stream)`, `play_ambient(stream, layer_id)`, `stop_ambient(layer_id)` | GDD henüz yazılmadı (Sistem #23); API imzası değişebilir — bkz. OQ-01 |
| **Animation State Machine** | Soft (dolaylı) | ASM track event callback'leri Sound & Animation System üzerinden `play_sfx` çağırır | `design/gdd/animation-state-machine.md` Ses Eşleştirme tablosuna bakınız |

**Hard:** ABM bu sistem olmadan başlatılamaz. **Soft:** ABM bu sistem olmadan çalışır; ilgili özellik devre dışı kalır.

## Tuning Knobs

| Sabit | Varsayılan | Güvenli Aralık | Çok düşükse | Çok yüksekse | Sahip |
|-------|-----------|----------------|-------------|--------------|-------|
| `MUSIC_CROSSFADE_SEC` | `1.5` sn | 0.5 – 3.0 sn | Geçiş sert ve ani; müzik değişimi oyuncuyu rahatsız eder | Geçiş yavaş fark edilir; yeni müzik çok geç girer | Audio Director |
| `AMBIENT_ATTACK_SEC` | `2.0` sn | 0.5 – 4.0 sn | Ambient ani açılır; doğal olmayan "pop" sesi | Ortam sesi çok yavaş gelir; lokasyon değişikliği duyulamaz | Audio Director |
| `AMBIENT_RELEASE_SEC` | `1.0` sn | 0.3 – 2.0 sn | Ambient kesintisi ani; "klik" artefaktı oluşabilir | Fade-out çok uzun; kapandıktan sonra ses duyulmaya devam eder | Audio Director |
| `SFX_POLYPHONY_LIMIT` | `8` | 4 – 16 | Hızlı ardışık tap'lerde SFX'ler birbirini keser; ASMR tatmini bozulur | Eşzamanlı çok fazla `AudioStreamPlayer`; mobil bellek/CPU baskısı | Lead Programmer |
| `AMBIENT_LAYER_COUNT` | `3` | Sabit | — | Arttırmak için kod değişikliği gerekir | Audio Director |
| `DEFAULT_MUSIC_BPM` | `70` | 60 – 90 (referans) | Müzik durağan; ASMR için alt sınır | Tempo arttıkça casual/idle atmosfer bozulur; gerginlik hissi | Sound Designer (kod sabiti değil; üretim referansı) |
| `SFX_VARIANT_MIN` | `3` | 2 – 5 | 2 varyant tekrar edilir; az da olsa machine gun effect duyulabilir | 5+ varyant asset üretim maliyeti artar; azalan geri dönüş | Audio Director / Sound Designer |
| `SFX_PITCH_RANGE` | `0.05` | 0.02 – 0.10 | Pitch variation duyulmaz; etkisiz | Ses karakteri bozulur; aynı SFX farklı bir ses gibi algılanır | Audio Director |
| `SFX_PRIORITY_HIGH` | `2` | Sabit | — | High priority SFX her zaman çalar; polyphony dışı | Lead Programmer |
| `SFX_PRIORITY_MEDIUM` | `1` | Sabit | — | Varsayılan öncelik | Lead Programmer |
| `SFX_PRIORITY_LOW` | `0` | Sabit | — | Polyphony dolunca ilk kesilir | Lead Programmer |

## Visual/Audio Requirements

Bu sistem görsel çıktı üretmez. Aşağıdaki gereksinimler yalnızca ses varlıklarını kapsar.

### Müzik

| Asset | Format | BPM | Loop | Notlar |
|-------|--------|-----|------|--------|
| `mus_bakery_main_loop.ogg` | OGG Vorbis | 70 | Seamless | Loop noktası metronom darbesinde; artefaktsız |

### Ambient

| Asset | Format | İçerik | Loop | Notlar |
|-------|--------|--------|------|--------|
| `amb_bakery_oven_loop.ogg` | OGG Vorbis | Fırın hışırtısı, kor sesi | Seamless | 80–400 Hz ağırlıklı; odanın sıcaklığını verir |
| `amb_town_outdoor_loop.ogg` | OGG Vorbis | Uzak kasaba — kuş, rüzgar, hafif kalabalık | Seamless | Yüksek frekans yok; müzikle çakışmaz |

### SFX

Tekrarlayan SFX'ler `AudioStreamRandomizer` resource olarak paketlenir; her biri min.
`SFX_VARIANT_MIN` (varsayılan: 3) varyant içerir. Varyant sayısı asset adının sonunda belirtilir.

| Asset (Randomizer) | Varyant | Öncelik | Eylem | Notlar |
|--------------------|---------|---------|-------|--------|
| `sfx_dough_knead.tres` | 3 | LOW | Hamur yoğurma "mlap mlap" | Yumuşak, organik; pitch ±5% |
| `sfx_dough_shape.tres` | 2 | MEDIUM | Şekil verme "fış" | Sessiz hava kaçışı; narin |
| `sfx_oven_door_creak.tres` | 2 | MEDIUM | Fırın kapısı — ağır metalik ses | Kısa < 0.5 sn; "krank" karakteri |
| `sfx_bread_thud.tres` | 3 | HIGH | Ekmek hasat — tok vuruş | Somut, kütlesel; ASMR zirve anı |
| `sfx_bread_harvest_puf.tres` | 2 | HIGH | Hasat "puf" | Hava kaçması; yumuşak |
| `sfx_coin_ding.tres` | 3 | HIGH | Para kazanma | Hafif, neşeli; yüksek pitch |
| `sfx_register_click.tres` | 2 | HIGH | Kasa/vitrin satış | Mekanik, kuru |
| `sfx_customer_mmm.tres` | 3 | MEDIUM | Müşteri memnuniyeti | Kısa vokal; sıcak |
| `sfx_customer_leave.tres` | 2 | MEDIUM | Müşteri kaçışı / hayal kırıklığı | Hafif, nazik negatif geri bildirim; sert değil |
| `sfx_upgrade_unlock.tres` | 2 | HIGH | Upgrade satın alma | Tatmin edici "tık + parıltı"; motivasyon anı |
| `sfx_recipe_unlock.tres` | 2 | HIGH | Yeni tarif açma | Meraklı, büyülü his; duygusal zirve |
| `sfx_offline_return.tres` | 1 | HIGH | Offline dönüş — üretim patlaması | Tek varyant; dramatik, coşkulu |

### Teknik Gereksinimler

| Parametre | Değer |
|-----------|-------|
| Format | OGG Vorbis |
| Sample Rate | 44.1 kHz / 16-bit |
| SFX Loudness | −14 LUFS |
| Müzik / Ambient Loudness | −18 LUFS |
| True Peak | −2.0 dBTP max (mobil codec zinciri inter-sample peak oluşturabilir) |
| Pitch Variation | `pitch_scale = randf_range(1.0 - SFX_PITCH_RANGE, 1.0 + SFX_PITCH_RANGE)` her `play_sfx` çağrısında uygulanır |

## UI Requirements

Audio Bus/Mixer'ın doğrudan yönettiği bir UI yoktur. Ses kontrolleri (slider'lar, mute toggle)
Settings & Preferences ekranına aittir. Bu sistem yalnızca o ekranın ürettiği sinyalleri tüketir.

## Acceptance Criteria

| # | Kriter | Test Yöntemi |
|---|--------|--------------|
| AC-01 | `audio_changed` sinyalinde ilgili bus'ların dB değerleri `slider_to_db()` formülüne göre güncellenir (`slider=80 → −1.9 dB ± 0.1`) | GUT: sinyal emit et; `AudioServer.get_bus_volume_db()` ile doğrula |
| AC-02 | `master_mute=true` → `Master` bus `-80.0 dB`; alt bus değerleri değişmez | GUT: mute öncesi/sonrası `get_bus_volume_db()` karşılaştır |
| AC-03 | `master_mute=false` → `Master` bus mute önceki dB değerine döner | GUT: mute → değer değiştir → unmute; önceki değer assert et |
| AC-04 | `battery_saver=true` → `Ambient` bus `-80.0 dB`; `Music` ve `SFX` etkilenmez | GUT: `battery_saver_changed(true)` emit et; üç bus değerini ayrı ayrı assert et |
| AC-05 | `play_music(stream_b)` çağrıldığında eski track `MUSIC_CROSSFADE_SEC` süresinde fade-out, yeni track fade-in yapar | Manuel: iki stream ile çağrı; geçiş süresi `MUSIC_CROSSFADE_SEC ± 0.1 sn` |
| AC-06 | `play_ambient` layer 0, 1, 2 bağımsız çalışır; `stop_ambient(1)` yalnızca katman 1'i durdurur | GUT: üç katman başlat; her `stop_ambient(id)` yalnızca hedef katmanı durdurur assert et |
| AC-07 | 4. `play_ambient()` çağrısı `push_error` ile loglanır; mevcut 3 katman etkilenmez | GUT: 3 katman dolu → 4. çağrı; error loglandı + katman sayısı 3 assert et |
| AC-08 | Hızlı ardışık `play_sfx()` `SFX_POLYPHONY_LIMIT`'i aşmaz; limit aşılınca en eski node durdurulur | GUT: `LIMIT + 2` kez çağır; `get_child_count() <= LIMIT` + en eski `playing == false` assert et |
| AC-09 | Uygulama arka plana alınca `Master` `-80.0 dB`; öne gelince önceki değer restore edilir | Manuel: home tuşu → Remote Debugger'dan bus değerini oku; geri dönünce eski değer |
| AC-10 | `AudioManager` script'inde `_process()` içinde `set_bus_volume_db` çağrısı yoktur | Statik kod incelemesi: `audio_manager.gd` dosyasında `_process` bloğu içinde `set_bus_volume_db` aranır — bulunmamalı |
| AC-11 | Tekrarlayan SFX çağrılarında ardışık iki çalışta aynı stream seçilmez (`AudioStreamRandomizer` bunu garanti eder) | GUT: aynı randomizer ile 10 ardışık `play_sfx` çağrısı; arka arkaya aynı stream gelmemeli (shuffle mode aktif) |
| AC-12 | HIGH öncelikli SFX, polyphony limitinde LOW öncelikli node'u keser; HIGH node çalmaya devam eder | GUT: `SFX_POLYPHONY_LIMIT` dolu LOW node varken HIGH priority `play_sfx` çağrısı; LOW node durdurulur, HIGH node çalar assert et |

## Open Questions

| # | Soru | Etki | Sahip | Hedef |
|---|------|------|-------|-------|
| OQ-01 | Sound & Animation System (Sistem #23) GDD'si yazılmadan `play_sfx` API imzası sabitlenebilir mi? | ABM değişmez; Sound & Animation kodu etkilenir | Lead Programmer | Sistem #23 GDD başlamadan önce |
| OQ-02 | Lokasyona göre farklı müzik track'i kullanılacak mı? (Location/Prestige bağlantısı) | "Evet" ise `play_music` çağrıları Location GDD'ye bağlanmalı; müzik asset sayısı artar | Game Designer | Location/Prestige GDD sırasında |
| OQ-03 | Godot 4.6'da arka plan algılaması için `ApplicationPaused` sinyali mi, `ApplicationFocusChanged` mi kullanılmalı? | Edge Case #5 ve AC-09'un implementasyonu buna bağlı | Lead Programmer | Implementasyona başlamadan |
