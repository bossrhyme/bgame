# Retrospective: Sprint 1
Period: 2026-04-09 — 2026-04-09 (tek oturum)
Generated: 2026-04-12

---

## Metrics

| Metrik | Planlanan | Gerçekleşen | Delta |
|--------|-----------|-------------|-------|
| Must Have task | 5 | 5 | 0 |
| Should Have task | 3 | 3 | 0 |
| Nice to Have task | 2 | 1 | -1 |
| Toplam task tamamlama | 8/10 | 9/10 | +1 |
| Tamamlanma oranı | %80 (Must+Should) | %90 | +10pp |
| Tahmini efor (gün) | 8.0 | ~1 oturum | — |
| Commit sayısı | — | 11 (9 feat, 2 chore) | — |
| GUT test fonksiyonu | — | 137 | — |
| Kaynak satır (src/) | — | 1 348 | — |
| Test satır (tests/) | — | 1 456 | — |
| TODO / FIXME / HACK | — | 0 / 0 / 0 | — |
| Eklenmemiş hata | — | 0 | — |

---

## Velocity Trend

| Sprint | Planlanan | Tamamlanan | Oran |
|--------|-----------|------------|------|
| Sprint 1 (bu) | 10 task | 9 task | %90 |

**Trend:** Veri yok (ilk sprint). Referans baz çizgisi oluşturuldu: **9 task / oturum**.

---

## What Went Well

- **%100 Must Have + Should Have tamamlandı.** Kritik yol (S1-01→S1-05) hiç kaymadı; fırın döngüsünün çekirdeği çalışır durumda.
- **Test kodu kaynak kodu geçti (1 456 > 1 348 satır).** Test-first yaklaşımı disiplinli uygulandı; 137 GUT testi tüm formülleri, edge case'leri ve sinyal API'lerini kapsıyor.
- **Sıfır teknik borç.** Hiç TODO/FIXME/HACK yok; kod temiz teslim edildi.
- **ADR-0003 ihlali yok.** `_process()` hiçbir sistem dosyasında gameplay mantığı için kullanılmadı — tüm zamanlama `SceneTreeTimer` / `Timer.timeout` üzerinden.
- **Dependency injection standardı tutuldu.** `_economy_ref`, `_settings_ref`, `_set_save_path()` pattern'ları test izolasyonunu tam sağladı; autoload bağımlılığı sıfır.
- **S1-09 (Nice to Have) bonus tamamlandı.** AnimationManager ve battery_saver entegrasyonu planlanandan fazla teslim edildi.

---

## What Went Poorly

- **Git push proxy 403 — çok oturum bloke etti.** S1-04'ten itibaren local proxy token'ı geçersiz kaldı; S1-04, S1-05, S1-06, S1-09 birden fazla oturumda push edilemedi. Her oturum sonunda stop hook uyarısı alındı. Manuel PAT girişiyle çözüldü ama 3+ oturum gecikmeye neden oldu.
- **S1-07 ve S1-08 ayrı task olarak planlandı, ayrı commit yok.** "Economy GUT test suite" ve "Baking GUT test suite" ayrı Should Have görevleri olarak listelenmiş; ancak testler implementasyonla birlikte tek commit'te teslim edildi. Planlama ile gerçekleşme arasında görünürlük kaybı oluştu.
- **S1-10 (Touch/Gesture Input) tamamlanmadı.** Nice to Have olduğu için blocker değil, ancak Sprint 2'ye carryover olarak geçiyor.
- **Tüm commitler aynı günde (2026-04-09).** Gerçek efor dağılımı görünmüyor; task bazlı zaman takibi yapılamadı.

---

## Blockers Encountered

| Blocker | Süre | Çözüm | Önleme |
|---------|------|-------|--------|
| Git push proxy 403 | 3+ oturum | Manuel PAT ile `git remote set-url` | Oturum başında proxy token kontrolü; gerekirse PAT credential store kullan |
| MCP GitHub API 403 (push_files) | 1 oturum deneme | Geçersiz — integration write izni yok | MCP araçlarını push için kullanmaya çalışma; yalnızca read-only kullan |

---

