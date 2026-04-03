# ADR-0001 — Engine: Godot 4.6

**Status:** Accepted
**Date:** 2026-04-02
**Deciders:** Proje sahibi

---

## Context

Ekmek Ustası, mobil (iOS/Android) hedefli bir 2D idle/clicker hibrit oyundur.
Engine seçimi tüm geliştirme sürecini etkiler: dil, export pipeline, eklenti
ekosistemi, lisans maliyeti ve geliştirici deneyimi.

## Problem

Hangi oyun motoru projenin hedefleriyle en iyi örtüşür?
- Mobil 2D idle oyun
- Solo/küçük ekip geliştirme
- Hızlı prototipleme ihtiyacı
- Sıfır lisans maliyeti tercihi

## Kısıtlar

- Platform: iOS + Android zorunlu
- Bütçe: Ücretsiz veya gelir eşiğine kadar ücretsiz motor
- Dil: GDScript veya C# tercih edilir (C++ değil)
- Ekip: Küçük, 2D deneyimli

## Karar

**Godot 4.6 + GDScript** kullanılacak.
- C++ sadece performans kritik sistemler için GDExtension üzerinden
- Rendering: Mobile Renderer (iOS/Android), Forward+ editor önizlemesi
- Physics: Jolt (Godot 4.6 varsayılanı)

## Değerlendirilen Alternatifler

| Motor | Artı | Eksi | Eleme Gerekçesi |
|-------|------|------|-----------------|
| **Godot 4.6** ✓ | MIT lisans, native 2D, GDScript | Daha küçük ekosistem | — Seçildi |
| Unity 6 | Büyük ekosistem, Addressables | Gelir bazlı lisans riski, 3D odaklı | Lisans belirsizliği + 2D için fazla |
| Unreal Engine 5 | En yüksek grafik kalitesi | C++ zorunlu, mobil için ağır | Idle oyun için overkill |

## Sonuçlar

**Olumlu:**
- MIT lisansı → sıfır royalty maliyeti
- Native 2D sahne sistemi → sprite, tilemap, 2D fizik kutudan çıkar
- GDScript → Python-benzeri sözdizimi, hızlı iterasyon
- Godot 4.6 Jolt fiziği → kararlı, performanslı mobil fizik

**Olumsuz / Riskler:**
- Godot 4.4–4.6 LLM eğitim verisinin dışında → API önerileri doğrulanmalı
- Unity/Unreal kadar geniş eklenti ekosistemi yok → bazı araçlar el yapımı olacak

## Doğrulama Kriterleri

- [ ] Godot 4.6 ile iOS ve Android export başarılı
- [ ] GUT test framework entegre edildi
- [ ] Mid-range Android cihazda 60 FPS hedefi tutturuluyor

## İlgili Kararlar

- ADR-0003: Idle Loop — Timer bazlı güncelleme (Godot Timer node tercih sebebi)
