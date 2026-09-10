extends Node

const SAMPLE_RATE := 22050

var ambience := AudioStreamPlayer.new()
var sfx_players: Array[AudioStreamPlayer] = []
var cached_sfx: Dictionary = {}
var cached_ambience: Dictionary = {}
var observed_scene_id := 0
var last_act := -1
var last_hp := -1
var last_enemy_count := -1
var last_attack_active := false
var last_dash_active := false
var last_deflect_active := false
var last_stage := ""
var last_dead := false

func _ready() -> void:
	ambience.name = "ActAmbience"
	add_child(ambience)
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%d" % i
		add_child(player)
		sfx_players.append(player)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("perform_attack"):
		if ambience.playing:
			ambience.stop()
		reset_observer()
		return

	var scene_id := scene.get_instance_id()
	if scene_id != observed_scene_id:
		observed_scene_id = scene_id
		last_act = -1
		last_hp = int(scene.get("player_hp"))
		last_enemy_count = int(Array(scene.get("enemies")).size())
		last_stage = str(scene.get("stage"))
		last_dead = bool(scene.get("dead"))

	var act := int(scene.get("current_act"))
	if act != last_act:
		last_act = act
		set_act_ambience(act)
		play_sfx("act")

	var attack_active := float(scene.get("attack_time")) > 0.0
	if attack_active and not last_attack_active:
		play_sfx("strike")
	last_attack_active = attack_active

	var dash_active := float(scene.get("dash_time")) > 0.0
	if dash_active and not last_dash_active:
		play_sfx("boost")
	last_dash_active = dash_active

	var deflect_active := float(scene.get("deflect_time")) > 0.0
	if deflect_active and not last_deflect_active:
		play_sfx("parry")
	last_deflect_active = deflect_active

	var hp := int(scene.get("player_hp"))
	if last_hp >= 0 and hp < last_hp:
		play_sfx("hurt")
	last_hp = hp

	var count := Array(scene.get("enemies")).size()
	if last_enemy_count >= 0 and count < last_enemy_count:
		play_sfx("impact")
	last_enemy_count = count

	var stage := str(scene.get("stage"))
	if stage != last_stage:
		if stage == "boss": play_sfx("boss")
		elif stage == "choice": play_sfx("signal")
		elif stage == "module": play_sfx("module")
		last_stage = stage

	var dead := bool(scene.get("dead"))
	if dead and not last_dead:
		play_sfx("death")
	last_dead = dead
	apply_levels()

func reset_observer() -> void:
	observed_scene_id = 0
	last_act = -1
	last_hp = -1
	last_enemy_count = -1
	last_attack_active = false
	last_dash_active = false
	last_deflect_active = false
	last_stage = ""
	last_dead = false

func apply_levels() -> void:
	ambience.volume_db = linear_to_db(maxf(SettingsManager.music_volume, 0.0001))
	ambience.stream_paused = SettingsManager.music_volume <= 0.001
	for player in sfx_players:
		player.volume_db = linear_to_db(maxf(SettingsManager.sfx_volume, 0.0001))

func set_act_ambience(act: int) -> void:
	if not cached_ambience.has(act):
		cached_ambience[act] = build_ambience(act)
	ambience.stream = cached_ambience[act]
	ambience.volume_db = linear_to_db(maxf(SettingsManager.music_volume * 0.42, 0.0001))
	ambience.play()

func play_sfx(id: String) -> void:
	if SettingsManager.sfx_volume <= 0.001:
		return
	if not cached_sfx.has(id):
		cached_sfx[id] = build_sfx(id)
	var player := free_sfx_player()
	player.stream = cached_sfx[id]
	player.volume_db = linear_to_db(maxf(SettingsManager.sfx_volume * sfx_gain(id), 0.0001))
	player.pitch_scale = 1.0
	player.play()

func free_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	return sfx_players[0]

func sfx_gain(id: String) -> float:
	match id:
		"hurt", "death": return 0.72
		"boss": return 0.68
		"boost": return 0.52
		_: return 0.58

func build_sfx(id: String) -> AudioStreamWAV:
	match id:
		"strike": return synth_sweep(190.0, 110.0, 0.11, 0.75, "noise")
		"impact": return synth_sweep(105.0, 48.0, 0.12, 0.95, "square")
		"boost": return synth_sweep(120.0, 410.0, 0.18, 0.62, "sine")
		"parry": return synth_sweep(760.0, 1280.0, 0.09, 0.54, "sine")
		"hurt": return synth_sweep(150.0, 62.0, 0.20, 0.78, "square")
		"death": return synth_sweep(180.0, 28.0, 0.62, 0.85, "sine")
		"boss": return synth_sweep(52.0, 105.0, 0.75, 0.82, "square")
		"signal": return synth_sweep(430.0, 690.0, 0.32, 0.48, "sine")
		"module": return synth_sweep(310.0, 930.0, 0.38, 0.45, "sine")
		"act": return synth_sweep(95.0, 190.0, 0.55, 0.38, "sine")
		_: return synth_sweep(220.0, 220.0, 0.10, 0.4, "sine")

func synth_sweep(start_hz: float, end_hz: float, seconds: float, amplitude: float, waveform: String) -> AudioStreamWAV:
	var frames := maxi(1, int(seconds * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in range(frames):
		var t := float(i) / float(maxi(1, frames - 1))
		var hz := lerpf(start_hz, end_hz, t)
		phase += TAU * hz / float(SAMPLE_RATE)
		var wave := sin(phase)
		if waveform == "square":
			wave = 1.0 if wave >= 0.0 else -1.0
		elif waveform == "noise":
			var pseudo := sin(float(i * 9176 + 331) * 0.0174533)
			wave = wave * 0.55 + pseudo * 0.45
		var attack := minf(1.0, t * 18.0)
		var release := pow(1.0 - t, 1.65)
		var sample := int(clampf(wave * amplitude * attack * release, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func build_ambience(act: int) -> AudioStreamWAV:
	var seconds := 4.0
	var frames := int(seconds * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var base := [43.0, 52.0, 46.0, 58.0, 39.0][clampi(act - 1, 0, 4)]
	var fifth := base * 1.5
	var high := base * (2.0 + float(act) * 0.09)
	for i in range(frames):
		var time := float(i) / float(SAMPLE_RATE)
		var slow := sin(TAU * base * time) * 0.44
		var layer := sin(TAU * fifth * time + sin(time * 0.7) * 0.4) * 0.20
		var shimmer := sin(TAU * high * time) * (0.06 + 0.03 * sin(time * 1.9))
		var pulse := 0.80 + 0.20 * sin(TAU * (0.22 + float(act) * 0.025) * time)
		var sample := int(clampf((slow + layer + shimmer) * pulse * 0.34, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream
