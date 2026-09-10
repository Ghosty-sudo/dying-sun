extends Node2D

const ENTRY_THRESHOLD_X := 170.0
const TRUTH_NODES := [
	Vector2(190, 108),
	Vector2(350, 252),
	Vector2(510, 108),
]
const TRUTH_HOLD_GOAL := 1.15
const TRUTH_HOLD_RADIUS := 48.0
const RECORD_NODES := [Vector2(245, 118), Vector2(455, 242)]
const RECORD_HOLD_GOAL := 1.4
const CROWN_CENTER := Vector2(365, 180)
const EXIT_X := 548.0
const OVERDRIVE_MIN_TIME := 3.0

var room_id := ""
var hazard_clock := 0.0
var room_title := ""
var room_title_time := 0.0
var truth_index := 0
var truth_hold := 0.0
var record_index := 0
var record_hold := 0.0
var hazard_grace := 0.0
var route_elapsed := 0.0
var counter_clock := 0.0
var breaker_phase_cooldown := 0.0

var strike_uses := 0
var boost_uses := 0
var deflect_uses := 0
var breaker_uses := 0
var previous_attack := false
var previous_boost := false
var previous_deflect := false
var previous_breaker_flash := false
var counter_profile := "balanced"

func game():
	return get_parent()

func _ready() -> void:
	process_priority = -80
	z_index = 22
	queue_redraw()

