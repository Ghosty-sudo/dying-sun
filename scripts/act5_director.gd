extends Node2D

const ENTRY_THRESHOLD_X := 170.0
const ECHO_NODES := [
	Vector2(185, 108),
	Vector2(340, 250),
	Vector2(500, 112),
]
const ECHO_HOLD_GOAL := 1.35
const ECHO_HOLD_RADIUS := 50.0
const CORE_CENTER := Vector2(365, 180)
const CORE_START := Vector2(108, 180)
const CORE_EXIT_X := 548.0
const LINK_RADIUS := 94.0
const LINK_SPEED := 44.0
const SEVER_NODES := [
	Vector2(205, 118),
	Vector2(365, 242),
	Vector2(515, 112),
]
const SEVER_RADIUS := 84.0
const SEVER_MIN_BREAKER_POWER := 0.28

var room_id := ""
var room_title := ""
var room_title_time := 0.0
var hazard_clock := 0.0
var hazard_grace := 0.0

var echo_index := 0
var echo_hold := 0.0

var link_pos := CORE_START
var link_wave := 0
var link_pulse_clock := 0.0
var link_elapsed := 0.0

var sever_index := 0
var breaker_flash_active := false

var boss_support_clock := 0.0
var boss_fracture_clock := 0.0
var reconciliation_ready := false

func game():
	return get_parent()

func _ready() -> void:
	# Earlier than the campaign parent so Act V replaces the generic wave loop
	# before the fallback progression can consume wave_a/wave_b.
	process_priority = -70
	z_index = 23
	queue_redraw()

