extends Node2D

const ENTRY_THRESHOLD_X := 170.0
const RELAY_NODES := [
	Vector2(190, 108),
	Vector2(330, 252),
	Vector2(500, 112),
]
const ARC_SEGMENTS := [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 0)]
const RELAY_HOLD_GOAL := 1.35
const RELAY_HOLD_RADIUS := 50.0
const RELAY_EXIT_X := 548.0
const CIVILIAN_START := Vector2(112, 180)
const CIVILIAN_ESCORT_RADIUS := 92.0
const CIVILIAN_ESCORT_SPEED := 46.0
const DEFENSE_MIN_TIME := 4.2

var room_id := ""
var hazard_clock := 0.0
var relay_index := 0
var relay_hold := 0.0
var relay_grace := 0.0
var escort_pos := CIVILIAN_START
var civilian_wave := 0
var route_elapsed := 0.0
var defense_pulse := 0.0
var defense_pulse_flash := 0.0
var room_title := ""
var room_title_time := 0.0

func game():
	return get_parent()

func _ready() -> void:
	# Run before the parent campaign progression so generic wave_a/wave_b
	# cannot consume the intentionally non-wave Black Relay states.
	process_priority = -90
	z_index = 21
	queue_redraw()

func _process(delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	room_title_time = maxf(0.0, room_title_time - delta)
	defense_pulse_flash = maxf(0.0, defense_pulse_flash - delta)
	if int(parent.current_act) != 3:
		room_id = ""
		queue_redraw()
		return
	if parent.ui_mode != "play" or parent.paused or parent.dead:
		queue_redraw()
		return

	hazard_clock += delta
	relay_grace = maxf(0.0, relay_grace - delta)

	if parent.stage == "wave_a":
		begin_relay_entry(parent)
	elif parent.stage == "wave_b":
		begin_post_choice_route(parent)

	match str(parent.stage):
		"sector_relay_entry":
			if parent.player_pos.x >= ENTRY_THRESHOLD_X:
				begin_relay_sync(parent)
		"sector_relay_sync":
			apply_relay_arc(parent)
			update_relay_sync(parent, delta)
		"sector_civilian_feed":
			apply_relay_arc(parent)
			update_civilian_feed(parent, delta)
		"sector_defense_push":
			update_defense_push(parent, delta)

	queue_redraw()

func begin_relay_entry(parent) -> void:
	room_id = "relay_entry"
	hazard_clock = 0.0
	relay_index = 0
	relay_hold = 0.0
	relay_grace = 1.0
	escort_pos = CIVILIAN_START
	civilian_wave = 0
	route_elapsed = 0.0
	defense_pulse = 0.0
	parent.stage = "sector_relay_entry"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(76, 180)
	announce(parent, "BLACK RELAY // ENTER THE ROUTING SPINE")

func begin_relay_sync(parent) -> void:
	room_id = "relay_sync"
	hazard_clock = 0.0
	relay_index = 0
	relay_hold = 0.0
	relay_grace = 1.15
	parent.stage = "sector_relay_sync"
	parent.player_pos = Vector2(100, 180)
	spawn_relay_pressure(parent)

func spawn_relay_pressure(parent) -> void:
	parent.enemies.clear()
	parent.projectiles.clear()
	match relay_index:
		0:
			parent.enemies.append(parent.make_enemy(Vector2(440, 230), 5, "RELAY-DRONE"))
		1:
			parent.enemies.append(parent.make_enemy(Vector2(455, 105), 5, "WARDEN"))
			parent.enemies.append(parent.make_enemy(Vector2(520, 245), 5, "RELAY-DRONE"))
		2:
			parent.enemies.append(parent.make_enemy(Vector2(405, 92), 5, "RELAY-DRONE"))
			parent.enemies.append(parent.make_enemy(Vector2(515, 238), 5, "HUSK"))
	announce(parent, "ROUTING SPINE // HOLD RELAY %d OF 3" % [relay_index + 1])

func update_relay_sync(parent, delta: float) -> void:
	if relay_index >= RELAY_NODES.size():
		return
	var node_pos: Vector2 = RELAY_NODES[relay_index]
	if parent.player_pos.distance_to(node_pos) <= RELAY_HOLD_RADIUS:
		relay_hold = minf(RELAY_HOLD_GOAL, relay_hold + delta)
	else:
		relay_hold = maxf(0.0, relay_hold - delta * 0.45)
	if relay_hold < RELAY_HOLD_GOAL:
		return

	relay_index += 1
	relay_hold = 0.0
	relay_grace = 0.72
	AudioManager.play_sfx("relay_lock")
	parent.flash_status("BLACK RELAY // NODE %d STABLE" % relay_index)
	if relay_index >= RELAY_NODES.size():
		GameState.set_flag("black_relay_spine_online")
		SaveManager.save_campaign()
		parent.enemies.clear()
		parent.projectiles.clear()
		room_id = "relay_choice"
		parent.start_narrative_choice()
		return
	spawn_relay_pressure(parent)

func begin_post_choice_route(parent) -> void:
	if GameState.has_flag("civilian_grid_preserved"):
		begin_civilian_feed(parent)
	else:
		begin_defense_push(parent)

func begin_civilian_feed(parent) -> void:
	room_id = "civilian_feed"
	hazard_clock = 0.0
	relay_grace = 0.9
	route_elapsed = 0.0
	civilian_wave = 0
	escort_pos = CIVILIAN_START
	parent.stage = "sector_civilian_feed"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(86, 180)
	parent.enemies.append(parent.make_enemy(Vector2(360, 105), 5, "RELAY-DRONE"))
	parent.enemies.append(parent.make_enemy(Vector2(430, 250), 5, "WARDEN"))
	announce(parent, "CIVILIAN FEED // STAY WITH THE CURRENT // DEFENSE DARK")

func update_civilian_feed(parent, delta: float) -> void:
	route_elapsed += delta
	if parent.player_pos.distance_to(escort_pos) <= CIVILIAN_ESCORT_RADIUS:
		escort_pos.x = minf(RELAY_EXIT_X, escort_pos.x + CIVILIAN_ESCORT_SPEED * delta)
		escort_pos.y = lerpf(escort_pos.y, parent.player_pos.y, minf(1.0, delta * 1.6))

	if civilian_wave == 0 and escort_pos.x >= 285.0:
		civilian_wave = 1
		parent.enemies.append(parent.make_enemy(Vector2(515, 110), 6, "RELAY-DRONE"))
		AudioManager.play_sfx("relay_pulse")
		parent.flash_status("VAULT FEED // HOSTILE RELAY ACQUIRED")
	elif civilian_wave == 1 and escort_pos.x >= 425.0:
		civilian_wave = 2
		parent.enemies.append(parent.make_enemy(Vector2(520, 245), 6, "WARDEN"))
		AudioManager.play_sfx("relay_pulse")
		parent.flash_status("VAULT FEED // FINAL TRANSFER")

	if escort_pos.x >= RELAY_EXIT_X:
		GameState.set_flag("civilian_feed_completed")
		SaveManager.save_campaign()
		begin_relay_saint(parent)

func begin_defense_push(parent) -> void:
	room_id = "defense_push"
	hazard_clock = 0.0
	route_elapsed = 0.0
	defense_pulse = 0.55
	defense_pulse_flash = 0.0
	parent.stage = "sector_defense_push"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(78, 180)
	parent.enemies.append(parent.make_enemy(Vector2(285, 95), 6, "RELAY-DRONE"))
	parent.enemies.append(parent.make_enemy(Vector2(380, 255), 5, "WARDEN"))
	parent.enemies.append(parent.make_enemy(Vector2(485, 105), 6, "RELAY-DRONE"))
	parent.enemies.append(parent.make_enemy(Vector2(535, 245), 6, "HUSK"))
	announce(parent, "DEFENSE LATTICE // PUSH TO UPLINK // GRID FIRING")

func update_defense_push(parent, delta: float) -> void:
	route_elapsed += delta
	defense_pulse -= delta
	if defense_pulse <= 0.0:
		defense_pulse = 0.90
		fire_defense_lattice(parent)
	if parent.player_pos.x >= RELAY_EXIT_X and route_elapsed >= DEFENSE_MIN_TIME:
		GameState.set_flag("defense_push_completed")
		SaveManager.save_campaign()
		begin_relay_saint(parent)

func fire_defense_lattice(parent) -> void:
	if parent.enemies.is_empty():
		return
	var best := -1
	var best_distance := 99999.0
	for i in range(parent.enemies.size()):
		var enemy: Dictionary = parent.enemies[i]
		if parent.is_boss_kind(str(enemy.get("kind", ""))):
			continue
		var distance := Vector2(enemy["pos"]).distance_to(parent.player_pos)
		if distance < best_distance:
			best = i
			best_distance = distance
	if best < 0:
		return
	var target: Dictionary = parent.enemies[best]
	target["hp"] = int(target["hp"]) - 1
	target["flash"] = 0.18
	parent.apply_stagger(target, 1.8)
	defense_pulse_flash = 0.18
	AudioManager.play_sfx("relay_pulse")
	if int(target["hp"]) <= 0:
		parent.enemies.remove_at(best)
		parent.wave_kills += 1
	else:
		parent.enemies[best] = target
	parent.flash_status("DEFENSE LATTICE // TARGET CUT")

func begin_relay_saint(parent) -> void:
	room_id = "relay_chamber"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(102, 180)
	parent.spawn_boss()
	if GameState.has_flag("defense_lattice_powered") and not parent.enemies.is_empty():
		var saint: Dictionary = parent.enemies[0]
		saint["hp"] = maxi(1, int(saint["hp"]) - 4)
		saint["stagger"] = minf(float(saint["stagger_max"]) - 0.1, float(saint["stagger"]) + 2.5)
		parent.enemies[0] = saint
		announce(parent, "RELAY SAINT // LATTICE CUTS ITS SHIELD")
	else:
		announce(parent, "RELAY SAINT // DEFENSE GRID DARK")

func announce(parent, text: String) -> void:
	room_title = text
	room_title_time = 2.4
	parent.flash_status(text)

func objective_text() -> String:
	var parent = game()
	if parent == null or int(parent.current_act) != 3:
		return ""
	match str(parent.stage):
		"sector_relay_entry":
			return "OBJECTIVE // ENTER THE ROUTING SPINE"
		"sector_relay_sync":
			var progress := int(round(clampf(relay_hold / RELAY_HOLD_GOAL, 0.0, 1.0) * 100.0))
			return "OBJECTIVE // STABILIZE RELAY %d/3 // HOLD IN RING %d%%" % [mini(relay_index + 1, 3), progress]
		"sector_civilian_feed":
			var ratio := clampf((escort_pos.x - CIVILIAN_START.x) / (RELAY_EXIT_X - CIVILIAN_START.x), 0.0, 1.0)
			return "OBJECTIVE // ESCORT POWER TO VAULTS // STAY NEAR CURRENT %d%%" % int(round(ratio * 100.0))
		"sector_defense_push":
			return "OBJECTIVE // REACH UPLINK // DEFENSE LATTICE IS COVERING YOU"
	return ""

func active_arc_segment() -> int:
	return int(floor(hazard_clock / 1.55)) % ARC_SEGMENTS.size()

func relay_arc_hot() -> bool:
	return relay_grace <= 0.0 and fmod(hazard_clock, 1.55) < 0.46

func apply_relay_arc(parent) -> void:
	if not relay_arc_hot() or parent.hurt_cooldown > 0.0 or parent.dash_time > 0.0:
		return
	var segment: Vector2i = ARC_SEGMENTS[active_arc_segment()]
	var a: Vector2 = RELAY_NODES[segment.x]
	var b: Vector2 = RELAY_NODES[segment.y]
	if distance_to_segment(parent.player_pos, a, b) <= 14.0:
		parent.hurt_player(1)
		parent.flash_status("BLACK ARC // BOOST THROUGH THE SURGE")

func distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)