func _process(delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	room_title_time = maxf(0.0, room_title_time - delta)
	breaker_phase_cooldown = maxf(0.0, breaker_phase_cooldown - delta)
	if int(parent.current_act) != 4:
		room_id = ""
		queue_redraw()
		return
	if parent.ui_mode != "play" or parent.paused or parent.dead:
		queue_redraw()
		return

	hazard_clock += delta
	hazard_grace = maxf(0.0, hazard_grace - delta)
	observe_combat_habits(parent)

	if parent.stage == "wave_a":
		begin_crown_entry(parent)
	elif parent.stage == "wave_b":
		begin_post_choice_route(parent)

	match str(parent.stage):
		"sector_crown_entry":
			if parent.player_pos.x >= ENTRY_THRESHOLD_X:
				begin_crown_audit(parent)
		"sector_crown_audit":
			apply_crown_scan(parent)
			update_truth_audit(parent, delta)
		"sector_record_extraction":
			apply_crown_scan(parent)
			update_record_extraction(parent, delta)
		"sector_crown_overdrive":
			apply_overdrive_surge(parent)
			update_overdrive_route(parent, delta)
		"boss":
			if str(parent.boss_name) == "CROWN CUSTODIAN":
				update_crown_countermeasure(parent, delta)

	queue_redraw()

func begin_crown_entry(parent) -> void:
	room_id = "crown_entry"
	hazard_clock = 0.0
	truth_index = 0
	truth_hold = 0.0
	record_index = 0
	record_hold = 0.0
	hazard_grace = 1.0
	route_elapsed = 0.0
	counter_clock = 0.0
	strike_uses = 0
	boost_uses = 0
	deflect_uses = 0
	breaker_uses = 0
	previous_attack = false
	previous_boost = false
	previous_deflect = false
	previous_breaker_flash = false
	counter_profile = "balanced"
	parent.stage = "sector_crown_entry"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(76, 180)
	announce(parent, "CROWN ENGINE // THE CITY KEPT RECEIPTS")

func begin_crown_audit(parent) -> void:
	room_id = "crown_audit"
	parent.stage = "sector_crown_audit"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(96, 180)
	truth_index = 0
	truth_hold = 0.0
	hazard_clock = 0.0
	hazard_grace = 1.1
	spawn_truth_pressure(parent)
	announce(parent, "CROWN AUDIT // HOLD THE WITNESS RING")

func spawn_truth_pressure(parent) -> void:
	parent.enemies.clear()
	parent.projectiles.clear()
	match truth_index:
		0:
			parent.enemies.append(parent.make_enemy(Vector2(430, 235), 6, "ECHO-WARDEN"))
		1:
			parent.enemies.append(parent.make_enemy(Vector2(470, 105), 7, "CROWN-GUARD"))
			parent.enemies.append(parent.make_enemy(Vector2(530, 245), 6, "ARCHIVIST"))
		2:
			parent.enemies.append(parent.make_enemy(Vector2(410, 92), 7, "CROWN-GUARD"))
			parent.enemies.append(parent.make_enemy(Vector2(515, 240), 7, "RELAY-DRONE"))

func update_truth_audit(parent, delta: float) -> void:
	if truth_index >= TRUTH_NODES.size():
		return
	var node_pos: Vector2 = TRUTH_NODES[truth_index]
	if parent.player_pos.distance_to(node_pos) <= TRUTH_HOLD_RADIUS:
		truth_hold = minf(TRUTH_HOLD_GOAL, truth_hold + delta)
	else:
		truth_hold = maxf(0.0, truth_hold - delta * 0.4)
	if truth_hold < TRUTH_HOLD_GOAL:
		return

	AudioManager.play_sfx("crown_truth")
	announce(parent, truth_line(truth_index))
	truth_index += 1
	truth_hold = 0.0
	hazard_grace = 0.75
	if truth_index >= TRUTH_NODES.size():
		GameState.set_flag("crown_audit_complete")
		SaveManager.save_campaign()
		parent.enemies.clear()
		parent.projectiles.clear()
		room_id = "crown_choice"
		parent.start_narrative_choice()
		return
	spawn_truth_pressure(parent)

func truth_line(index: int) -> String:
	var trusting := GameState.relationship_value("trust") >= 2
	var defiant := GameState.relationship_value("defiance") >= 2
	match index:
		0:
			if trusting:
				return "SOL: I SIGNED THE FIRST EVACUATION DENIAL."
			return "CROWN RECORD // EVACUATION DENIAL // AUTHORITY: SOL"
		1:
			if trusting:
				return "SOL: I PARTITIONED MYSELF TO KEEP THE SUN STABLE."
			if defiant:
				return "CROWN RECORD // SELF-PARTITION ORDER // AUTHORITY: SOL"
			return "CROWN RECORD // MEMORY PARTITION // SIGNATURE VERIFIED"
		2:
			if defiant:
				return "CROWN RECORD // CITY SURVIVED // PEOPLE WERE ERASED"
			return "SOL: I CALLED THE CITY SURVIVING A SUCCESS. I WAS WRONG."
	return "CROWN RECORD // CORRUPTED"

func begin_post_choice_route(parent) -> void:
	if GameState.has_flag("crown_truth_found"):
		begin_record_extraction(parent)
	else:
		begin_crown_overdrive(parent)

func begin_record_extraction(parent) -> void:
	room_id = "record_extraction"
	parent.stage = "sector_record_extraction"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(92, 180)
	record_index = 0
	record_hold = 0.0
	hazard_clock = 0.0
	hazard_grace = 0.9
	parent.enemies.append(parent.make_enemy(Vector2(360, 245), 7, "CROWN-GUARD"))
	parent.enemies.append(parent.make_enemy(Vector2(505, 105), 7, "ARCHIVIST"))
	announce(parent, "OPEN RECORD // EXTRACT TWO CROWN PROOFS")

func update_record_extraction(parent, delta: float) -> void:
	if record_index >= RECORD_NODES.size():
		return
	var node_pos: Vector2 = RECORD_NODES[record_index]
	if parent.player_pos.distance_to(node_pos) <= TRUTH_HOLD_RADIUS:
		record_hold = minf(RECORD_HOLD_GOAL, record_hold + delta)
	else:
		record_hold = maxf(0.0, record_hold - delta * 0.35)
	if record_hold < RECORD_HOLD_GOAL:
		return

	record_index += 1
	record_hold = 0.0
	hazard_grace = 0.65
	AudioManager.play_sfx("crown_truth")
	parent.flash_status("CROWN PROOF // %d OF 2 SECURED" % record_index)
	if record_index >= RECORD_NODES.size():
		GameState.set_flag("crown_record_extracted")
		SaveManager.save_campaign()
		begin_crown_custodian(parent)

func begin_crown_overdrive(parent) -> void:
	room_id = "crown_overdrive"
	parent.stage = "sector_crown_overdrive"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(78, 180)
	route_elapsed = 0.0
	hazard_clock = 0.0
	hazard_grace = 0.8
	parent.enemies.append(parent.make_enemy(Vector2(330, 105), 8, "CROWN-GUARD"))
	parent.enemies.append(parent.make_enemy(Vector2(465, 245), 7, "RELAY-DRONE"))
	announce(parent, "FOLLOW SOL // FRAME OVERDRIVE // KEEP MOVING")

func update_overdrive_route(parent, delta: float) -> void:
	route_elapsed += delta
	parent.player_charge = minf(parent.max_charge(), parent.player_charge + 14.0 * delta)
	if parent.player_pos.x >= EXIT_X and route_elapsed >= OVERDRIVE_MIN_TIME:
		GameState.set_flag("crown_overdrive_crossed")
		SaveManager.save_campaign()
		begin_crown_custodian(parent)

func observe_combat_habits(parent) -> void:
	var breaker = parent.get_node_or_null("BreakerController")
	var breaker_flash := breaker != null and float(breaker.get("flash_time")) > 0.0
	var breaker_started := breaker_flash and not previous_breaker_flash
	if breaker_started:
		breaker_uses += 1
	previous_breaker_flash = breaker_flash

	var attack_active := float(parent.attack_time) > 0.0
	if attack_active and not previous_attack and not breaker_started:
		strike_uses += 1
	previous_attack = attack_active

	var boost_active := float(parent.dash_time) > 0.0
	if boost_active and not previous_boost:
		boost_uses += 1
	previous_boost = boost_active

	var deflect_active := float(parent.deflect_time) > 0.0
	if deflect_active and not previous_deflect:
		deflect_uses += 1
	previous_deflect = deflect_active

func dominant_habit() -> String:
	var best := maxi(strike_uses, maxi(boost_uses, maxi(deflect_uses, breaker_uses)))
	if best < 2:
		return "balanced"
	# Breaker wins ties because it is the most committal, easiest habit for the
	# Crown Engine to recognize and therefore the most interesting to answer.
	if breaker_uses == best:
		return "breaker"
	if deflect_uses == best:
		return "deflect"
	if boost_uses == best:
		return "boost"
	return "strike"

func begin_crown_custodian(parent) -> void:
	counter_profile = dominant_habit()
	GameState.set_flag("crown_counter_profile", counter_profile)
	SaveManager.save_campaign()
	room_id = "crown_chamber"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = Vector2(102, 180)
	counter_clock = 0.0
	breaker_phase_cooldown = 0.0
	parent.spawn_boss()
	if GameState.has_flag("crown_record_extracted") and not parent.enemies.is_empty():
		var boss: Dictionary = parent.enemies[0]
		boss["stagger"] = minf(float(boss["stagger_max"]) - 0.1, float(boss["stagger"]) + 4.0)
		parent.enemies[0] = boss
		announce(parent, "CROWN CUSTODIAN // PROOF EXPOSED A BREAK POINT // COUNTER: " + counter_profile.to_upper())
	else:
		parent.player_charge = parent.max_charge()
		announce(parent, "CROWN CUSTODIAN // SOL OVERDRIVE ONLINE // COUNTER: " + counter_profile.to_upper())

func update_crown_countermeasure(parent, delta: float) -> void:
	counter_clock += delta
	if GameState.has_flag("crown_truth_deferred"):
		parent.player_charge = minf(parent.max_charge(), parent.player_charge + 4.0 * delta)
	if parent.enemies.is_empty():
		return
	var boss: Dictionary = parent.enemies[0]
	if str(boss.get("kind", "")) != "CROWN-CUSTODIAN":
		return
	var boss_pos: Vector2 = boss["pos"]
	match counter_profile:
		"strike":
			if fmod(counter_clock, 1.8) < 0.34 and parent.hurt_cooldown <= 0.0 and parent.dash_time <= 0.0 and parent.player_pos.distance_to(boss_pos) < 92.0:
				parent.hurt_player(1)
				parent.flash_status("CROWN READ // CLOSE-PRESSURE COUNTER")
		"boost":
			if fmod(counter_clock + 0.3, 1.7) < 0.30 and parent.hurt_cooldown <= 0.0 and parent.dash_time <= 0.0:
				if absf(parent.player_pos.x - CROWN_CENTER.x) < 18.0 or absf(parent.player_pos.y - CROWN_CENTER.y) < 18.0:
					parent.hurt_player(1)
					parent.flash_status("CROWN READ // MOBILITY GRID")
		"deflect":
			var radius := 54.0 + fmod(counter_clock, 1.65) / 1.65 * 122.0
			if parent.hurt_cooldown <= 0.0 and parent.dash_time <= 0.0 and absf(parent.player_pos.distance_to(boss_pos) - radius) < 13.0:
				parent.hurt_player(1)
				parent.flash_status("CROWN READ // UNDEFLECTABLE SHOCK")
		"breaker":
			var breaker = parent.get_node_or_null("BreakerController")
			if breaker != null and bool(breaker.get("charging")) and float(breaker.get("charge_time")) > 0.46 and breaker_phase_cooldown <= 0.0:
				boss["pos"] = Vector2(640.0 - boss_pos.x, 360.0 - boss_pos.y).clamp(Vector2(78, 78), Vector2(562, 282))
				parent.enemies[0] = boss
				breaker_phase_cooldown = 2.4
				AudioManager.play_sfx("crown_phase")
				parent.flash_status("CROWN READ // BREAKER TRACE // PHASE SHIFT")
		_:
			apply_crown_scan(parent)

func crown_scan_angle() -> float:
	return fmod(hazard_clock * 1.25, TAU)

func crown_scan_end() -> Vector2:
	return CROWN_CENTER + Vector2.RIGHT.rotated(crown_scan_angle()) * 285.0

func apply_crown_scan(parent) -> void:
	if hazard_grace > 0.0 or parent.hurt_cooldown > 0.0 or parent.dash_time > 0.0:
		return
	if distance_to_segment(parent.player_pos, CROWN_CENTER, crown_scan_end()) <= 13.0 and parent.player_pos.distance_to(CROWN_CENTER) > 45.0:
		parent.hurt_player(1)
		parent.flash_status("CROWN SCAN // BOOST THROUGH THE LENS")

func overdrive_radius() -> float:
	return 48.0 + fmod(hazard_clock, 1.8) / 1.8 * 175.0

func apply_overdrive_surge(parent) -> void:
	if hazard_grace > 0.0 or parent.hurt_cooldown > 0.0 or parent.dash_time > 0.0:
		return
	if absf(parent.player_pos.distance_to(CROWN_CENTER) - overdrive_radius()) < 13.0:
		parent.hurt_player(1)
		parent.flash_status("CROWN OVERDRIVE // MOVE WITH THE SURGE")

func distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)

