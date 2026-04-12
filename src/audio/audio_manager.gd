## AudioManager
##
## Oyun sesini merkezi olarak yönetir: 4 bus (Master/Music/SFX/Ambient),
## müzik crossfade, ambient katmanları ve SFX polyphony + priority sistemi.
##
## Mimari kuralları (GDD Audio Bus/Mixer):
##   - SettingsManager.audio_changed sinyalini dinler; AudioServer bus'larını günceller
##   - play_sfx: SFX_POLYPHONY_LIMIT=8; doluysa en düşük öncelikli oynatıcı kesilir
##   - play_music: F-2 crossfade (Tween, 1.5sn); _process() yasak (ADR-0003)
##   - play_ambient: F-3 fade-in (Tween, 2.0sn); stop_ambient: fade-out (1.0sn)
##   - Bağımlılık enjeksiyonu: _settings_ref test izolasyonu için
class_name AudioManager
extends Node

# ── Sabitler ─────────────────────────────────────────────────────────────────

const BUS_MASTER: String  = "Master"
const BUS_MUSIC: String   = "Music"
const BUS_SFX: String     = "SFX"
const BUS_AMBIENT: String = "Ambient"

const MUSIC_CROSSFADE_SEC: float   = 1.5
const AMBIENT_ATTACK_SEC: float    = 2.0
const AMBIENT_RELEASE_SEC: float   = 1.0

const SFX_POLYPHONY_LIMIT: int     = 8
const SFX_HIGH_PRIORITY_LIMIT: int = 4
const SFX_PITCH_RANGE: float       = 0.05

const SFX_PRIORITY_HIGH: int   = 2
const SFX_PRIORITY_MEDIUM: int = 1
const SFX_PRIORITY_LOW: int    = 0

const SILENCE_DB: float = -80.0

# ── Durum ─────────────────────────────────────────────────────────────────────

## Aktif SFX oynatıcı listesi: {"player": AudioStreamPlayer, "priority": int}
var _active_sfx: Array = []

## Müzik oynatıcıları: crossfade için outgoing sonrası incoming tutulur
var _music_players: Array[AudioStreamPlayer] = []

## Ambient katman oynatıcıları (layer 0–2)
var _ambient_players: Array[AudioStreamPlayer] = []

## SettingsManager bağımlılık enjeksiyonu (test izolasyonu)
var _settings_ref: SettingsManager = null

## Aktif müzik crossfade Tween referansı
var _music_tween: Tween = null


func _ready() -> void:
	var settings := _get_settings()
	if settings:
		settings.audio_changed.connect(_on_audio_changed)
		settings.battery_saver_changed.connect(_on_battery_saver_changed)


# ── Public API — SFX ─────────────────────────────────────────────────────────

## SFX oynatır. Polyphony doluysa en düşük öncelikli oynatıcı kesilir.
## priority: SFX_PRIORITY_HIGH / MEDIUM / LOW
## Returns: oynatıcı node (null = polyphony / öncelik reddi)
func play_sfx(stream: AudioStream, priority: int = SFX_PRIORITY_MEDIUM) -> AudioStreamPlayer:
	# HIGH priority slot limiti (F-1)
	if priority == SFX_PRIORITY_HIGH and _count_high_priority() >= SFX_HIGH_PRIORITY_LIMIT:
		return null

	# Polyphony limiti: en düşük öncelikliyi kes
	if _active_sfx.size() >= SFX_POLYPHONY_LIMIT:
		var cut_idx := _find_lowest_priority_idx(priority)
		if cut_idx < 0:
			return null  # Tüm oynatıcılar daha yüksek öncelikli → reddet
		_cut_sfx(cut_idx)

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_SFX
	player.pitch_scale = 1.0 + randf_range(-SFX_PITCH_RANGE, SFX_PITCH_RANGE)
	add_child(player)
	player.play()

	var entry := {"player": player, "priority": priority}
	_active_sfx.append(entry)
	player.finished.connect(_remove_sfx_entry.bind(entry))
	return player


# ── Public API — Müzik ───────────────────────────────────────────────────────

## Müzik parçasını crossfade ile geçirir (F-2, MUSIC_CROSSFADE_SEC).
## Önceki parça fade-out, yeni parça SILENCE_DB'den fade-in.
func play_music(stream: AudioStream) -> void:
	for p: AudioStreamPlayer in _music_players:
		if is_instance_valid(p) and p.playing:
			_fade_out_and_free(p, MUSIC_CROSSFADE_SEC)
	_music_players.clear()

	var incoming := AudioStreamPlayer.new()
	incoming.stream = stream
	incoming.bus = BUS_MUSIC
	incoming.volume_db = SILENCE_DB
	add_child(incoming)
	incoming.play()
	_music_players.append(incoming)

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(incoming, "volume_db", 0.0, MUSIC_CROSSFADE_SEC)


