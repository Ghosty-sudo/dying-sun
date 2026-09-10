extends Node2D

const INTAKE_THRESHOLD_X := 430.0
const FURNACE_VENTS := [Vector2(245, 110), Vector2(365, 250), Vector2(505, 135)]
const GATE_CORE := Vector2(365, 180)

var room_id := ""
var hazard_clock := 0.0
var room_title := ""
var room_title_time := 0.0

func game():
	return get_parent()

func _ready() -> void:
	z_index = 20
	queue_redraw()

func _process(delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	hazard_clock += delta
	room_title_time = maxf(0.0, room_title_time - delta)
	if parent.ui_mode != "play" or parent.paused:
		queue_redraw()
		return
	if int(parent.current_act) != 1:
		room_id = ""
		queue_redraw()
		return
	if parent.dead:
		queue_redraw()
		return

	if parent.stage == "wave_a":
		begin_intake_walk(parent)
	elif parent.stage == "wave_b":
		begin_gate_approach(parent)

	match str(parent.stage):
		"sector_intake_walk":
			if parent.player_pos.x >= INTAKE_THRESHOLD_X:
				begin_furnace(parent)
		"sector_furnace":
			apply_furnace_hazard(parent)
			if parent.enemies.is_empty():
				begin_coolant_bridge(parent)
		"sector_coolant":
			apply_coolant_hazard(parent)
			if parent.enemies.is_empty():
				room_id = "sol_link"
				parent.start_narrative_choice()
		"sector_gate_approach":
			apply_gate_hazard(parent)
			if parent.enemies.is_empty():
				begin_gate_pressure(parent)
		"sector_gate_pressure":
			apply_gate_hazard(parent)
			if parent.enemies.is_empty():
				room_id = "custodian_chamber"
				parent.spawn_boss()

	queue_redraw()

func begin_intake_walk(parent) -> void:
	room_id = "intake_walk"
	parent.stage = "sector_intake_walk"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(86, 182)
	announce(parent, "INTAKE ACCESS // FIND THE INNER SEAL")

func begin_furnace(parent) -> void:
	room_id = "furnace"
	parent.stage = "sector_furnace"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(84, 182)
	parent.enemies.append(parent.make_enemy(Vector2(330, 112), 3, "WARDEN"))
	parent.enemies.append(parent.make_enemy(Vector2(470, 242), 4, "HUSK"))
	announce(parent, "ASH FURNACE // VENTS CYCLING")

func begin_coolant_bridge(parent) -> void:
	room_id = "coolant"
	parent.stage = "sector_coolant"
	parent.projectiles.clear()
	parent.player_pos = Vector2(92, 180)
	parent.enemies.append(parent.make_enemy(Vector2(420, 110), 4, "HUSK"))
	parent.enemies.append(parent.make_enemy(Vector2(515, 228), 6, "SUN-HUSK"))
	announce(parent, "COOLANT BRIDGE // STAY OFF THE RAILS")

func begin_gate_approach(parent) -> void:
	room_id = "gate_approach"
	parent.stage = "sector_gate_approach"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(82, 182)
	parent.enemies.append(parent.make_enemy(Vector2(290, 92), 4, "WARDEN"))
	parent.enemies.append(parent.make_enemy(Vector2(340, 266), 4, "WARDEN"))
	parent.enemies.append(parent.make_enemy(Vector2(455, 112), 4, "HUSK"))
	parent.enemies.append(parent.make_enemy(Vector2(540, 238), 6, "SUN-HUSK"))
	announce(parent, "INNER GATE // BREAK THE SCREEN")

func begin_gate_pressure(parent) -> void:
	room_id = "gate_pressure"
	parent.stage = "sector_gate_pressure"
	parent.projectiles.clear()
	parent.player_pos = Vector2(102, 182)
	parent.enemies.append(parent.make_enemy(Vector2(410, 115), 5, "WARDEN"))
	parent.enemies.append(parent.make_enemy(Vector2(480, 240), 7, "SUN-HUSK"))
	announce(parent, "CUSTODIAN ANTECHAMBER // NO RETURN")

func announce(parent, text: String) -> void:
	room_title = text
	room_title_time = 2.4
	parent.flash_status(text)

func furnace_hot() -> bool:
	return fmod(hazard_clock, 2.4) < 0.72

func gate_hot() -> bool:
	return fmod(hazard_clock + 0.8, 2.0) < 0.58

func apply_furnace_hazard(parent) -> void:
	if not furnace_hot() or parent.hurt_cooldown > 0.0 or parent.dash_time > 0.0:
		return
	for vent in FURNACE_VENTS:
		if parent.player_pos.distance_to(vent) < 38.0:
			parent.hurt_player(1)
			parent.flash_status("FURNACE VENT // ARMOR BURN")
			return

func apply_coolant_hazard(parent) -> void:
	if parent.hurt_cooldown > 0.0 or parent.dash_time > 0.0:
		return
	if parent.player_pos.y < 78.0 or parent.player_pos.y > 286.0:
		parent.hurt_player(1)
		parent.flash_status("COOLANT RAIL // LIVE CURRENT")

func apply_gate_hazard(parent) -> void:
	if not gate_hot() or parent.hurt_cooldown > 0.0 or parent.dash_time > 0.0:
		return
	if parent.player_pos.distance_to(GATE_CORE) < 54.0:
		parent.hurt_player(1)
		parent.flash_status("GATE CORE // SOLAR DISCHARGE")

func _draw() -> void:
	if room_id.is_empty():
		return
	var parent = game()
	if parent == null or int(parent.current_act) != 1 or parent.ui_mode != "play":
		return
	var font := ThemeDB.fallback_font
	match room_id:
		"intake_walk":
			draw_line(Vector2(72, 86), Vector2(560, 86), Color(0.85, 0.55, 0.22, 0.34), 2.0)
			draw_line(Vector2(72, 274), Vector2(560, 274), Color(0.85, 0.55, 0.22, 0.34), 2.0)
			draw_rect(Rect2(430, 96, 118, 168), Color(0.85, 0.55, 0.22, 0.08), true)
			draw_string(font, Vector2(438, 184), "INNER SEAL", HORIZONTAL_ALIGNMENT_LEFT, 100, 10, Color(0.94, 0.72, 0.38, 0.80))
		"furnace":
			for vent in FURNACE_VENTS:
				draw_circle(vent, 38.0, Color(0.95, 0.28, 0.13, 0.22 if furnace_hot() else 0.07), true)
				draw_arc(vent, 39.0, 0.0, TAU, 24, Color(0.95, 0.50, 0.18, 0.75), 2.0)
		"coolant":
			draw_rect(Rect2(24, 24, 592, 54), Color(0.18, 0.65, 0.80, 0.16), true)
			draw_rect(Rect2(24, 286, 592, 50), Color(0.18, 0.65, 0.80, 0.16), true)
			draw_line(Vector2(24, 78), Vector2(616, 78), Color(0.40, 0.88, 0.96, 0.60), 2.0)
			draw_line(Vector2(24, 286), Vector2(616, 286), Color(0.40, 0.88, 0.96, 0.60), 2.0)
		"gate_approach", "gate_pressure", "custodian_chamber":
			draw_circle(GATE_CORE, 54.0, Color(1.0, 0.45, 0.12, 0.17 if gate_hot() else 0.05), true)
			draw_arc(GATE_CORE, 58.0, 0.0, TAU, 32, Color(0.95, 0.62, 0.22, 0.72), 3.0)
			draw_line(Vector2(365, 58), Vector2(365, 302), Color(0.95, 0.62, 0.22, 0.25), 2.0)
	if room_title_time > 0.0:
		draw_rect(Rect2(330, 76, 270, 28), Color(0.02, 0.025, 0.04, 0.84), true)
		draw_string(font, Vector2(340, 95), room_title, HORIZONTAL_ALIGNMENT_LEFT, 250, 9, Color(0.96, 0.83, 0.58, 0.94))