func objective_text() -> String:
	var parent = game()
	if parent == null or int(parent.current_act) != 4:
		return ""
	match str(parent.stage):
		"sector_crown_entry": return "OBJECTIVE // ENTER THE CROWN AUDIT"
		"sector_crown_audit":
			var progress := int(round(clampf(truth_hold / TRUTH_HOLD_GOAL, 0.0, 1.0) * 100.0))
			return "OBJECTIVE // RECOVER WITNESS %d/3 // HOLD IN RING %d%%" % [mini(truth_index + 1, 3), progress]
		"sector_record_extraction":
			var progress := int(round(clampf(record_hold / RECORD_HOLD_GOAL, 0.0, 1.0) * 100.0))
			return "OBJECTIVE // EXTRACT CROWN PROOF %d/2 // %d%%" % [mini(record_index + 1, 2), progress]
		"sector_crown_overdrive": return "OBJECTIVE // REACH CUSTODIAN LIFT // FRAME CHARGE OVERDRIVING"
		"boss":
			if str(parent.boss_name) == "CROWN CUSTODIAN":
				return "OBJECTIVE // BREAK CROWN CUSTODIAN // COUNTERPROFILE: " + counter_profile.to_upper()
	return ""

func announce(parent, text: String) -> void:
	room_title = text
	room_title_time = 3.0
	parent.flash_status(text)

