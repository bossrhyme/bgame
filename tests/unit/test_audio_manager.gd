## test_audio_manager.gd
##
## GUT testleri — AudioManager (S2-02)
## Kapsanan AC'ler: AC-01, AC-04, AC-06, AC-07, AC-08, AC-12
##
## Not: AudioStreamWAV.new() (boş stream) kullanılır. finished sinyali audio
## frame'inde emit edilir; testler aynı frame içinde senkron kontrol yapar.
extends GutTest

var _am: AudioManager


func before_each() -> void:
	_am = AudioManager.new()
	add_child_autofree(_am)


func _make_stream() -> AudioStream:
	return AudioStreamWAV.new()


# ── AC-01: play_sfx oynatıcı döndürür ────────────────────────────────────────

func test_play_sfx_returns_player() -> void:
	var player := _am.play_sfx(_make_stream())
	assert_not_null(player, "play_sfx bir AudioStreamPlayer döndürmeli")


func test_play_sfx_adds_to_active_list() -> void:
	_am.play_sfx(_make_stream())
	assert_eq(_am._active_sfx.size(), 1, "play_sfx _active_sfx'e eklenmeli")


func test_play_sfx_player_has_sfx_bus() -> void:
	var player := _am.play_sfx(_make_stream())
	if player:
		assert_eq(player.bus, AudioManager.BUS_SFX, "SFX oynatıcı BUS_SFX'e atanmalı")


func test_play_sfx_pitch_randomized() -> void:
	var player := _am.play_sfx(_make_stream())
	if player:
		assert_true(
			player.pitch_scale >= 1.0 - AudioManager.SFX_PITCH_RANGE and
			player.pitch_scale <= 1.0 + AudioManager.SFX_PITCH_RANGE,
			"Pitch ±SFX_PITCH_RANGE aralığında olmalı"
		)


# ── AC-04: Polyphony limiti ───────────────────────────────────────────────────

func test_polyphony_limit_all_slots_fill() -> void:
	for i in range(AudioManager.SFX_POLYPHONY_LIMIT):
		_am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_MEDIUM)
	assert_eq(_am._active_sfx.size(), AudioManager.SFX_POLYPHONY_LIMIT,
		"8 oynatıcı aktif olmalı")


func test_polyphony_limit_rejects_when_all_higher_priority() -> void:
	# 8 MEDIUM doldur, LOW ile gelen reddedilmeli
	for i in range(AudioManager.SFX_POLYPHONY_LIMIT):
		_am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_MEDIUM)
	var result := _am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_LOW)
	assert_null(result, "Düşük öncelikli SFX polyphony doluyken reddedilmeli")


func test_polyphony_limit_cuts_lowest_for_higher_incoming() -> void:
	# 8 LOW doldur, HIGH ile gelen kabul edilmeli ve toplam limit aşılmamalı
	for i in range(AudioManager.SFX_POLYPHONY_LIMIT):
		_am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_LOW)
	assert_eq(_am._active_sfx.size(), AudioManager.SFX_POLYPHONY_LIMIT)

	var result := _am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_HIGH)
	assert_not_null(result, "Yüksek öncelikli SFX düşükler varken eklenebilmeli")
	assert_eq(_am._active_sfx.size(), AudioManager.SFX_POLYPHONY_LIMIT,
		"Toplam limit aşılmamalı")


func test_polyphony_limit_keeps_priority_of_cut_entry() -> void:
	# LOW kesilince, kalan + yeni toplam LOW sayısı azalmalı
	for i in range(AudioManager.SFX_POLYPHONY_LIMIT):
		_am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_LOW)
	_am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_HIGH)
	# Sonuçta en az 1 HIGH priority entry olmalı
	var high_count: int = 0
	for e: Dictionary in _am._active_sfx:
		if e.get("priority") == AudioManager.SFX_PRIORITY_HIGH:
			high_count += 1
	assert_eq(high_count, 1, "HIGH priority entry listede bulunmalı")


# ── AC-06: Battery saver — ambient bus ───────────────────────────────────────

func test_battery_saver_enabled_silences_ambient() -> void:
	var bus_idx := AudioServer.get_bus_index(AudioManager.BUS_AMBIENT)
	if bus_idx < 0:
		pass_test("Ambient bus test ortamında tanımlı değil — atlanıyor")
		return
	AudioServer.set_bus_volume_db(bus_idx, 0.0)
	_am._on_battery_saver_changed(true)
	assert_almost_eq(
		AudioServer.get_bus_volume_db(bus_idx),
		AudioManager.SILENCE_DB,
		0.01,
		"battery_saver etkinken Ambient bus SILENCE_DB olmalı"
	)


