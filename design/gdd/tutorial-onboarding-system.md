# Tutorial / Onboarding System GDD

**Sistem:** #26 / 29
**Kategori:** Meta — Vertical Slice
**Durum:** Designed
**Bağımlılıklar:** Economy System (#4), Oven/Baking System (#9), Recipe System (#10), Customer/Order System (#11), Upgrade Tree System (#12), UI/HUD System (#15), Save/Load System (#5)

---

## 1. Overview

Tutorial/Onboarding System, yeni oyuncuyu ilk 3 dakika içinde temel döngüyü (hamur yoğur → pişir → sat → upgrade al) keşfettirerek bağımsız oynamaya hazırlar. Sistem "contextual coach" modelini uygular: öğretici ipuçları yalnızca ilgili eylem önünde belirince gösterilir; bağımsız UI akışını kesmez. Beş zorunlu adım sırayla kilitli başlar; oyuncu her adımı tamamlayınca bir sonraki açılır. Tutorial tamamlandıktan sonra bir daha asla gösterilmez (SaveLoad ile kalıcı işaretlenir). Tekrar oynayanlar için skip seçeneği mevcuttur.

## 2. Player Fantasy

**Temel his:** "Ustam elimden tuttu" — Oyuncu ilk hamuru yoğururken nereye tap yapacağını biliyor, ne kazanacağını görüyor. Öğrenmek için menü okumak zorunda değil; oynarken öğreniyor.

**İkincil his:** "Sıfırdan başladım, hep ilerliyorum" — Tutorial her adımda küçük bir ödül verir (altın, deneyim sempati, "iyi yaptın!" sesi). Boş ekran yok, bekleme yok.

**Kaçınılması gereken:** Uzun metin kutucukları, skip edilemeyen animasyonlar, bağımsız akışı durduran modal dialoglar. Tutorial oyunun önüne geçemez.

## 3. Detailed Rules

### 3.1 Tutorial Adımları (Zorunlu Sıra)

| Adım | ID | Tetikleyici | Görev | Ödül |
|------|----|------------|-------|------|
| 1 | `tut_knead` | İlk başlatma | Hamur yoğurma gesturetını 1 kez tamamla | 10 altın |
| 2 | `tut_bake` | Adım 1 tamamlandı | Birinci ekmeği fırına at | 15 altın |
| 3 | `tut_harvest` | Adım 2 + pişirme bitti | Ekmeği fırından al | 15 altın |
| 4 | `tut_sell` | Adım 3 tamamlandı | Vitrine ilk müşteriye sat | 20 altın |
| 5 | `tut_upgrade` | Adım 4 tamamlandı | Upgrade Tree'den 1 upgrade satın al | 25 altın + ilk tarif kilidi açılır |

### 3.2 Contextual Coach (Tooltip) Davranışı

- Her adımda, hedef UI elementinin üzerinde küçük bir animasyonlu ok + tek satır metin gösterilir.
- Metin: maksimum 60 karakter (lokalizasyon kısıtı).
- Tooltip, adım tamamlanır tamamlanmaz kaybolur (fade-out 0.3s).
- Birden fazla tooltip aynı anda gösterilemez.
- Tooltip, hedef UI elementine tıklanabilirliği engellemez (yalnızca görsel overlay).

### 3.3 Skip Mekanizması

- İlk 5 saniye içinde sağ üst köşede "Atla" butonu görünür.
- "Atla" → confirm dialog ("Tutorial'ı atlamak ister misin?") → evet → `tutorial_completed` flag yazılır, tüm adımlar skip edilir.
- Skip sonrası başlangıç bonusu VERİLMEZ (bonus sadece tamamlamayla gelir).

### 3.4 Kalıcılık

- `tutorial_completed: bool` — SaveLoad System üzerinden persist edilir.
- Uygulama kapanıp açılsa dahi tamamlanmış adımlar korunur.
- Prestige tutorial'ı SIFIRLAMAZ (Collection/Dex gibi, kalıcı deneyim).

### 3.5 Yeniden Oynatma (Opsiyonel)

- Settings menüsünde "Tutorial'ı Tekrar Oynat" seçeneği — güvenli aralık dışı davranışlara karşı çözüm.
- Yeniden oynatma, ödülleri tekrar vermez (idempotent).

### 3.6 Eğitim Dışı İpuçları (Hint System)

Tutorial bitiminden sonra oyuncuya bağlamsal kısa ipuçları (hint) gösterilebilir:
- `hint_offline_return` — ilk offline dönüşte "Fırının çalışmaya devam etti!" baloncuğu (1 kez)
- `hint_new_upgrade` — upgrade ağacına yeni upgrade eklendiğinde (1 kez, 30 saniye sonra yok olur)
- `hint_daily_task` — ilk görev tamamlandığında "Günlük ödülünü talep et!" (1 kez)

Her hint yalnızca 1 kez gösterilir; görüntülendiğinde SaveLoad'a kaydedilir.

## 4. Formulas

### F-1: Tutorial Ödül Toplamı

```
total_tutorial_reward = sum(step_reward[i] for i in completed_steps)
```

5 adım tamamlansa: 10 + 15 + 15 + 20 + 25 = **85 altın**

Bu değer yeni oyuncunun ilk upgrade'i satın almasına yetecek şekilde tasarlanmıştır
(`base_cost` en ucuz upgrade = 50 altın; ADR-economy, F-1).

### F-2: Adım Geçerlilik Kontrolü

```
step_unlocked(id) ← prev_step_completed(id) == true
```

Adım sırası katı: önceki adım bitmeden sonraki adım trigger edilemez.

### F-3: Hint Gösterim Koşulu

```
show_hint(id) ←
    tutorial_completed == true
    AND hint_shown[id] == false
    AND trigger_condition(id) == true
```

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| Oyun Adım 2'deyken kapanırsa | SaveLoad step progress korunur; adım 2'den devam |
| Müşteri pişirme bitmeden gelirse | Adım 3 henüz başlamadı; müşteri normal bekleme süresi çalışır |
| Tutorial sırasında reklam teklifi gelirse | AdMonetizationSystem tutorial devam ederken teklif gösterMEZ (`tut_active` flag kontrolü) |
| Tutorial tamamlandıktan sonra yeniden oynat + ödül istemi | Ödüller verilmez — idempotent `reward_given` flag kontrolü |
| Skip → başlangıç altın 0 | Oyuncu tutorial ödülsüz başlar; game balance'ı bozulmaması için starting_gold = 30 (sabit) |
| Lokalizasyon çok uzun metin | Tooltip 60 karakter hard-limit; aşılırsa "..." ile kesilir |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Economy System (#4)** | `earn_gold()` — adım ödülleri |
| **Oven/Baking System (#9)** | `bake_started`, `bake_completed` sinyalleri — adım 2-3 tetikleyicileri |
| **Recipe System (#10)** | `unlock_recipe()` — adım 5 bonusu (ilk tarif) |
| **Customer/Order System (#11)** | `order_delivered` sinyali — adım 4 tetikleyici |
| **Upgrade Tree System (#12)** | `upgrade_purchased` sinyali — adım 5 tetikleyici |
| **UI/HUD System (#15)** | Tooltip overlay konumlandırması |
| **Save/Load System (#5)** | `tutorial_completed`, `hint_shown[]` kalıcılığı |
| **Ad Monetization System (#25)** | `tut_active` flag kontrolü — reklam teklifi baskılama |

## 7. Tuning Knobs

| Parametre | Varsayılan | Güvenli Aralık | Etki |
|-----------|-----------|----------------|------|
| `STEP_REWARDS[]` | [10,15,15,20,25] | her adım [5, 50] | Düşük → motivasyon azalır; yüksek → ekonomi bozulur |
| `SKIP_BUTTON_DELAY_SEC` | 5.0 | [0, 15] | 0 → herkes atlar; 15 → sinir bozucu |
| `TOOLTIP_FADE_SEC` | 0.3 | [0.1, 0.8] | Görsel cevap hızı |
| `HINT_LIFETIME_SEC` | 30.0 | [10, 60] | Hint ne kadar süre görünür kalır |
| `STARTING_GOLD` | 30 | [0, 100] | Skip yapan oyuncunun başlangıç altını |

## 8. Acceptance Criteria

- [ ] 5 zorunlu adım sırayla kilitlenir; önceki tamamlanmadan sonraki gösterilmez
- [ ] Her adım tamamlandığında doğru altın ödülü Economy'ye eklendi
- [ ] Adım 5 tamamlandığında ilk tarif kilidi açıldı
- [ ] Tutorial tamamlandıktan sonra uygulamayı kapatıp açınca tekrar başlamıyor
- [ ] "Atla" butonu 5 saniye sonra belirir; tıklandığında confirm dialog gösterilir
- [ ] Skip sonrası ödül VERİLMEZ; başlangıç altını 30 olarak ayarlandı
- [ ] Prestige sonrası tutorial yeniden başlamıyor
- [ ] Tutorial aktifken reklam teklifi UI gizleniyor (`tut_active` flag)
- [ ] Hint sistemi: her hint yalnızca 1 kez gösterildi, tamamlandıktan sonra kayıt edildi
- [ ] Tooltip maksimum 60 karakter; aşılıyorsa kısaltılıyor
- [ ] GUT testleri: adım sırası, ödül idempotency, skip akışı, kalıcılık
