extends Node2D

const COMPLETE_FLAG := "combat_orientation_complete"
const MOVE_DISTANCE_REQUIRED := 22.0

var saw_move := false
var saw_strike := false
var saw_boost := false
var saw_deflect := false
var travelled := 0.0
var last_player_pos := Vector2.ZERO
var tracking_started := false
var completion_announced := false

func game():
	return get_parent()

func orientation_complete() -> bool:
	return GameState.has_flag(COMPLETE_FLAG)

func active_combat(parent) -> bool:
	return parent != null and parent.ui_mode == "play" and int(parent.current_act) == 1 and not parent.paused and not parent.dead and not parent.dialogue_open and not parent.module_pending and str(parent.stage) in ["wave_a", "wave_b", "boss"]

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	if orientation_complete() or int(parent.current_act) != 1:
		queue_redraw()
		return

	if not active_combat(parent):
		last_player_pos = Vector2(parent.player_pos)
		tracking_started = false
		queue_redraw()
		return

	var current_pos := Vector2(parent.player_pos)
	if not tracking_started:
		last_player_pos = current_pos
		tracking_started = true
	else:
		travelled += current_pos.distance_to(last_player_pos)
		last_player_pos = current_pos
		if travelled >= MOVE_DISTANCE_REQUIRED:
			saw_move = true

	if float(parent.attack_time) > 0.0:
		saw_strike = true
	if float(parent.dash_time) > 0.0:
		saw_boost = true
	if float(parent.deflect_time) > 0.0:
		saw_deflect = true

	if saw_move and saw_strike and saw_boost and saw_deflect:
		complete_orientation(parent)
	queue_redraw()

func complete_orientation(parent) -> void:
	if orientation_complete():
		return
	GameState.set_flag(COMPLETE_FLAG)
	SaveManager.save_campaign()
	if not completion_announced:
		completion_announced = true
		parent.flash_status("FRAME LINK // CALIBRATED")
		AudioManager.play_sfx("confirm")

func prompt_id() -> String:
	if not saw_move:
		return "move"
	if not saw_strike:
		return "strike"
	if not saw_boost:
		return "boost"
	if not saw_deflect:
		return "deflect"
	return "complete"

func prompt_copy(parent) -> Array[String]:
	var touch := bool(parent.touch_mode)
	match prompt_id():
		"move":
			return ["MOVE // LEFT THUMB" if touch else "MOVE // WASD / LEFT STICK", "Wake the frame. Stay mobile."]
		"strike":
			return ["STRIKE // STRIKE" if touch else "STRIKE // SPACE / A", "Build stagger. Own the opening."]
		"boost":
			return ["BOOST // BOOST" if touch else "BOOST // SHIFT / B", "Spend charge to cross danger."]
		"deflect":
			return ["DEFLECT // PARRY" if touch else "DEFLECT // F / X", "Meet the hit. Steal the opening."]
	return ["FRAME LINK // CALIBRATED", ""]

func should_draw_prompt(parent) -> bool:
	return active_combat(parent) and not orientation_complete() and float(parent.act_banner_time) < 0.75

func _draw() -> void:
	var parent = game()
	if parent == null or not should_draw_prompt(parent):
		return
	var copy := prompt_copy(parent)
	var font := ThemeDB.fallback_font
	var panel := Rect2(382.0, 76.0, 222.0, 48.0)
	draw_rect(panel, Color(0.025, 0.035, 0.055, 0.92), true)
	draw_rect(panel, Color("83bcc9"), false, 2.0)
	draw_string(font, panel.position + Vector2(10.0, 18.0), copy[0], HORIZONTAL_ALIGNMENT_LEFT, 202.0, 10, Color("f2dfb2"))
	draw_string(font, panel.position + Vector2(10.0, 36.0), copy[1], HORIZONTAL_ALIGNMENT_LEFT, 202.0, 9, Color("aeb8c6"))