## Müziği fade-out ile durdurur.
func stop_music() -> void:
	for p: AudioStreamPlayer in _music_players:
		if is_instance_valid(p):
			_fade_out_and_free(p, MUSIC_CROSSFADE_SEC)
	_music_players.clear()
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()


# ── Public API — Ambient ─────────────────────────────────────────────────────

## Ambient katmanını çalar (F-3, fade-in AMBIENT_ATTACK_SEC). layer_idx: 0–2.
func play_ambient(stream: AudioStream, layer_idx: int = 0) -> void:
	layer_idx = clampi(layer_idx, 0, 2)

	if layer_idx < _ambient_players.size():
		var old: AudioStreamPlayer = _ambient_players[layer_idx]
		if is_instance_valid(old):
			_fade_out_and_free(old, AMBIENT_RELEASE_SEC)

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_AMBIENT
	player.volume_db = SILENCE_DB
	add_child(player)
	player.play()

	while _ambient_players.size() <= layer_idx:
		_ambient_players.append(null)
	_ambient_players[layer_idx] = player

	var t := create_tween()
	t.tween_property(player, "volume_db", 0.0, AMBIENT_ATTACK_SEC)


## Tüm ambient katmanlarını durdurur (fade-out AMBIENT_RELEASE_SEC).
func stop_ambient() -> void:
	for p: AudioStreamPlayer in _ambient_players:
		if is_instance_valid(p):
			_fade_out_and_free(p, AMBIENT_RELEASE_SEC)
	_ambient_players.clear()


# ── Internal — SettingsManager sinyalleri ────────────────────────────────────

func _on_audio_changed(music: int, sfx: int, ambient: int, mute: bool) -> void:
	_apply_bus_volumes(mute, music, sfx, ambient)


func _on_battery_saver_changed(enabled: bool) -> void:
	var bus_idx: int = AudioServer.get_bus_index(BUS_AMBIENT)
	if bus_idx < 0:
		return
	if enabled:
		AudioServer.set_bus_volume_db(bus_idx, SILENCE_DB)
	else:
		var settings := _get_settings()
		if settings:
			AudioServer.set_bus_volume_db(bus_idx, _slider_to_db(settings.ambient_volume))


func _apply_bus_volumes(mute: bool, music: int, sfx: int, ambient: int) -> void:
	_set_bus_db(BUS_MUSIC,   SILENCE_DB if mute else _slider_to_db(music))
	_set_bus_db(BUS_SFX,     SILENCE_DB if mute else _slider_to_db(sfx))
	_set_bus_db(BUS_AMBIENT, SILENCE_DB if mute else _slider_to_db(ambient))


func _set_bus_db(bus_name: String, db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func _slider_to_db(value: int) -> float:
	if value <= 0:
		return SILENCE_DB
	return linear_to_db(clampf(value / 100.0, 0.0, 1.0))


# ── Internal — SFX yardımcıları ───────────────────────────────────────────────

func _remove_sfx_entry(entry: Dictionary) -> void:
	_active_sfx.erase(entry)
	var player: AudioStreamPlayer = entry.get("player")
	if is_instance_valid(player):
		player.queue_free()


## Gelen öncelikten DÜŞÜK en eski oynatıcının indeksini döndürür.
## Bulunamazsa -1 → polyphony limiti reddi.
func _find_lowest_priority_idx(incoming_priority: int) -> int:
	var lowest_prio: int = incoming_priority
	var found_idx: int = -1
	for i in range(_active_sfx.size()):
		var p: int = _active_sfx[i].get("priority", SFX_PRIORITY_MEDIUM)
		if p < lowest_prio:
			lowest_prio = p
			found_idx = i
	return found_idx


func _cut_sfx(idx: int) -> void:
	var entry: Dictionary = _active_sfx[idx]
	_active_sfx.remove_at(idx)
	var player: AudioStreamPlayer = entry.get("player")
	if is_instance_valid(player):
		player.stop()
		player.queue_free()


func _count_high_priority() -> int:
	var count: int = 0
	for entry: Dictionary in _active_sfx:
		if entry.get("priority", SFX_PRIORITY_MEDIUM) == SFX_PRIORITY_HIGH:
			count += 1
	return count


func _fade_out_and_free(player: AudioStreamPlayer, duration: float) -> void:
	var t := create_tween()
	t.tween_property(player, "volume_db", SILENCE_DB, duration)
	t.tween_callback(player.queue_free)


# ── Bağımlılık enjeksiyonu ────────────────────────────────────────────────────

func _get_settings() -> SettingsManager:
	if _settings_ref:
		return _settings_ref
	return get_node_or_null("/root/Settings") as SettingsManager