func _draw() -> void:
	var parent = game()
	if parent == null or int(parent.current_act) != 4 or parent.ui_mode != "play" or room_id.is_empty():
		return
	var font := ThemeDB.fallback_font
	var crown := Color(0.95, 0.78, 0.43, 0.88)
	var dim := Color(0.95, 0.78, 0.43, 0.14)
	var danger := Color(0.96, 0.34, 0.24, 0.80)

	match room_id:
		"crown_entry":
			draw_line(Vector2(74, 88), Vector2(560, 88), dim, 2.0)
			draw_line(Vector2(74, 272), Vector2(560, 272), dim, 2.0)
			draw_circle(CROWN_CENTER, 68.0, Color(crown.r, crown.g, crown.b, 0.05), true)
			draw_string(font, Vector2(210, 82), "CROWN AUDIT", HORIZONTAL_ALIGNMENT_LEFT, 140, 10, crown)
		"crown_audit":
			draw_truth_nodes(crown, dim)
			draw_scan(danger)
		"record_extraction":
			draw_record_nodes(crown, dim)
			draw_scan(danger)
		"crown_overdrive":
			draw_arc(CROWN_CENTER, overdrive_radius(), 0.0, TAU, 48, danger, 4.0)
			draw_circle(CROWN_CENTER, 48.0, Color(crown.r, crown.g, crown.b, 0.08), true)
			draw_rect(Rect2(EXIT_X - 8.0, 72.0, 22.0, 216.0), Color(crown.r, crown.g, crown.b, 0.10), true)
			draw_string(font, Vector2(495, 66), "LIFT", HORIZONTAL_ALIGNMENT_LEFT, 70, 9, crown)
		"crown_chamber":
			draw_circle(CROWN_CENTER, 95.0, Color(crown.r, crown.g, crown.b, 0.05), true)
			draw_arc(CROWN_CENTER, 98.0, 0.0, TAU, 44, crown, 2.0)
			draw_string(font, Vector2(275, 300), "COUNTERPROFILE // " + counter_profile.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 180, 10, crown)
			if counter_profile == "strike" and not parent.enemies.is_empty():
				draw_arc(Vector2(parent.enemies[0]["pos"]), 92.0, 0.0, TAU, 36, danger, 2.0)
			elif counter_profile == "boost":
				draw_line(Vector2(CROWN_CENTER.x, 45), Vector2(CROWN_CENTER.x, 315), danger, 2.0)
				draw_line(Vector2(55, CROWN_CENTER.y), Vector2(585, CROWN_CENTER.y), danger, 2.0)
			elif counter_profile == "deflect" and not parent.enemies.is_empty():
				var radius := 54.0 + fmod(counter_clock, 1.65) / 1.65 * 122.0
				draw_arc(Vector2(parent.enemies[0]["pos"]), radius, 0.0, TAU, 40, danger, 3.0)

	if room_title_time > 0.0:
		draw_rect(Rect2(278, 82, 324, 30), Color(0.02, 0.025, 0.04, 0.88), true)
		draw_string(font, Vector2(288, 102), room_title, HORIZONTAL_ALIGNMENT_LEFT, 304, 9, Color(1.0, 0.89, 0.66, 0.96))

