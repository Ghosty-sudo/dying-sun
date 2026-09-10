extends Node2D

const INTAKE_THRESHOLD_X := 430.0
const FURNACE_VENTS := [Vector2(245, 110), Vector2(365, 250), Vector2(505, 135)]
const GATE_CORE := Vector2(365, 180)

const MEMORY_ENTRY_THRESHOLD_X := 255.0
const MEMORY_SEAL_POS := Vector2(390, 180)
const MEMORY_CORE_POS := Vector2(350, 180)
const MEMORY_EXIT_X := 548.0
const ARCHIVE_HOLD_GOAL := 5.0
const PURGE_BANDS := [
	Rect2(165, 44, 72, 272),
	Rect2(305, 44, 72, 272),
	Rect2(445, 44, 72, 272),
]

var room_id := ""
var hazard_clock := 0.0
var room_title := ""
var room_title_time := 0.0

var furnace_phase := 0
var furnace_grace := 0.0

var memory_suppression := 0.0
var memory_grace := 0.0
var archive_hold := 0.0
var archive_reinforcements := 0

func game():
	return get_parent()

func _ready() -> void:
	process_priority = -100
	z_index = 20
	queue_redraw()

func _process(delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	hazard_clock += delta
	furnace_grace = maxf(0.0, furnace_grace - delta)
	memory_suppression = maxf(0.0, memory_suppression - delta)
	memory_grace = maxf(0.0, memory_grace - delta)
	room_title_time = maxf(0.0, room_title_time - delta)
	if parent.ui_mode != "play" or parent.paused:
		queue_redraw()
		return
	if parent.dead:
		queue_redraw()
		return

	match int(parent.current_act):
		1:
			process_act_one(parent)
		2:
			process_act_two(parent, delta)
		_:
			room_id = ""

	queue_redraw()

func process_act_one(parent) -> void:
	if parent.stage == "wave_a":
		begin_intake_walk(parent)
	elif parent.stage == "wave_b":
		begin_gate_approach(parent)

	match str(parent.stage):
		"sector_intake_walk":
			if parent.player_pos.x >= INTAKE_THRESHOLD_X:
				begin_furnace(parent)
		"sector_furnace":
			if furnace_phase >= 1:
				apply_furnace_hazard(parent)
			if parent.enemies.is_empty():
				if furnace_phase == 0:
					begin_furnace_second(parent)
				else:
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

func process_act_two(parent, delta: float) -> void:
	if parent.stage == "wave_a":
		begin_memory_entry(parent)
	elif parent.stage == "wave_b":
		begin_memory_consequence(parent)

	match str(parent.stage):
		"sector_memory_entry":
			if parent.player_pos.x >= MEMORY_ENTRY_THRESHOLD_X:
				begin_memory_seal(parent)
		"sector_memory_seal":
			if parent.enemies.is_empty():
				begin_memory_gallery(parent)
		"sector_memory_gallery":
			apply_memory_sweep(parent)
			if parent.enemies.is_empty():
				room_id = "memory_choice"
				parent.start_narrative_choice()
		"sector_archive_hold":
			apply_memory_sweep(parent)
			update_archive_hold(parent, delta)
		"sector_purge_run":
			apply_purge_hazard(parent)
			if parent.player_pos.x >= MEMORY_EXIT_X:
				begin_archivist_boss(parent)

func begin_intake_walk(parent) -> void:
	room_id = "intake_walk"
	furnace_phase = 0
	furnace_grace = 0.0
	parent.stage = "sector_intake_walk"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(86, 182)
	announce(parent, "INTAKE ACCESS // FIND THE INNER SEAL")

func begin_furnace(parent) -> void:
	room_id = "furnace"
	furnace_phase = 0
	furnace_grace = 0.0
	parent.stage = "sector_furnace"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(84, 182)
	parent.enemies.append(parent.make_enemy(Vector2(350, 180), 3, "WARDEN"))
	announce(parent, "ASH FURNACE // ONE TARGET // CLOSE AND STRIKE")

func begin_furnace_second(parent) -> void:
	furnace_phase = 1
	furnace_grace = 1.4
	hazard_clock = 0.0
	parent.projectiles.clear()
	parent.enemies.append(parent.make_enemy(Vector2(485, 180), 3, "HUSK"))
	announce(parent, "ASH FURNACE // RANGED CONTACT // VENTS ARMING")

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

func begin_memory_entry(parent) -> void:
	room_id = "memory_entry"
	memory_suppression = 0.0
	memory_grace = 0.0
	archive_hold = 0.0
	archive_reinforcements = 0
	parent.stage = "sector_memory_entry"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(76, 180)
	announce(parent, "MEMORY WORKS // BREAKER ONLINE // FIND THE INDEX SEAL")

func begin_memory_seal(parent) -> void:
	room_id = "memory_seal"
	parent.stage = "sector_memory_seal"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(110, 180)
	var seal: Dictionary = parent.make_enemy(MEMORY_SEAL_POS, 3, "MEMORY-SEAL")
	seal["breaker_only"] = true
	seal["stagger_max"] = 999.0
	parent.enemies.append(seal)
	announce(parent, "INDEX SEAL // HOLD BREAKER AND RELEASE")

func begin_memory_gallery(parent) -> void:
	room_id = "memory_gallery"
	parent.stage = "sector_memory_gallery"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(92, 180)
	hazard_clock = 0.0
	memory_grace = 1.25
	memory_suppression = 0.0
	parent.enemies.append(parent.make_enemy(Vector2(350, 245), 4, "WARDEN"))
	parent.enemies.append(parent.make_enemy(Vector2(485, 105), 5, "ARCHIVIST"))
	announce(parent, "MEMORY GALLERY // BREAKER SILENCES THE SWEEP")

func begin_memory_consequence(parent) -> void:
	if GameState.has_flag("archive_burned"):
		begin_purge_run(parent)
	else:
		begin_archive_hold(parent)

func begin_archive_hold(parent) -> void:
	room_id = "archive_hold"
	parent.stage = "sector_archive_hold"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(118, 180)
	hazard_clock = 0.0
	memory_grace = 1.0
	memory_suppression = 0.0
	archive_hold = 0.0
	archive_reinforcements = 0
	parent.enemies.append(parent.make_enemy(Vector2(385, 245), 4, "WARDEN"))
	parent.enemies.append(parent.make_enemy(Vector2(500, 105), 5, "ARCHIVIST"))
	announce(parent, "PRESERVE // HOLD THE INDEX CORE // 5 SECONDS")

func begin_purge_run(parent) -> void:
	room_id = "purge_run"
	parent.stage = "sector_purge_run"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(74, 180)
	hazard_clock = 0.0
	memory_grace = 0.9
	memory_suppression = 0.0
	parent.enemies.append(parent.make_enemy(Vector2(405, 180), 5, "SUN-HUSK"))
	announce(parent, "BURN // PURGE FRONT MOVING // REACH THE FAR DOOR")

func begin_archivist_boss(parent) -> void:
	room_id = "archivist_chamber"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(102, 180)
	parent.spawn_boss()
	if GameState.has_flag("archive_burned"):
		announce(parent, "THE ARCHIVIST // PURGE-DAMAGED")
	else:
		announce(parent, "THE ARCHIVIST // ARCHIVE INTACT")

func update_archive_hold(parent, delta: float) -> void:
	if parent.player_pos.distance_to(MEMORY_CORE_POS) <= 78.0:
		archive_hold = minf(ARCHIVE_HOLD_GOAL, archive_hold + delta)
	else:
		archive_hold = maxf(0.0, archive_hold - delta * 0.25)

	if archive_hold >= ARCHIVE_HOLD_GOAL:
		GameState.set_flag("archive_hold_completed")
		SaveManager.save_campaign()
		begin_archivist_boss(parent)
		return

	if parent.enemies.is_empty() and archive_reinforcements < 2:
		archive_reinforcements += 1
		if archive_reinforcements == 1:
			parent.enemies.append(parent.make_enemy(Vector2(515, 180), 4, "ARCHIVIST"))
		else:
			parent.enemies.append(parent.make_enemy(Vector2(505, 95), 4, "WARDEN"))
		announce(parent, "INDEX CORE // REINFORCEMENT %d" % archive_reinforcements)

func on_breaker_fired(hit_any: bool, ratio: float) -> void:
	var parent = game()
	if parent == null or int(parent.current_act) != 2:
		return
	if str(parent.stage) == "sector_memory_seal":
		if hit_any:
			parent.flash_status("BREAKER // INDEX SEAL FRACTURED")
		return
	if str(parent.stage) in ["sector_memory_gallery", "sector_archive_hold", "sector_purge_run"]:
		memory_suppression = maxf(memory_suppression, 1.25 + ratio * 0.75)
		parent.flash_status("BREAKER // MEMORY FIELD SILENCED")

func announce(parent, text: String) -> void:
	room_title = text
	room_title_time = 2.4
	parent.flash_status(text)

func furnace_hot() -> bool:
	return furnace_phase >= 1 and furnace_grace <= 0.0 and fmod(hazard_clock, 2.8) < 0.50

func gate_hot() -> bool:
	return fmod(hazard_clock + 0.8, 2.0) < 0.58

func memory_sweep_x() -> float:
	var phase := fmod(hazard_clock, 4.0) / 4.0
	var folded := phase * 2.0 if phase <= 0.5 else (1.0 - phase) * 2.0
	return lerpf(92.0, 548.0, folded)

func memory_field_active() -> bool:
	return memory_grace <= 0.0 and memory_suppression <= 0.0

func purge_band_index() -> int:
	return int(floor(fmod(hazard_clock, 2.4) / 0.8)) % PURGE_BANDS.size()

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

func apply_memory_sweep(parent) -> void:
	if not memory_field_active() or parent.hurt_cooldown > 0.0 or parent.dash_time > 0.0:
		return
	if absf(parent.player_pos.x - memory_sweep_x()) < 20.0:
		parent.hurt_player(1)
		parent.flash_status("MEMORY SWEEP // FRAME DESYNC")

func apply_purge_hazard(parent) -> void:
	if not memory_field_active() or parent.hurt_cooldown > 0.0 or parent.dash_time > 0.0:
		return
	var band: Rect2 = PURGE_BANDS[purge_band_index()]
	if band.has_point(parent.player_pos):
		parent.hurt_player(1)
		parent.flash_status("MEMORY PURGE // THERMAL SPIKE")

func _draw() -> void:
	if room_id.is_empty():
		return
	var parent = game()
	if parent == null or parent.ui_mode != "play":
		return
	var font := ThemeDB.fallback_font
	match int(parent.current_act):
		1:
			draw_act_one(font)
		2:
			draw_act_two(font)
	if room_title_time > 0.0:
		draw_rect(Rect2(300, 76, 300, 28), Color(0.02, 0.025, 0.04, 0.84), true)
		draw_string(font, Vector2(310, 95), room_title, HORIZONTAL_ALIGNMENT_LEFT, 280, 9, Color(0.96, 0.83, 0.58, 0.94))

func draw_act_one(font: Font) -> void:
	match room_id:
		"intake_walk":
			draw_line(Vector2(72, 86), Vector2(560, 86), Color(0.85, 0.55, 0.22, 0.34), 2.0)
			draw_line(Vector2(72, 274), Vector2(560, 274), Color(0.85, 0.55, 0.22, 0.34), 2.0)
			draw_rect(Rect2(430, 96, 118, 168), Color(0.85, 0.55, 0.22, 0.08), true)
			draw_string(font, Vector2(438, 184), "INNER SEAL", HORIZONTAL_ALIGNMENT_LEFT, 100, 10, Color(0.94, 0.72, 0.38, 0.80))
		"furnace":
			for vent in FURNACE_VENTS:
				var active_alpha := 0.22 if furnace_hot() else 0.04
				draw_circle(vent, 38.0, Color(0.95, 0.28, 0.13, active_alpha), true)
				draw_arc(vent, 39.0, 0.0, TAU, 24, Color(0.95, 0.50, 0.18, 0.75 if furnace_phase >= 1 else 0.25), 2.0)
		"coolant":
			draw_rect(Rect2(24, 24, 592, 54), Color(0.18, 0.65, 0.80, 0.16), true)
			draw_rect(Rect2(24, 286, 592, 50), Color(0.18, 0.65, 0.80, 0.16), true)
			draw_line(Vector2(24, 78), Vector2(616, 78), Color(0.40, 0.88, 0.96, 0.60), 2.0)
			draw_line(Vector2(24, 286), Vector2(616, 286), Color(0.40, 0.88, 0.96, 0.60), 2.0)
		"gate_approach", "gate_pressure", "custodian_chamber":
			draw_circle(GATE_CORE, 54.0, Color(1.0, 0.45, 0.12, 0.17 if gate_hot() else 0.05), true)
			draw_arc(GATE_CORE, 58.0, 0.0, TAU, 32, Color(0.95, 0.62, 0.22, 0.72), 3.0)
			draw_line(Vector2(365, 58), Vector2(365, 302), Color(0.95, 0.62, 0.22, 0.25), 2.0)

func draw_act_two(font: Font) -> void:
	var memory_color := Color(0.47, 0.78, 0.80, 0.82)
	var dim_memory := Color(0.47, 0.78, 0.80, 0.16)
	match room_id:
		"memory_entry":
			draw_line(Vector2(72, 92), Vector2(560, 92), dim_memory, 2.0)
			draw_line(Vector2(72, 268), Vector2(560, 268), dim_memory, 2.0)
			draw_rect(Rect2(MEMORY_ENTRY_THRESHOLD_X, 100, 12, 160), Color(0.47, 0.78, 0.80, 0.14), true)
			draw_string(font, Vector2(275, 128), "BREAKER ONLINE", HORIZONTAL_ALIGNMENT_LEFT, 150, 10, memory_color)
		"memory_seal":
			draw_circle(MEMORY_SEAL_POS, 34.0, Color(0.47, 0.78, 0.80, 0.12), true)
			draw_arc(MEMORY_SEAL_POS, 36.0, 0.0, TAU, 28, memory_color, 3.0)
			draw_line(MEMORY_SEAL_POS + Vector2(0, -58), MEMORY_SEAL_POS + Vector2(0, 58), memory_color, 2.0)
			draw_string(font, MEMORY_SEAL_POS + Vector2(-52, -46), "BREAKER LOCK", HORIZONTAL_ALIGNMENT_LEFT, 110, 9, memory_color)
		"memory_gallery":
			draw_memory_sweep(memory_color)
			draw_string(font, Vector2(380, 310), "MEMORY SWEEP", HORIZONTAL_ALIGNMENT_LEFT, 120, 9, memory_color)
		"archive_hold":
			draw_memory_sweep(memory_color)
			var ratio := clampf(archive_hold / ARCHIVE_HOLD_GOAL, 0.0, 1.0)
			draw_circle(MEMORY_CORE_POS, 78.0, Color(0.47, 0.78, 0.80, 0.06), true)
			draw_arc(MEMORY_CORE_POS, 80.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36, memory_color, 4.0)
			draw_string(font, MEMORY_CORE_POS + Vector2(-48, 4), "HOLD INDEX", HORIZONTAL_ALIGNMENT_CENTER, 96, 10, memory_color)
		"purge_run":
			for i in range(PURGE_BANDS.size()):
				var active := memory_field_active() and i == purge_band_index()
				var fill := Color(0.86, 0.25, 0.25, 0.24 if active else 0.05)
				draw_rect(PURGE_BANDS[i], fill, true)
				draw_rect(PURGE_BANDS[i], Color(0.95, 0.45, 0.36, 0.65 if active else 0.18), false, 2.0)
			draw_rect(Rect2(MEMORY_EXIT_X - 8.0, 78.0, 22.0, 204.0), Color(0.47, 0.78, 0.80, 0.10), true)
			draw_string(font, Vector2(500, 68), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, 70, 10, memory_color)
		"archivist_chamber":
			draw_circle(MEMORY_CORE_POS, 92.0, Color(0.47, 0.78, 0.80, 0.05), true)
			draw_arc(MEMORY_CORE_POS, 94.0, 0.0, TAU, 40, memory_color, 2.0)

func draw_memory_sweep(memory_color: Color) -> void:
	if not memory_field_active():
		return
	var x := memory_sweep_x()
	draw_rect(Rect2(x - 18.0, 38.0, 36.0, 286.0), Color(0.47, 0.78, 0.80, 0.09), true)
	draw_line(Vector2(x, 38), Vector2(x, 324), memory_color, 2.0)
