extends Node

const SETTINGS_PATH := "user://dying_sun_settings_v1.json"

var master_volume: float = 1.0
var music_volume: float = 0.80
var sfx_volume: float = 0.90
var screen_shake: bool = true
var high_contrast: bool = false
var fullscreen: bool = false

func _ready() -> void:
	load_settings()
	apply_display()

func snapshot() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"screen_shake": screen_shake,
		"high_contrast": high_contrast,
		"fullscreen": fullscreen,
	}

func load_settings() -> bool:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return false
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		return false
	master_volume = clampf(float(parsed.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(parsed.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(parsed.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	screen_shake = bool(parsed.get("screen_shake", screen_shake))
	high_contrast = bool(parsed.get("high_contrast", high_contrast))
	fullscreen = bool(parsed.get("fullscreen", fullscreen))
	return true

func save_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot()))
	file.flush()
	return true

func set_master(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()

func set_music(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()

func set_sfx(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_settings()

func toggle_screen_shake() -> void:
	screen_shake = not screen_shake
	save_settings()

func toggle_high_contrast() -> void:
	high_contrast = not high_contrast
	save_settings()

func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_display()
	save_settings()

func apply_audio() -> void:
	if AudioServer.bus_count <= 0:
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)

func apply_display() -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