func _draw() -> void:
	var parent = game()
	if parent == null or int(parent.current_act) != 3 or parent.ui_mode != "play" or room_id.is_empty():
		return
	var font := ThemeDB.fallback_font
	var relay_color := Color(0.71, 0.58, 0.84, 0.88)
	var dim_relay := Color(0.71, 0.58, 0.84, 0.16)
	var danger := Color(0.90, 0.31, 0.40, 0.82)

	match room_id:
		"relay_entry":
			draw_line(Vector2(74, 88), Vector2(560, 88), dim_relay, 2.0)
			draw_line(Vector2(74, 272), Vector2(560, 272), dim_relay, 2.0)
			draw_rect(Rect2(ENTRY_THRESHOLD_X, 92, 10, 176), Color(0.71, 0.58, 0.84, 0.10), true)
			draw_string(font, Vector2(188, 82), "ROUTING SPINE", HORIZONTAL_ALIGNMENT_LEFT, 150, 10, relay_color)
			draw_relay_nodes(relay_color, dim_relay)
		"relay_sync":
			draw_relay_nodes(relay_color, dim_relay)
			draw_relay_arcs(relay_color, danger)
		"civilian_feed":
			draw_relay_nodes(relay_color, dim_relay)
			draw_relay_arcs(relay_color, danger)
			draw_line(CIVILIAN_START, Vector2(RELAY_EXIT_X, 180), Color(0.55, 0.75, 0.92, 0.28), 3.0)
			draw_circle(escort_pos, 16.0, Color(0.58, 0.82, 0.96, 0.20), true)
			draw_arc(escort_pos, 18.0, 0.0, TAU, 28, Color(0.65, 0.88, 1.0, 0.94), 3.0)
			draw_circle(escort_pos, 5.0, Color(0.92, 0.98, 1.0, 0.96), true)
			draw_string(font, Vector2(475, 314), "VAULT FEED", HORIZONTAL_ALIGNMENT_LEFT, 100, 9, relay_color)
		"defense_push":
			for x in [155.0, 265.0, 375.0, 485.0, 555.0]:
				var alpha := 0.58 if defense_pulse_flash > 0.0 else 0.20
				draw_line(Vector2(x, 54), Vector2(x, 306), Color(0.50, 0.78, 0.92, alpha), 2.0)
			draw_rect(Rect2(RELAY_EXIT_X - 8.0, 72.0, 20.0, 216.0), Color(0.71, 0.58, 0.84, 0.12), true)
			draw_string(font, Vector2(500, 66), "UPLINK", HORIZONTAL_ALIGNMENT_LEFT, 80, 9, relay_color)
		"relay_chamber":
			draw_circle(Vector2(365, 180), 92.0, Color(0.71, 0.58, 0.84, 0.05), true)
			draw_arc(Vector2(365, 180), 94.0, 0.0, TAU, 40, relay_color, 2.0)
			draw_line(Vector2(365, 70), Vector2(365, 290), dim_relay, 2.0)

	if room_title_time > 0.0:
		draw_rect(Rect2(300, 76, 300, 28), Color(0.02, 0.025, 0.04, 0.84), true)
		draw_string(font, Vector2(310, 95), room_title, HORIZONTAL_ALIGNMENT_LEFT, 280, 9, Color(0.89, 0.79, 0.98, 0.96))

