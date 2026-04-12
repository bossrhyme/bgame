## GestureConfig — Touch/Gesture eşik değerleri Resource
##
## Tüm değerler Godot Inspector'dan değiştirilebilir; kod değişikliği gerekmez.
## Kaynak dosyası: assets/data/gesture_config.tres
## Tuning Knobs referansı: design/gdd/touch-gesture-input.md — Tuning Knobs bölümü
class_name GestureConfig
extends Resource

## Hamur yoğurma için gereken tam tur sayısı. Güvenli aralık: 2–5.
@export var circles_required: int = 3
## Circular/drag intent onayı için minimum parmak hareketi (px). Güvenli aralık: 20–80.
@export var min_radius: float = 40.0
## Bu mesafeyi aşan circular gesture iptal edilir (px). Güvenli aralık: 150–300.
@export var max_radius: float = 200.0
## Bu süreyi aşan dokunuş tap sayılmaz (ms). Güvenli aralık: 150–500.
@export var tap_max_ms: float = 300.0
## Bu süre hareketsiz basılırsa long-press intent onaylanır (ms). Güvenli aralık: 150–400.
@export var long_press_duration_ms: float = 250.0
## Her tam turda titreşim süresi (ms). Güvenli aralık: 10–50.
@export var haptic_tick_ms: int = 20
## Yoğurma tamamlandığında titreşim süresi (ms). Güvenli aralık: 40–150.
@export var haptic_complete_ms: int = 80
## DropZone snap alanı yarıçapı (px). Güvenli aralık: 40–100.
@export var drag_drop_snap_radius: float = 60.0
