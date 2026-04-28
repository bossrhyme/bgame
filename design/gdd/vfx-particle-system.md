# VFX/Particle System GDD

**Sistem:** #25 / 29
**Kategori:** UI — Vertical Slice
**Durum:** Designed
**Bağımlılıklar:** Economy System (#4), Animation System (#7), Recipe System (#10)

---

## 1. Overview

VFX/Particle System, oyun olaylarını görsel efektlere dönüştüren koordinasyon katmanıdır. Altın kazanımında coin animasyonu, tarif açılımında patlama efekti tetikler. Sahne node'larına değil sinyallere dayanır; gerçek `GPUParticles2D` node'ları sahnede bulunur, bu sistem onlara ne zaman tetikleneceklerini iletir. `battery_saver` modunda tüm VFX devre dışı bırakılır.

## 2. Player Fantasy

**Temel his:** "Kazandım!" — Ekmek satıldığında coin'ler ekrana yağar, oyuncu üretiminin karşılığını somut hisseder.

**İkincil his:** Sürpriz açılım. Yeni bir tarif açıldığında parlak bir patlama efekti belirir — oyuncu bu anın özel olduğunu anlar.

**Kaçınılması gereken:** Pil tüketen efektler. Battery saver modunda efektler tamamen kesilir; performans her zaman estetiğin önündedir.

## 3. Detailed Rules

### Coin VFX Akışı

```
EconomySystem.gold_changed(new_balance)
    → AnimationManager._on_gold_changed(new_balance)
        [battery_saver kontrolü — true ise STOP]
        → AnimationManager.coin_spawn_requested.emit(count, delta)
            → VFXSystem._on_coin_spawn_requested(count, delta)
                → VFXSystem.coin_vfx_requested.emit(count, delta)
                    → Sahne coin GPUParticles2D spawn eder
```

### Unlock VFX Akışı

```
RecipeManager.recipe_unlocked(recipe_id)
    → VFXSystem._on_recipe_unlocked(recipe_id)
        [battery_saver kontrolü — true ise STOP]
        → VFXSystem.unlock_vfx_requested.emit(recipe_id)
            → Sahne unlock GPUParticles2D patlar
```

### Battery Saver Modu

- `SettingsManager.battery_saver_changed` sinyali dinlenir.
- `battery_saver=true` → `vfx_disabled` sinyali yayılır; sahne node'ları `process_mode = DISABLED` ayarlar.
- `battery_saver=false` → `vfx_enabled` sinyali yayılır; sahne node'ları `process_mode = INHERIT` ayarlar.
- Coin için ek kontrol gerekmez: AnimationManager zaten `coin_spawn_requested` yayımını engeller.

## 4. Formulas

### F-1: Coin Sayısı (AnimationManager'dan alınır)

```
delta ≤ 0     → count = 0  (VFX tetiklenmez)
delta ≤  50   → count = 1
delta ≤ 500   → count = 3
delta ≤ 2000  → count = 5
delta > 2000  → count = 8
```

VFXSystem bu formülü uygulamaz; yalnızca `coin_spawn_requested(count, delta)` değerini iletir.

### F-2: Eş Zamanlı Grup Limiti (AnimationManager'da uygulanır)

```
max_concurrent_groups = 3
```

## 5. Edge Cases

| Durum | Davranış |
|-------|----------|
| `battery_saver=true` iken coin kazanılırsa | AnimationManager zaten sinyal yayımını engeller; VFXSystem'e ulaşmaz |
| `battery_saver=true` iken tarif açılırsa | VFXSystem `unlock_vfx_requested` yayımlamaz |
| AnimationManager null ise | push_warning + sinyal bağlantısı atlanır |
| RecipeManager null ise | push_warning + sinyal bağlantısı atlanır |
| Coin VFX spawn edilirken battery_saver aktif olursa | `vfx_disabled` sinyali sahneye gider; sahne aktif particle node'ları durdurur |

## 6. Dependencies

| Sistem | Kullanım |
|--------|----------|
| **Animation System (#7)** | `coin_spawn_requested` sinyali — coin VFX tetikleme kaynağı |
| **Recipe System (#10)** | `recipe_unlocked` sinyali — unlock VFX tetikleme kaynağı |
| **Settings/Preferences (#23)** | `battery_saver_changed` — VFX etkinleştirme/devre dışı bırakma |

## 7. Tuning Knobs

| Parametre | Değer | Güvenli Aralık | Etki |
|-----------|-------|----------------|------|
| Coin VFX sayısı | AnimationManager F-1 | — | VFXSystem kontrol etmez |
| `battery_saver` eşiği | SettingsManager | — | VFXSystem kontrol etmez |

VFXSystem sadece koordinasyon yapar; tüm sayısal değerler kaynak sistemlerde tanımlanır.

## 8. Acceptance Criteria

- [ ] Altın kazanıldığında `coin_vfx_requested(count, delta)` sinyali emit ediliyor
- [ ] `battery_saver=true` iken tarif açılsa da `unlock_vfx_requested` yayımlanmıyor
- [ ] `battery_saver=true` iken `vfx_disabled` sinyali emit ediliyor
- [ ] `battery_saver=false`'a geçince `vfx_enabled` sinyali emit ediliyor
- [ ] AnimationManager null ise sistem çökmiyor
- [ ] GUT testleri: coin yönlendirme, unlock suppression, battery_saver toggle