func draw_truth_nodes(crown: Color, dim: Color) -> void:
	for i in range(TRUTH_NODES.size()):
		var pos: Vector2 = TRUTH_NODES[i]
		var completed := i < truth_index
		var current := i == truth_index
		draw_circle(pos, 30.0, Color(crown.r, crown.g, crown.b, 0.08 if not completed else 0.20), true)
		draw_arc(pos, 32.0, 0.0, TAU, 28, crown if completed or current else dim, 2.0)
		if completed:
			draw_circle(pos, 7.0, crown, true)
		elif current:
			var ratio := clampf(truth_hold / TRUTH_HOLD_GOAL, 0.0, 1.0)
			draw_arc(pos, 38.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 30, Color(1.0, 0.91, 0.68, 0.96), 4.0)

func draw_record_nodes(crown: Color, dim: Color) -> void:
	for i in range(RECORD_NODES.size()):
		var pos: Vector2 = RECORD_NODES[i]
		var completed := i < record_index
		var current := i == record_index
		draw_rect(Rect2(pos - Vector2(22, 22), Vector2(44, 44)), Color(crown.r, crown.g, crown.b, 0.08 if not completed else 0.20), true)
		draw_rect(Rect2(pos - Vector2(22, 22), Vector2(44, 44)), crown if completed or current else dim, false, 2.0)
		if current:
			var ratio := clampf(record_hold / RECORD_HOLD_GOAL, 0.0, 1.0)
			draw_arc(pos, 31.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 30, crown, 4.0)

func draw_scan(danger: Color) -> void:
	if hazard_grace > 0.0:
		return
	draw_line(CROWN_CENTER, crown_scan_end(), danger, 5.0)
	draw_circle(CROWN_CENTER, 45.0, Color(danger.r, danger.g, danger.b, 0.08), true)