func test_battery_saver_disabled_no_crash() -> void:
	# _settings_ref null iken battery_saver=false çağrısı hata vermemeli
	_am._settings_ref = null
	_am._on_battery_saver_changed(false)
	pass_test("battery_saver=false çağrısı null settings ile crash vermedi")


# ── AC-07: Master mute — tüm bus'lar SILENCE_DB ──────────────────────────────

func test_master_mute_silences_music_bus() -> void:
	var music_idx := AudioServer.get_bus_index(AudioManager.BUS_MUSIC)
	if music_idx < 0:
		pass_test("Music bus test ortamında tanımlı değil — atlanıyor")
		return
	AudioServer.set_bus_volume_db(music_idx, 0.0)
	_am._on_audio_changed(80, 80, 70, true)
	assert_almost_eq(
		AudioServer.get_bus_volume_db(music_idx),
		AudioManager.SILENCE_DB,
		0.01,
		"Music bus mute'da SILENCE_DB olmalı"
	)


func test_master_mute_silences_sfx_bus() -> void:
	var sfx_idx := AudioServer.get_bus_index(AudioManager.BUS_SFX)
	if sfx_idx < 0:
		pass_test("SFX bus test ortamında tanımlı değil — atlanıyor")
		return
	AudioServer.set_bus_volume_db(sfx_idx, 0.0)
	_am._on_audio_changed(80, 80, 70, true)
	assert_almost_eq(
		AudioServer.get_bus_volume_db(sfx_idx),
		AudioManager.SILENCE_DB,
		0.01,
		"SFX bus mute'da SILENCE_DB olmalı"
	)


func test_unmute_does_not_crash() -> void:
	_am._on_audio_changed(80, 80, 70, false)
	pass_test("Mute=false çağrısı hata vermedi")


# ── AC-08: play_music — crossfade player yönetimi ────────────────────────────

func test_play_music_creates_player_in_list() -> void:
	_am.play_music(_make_stream())
	assert_eq(_am._music_players.size(), 1, "play_music _music_players listesine eklenmeli")


func test_play_music_player_starts_at_silence() -> void:
	_am.play_music(_make_stream())
	if _am._music_players.size() > 0:
		var p: AudioStreamPlayer = _am._music_players[0]
		assert_almost_eq(
			p.volume_db,
			AudioManager.SILENCE_DB,
			0.01,
			"Yeni müzik oynatıcı SILENCE_DB'den başlamalı (F-2 crossfade)"
		)


func test_play_music_second_call_clears_previous_list() -> void:
	_am.play_music(_make_stream())
	assert_eq(_am._music_players.size(), 1)
	_am.play_music(_make_stream())
	assert_eq(_am._music_players.size(), 1, "İkinci play_music önceki listeyi temizlemeli")


func test_play_music_player_uses_music_bus() -> void:
	_am.play_music(_make_stream())
	if _am._music_players.size() > 0:
		assert_eq(_am._music_players[0].bus, AudioManager.BUS_MUSIC,
			"Müzik oynatıcı BUS_MUSIC'e atanmalı")


# ── AC-12: SFX high priority slot limiti ────────────────────────────────────

func test_high_priority_limit_accepts_up_to_limit() -> void:
	for i in range(AudioManager.SFX_HIGH_PRIORITY_LIMIT):
		var result := _am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_HIGH)
		assert_not_null(result, "HIGH priority limit içinde kabul edilmeli (slot %d)" % i)


func test_high_priority_limit_rejects_beyond_limit() -> void:
	for i in range(AudioManager.SFX_HIGH_PRIORITY_LIMIT):
		_am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_HIGH)
	var rejected := _am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_HIGH)
	assert_null(rejected, "HIGH priority limiti dolunca 5. HIGH reddedilmeli")


func test_high_priority_count_after_filling() -> void:
	for i in range(AudioManager.SFX_HIGH_PRIORITY_LIMIT):
		_am.play_sfx(_make_stream(), AudioManager.SFX_PRIORITY_HIGH)
	var count: int = 0
	for e: Dictionary in _am._active_sfx:
		if e.get("priority") == AudioManager.SFX_PRIORITY_HIGH:
			count += 1
	assert_eq(count, AudioManager.SFX_HIGH_PRIORITY_LIMIT,
		"Tam olarak SFX_HIGH_PRIORITY_LIMIT kadar HIGH entry olmalı")
