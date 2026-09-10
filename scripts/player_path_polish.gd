extends Node2D

const TOUCH_PAUSE_CENTER := Vector2(590, 45)
const TOUCH_PAUSE_RADIUS := 18.0
const TOUCH_RESTART_RECT := Rect2(205, 286, 230, 30)

func game():
	return get_parent()

func _ready() -> void:
	process_priority = 80
	z_index = 15
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	var parent = game()
	if parent == null or parent.ui_mode != "play":
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		parent.touch_mode = true
		if touch.position.distance_to(TOUCH_PAUSE_CENTER) <= TOUCH_PAUSE_RADIUS + 10.0:
			parent.paused = not parent.paused
			parent.pause_selection = 0
			get_viewport().set_input_as_handled()
			return
		if parent.paused and TOUCH_RESTART_RECT.has_point(touch.position):
			restart_checkpoint(parent)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
			return
		if parent.touch_mode and mouse.position.distance_to(TOUCH_PAUSE_CENTER) <= TOUCH_PAUSE_RADIUS + 10.0:
			parent.paused = not parent.paused
			parent.pause_selection = 0
			get_viewport().set_input_as_handled()
			return
		if parent.touch_mode and parent.paused and TOUCH_RESTART_RECT.has_point(mouse.position):
			restart_checkpoint(parent)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.pressed and parent.paused and int(button.button_index) == int(JOY_BUTTON_Y):
			restart_checkpoint(parent)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and parent.paused and key.keycode == KEY_R:
			restart_checkpoint(parent)
			get_viewport().set_input_as_handled()

func restart_checkpoint(parent) -> void:
	parent.paused = false
	parent.restart_from_checkpoint()
	parent.pause_selection = 0

func objective_text(parent = null) -> String:
	if parent == null:
		parent = game()
	if parent == null or parent.ui_mode != "play":
		return ""

	var director = parent.get_node_or_null("SectorDirector")
	var act3 = parent.get_node_or_null("Act3Director")
	match str(parent.stage):
		"sector_intake_walk": return "OBJECTIVE // REACH THE INNER SEAL"
		"sector_furnace":
			var phase := int(director.get("furnace_phase")) if director != null else 0
			return "OBJECTIVE // BREAK THE HUSK // VENTS ARE LIVE" if phase >= 1 else "OBJECTIVE // BREAK THE WARDEN // LEARN THE STRIKE"
		"sector_coolant": return "OBJECTIVE // CLEAR THE BRIDGE // AVOID LIVE RAILS"
		"sector_gate_approach": return "OBJECTIVE // BREAK THE INNER-GATE SCREEN"
		"sector_gate_pressure": return "OBJECTIVE // SURVIVE THE ANTECHAMBER"
		"sector_memory_entry": return "OBJECTIVE // REACH THE INDEX SEAL"
		"sector_memory_seal": return "OBJECTIVE // BREAKER REQUIRED // HOLD Q / LB / BRK THEN RELEASE"
		"sector_memory_gallery": return "OBJECTIVE // CLEAR THE GALLERY // BREAKER SILENCES THE SWEEP"
		"sector_archive_hold":
			var held := float(director.get("archive_hold")) if director != null else 0.0
			return "OBJECTIVE // HOLD THE INDEX CORE // %.1f / 5.0 SEC" % minf(5.0, held)
		"sector_purge_run": return "OBJECTIVE // REACH THE FAR DOOR // BREAKER SILENCES PURGE"
		"sector_relay_entry", "sector_relay_sync", "sector_civilian_feed", "sector_defense_push":
			if act3 != null and act3.has_method("objective_text"):
				return str(act3.objective_text())
	return ""

func _draw() -> void:
	var parent = game()
	if parent == null:
		return
	if parent.ui_mode == "title":
		draw_title_controls(parent)
		return
	if parent.ui_mode != "play":
		return

	draw_runtime_readability(parent)
	if parent.touch_mode:
		draw_touch_pause(parent)
	if parent.paused:
		draw_restart_affordance(parent)
	elif not parent.touch_mode and not parent.dead:
		draw_desktop_control_strip(parent)

