# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript (primary), C++ via GDExtension (performance-critical systems only)
- **Rendering**: Mobile Renderer (iOS/Android target), Forward+ for editor/desktop preview
- **Physics**: GodotPhysics2D (2D varsayılan — bu proje 2D'dir; Jolt 3D fizik motorudur, kullanılmıyor)

## Naming Conventions

- **Classes**: PascalCase (e.g., `BreadOven`, `CustomerQueue`)
- **Variables**: snake_case (e.g., `bake_time`, `gold_count`)
- **Signals/Events**: snake_case geçmiş zaman (e.g., `bread_baked`, `customer_served`)
- **Files**: snake_case, class adıyla eşleşir (e.g., `bread_oven.gd`)
- **Scenes/Prefabs**: PascalCase, root node adıyla eşleşir (e.g., `BreadOven.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_OVEN_CAPACITY`, `OFFLINE_CAP_HOURS`)

## Performance Budgets

- **Target Framerate**: 60 FPS (30 FPS minimum kabul edilebilir — mobil mid-range cihaz)
- **Frame Budget**: 16.6ms (60fps) / 33ms (30fps)
- **Draw Calls**: Mobil için max 100 draw call/frame
- **Memory Ceiling**: 512MB (mobil mid-range hedef)

## Testing

- **Framework**: GUT (Godot Unit Testing) — https://github.com/bitwes/Gut
- **Minimum Coverage**: Tüm gameplay formülleri ve ekonomi sistemi
- **Required Tests**: Offline üretim hesabı, upgrade maliyet ölçekleme, müşteri memnuniyeti, tarif açma koşulları

## Forbidden Patterns

- Singleton/autoload'u veri deposu olarak kullanmak (sadece servis katmanı için)
- Gameplay değerlerini kod içinde hardcode etmek (her zaman Resource/config dosyasından)
- `_process()` içinde gameplay logic veya ekonomi hesabı (idle sistemleri için timer bazlı güncelleme kullan)
  - ✓ İzin verilenler: input polling, animasyon güncellemesi, debug UI yenileme
  - ✗ Yasak: gameplay state değişikliği, timer güncelleme, ekonomi hesabı, offline üretim hesabı

## Allowed Libraries / Addons

- **GUT** — unit test framework
- *(Diğerleri eklendikçe buraya eklenecek)*

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- **2026-04-02** — Engine: Godot 4.6 seçildi → `docs/architecture/adr-0001-engine-godot-4-6.md`
- **2026-04-03** — Monetizasyon: Rewarded Ad (IAP yok) → `docs/architecture/adr-0002-monetization-rewarded-ads.md`
- **2026-04-03** — Idle Loop: Timer bazlı (_process() yasak) → `docs/architecture/adr-0003-idle-loop-timer-based.md`