## Estimation Accuracy

| Task | Tahmini | Gerçekleşen | Varyans | Muhtemel Neden |
|------|---------|-------------|---------|----------------|
| S1-04 Save/Load | 1.5 gün | < 1 oturum | Olumlu | ConfigFile API basit; test pattern'ı S1-03'ten alındı |
| S1-05 Oven/Baking | 2.0 gün | < 1 oturum | Olumlu | State machine tasarımı GDD'de iyi tanımlanmıştı |
| S1-09 Animation | 0.5 gün (NtH) | < 1 oturum | Nötr | Dependency injection altyapısı hazırdı |

**Genel tahmin doğruluğu:** Tüm tasklar tahmin sürelerinden önce tamamlandı. Sprint kapasitesi (8 gün) tek oturumda kullanıldı — bu agresif tahmin değil, oturum başına iş yoğunluğunun yüksek olduğunu gösteriyor. Gelecek sprint tahminlerinde "oturum başına kapasite" baz alınmalı, "gün" birimine dikkat edilmeli.

---

## Carryover Analysis

| Task | Kaynak Sprint | Taşıma Nedeni | Aksiyon |
|------|--------------|---------------|---------|
| S1-10 Touch/Gesture Input | Sprint 1 | Nice to Have, zaman kalmadı | Sprint 2'ye ekle veya descope et |

---

## Technical Debt Status

- TODO sayısı: **0** (önceki sprint: yok — ilk sprint)
- FIXME sayısı: **0**
- HACK sayısı: **0**
- Trend: **Temiz başlangıç**

Dikkat edilecek alan: `SaveLoadManager._save_game_internal()` içindeki `progression` ve `gameplay` bölümleri placeholder veriyle dolduruldu (`[]`, `{}`). Bu alanlar Sprint 2'de gerçek sistemlerle doldurulunca borç oluşabilir — şimdiden izlemeye alınmalı.

---

## Previous Action Items Follow-Up

*Önceki retrospektif yok — ilk sprint.*

---

## Action Items for Next Iteration

| # | Aksiyon | Sahip | Öncelik | Son Tarih |
|---|---------|-------|---------|-----------|
| 1 | Git push için PAT'ı credential store'a kaydet (`git config credential.helper store`) — her oturumda manuel giriş yapılmasın | godot-specialist | Yüksek | Sprint 2 başlangıcı |
| 2 | `SaveLoadManager` içindeki placeholder `progression` / `gameplay` bölümlerini gerçek sistemlerle doldur (OvenManager.get_save_data entegrasyonu) | godot-specialist | Yüksek | S2 Save/Load entegrasyon task'ı |
| 3 | S1-10 Touch/Gesture Input'u Sprint 2'ye al ya da descope kararı ver | producer | Orta | Sprint 2 planlaması |
| 4 | Sprint 2 task tahminlerinde "gün" yerine "oturum-karmaşıklığı" metriği dene (S/M/L/XL) | producer | Düşük | Sprint 2 planlaması |

---

## Process Improvements

- **Credential kalıcılığı:** `git credential.helper` yapılandırılırsa push blokajı tamamen ortadan kalkar. Proxy token değişimleri için fallback olarak PAT her zaman hazır olacak.
- **Test task'larını implementasyonla birleştir:** S1-07/S1-08 gibi ayrı "test suite" task'ları, implementasyon task'ının acceptance criteria'sına dahil edilsin. Ayrı commit zorunluluğu kaldırılabilir; tek commit "impl + tests" içerebilir. Bu gereksiz task bölünmesini önler.

---

## Summary

Sprint 1, Must Have ve Should Have hedeflerinin tamamını (%90 genel) tek oturumda teslim etti — güçlü bir başlangıç. Test kodu kaynak kodu hacmini geçti (1 456 vs 1 348 satır), teknik borç sıfır. En kritik sorun teknik değil altyapısal: git push proxy 403 hatası birden fazla oturumu engelledi ve manuel müdahale gerektirdi. **Sprint 2'ye geçmeden önce credential store yapılandırılmalı; `SaveLoadManager` placeholder bölümleri gerçek sistemlerle doldurulmalı.**