func _process(delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	room_title_time = maxf(0.0, room_title_time - delta)
	if int(parent.current_act) != 5:
		room_id = ""
		breaker_flash_active = false
		queue_redraw()
		return
	if parent.ui_mode != "play" or parent.paused or parent.dead:
		queue_redraw()
		return

	hazard_clock += delta
	hazard_grace = maxf(0.0, hazard_grace - delta)
	observe_breaker(parent)

	if parent.stage == "wave_a":
		begin_last_light_entry(parent)
	elif parent.stage == "wave_b":
		begin_final_route(parent)

	match str(parent.stage):
		"sector_last_light_entry":
			if parent.player_pos.x >= ENTRY_THRESHOLD_X:
				begin_echo_convergence(parent)
		"sector_echo_convergence":
			apply_collapse_wave(parent, 2.85)
			update_echo_convergence(parent, delta)
		"sector_shared_descent":
			apply_collapse_wave(parent, 2.70)
			update_shared_descent(parent, delta)
		"sector_sever_spine":
			apply_collapse_wave(parent, 2.45)
			update_sever_route(parent)
		"boss":
			if str(parent.boss_name) == "LAST LIGHT":
				update_last_light_boss(parent, delta)

	queue_redraw()

func begin_last_light_entry(parent) -> void:
	room_id = "last_light_entry"
	room_title = ""
	room_title_time = 0.0
	hazard_clock = 0.0
	hazard_grace = 1.1
	echo_index = 0
	echo_hold = 0.0
	link_pos = CORE_START
	link_wave = 0
	link_pulse_clock = 0.0
	link_elapsed = 0.0
	sever_index = 0
	boss_support_clock = 0.0
	boss_fracture_clock = 0.0
	reconciliation_ready = false
	parent.stage = "sector_last_light_entry"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(76, 180)
	announce(parent, "LAST LIGHT // DESCEND INTO THE SUN")

func begin_echo_convergence(parent) -> void:
	room_id = "echo_convergence"
	parent.stage = "sector_echo_convergence"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(96, 180)
	echo_index = 0
	echo_hold = 0.0
	hazard_clock = 0.0
	hazard_grace = 1.0
	spawn_echo_pressure(parent)
	announce(parent, "INNER CONTROL // THE CITY IS REPLAYING YOUR CHOICES")

func spawn_echo_pressure(parent) -> void:
	parent.enemies.clear()
	parent.projectiles.clear()
	match echo_index:
		0:
			if GameState.has_flag("archive_preserved"):
				parent.enemies.append(parent.make_enemy(Vector2(430, 235), 7, "ARCHIVIST"))
				parent.enemies.append(parent.make_enemy(Vector2(520, 105), 6, "WARDEN"))
			else:
				parent.enemies.append(parent.make_enemy(Vector2(430, 235), 7, "SUN-HUSK"))
				parent.enemies.append(parent.make_enemy(Vector2(520, 105), 6, "HUSK"))
		1:
			parent.enemies.append(parent.make_enemy(Vector2(435, 105), 7, "RELAY-DRONE"))
			if GameState.has_flag("civilian_grid_preserved"):
				parent.enemies.append(parent.make_enemy(Vector2(515, 242), 6, "WARDEN"))
			else:
				parent.enemies.append(parent.make_enemy(Vector2(515, 242), 7, "RELAY-DRONE"))
		2:
			parent.enemies.append(parent.make_enemy(Vector2(425, 92), 8, "CROWN-GUARD"))
			if GameState.has_flag("crown_truth_found"):
				parent.enemies.append(parent.make_enemy(Vector2(520, 242), 7, "ARCHIVIST"))
			else:
				parent.enemies.append(parent.make_enemy(Vector2(520, 242), 7, "ECHO-WARDEN"))

func update_echo_convergence(parent, delta: float) -> void:
	if echo_index >= ECHO_NODES.size():
		return
	var node_pos: Vector2 = ECHO_NODES[echo_index]
	if parent.player_pos.distance_to(node_pos) <= ECHO_HOLD_RADIUS:
		echo_hold = minf(ECHO_HOLD_GOAL, echo_hold + delta)
	else:
		echo_hold = maxf(0.0, echo_hold - delta * 0.40)
	if echo_hold < ECHO_HOLD_GOAL:
		return

	AudioManager.play_sfx("last_light_echo")
	announce(parent, echo_line(echo_index))
	echo_index += 1
	echo_hold = 0.0
	hazard_grace = 0.75
	if echo_index >= ECHO_NODES.size():
		GameState.set_flag("last_light_echoes_resolved")
		SaveManager.save_campaign()
		parent.enemies.clear()
		parent.projectiles.clear()
		room_id = "last_light_choice"
		parent.start_narrative_choice()
		return
	spawn_echo_pressure(parent)

func echo_line(index: int) -> String:
	match index:
		0:
			if GameState.has_flag("archive_preserved"):
				return "MEMORY ECHO // YOU SAVED WHAT THE CITY CALLED EXPENSIVE"
			return "MEMORY ECHO // YOU BURNED MEMORY TO BUY TIME"
		1:
			if GameState.has_flag("civilian_grid_preserved"):
				return "RELAY ECHO // YOU CHOSE PEOPLE OVER THE GUNS"
			return "RELAY ECHO // YOU CHOSE THE GUNS SO SOMEONE COULD SURVIVE"
		2:
			if GameState.has_flag("crown_truth_found"):
				return "CROWN ECHO // YOU MADE SOL'S FAILURE PART OF THE RECORD"
			return "CROWN ECHO // YOU CARRIED THE TRUTH FORWARD UNOPENED"
	return "LAST LIGHT // MEMORY RESOLVED"

func begin_final_route(parent) -> void:
	if GameState.has_flag("final_together"):
		begin_shared_descent(parent)
	else:
		begin_sever_spine(parent)

func begin_shared_descent(parent) -> void:
	room_id = "shared_descent"
	parent.stage = "sector_shared_descent"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(82, 180)
	link_pos = CORE_START
	link_wave = 0
	link_pulse_clock = 0.15
	link_elapsed = 0.0
	hazard_clock = 0.0
	hazard_grace = 0.9
	parent.enemies.append(parent.make_enemy(Vector2(365, 105), 7, "ECHO-WARDEN"))
	parent.enemies.append(parent.make_enemy(Vector2(465, 245), 7, "RELAY-DRONE"))
	AudioManager.play_sfx("sol_link")
	announce(parent, "STAY // CARRY SOL'S CORE LINK THROUGH THE COLLAPSE")

func update_shared_descent(parent, delta: float) -> void:
	link_elapsed += delta
	var linked: bool = Vector2(parent.player_pos).distance_to(link_pos) <= LINK_RADIUS
	if linked:
		link_pos.x = minf(CORE_EXIT_X, link_pos.x + LINK_SPEED * delta)
		link_pos.y = lerpf(link_pos.y, parent.player_pos.y, minf(1.0, delta * 1.5))
		link_pulse_clock -= delta
		if link_pulse_clock <= 0.0:
			link_pulse_clock = 1.35
			parent.player_charge = minf(parent.max_charge(), parent.player_charge + 16.0)
			if not parent.projectiles.is_empty():
				parent.projectiles.clear()
			AudioManager.play_sfx("sol_link")
			parent.flash_status("SOL LINK // FRAME CHARGE RESTORED")
	else:
		link_pulse_clock = minf(link_pulse_clock, 0.35)

	if link_wave == 0 and link_pos.x >= 300.0:
		link_wave = 1
		parent.enemies.append(parent.make_enemy(Vector2(520, 108), 8, "CROWN-GUARD"))
		announce(parent, "SOL LINK // HOLD FORMATION")
	elif link_wave == 1 and link_pos.x >= 430.0:
		link_wave = 2
		parent.enemies.append(parent.make_enemy(Vector2(520, 245), 8, "SUN-HUSK"))
		announce(parent, "SOL LINK // FINAL DESCENT")

	if link_pos.x >= CORE_EXIT_X:
		GameState.set_flag("last_light_link_carried")
		SaveManager.save_campaign()
		begin_last_light_boss(parent)

func begin_sever_spine(parent) -> void:
	room_id = "sever_spine"
	parent.stage = "sector_sever_spine"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(82, 180)
	sever_index = 0
	breaker_flash_active = false
	hazard_clock = 0.0
	hazard_grace = 0.9
	spawn_sever_pressure(parent)
	announce(parent, "SEVER // BREAK THREE AUTHORITY LOCKS // FULL BREAKER")

func spawn_sever_pressure(parent) -> void:
	parent.enemies.clear()
	parent.projectiles.clear()
	match sever_index:
		0:
			parent.enemies.append(parent.make_enemy(Vector2(430, 235), 7, "ECHO-WARDEN"))
		1:
			parent.enemies.append(parent.make_enemy(Vector2(455, 102), 8, "CROWN-GUARD"))
			parent.enemies.append(parent.make_enemy(Vector2(520, 245), 7, "RELAY-DRONE"))
		2:
			parent.enemies.append(parent.make_enemy(Vector2(430, 95), 8, "SUN-HUSK"))
			parent.enemies.append(parent.make_enemy(Vector2(515, 245), 8, "ARCHIVIST"))

func observe_breaker(parent) -> void:
	var breaker = parent.get_node_or_null("BreakerController")
	if breaker == null:
		breaker_flash_active = false
		return
	var active := float(breaker.get("flash_time")) > 0.0
	if active and not breaker_flash_active and str(parent.stage) == "sector_sever_spine":
		try_sever_lock(parent, float(breaker.get("flash_power")))
	breaker_flash_active = active

func try_sever_lock(parent, power: float) -> void:
	if sever_index >= SEVER_NODES.size():
		return
	var node_pos: Vector2 = SEVER_NODES[sever_index]
	if parent.player_pos.distance_to(node_pos) > SEVER_RADIUS:
		parent.flash_status("AUTHORITY LOCK // GET CLOSER")
		return
	if power < SEVER_MIN_BREAKER_POWER:
		parent.flash_status("AUTHORITY LOCK // CHARGE BREAKER LONGER")
		return

	sever_index += 1
	hazard_grace = 0.65
	AudioManager.play_sfx("sever_lock")
	parent.flash_status("AUTHORITY LOCK // %d OF 3 SEVERED" % sever_index)
	if sever_index >= SEVER_NODES.size():
		GameState.set_flag("last_light_authority_severed")
		SaveManager.save_campaign()
		begin_last_light_boss(parent)
		return
	spawn_sever_pressure(parent)

func update_sever_route(_parent) -> void:
	# Breaker releases are observed centrally in observe_breaker(). The route
	# itself stays alive under collapse pressure until all three locks are cut.
	pass

func begin_last_light_boss(parent) -> void:
	room_id = "last_light_boss"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(102, 180)
	hazard_clock = 0.0
	hazard_grace = 1.0
	boss_support_clock = 0.45
	boss_fracture_clock = 1.20
	reconciliation_ready = GameState.available_endings().has("reconciliation") and GameState.has_flag("final_together")
	parent.spawn_boss()
	if GameState.has_flag("last_light_authority_severed") and not parent.enemies.is_empty():
		var boss: Dictionary = parent.enemies[0]
		boss["stagger"] = minf(float(boss["stagger_max"]) - 0.1, float(boss["stagger"]) + 3.0)
		parent.enemies[0] = boss
		announce(parent, "LAST LIGHT // AUTHORITY KEYS CUT // NOTHING OWNS THE ENDING")
	elif reconciliation_ready:
		parent.player_charge = parent.max_charge()
		announce(parent, "LAST LIGHT // SOL LINK STABLE // A THIRD ANSWER IS POSSIBLE")
	else:
		announce(parent, "LAST LIGHT // STAY TOGETHER // SURVIVE THE COLLAPSE")
	AudioManager.play_sfx("solar_break")

func update_last_light_boss(parent, delta: float) -> void:
	apply_collapse_wave(parent, 2.20 if not reconciliation_ready else 2.45)
	if parent.enemies.is_empty():
		return

	if GameState.has_flag("final_together"):
		boss_support_clock -= delta
		var support_interval := 1.75 if reconciliation_ready else 2.30
		if boss_support_clock <= 0.0:
			boss_support_clock = support_interval
			parent.player_charge = minf(parent.max_charge(), parent.player_charge + (24.0 if reconciliation_ready else 15.0))
			if parent.projectiles.size() > 4:
				parent.projectiles.clear()
			AudioManager.play_sfx("sol_link")
			parent.flash_status("SOL: I AM STILL HERE // MOVE")
	else:
		boss_fracture_clock -= delta
		if boss_fracture_clock <= 0.0:
			boss_fracture_clock = 3.0
			var boss: Dictionary = parent.enemies[0]
			boss["attack_cd"] = maxf(float(boss["attack_cd"]), 0.95)
			boss["stagger"] = minf(float(boss["stagger_max"]) - 0.1, float(boss["stagger"]) + 0.7)
			parent.enemies[0] = boss
			AudioManager.play_sfx("sever_lock")
			parent.flash_status("SEVERED AUTHORITY // LAST LIGHT DESYNCHRONIZED")

func collapse_radius(cycle: float) -> float:
	var phase := fmod(hazard_clock, cycle) / cycle
	return lerpf(42.0, 220.0, phase)

func apply_collapse_wave(parent, cycle: float) -> void:
	if hazard_grace > 0.0 or parent.hurt_cooldown > 0.0 or parent.dash_time > 0.0:
		return
	var radius := collapse_radius(cycle)
	if absf(parent.player_pos.distance_to(CORE_CENTER) - radius) <= 11.5:
		parent.hurt_player(1)
		parent.flash_status("SOLAR COLLAPSE // BOOST THROUGH THE RING")

func announce(parent, text: String) -> void:
	room_title = text
	room_title_time = 2.5
	parent.flash_status(text)

func objective_text() -> String:
	var parent = game()
	if parent == null or int(parent.current_act) != 5:
		return ""
	match str(parent.stage):
		"sector_last_light_entry":
			return "OBJECTIVE // DESCEND INTO THE INNER CONTROL BODY"
		"sector_echo_convergence":
			var progress := int(round(clampf(echo_hold / ECHO_HOLD_GOAL, 0.0, 1.0) * 100.0))
			return "OBJECTIVE // STABILIZE MEMORY ECHO %d/3 // HOLD %d%%" % [mini(echo_index + 1, 3), progress]
		"sector_shared_descent":
			var ratio := clampf((link_pos.x - CORE_START.x) / (CORE_EXIT_X - CORE_START.x), 0.0, 1.0)
			return "OBJECTIVE // STAY WITH SOL'S CORE LINK // %d%%" % int(round(ratio * 100.0))
		"sector_sever_spine":
			return "OBJECTIVE // SEVER AUTHORITY LOCK %d/3 // CHARGE BREAKER INSIDE GLYPH" % mini(sever_index + 1, 3)
		"boss":
			if GameState.has_flag("final_together"):
				return "OBJECTIVE // BREAK LAST LIGHT // SOL IS FIGHTING WITH YOU"
			return "OBJECTIVE // BREAK LAST LIGHT // THE SYSTEM HAS NO AUTHORITY LEFT"
	return ""

func _draw() -> void:
	var parent = game()
	if parent == null or int(parent.current_act) != 5 or parent.ui_mode != "play" or room_id.is_empty():
		return

	var gold := Color(1.0, 0.78, 0.34, 0.92)
	var pale := Color(1.0, 0.92, 0.70, 0.92)
	var ember := Color(0.88, 0.25, 0.18, 0.82)
	var dim := Color(1.0, 0.63, 0.24, 0.16)
	var cyan := Color(0.48, 0.82, 0.90, 0.88)
	var font := ThemeDB.fallback_font

	# Inner-sun machinery: layered rings, radial conduits, and drifting motes.
	for i in range(12):
		var angle := hazard_clock * (0.05 + float(i % 3) * 0.015) + TAU * float(i) / 12.0
		var inner := CORE_CENTER + Vector2.RIGHT.rotated(angle) * 42.0
		var outer := CORE_CENTER + Vector2.RIGHT.rotated(angle) * (118.0 + float(i % 4) * 9.0)
		draw_line(inner, outer, Color(gold.r, gold.g, gold.b, 0.08 + float(i % 2) * 0.04), 1.0)
	for i in range(18):
		var px := 52.0 + fmod(float(i * 83) + hazard_clock * (7.0 + float(i % 4)), 536.0)
		var py := 88.0 + fmod(float(i * 47) + sin(hazard_clock * 0.6 + float(i)) * 26.0, 190.0)
		draw_circle(Vector2(px, py), 1.2 + float(i % 3) * 0.45, Color(gold.r, gold.g, gold.b, 0.18))

	draw_arc(CORE_CENTER, 34.0, 0.0, TAU, 48, pale, 2.0)
	draw_arc(CORE_CENTER, 58.0, -hazard_clock * 0.22, -hazard_clock * 0.22 + PI * 1.72, 52, gold, 2.0)
	draw_arc(CORE_CENTER, 82.0, hazard_clock * 0.15, hazard_clock * 0.15 + PI * 1.33, 52, Color(gold.r, gold.g, gold.b, 0.42), 2.0)

	if str(parent.stage) in ["sector_echo_convergence", "sector_shared_descent", "sector_sever_spine", "boss"]:
		var cycle := 2.20 if str(parent.stage) == "boss" else (2.45 if str(parent.stage) == "sector_sever_spine" else 2.75)
		var ring_radius := collapse_radius(cycle)
		draw_arc(CORE_CENTER, ring_radius, 0.0, TAU, 64, Color(ember.r, ember.g, ember.b, 0.38), 2.0)

	if room_id == "echo_convergence":
		for i in range(ECHO_NODES.size()):
			var node: Vector2 = ECHO_NODES[i]
			var resolved := i < echo_index
			var active := i == echo_index
			var color := Color(gold.r, gold.g, gold.b, 0.30) if resolved else (gold if active else dim)
			draw_circle(node, 8.0, color)
			draw_arc(node, ECHO_HOLD_RADIUS, 0.0, TAU, 36, Color(color.r, color.g, color.b, 0.42), 2.0)
			if active:
				var ratio := clampf(echo_hold / ECHO_HOLD_GOAL, 0.0, 1.0)
				draw_arc(node, ECHO_HOLD_RADIUS + 6.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36, pale, 4.0)
	elif room_id == "shared_descent" or (room_id == "last_light_boss" and GameState.has_flag("final_together")):
		var mote := link_pos if room_id == "shared_descent" else CORE_CENTER
		draw_line(Vector2(parent.player_pos), mote, Color(cyan.r, cyan.g, cyan.b, 0.38), 2.0)
		draw_circle(mote, 10.0, Color(cyan.r, cyan.g, cyan.b, 0.26))
		draw_arc(mote, 18.0, hazard_clock, hazard_clock + PI * 1.55, 24, cyan, 3.0)
		draw_circle(mote, 4.0, pale)
	elif room_id == "sever_spine":
		for i in range(SEVER_NODES.size()):
			var node: Vector2 = SEVER_NODES[i]
			var cut := i < sever_index
			var active := i == sever_index
			var color := Color(0.30, 0.34, 0.40, 0.35) if cut else (ember if active else dim)
			draw_arc(node, 24.0, 0.0, TAU, 28, color, 3.0)
			draw_line(node + Vector2(-13, -13), node + Vector2(13, 13), color, 3.0)
			draw_line(node + Vector2(-13, 13), node + Vector2(13, -13), color, 3.0)
			if active:
				draw_arc(node, SEVER_RADIUS, -PI * 0.25, PI * 1.25, 34, Color(ember.r, ember.g, ember.b, 0.28), 2.0)

	if room_id == "last_light_boss" and not parent.enemies.is_empty():
		var boss_pos := Vector2(parent.enemies[0]["pos"])
		for i in range(8):
			var angle := -hazard_clock * 0.24 + TAU * float(i) / 8.0
			draw_line(boss_pos + Vector2.RIGHT.rotated(angle) * 30.0, boss_pos + Vector2.RIGHT.rotated(angle) * 48.0, gold, 3.0)
		draw_arc(boss_pos, 37.0, hazard_clock * 0.4, hazard_clock * 0.4 + PI * 1.7, 32, pale, 3.0)
		if reconciliation_ready:
			draw_arc(boss_pos, 52.0, -hazard_clock * 0.22, -hazard_clock * 0.22 + PI * 1.65, 40, cyan, 2.0)

	var objective := objective_text()
	if not objective.is_empty():
		draw_rect(Rect2(118, 84, 404, 22), Color(0.025, 0.022, 0.018, 0.88), true)
		draw_rect(Rect2(118, 84, 404, 22), Color(gold.r, gold.g, gold.b, 0.35), false, 1.0)
		draw_string(font, Vector2(126, 99), objective, HORIZONTAL_ALIGNMENT_CENTER, 388, 8, pale)
	if room_title_time > 0.0 and not room_title.is_empty():
		var alpha := clampf(room_title_time / 0.4, 0.0, 1.0)
		draw_string(font, Vector2(70, 122), room_title, HORIZONTAL_ALIGNMENT_CENTER, 500, 10, Color(pale.r, pale.g, pale.b, alpha))