func draw_relay_nodes(relay_color: Color, dim_relay: Color) -> void:
	for i in range(RELAY_NODES.size()):
		var pos: Vector2 = RELAY_NODES[i]
		var completed := i < relay_index
		var current := i == relay_index and room_id == "relay_sync"
		draw_circle(pos, 30.0, Color(relay_color.r, relay_color.g, relay_color.b, 0.10 if not completed else 0.22), true)
		draw_arc(pos, 32.0, 0.0, TAU, 28, relay_color if completed or current else dim_relay, 2.0)
		if completed:
			draw_circle(pos, 8.0, relay_color, true)
		elif current:
			var ratio := clampf(relay_hold / RELAY_HOLD_GOAL, 0.0, 1.0)
			draw_arc(pos, 38.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 30, Color(0.88, 0.78, 1.0, 0.96), 4.0)

func draw_relay_arcs(relay_color: Color, danger: Color) -> void:
	for i in range(ARC_SEGMENTS.size()):
		var segment: Vector2i = ARC_SEGMENTS[i]
		var a: Vector2 = RELAY_NODES[segment.x]
		var b: Vector2 = RELAY_NODES[segment.y]
		var active := i == active_arc_segment() and relay_arc_hot()
		draw_line(a, b, danger if active else Color(relay_color.r, relay_color.g, relay_color.b, 0.12), 5.0 if active else 2.0)