func draw_runtime_readability(parent) -> void:
	var font := ThemeDB.fallback_font
	var objective := objective_text(parent)
	if not objective.is_empty():
		draw_rect(Rect2(24, 53, 592, 29), Color(0.025, 0.03, 0.045, 0.92), true)
		draw_rect(Rect2(24, 53, 592, 29), Color(0.40, 0.45, 0.56, 0.34), false, 1.0)
		draw_string(font, Vector2(34, 72), objective, HORIZONTAL_ALIGNMENT_LEFT, 560, 9, Color(0.90, 0.91, 0.94, 0.96))

	draw_string(font, Vector2(153, 40), "ARMOR %d/%d" % [parent.player_hp, parent.max_hp()], HORIZONTAL_ALIGNMENT_LEFT, 82, 8, Color(0.72, 0.76, 0.82, 0.88))
	var charge_percent := int(round((float(parent.player_charge) / maxf(1.0, float(parent.max_charge()))) * 100.0))
	draw_string(font, Vector2(153, 51), "FRAME %d%%" % charge_percent, HORIZONTAL_ALIGNMENT_LEFT, 82, 8, Color(0.52, 0.75, 0.82, 0.90))

func draw_title_controls(parent) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(22, 312, 596, 46), Color(0.025, 0.03, 0.045, 0.94), true)
	if parent.touch_mode:
		draw_string(font, Vector2(34, 333), "TOUCH // left side moves // combat buttons appear in play", HORIZONTAL_ALIGNMENT_CENTER, 572, 9, Color(0.76, 0.80, 0.87, 0.95))
		draw_string(font, Vector2(34, 349), "PAUSE // top-right II button // tap choices and dialogue", HORIZONTAL_ALIGNMENT_CENTER, 572, 9, Color(0.61, 0.72, 0.82, 0.95))
	else:
		draw_string(font, Vector2(34, 333), "MOVE WASD / LEFT STICK   STRIKE SPACE / A   BOOST SHIFT / B", HORIZONTAL_ALIGNMENT_CENTER, 572, 9, Color(0.76, 0.80, 0.87, 0.95))
		draw_string(font, Vector2(34, 349), "PARRY F / X   ADVANCE E / Y   PAUSE ESC / START   ACT II+ BREAKER Q / LB", HORIZONTAL_ALIGNMENT_CENTER, 572, 8, Color(0.61, 0.72, 0.82, 0.95))

func draw_desktop_control_strip(parent) -> void:
	if parent.dialogue_open or parent.module_pending:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(24, 334, 592, 26), Color(0.025, 0.03, 0.045, 0.93), true)
	var line := "SPACE/A STRIKE   SHIFT/B BOOST   F/X PARRY   E/Y ADVANCE   ESC/START PAUSE"
	if int(parent.current_act) >= 2:
		line = "SPACE/A STRIKE   SHIFT/B BOOST   F/X PARRY   Q/LB BREAKER   ESC/START PAUSE"
	draw_string(font, Vector2(32, 351), line, HORIZONTAL_ALIGNMENT_CENTER, 576, 8, Color(0.65, 0.70, 0.78, 0.96))

func draw_touch_pause(parent) -> void:
	if parent.dead:
		return
	var font := ThemeDB.fallback_font
	var fill := Color(0.12, 0.14, 0.19, 0.88) if not parent.paused else Color(0.28, 0.22, 0.14, 0.92)
	draw_circle(TOUCH_PAUSE_CENTER, TOUCH_PAUSE_RADIUS, fill, true)
	draw_arc(TOUCH_PAUSE_CENTER, TOUCH_PAUSE_RADIUS, 0.0, TAU, 24, Color(0.82, 0.78, 0.68, 0.90), 2.0)
	draw_string(font, TOUCH_PAUSE_CENTER + Vector2(-10, 4), "II", HORIZONTAL_ALIGNMENT_CENTER, 20, 9, Color(0.95, 0.92, 0.84, 0.96))

func draw_restart_affordance(parent) -> void:
	var font := ThemeDB.fallback_font
	if parent.touch_mode:
		draw_rect(TOUCH_RESTART_RECT, Color(0.16, 0.11, 0.12, 0.94), true)
		draw_rect(TOUCH_RESTART_RECT, Color(0.74, 0.42, 0.38, 0.88), false, 2.0)
		draw_string(font, TOUCH_RESTART_RECT.position + Vector2(0, 20), "RESTART CHECKPOINT", HORIZONTAL_ALIGNMENT_CENTER, TOUCH_RESTART_RECT.size.x, 11, Color(0.96, 0.88, 0.84, 0.98))
	else:
		draw_string(font, Vector2(0, 302), "R / Y // RESTART CHECKPOINT", HORIZONTAL_ALIGNMENT_CENTER, 640, 10, Color(0.78, 0.67, 0.62, 0.95))
