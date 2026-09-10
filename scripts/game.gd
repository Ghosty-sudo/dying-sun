extends Node2D

const Campaign := preload("res://scripts/campaign_data.gd")

const ARENA := Rect2(24.0, 24.0, 592.0, 312.0)
const SUN_POS := Vector2(510.0, 145.0)
const CONSOLE_POS := Vector2(475.0, 282.0)
const PLAYER_SPEED := 124.0
const DASH_SPEED := 350.0
const BASE_MAX_CHARGE := 100.0
const BASE_CHARGE_REGEN := 23.0
const BASE_BOOST_COST := 30.0
const TOUCH_STICK_CENTER := Vector2(92.0, 287.0)
const TOUCH_STICK_RADIUS := 48.0
const TOUCH_ATTACK_CENTER := Vector2(562.0, 282.0)
const TOUCH_BOOST_CENTER := Vector2(500.0, 312.0)
const TOUCH_UTILITY_CENTER := Vector2(438.0, 312.0)
const TOUCH_BUTTON_RADIUS := 32.0

var ui_mode := "title"
var settings_return := "title"
var menu_selection := 0
var settings_selection := 0
var paused := false
var pause_selection := 0
var menu_nav_cooldown := 0.0

var current_act := 1
var stage := "wave_a"
var dialogue_context := ""
var act_banner_time := 0.0
var boss_name := ""
var boss_announced := false
var ending_id := ""
var ending_lines: Array[String] = []
var ending_index := 0

var player_pos := Vector2(92.0, 182.0)
var player_hp := 6
var player_charge := 100.0
var last_move := Vector2.RIGHT
var dash_time := 0.0
var dash_cooldown := 0.0
var attack_time := 0.0
var attack_cooldown := 0.0
var hurt_cooldown := 0.0
var deflect_time := 0.0
var deflect_cooldown := 0.0
var combo_step := 0
var combo_window := 0.0
var elapsed := 0.0
var wave_kills := 0

var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var dead := false

var dialogue_open := false
var choice_pending := false
var module_pending := false
var dialogue_lines: Array[String] = []
var dialogue_index := 0
var module_choices: Array[Dictionary] = []
var status_flash := ""
var status_time := 0.0

var touch_move_id := -1
var touch_origin := Vector2.ZERO
var touch_move := Vector2.ZERO
var touch_mode := false

func _ready() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	SaveManager.load_campaign()
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	menu_nav_cooldown = maxf(0.0, menu_nav_cooldown - delta)
	status_time = maxf(0.0, status_time - delta)
	act_banner_time = maxf(0.0, act_banner_time - delta)

	if ui_mode != "play" or paused:
		queue_redraw()
		return

	dash_time = maxf(0.0, dash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	attack_time = maxf(0.0, attack_time - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	deflect_time = maxf(0.0, deflect_time - delta)
	deflect_cooldown = maxf(0.0, deflect_cooldown - delta)
	combo_window = maxf(0.0, combo_window - delta)
	if combo_window <= 0.0:
		combo_step = 0
	if dash_time <= 0.0:
		player_charge = minf(max_charge(), player_charge + charge_regen() * delta)

	if dead:
		queue_redraw()
		return

	if not dialogue_open and not module_pending:
		update_player(delta)
		update_enemies(delta)
		update_projectiles(delta)
		check_encounter_progression()

	queue_redraw()

func title_options() -> Array[String]:
	var options: Array[String] = []
	if SaveManager.has_save() and not GameState.has_flag("campaign_complete"):
		options.append("CONTINUE")
	options.append("NEW GAME")
	options.append("SETTINGS")
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		options.append("QUIT")
	return options

func start_new_game() -> void:
	SaveManager.start_new_campaign()
	current_act = 1
	ui_mode = "play"
	paused = false
	begin_act_from_checkpoint()

func continue_game() -> void:
	if not SaveManager.load_campaign():
		start_new_game()
		return
	if GameState.has_flag("campaign_complete"):
		show_saved_ending()
		return
	current_act = clampi(GameState.act, 1, 5)
	ui_mode = "play"
	paused = false
	begin_act_from_checkpoint()

func begin_act_from_checkpoint() -> void:
	reset_combat_runtime()
	current_act = clampi(GameState.act, 1, 5)
	act_banner_time = 2.2
	var after_choice := GameState.checkpoint == Campaign.act_id(current_act) + "_after_choice"
	if after_choice:
		stage = "wave_b"
		spawn_campaign_wave(1)
	else:
		stage = "wave_a"
		spawn_campaign_wave(0)

func reset_combat_runtime() -> void:
	player_pos = Vector2(92.0, 182.0)
	player_hp = max_hp()
	player_charge = max_charge()
	last_move = Vector2.RIGHT
	dash_time = 0.0
	dash_cooldown = 0.0
	attack_time = 0.0
	attack_cooldown = 0.0
	hurt_cooldown = 0.0
	deflect_time = 0.0
	deflect_cooldown = 0.0
	combo_step = 0
	combo_window = 0.0
	wave_kills = 0
	dead = false
	boss_announced = false
	boss_name = ""
	dialogue_open = false
	choice_pending = false
	module_pending = false
	dialogue_lines.clear()
	dialogue_index = 0
	module_choices.clear()
	touch_move_id = -1
	touch_move = Vector2.ZERO
	enemies.clear()
	projectiles.clear()

func max_hp() -> int:
	return 7 if GameState.has_module("ghost_chassis") else 6

func max_charge() -> float:
	return 125.0 if GameState.has_module("burn_capacitor") else BASE_MAX_CHARGE

func charge_regen() -> float:
	return BASE_CHARGE_REGEN + (7.0 if GameState.has_module("burn_capacitor") else 0.0)

func boost_cost() -> float:
	return 24.0 if GameState.has_module("phase_coil") else BASE_BOOST_COST

func deflect_window_length() -> float:
	return 0.21 if GameState.has_module("sol_echo") else 0.17

func stagger_multiplier() -> float:
	return 1.25 if GameState.has_module("impact_servo") else 1.0

func spawn_campaign_wave(index: int) -> void:
	enemies.clear()
	projectiles.clear()
	var specs := Campaign.wave(current_act, index)
	for spec in specs:
		enemies.append(make_enemy_from_spec(spec))

	if index == 1:
		if current_act == 2 and GameState.has_flag("archive_preserved"):
			enemies.append(make_enemy(Vector2(520, 90), 5, "WARDEN"))
		if current_act == 3 and GameState.has_flag("civilian_grid_preserved"):
			enemies.append(make_enemy(Vector2(520, 95), 6, "WARDEN"))
		if current_act == 3 and GameState.has_flag("defense_lattice_powered") and not enemies.is_empty():
			enemies[0]["hp"] = maxi(1, int(enemies[0]["hp"]) - 2)
			enemies[0]["max_hp"] = int(enemies[0]["hp"])

func make_enemy_from_spec(spec: Dictionary) -> Dictionary:
	return make_enemy(Vector2(spec.get("pos", Vector2(320, 180))), int(spec.get("hp", 3)), str(spec.get("kind", "WARDEN")))

func make_enemy(pos: Vector2, hp: int, kind: String) -> Dictionary:
	var stagger_max := 3.0
	if kind == "SUN-HUSK" or kind == "CROWN-GUARD":
		stagger_max = 5.0
	elif kind == "ARCHIVIST" or kind == "RELAY-DRONE":
		stagger_max = 4.0
	elif is_boss_kind(kind):
		stagger_max = 9.0 + float(current_act)
	return {
		"pos": pos,
		"hp": hp,
		"max_hp": hp,
		"kind": kind,
		"flash": 0.0,
		"attack_cd": 0.45,
		"telegraph": 0.0,
		"state": "idle",
		"state_time": 0.0,
		"velocity": Vector2.ZERO,
		"stagger": 0.0,
		"stagger_max": stagger_max,
		"stunned": 0.0,
		"pattern": 0,
		"orbit_dir": -1.0 if int(pos.x + pos.y) % 2 == 0 else 1.0,
	}

func is_boss_kind(kind: String) -> bool:
	return kind in ["GATE-CUSTODIAN", "THE-ARCHIVIST", "RELAY-SAINT", "CROWN-CUSTODIAN", "LAST-LIGHT"]

func check_encounter_progression() -> void:
	if not enemies.is_empty():
		return
	match stage:
		"wave_a":
			start_narrative_choice()
		"wave_b":
			if GameState.has_module("memory_sink"):
				player_hp = mini(max_hp(), player_hp + 1)
				flash_status("MEMORY SINK // ARMOR RESTORED")
			spawn_boss()
		"boss":
			finish_current_act()

func start_narrative_choice() -> void:
	stage = "choice"
	dialogue_open = true
	choice_pending = false
	dialogue_context = "pre_choice"
	dialogue_lines = Campaign.pre_choice_dialogue(current_act)
	dialogue_index = 0

func spawn_boss() -> void:
	stage = "boss"
	projectiles.clear()
	var spec := Campaign.boss_spec(current_act)
	boss_name = str(spec.get("name", "CUSTODIAN"))
	var kind := str(spec.get("kind", "GATE-CUSTODIAN"))
	var hp := int(spec.get("hp", 18))
	if current_act == 2 and GameState.has_flag("archive_burned"):
		hp = maxi(1, hp - 3)
	enemies = [make_enemy(Vector2(505, 160), hp, kind)]
	boss_announced = true
	flash_status(boss_name + " // ONLINE")

func finish_current_act() -> void:
	stage = "act_complete"
	projectiles.clear()
	if current_act == 4 and GameState.has_flag("crown_truth_found"):
		GameState.set_flag("sol_core_recovered")
	GameState.set_flag(Campaign.act_id(current_act) + "_cleared")
	SaveManager.save_campaign()
	dialogue_open = true
	choice_pending = false
	dialogue_context = "act_complete"
	dialogue_lines = Campaign.act_complete_dialogue(current_act)
	dialogue_index = 0

func open_module_selection() -> void:
	module_choices = Campaign.module_options(current_act)
	if module_choices.is_empty():
		advance_to_next_act()
		return
	module_pending = true
	dialogue_open = false
	choice_pending = false
	stage = "module"

func choose_module(index: int) -> void:
	if not module_pending or index < 0 or index >= module_choices.size():
		return
	var picked: Dictionary = module_choices[index]
	GameState.add_module(str(picked.get("id", "")))
	module_pending = false
	module_choices.clear()
	SaveManager.save_campaign()
	advance_to_next_act()

func advance_to_next_act() -> void:
	if current_act >= 5:
		resolve_final_ending()
		return
	current_act += 1
	GameState.set_checkpoint(Campaign.act_id(current_act) + "_start", current_act)
	SaveManager.save_campaign()
	begin_act_from_checkpoint()

func apply_narrative_choice(choice: int) -> void:
	match current_act:
		1:
			if choice == 1:
				GameState.record_relationship("trust", 1)
				GameState.record_relationship("curiosity", 1)
				GameState.set_flag("first_contact_trust")
			else:
				GameState.record_relationship("defiance", 1)
				GameState.set_flag("first_contact_defiance")
		2:
			if choice == 1:
				GameState.record_relationship("mercy", 1)
				GameState.record_relationship("curiosity", 1)
				GameState.set_flag("archive_preserved")
			else:
				GameState.record_relationship("pragmatism", 1)
				GameState.set_flag("archive_burned")
		3:
			if choice == 1:
				GameState.record_relationship("mercy", 1)
				GameState.set_flag("civilian_grid_preserved")
			else:
				GameState.record_relationship("pragmatism", 1)
				GameState.set_flag("defense_lattice_powered")
		4:
			if choice == 1:
				GameState.record_relationship("curiosity", 1)
				GameState.record_relationship("defiance", 1)
				GameState.set_flag("crown_truth_found")
			else:
				GameState.record_relationship("trust", 1)
				GameState.set_flag("crown_truth_deferred")
		5:
			if choice == 1:
				GameState.record_relationship("trust", 1)
				GameState.remember_promise("last_light_together", "Decide what survives together")
				GameState.set_flag("final_together")
			else:
				GameState.record_relationship("defiance", 1)
				GameState.set_flag("final_sever")

func choose_path(choice: int) -> void:
	if not choice_pending or stage != "choice":
		return
	choice_pending = false
	apply_narrative_choice(choice)
	GameState.set_checkpoint(Campaign.act_id(current_act) + "_after_choice", current_act)
	SaveManager.save_campaign()
	dialogue_context = "choice_result"
	dialogue_lines = Campaign.choice_result_dialogue(current_act, choice)
	dialogue_index = 0

func resolve_final_ending() -> void:
	var available := GameState.available_endings()
	if GameState.has_flag("final_together") and available.has("reconciliation"):
		ending_id = "reconciliation"
		GameState.resolve_promise("last_light_together", true)
	elif GameState.has_flag("final_sever"):
		ending_id = "sever_system"
	elif GameState.has_flag("civilian_grid_preserved") and GameState.has_flag("archive_preserved"):
		ending_id = "preserve_city"
	elif available.has("preserve_sol"):
		ending_id = "preserve_sol"
	else:
		ending_id = "burn_clean"
	GameState.set_ending(ending_id)
	SaveManager.save_campaign()
	show_saved_ending()

func show_saved_ending() -> void:
	ending_id = GameState.ending_seen
	if ending_id.is_empty():
		ending_id = "burn_clean"
	ending_lines = Campaign.ending_lines(ending_id)
	ending_index = 0
	ui_mode = "ending"
	paused = false

func update_player(delta: float) -> void:
	var move := touch_move
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1.0
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var device := int(pads[0])
		var joy := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if joy.length() > 0.22:
			move += joy
	if move.length_squared() > 0.0:
		move = move.normalized()
		last_move = move
	var speed := DASH_SPEED if dash_time > 0.0 else PLAYER_SPEED
	player_pos += move * speed * delta
	player_pos = clamp_to_arena(player_pos, 12.0)

func update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		enemy["flash"] = maxf(0.0, float(enemy["flash"]) - delta)
		enemy["attack_cd"] = maxf(0.0, float(enemy["attack_cd"]) - delta)
		enemy["telegraph"] = maxf(0.0, float(enemy["telegraph"]) - delta)
		enemy["state_time"] = maxf(0.0, float(enemy["state_time"]) - delta)
		enemy["stunned"] = maxf(0.0, float(enemy["stunned"]) - delta)
		if float(enemy["stunned"]) > 0.0:
			enemies[i] = enemy
			continue
		var kind := str(enemy["kind"])
		if is_boss_kind(kind):
			update_boss(enemy, delta)
		elif kind == "WARDEN" or kind == "ECHO-WARDEN" or kind == "CROWN-GUARD":
			update_melee_enemy(enemy, delta)
		elif kind == "HUSK" or kind == "ARCHIVIST" or kind == "RELAY-DRONE":
			update_ranged_enemy(enemy, delta)
		elif kind == "SUN-HUSK":
			update_sun_husk(enemy, delta)
		enemies[i] = enemy

func update_melee_enemy(enemy: Dictionary, delta: float) -> void:
	var pos: Vector2 = enemy["pos"]
	var toward := player_pos - pos
	var distance := toward.length()
	var kind := str(enemy["kind"])
	var speed := 45.0
	var damage := 1
	if kind == "ECHO-WARDEN": speed = 54.0
	if kind == "CROWN-GUARD":
		speed = 42.0
		damage = 2
	if str(enemy["state"]) == "telegraph":
		if float(enemy["telegraph"]) <= 0.0:
			enemy["state"] = "idle"
			enemy["attack_cd"] = 0.85
			if distance < 78.0:
				pos += toward.normalized() * minf(42.0, distance)
				enemy["pos"] = clamp_to_arena(pos, 14.0)
				attempt_enemy_hit(pos, 31.0, damage, 2.2)
				if kind == "ECHO-WARDEN":
					spawn_projectile(pos, -toward.normalized(), 92.0, 1, "ECHO")
		return
	if distance > 43.0:
		pos += toward.normalized() * speed * delta
		enemy["pos"] = pos
	elif float(enemy["attack_cd"]) <= 0.0:
		enemy["state"] = "telegraph"
		enemy["telegraph"] = 0.30 if kind == "ECHO-WARDEN" else 0.36

func update_ranged_enemy(enemy: Dictionary, delta: float) -> void:
	var pos: Vector2 = enemy["pos"]
	var toward := player_pos - pos
	var distance := toward.length()
	var kind := str(enemy["kind"])
	if kind == "ARCHIVIST":
		var tangent := Vector2(-toward.y, toward.x).normalized() * float(enemy["orbit_dir"])
		pos += tangent * 28.0 * delta
		if distance < 125.0: pos -= toward.normalized() * 24.0 * delta
		elif distance > 205.0: pos += toward.normalized() * 20.0 * delta
	elif kind == "RELAY-DRONE":
		var tangent := Vector2(-toward.y, toward.x).normalized() * float(enemy["orbit_dir"])
		pos += tangent * 42.0 * delta
		if distance < 110.0: pos -= toward.normalized() * 28.0 * delta
	elif distance < 105.0:
		pos -= toward.normalized() * 34.0 * delta
	elif distance > 185.0:
		pos += toward.normalized() * 28.0 * delta
	enemy["pos"] = clamp_to_arena(pos, 14.0)
	if float(enemy["attack_cd"]) > 0.0 or distance > 245.0:
		return
	if kind == "ARCHIVIST":
		spawn_projectile(pos, toward.normalized().rotated(-0.12), 108.0, 1, "MEMORY BOLT")
		spawn_projectile(pos, toward.normalized().rotated(0.12), 108.0, 1, "MEMORY BOLT")
		enemy["attack_cd"] = 1.30
	elif kind == "RELAY-DRONE":
		for angle in [-0.22, 0.0, 0.22]:
			spawn_projectile(pos, toward.normalized().rotated(angle), 120.0, 1, "RELAY SHARD")
		enemy["attack_cd"] = 1.65
	else:
		spawn_projectile(pos, toward.normalized(), 105.0, 1, "MEMORY BOLT")
		enemy["attack_cd"] = 1.38
	enemy["flash"] = 0.08

func update_sun_husk(enemy: Dictionary, delta: float) -> void:
	var pos: Vector2 = enemy["pos"]
	var toward := player_pos - pos
	var state := str(enemy["state"])
	if state == "charge_telegraph":
		if float(enemy["telegraph"]) <= 0.0:
			enemy["state"] = "charge"
			enemy["state_time"] = 0.34
			enemy["velocity"] = toward.normalized() * 245.0
		return
	if state == "charge":
		pos += Vector2(enemy["velocity"]) * delta
		enemy["pos"] = clamp_to_arena(pos, 16.0)
		if pos.distance_to(player_pos) < 28.0:
			attempt_enemy_hit(pos, 30.0, 2, 3.2)
			enemy["state"] = "recover"
			enemy["state_time"] = 0.60
		elif float(enemy["state_time"]) <= 0.0:
			enemy["state"] = "recover"
			enemy["state_time"] = 0.60
		return
	if state == "recover":
		if float(enemy["state_time"]) <= 0.0:
			enemy["state"] = "idle"
			enemy["attack_cd"] = 0.55
		return
	if toward.length() > 115.0:
		pos += toward.normalized() * 37.0 * delta
		enemy["pos"] = pos
	if float(enemy["attack_cd"]) <= 0.0 and toward.length() < 225.0:
		enemy["state"] = "charge_telegraph"
		enemy["telegraph"] = 0.58

func update_boss(enemy: Dictionary, delta: float) -> void:
	var pos: Vector2 = enemy["pos"]
	var toward := player_pos - pos
	var distance := toward.length()
	var kind := str(enemy["kind"])
	var enraged := int(enemy["hp"]) <= int(enemy["max_hp"]) / 2
	if str(enemy["state"]) == "telegraph":
		if float(enemy["telegraph"]) <= 0.0:
			enemy["state"] = "idle"
			execute_boss_pattern(enemy, pos, toward, distance, enraged)
			enemy["attack_cd"] = 0.56 if enraged else 0.82
		return
	var desired := 90.0
	if kind == "RELAY-SAINT": desired = 125.0
	if distance > desired + 20.0:
		pos += toward.normalized() * (52.0 if enraged else 42.0) * delta
	elif distance < desired - 25.0:
		pos -= toward.normalized() * 22.0 * delta
	enemy["pos"] = clamp_to_arena(pos, 24.0)
	if float(enemy["attack_cd"]) <= 0.0:
		enemy["state"] = "telegraph"
		enemy["telegraph"] = 0.38 if enraged else 0.52

func execute_boss_pattern(enemy: Dictionary, pos: Vector2, toward: Vector2, distance: float, enraged: bool) -> void:
	var kind := str(enemy["kind"])
	var pattern := int(enemy["pattern"])
	enemy["pattern"] = pattern + 1
	match kind:
		"GATE-CUSTODIAN":
			if pattern % 2 == 0:
				boss_lunge(enemy, pos, toward, distance, 58.0, 2 if enraged else 1)
			else:
				fire_arc(pos, toward.angle(), 7 if enraged else 5, 1.25, 128.0)
		"THE-ARCHIVIST":
			if pattern % 3 == 0:
				fire_ring(pos, 8 if enraged else 6, 108.0)
			elif pattern % 3 == 1:
				fire_arc(pos, toward.angle(), 7, 1.65, 116.0)
			else:
				enemy["pos"] = Vector2(640.0 - pos.x, 360.0 - pos.y).clamp(Vector2(60, 60), Vector2(580, 300))
				fire_arc(Vector2(enemy["pos"]), (player_pos - Vector2(enemy["pos"])).angle(), 3, 0.42, 150.0)
		"RELAY-SAINT":
			if pattern % 2 == 0:
				fire_cross(pos, 138.0)
				fire_arc(pos, toward.angle(), 3, 0.32, 154.0)
			else:
				boss_lunge(enemy, pos, toward, distance, 80.0, 2)
		"CROWN-CUSTODIAN":
			if pattern % 3 == 0:
				fire_ring(pos, 10 if enraged else 8, 126.0)
			elif pattern % 3 == 1:
				boss_lunge(enemy, pos, toward, distance, 72.0, 2)
			else:
				fire_arc(pos, toward.angle(), 9 if enraged else 7, 1.8, 138.0)
		"LAST-LIGHT":
			if pattern % 4 == 0:
				fire_ring(pos, 12 if enraged else 9, 140.0)
			elif pattern % 4 == 1:
				boss_lunge(enemy, pos, toward, distance, 86.0, 2)
			elif pattern % 4 == 2:
				fire_cross(pos, 160.0)
				fire_arc(pos, toward.angle(), 5, 0.65, 170.0)
			else:
				fire_arc(pos, toward.angle(), 11 if enraged else 9, 2.0, 145.0)

func boss_lunge(enemy: Dictionary, pos: Vector2, toward: Vector2, distance: float, travel: float, damage: int) -> void:
	if distance <= 0.001:
		return
	pos += toward.normalized() * minf(travel, distance)
	enemy["pos"] = clamp_to_arena(pos, 24.0)
	attempt_enemy_hit(Vector2(enemy["pos"]), 42.0, damage, 4.0)

func fire_arc(origin: Vector2, angle: float, count: int, spread: float, speed: float) -> void:
	for j in range(count):
		var t := 0.5 if count == 1 else float(j) / float(count - 1)
		var shot_angle := angle + lerpf(-spread * 0.5, spread * 0.5, t)
		spawn_projectile(origin, Vector2.RIGHT.rotated(shot_angle), speed, 1, "SOLAR ARC")

func fire_ring(origin: Vector2, count: int, speed: float) -> void:
	for j in range(count):
		var angle := TAU * float(j) / float(count)
		spawn_projectile(origin, Vector2.RIGHT.rotated(angle), speed, 1, "MEMORY RING")

func fire_cross(origin: Vector2, speed: float) -> void:
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		spawn_projectile(origin, Vector2.RIGHT.rotated(angle), speed, 1, "RELAY SHARD")

func spawn_projectile(origin: Vector2, direction: Vector2, speed: float, damage: int, kind: String) -> void:
	projectiles.append({"pos": origin, "velocity": direction.normalized() * speed, "damage": damage, "life": 3.0, "kind": kind})

func update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile := projectiles[i]
		projectile["life"] = float(projectile["life"]) - delta
		projectile["pos"] = Vector2(projectile["pos"]) + Vector2(projectile["velocity"]) * delta
		var pos: Vector2 = projectile["pos"]
		if float(projectile["life"]) <= 0.0 or not ARENA.grow(20.0).has_point(pos):
			projectiles.remove_at(i)
			continue
		if pos.distance_to(player_pos) < 15.0:
			if deflect_time > 0.0:
				var refund := 24.0 if GameState.has_module("mirror_lattice") else 14.0
				player_charge = minf(max_charge(), player_charge + refund)
				if GameState.has_module("mirror_lattice"):
					damage_nearest_enemy(pos, 1, 2.0)
				flash_status("PERFECT DEFLECT // +CHARGE")
				projectiles.remove_at(i)
				continue
			if dash_time <= 0.0:
				hurt_player(int(projectile["damage"]))
				projectiles.remove_at(i)
				continue
		projectiles[i] = projectile

func attempt_enemy_hit(origin: Vector2, radius: float, damage: int, stagger_return: float) -> void:
	if origin.distance_to(player_pos) > radius:
		return
	if dash_time > 0.0:
		flash_status("BOOST EVADE")
		return
	if deflect_time > 0.0:
		var refund := 28.0 if GameState.has_module("mirror_lattice") else 18.0
		player_charge = minf(max_charge(), player_charge + refund)
		stagger_nearby_enemy(origin, stagger_return)
		if GameState.has_module("mirror_lattice"):
			damage_nearest_enemy(origin, 1, 1.5)
		flash_status("PERFECT DEFLECT")
		return
	hurt_player(damage)

func hurt_player(damage: int) -> void:
	if hurt_cooldown > 0.0:
		return
	player_hp -= damage
	hurt_cooldown = 1.0 if GameState.has_module("ghost_chassis") else 0.72
	combo_step = 0
	combo_window = 0.0
	flash_status("ARMOR BREACH")
	if player_hp <= 0:
		player_hp = 0
		dead = true
		GameState.register_death()
		SaveManager.save_campaign()

func stagger_nearby_enemy(origin: Vector2, amount: float) -> void:
	var best := -1
	var best_distance := 99999.0
	for i in range(enemies.size()):
		var distance := Vector2(enemies[i]["pos"]).distance_to(origin)
		if distance < 52.0 and distance < best_distance:
			best = i
			best_distance = distance
	if best >= 0:
		var enemy := enemies[best]
		apply_stagger(enemy, amount)
		enemies[best] = enemy

func damage_nearest_enemy(origin: Vector2, damage: int, stagger: float) -> void:
	var best := -1
	var best_distance := 99999.0
	for i in range(enemies.size()):
		var distance := Vector2(enemies[i]["pos"]).distance_to(origin)
		if distance < 110.0 and distance < best_distance:
			best = i
			best_distance = distance
	if best < 0:
		return
	var enemy := enemies[best]
	enemy["hp"] = int(enemy["hp"]) - damage
	apply_stagger(enemy, stagger)
	if int(enemy["hp"]) <= 0:
		enemies.remove_at(best)
		wave_kills += 1
	else:
		enemies[best] = enemy

func perform_attack() -> void:
	if attack_cooldown > 0.0 or dialogue_open or module_pending or dead or paused:
		return
	combo_step = combo_step + 1 if combo_window > 0.0 else 1
	if combo_step > 3: combo_step = 1
	combo_window = 0.48
	attack_time = 0.15 if combo_step < 3 else 0.22
	attack_cooldown = 0.24 if combo_step < 3 else 0.38
	var attack_range := 52.0 + float(combo_step - 1) * 6.0
	var damage := 1 if combo_step < 3 else 2
	if combo_step == 3 and GameState.has_module("sol_echo"):
		damage += 1
	var stagger_damage := (1.0 if combo_step == 1 else (1.3 if combo_step == 2 else 2.4)) * stagger_multiplier()
	var hit_any := false
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		var to_enemy := Vector2(enemy["pos"]) - player_pos
		if to_enemy.length() <= attack_range:
			var facing_score := last_move.normalized().dot(to_enemy.normalized())
			if facing_score > -0.10:
				var hit_damage := damage + (1 if is_boss_kind(str(enemy["kind"])) and GameState.has_module("crown_spike") else 0)
				enemy["hp"] = int(enemy["hp"]) - hit_damage
				enemy["flash"] = 0.12
				apply_stagger(enemy, stagger_damage)
				hit_any = true
				if int(enemy["hp"]) <= 0:
					enemies.remove_at(i)
					wave_kills += 1
				else:
					enemies[i] = enemy
	if hit_any:
		flash_status("CHAIN %d // IMPACT" % combo_step)

func apply_stagger(enemy: Dictionary, amount: float) -> void:
	enemy["stagger"] = float(enemy["stagger"]) + amount
	if float(enemy["stagger"]) >= float(enemy["stagger_max"]):
		enemy["stagger"] = 0.0
		enemy["stunned"] = 1.20 if is_boss_kind(str(enemy["kind"])) else 0.95
		enemy["state"] = "idle"
		enemy["telegraph"] = 0.0
		flash_status("SYSTEM BREAK")

func perform_boost() -> void:
	if dash_cooldown > 0.0 or dialogue_open or module_pending or dead or paused:
		return
	var cost := boost_cost()
	if player_charge < cost:
		flash_status("CHARGE LOW")
		return
	player_charge -= cost
	dash_time = 0.16
	dash_cooldown = 0.24
	flash_status("BOOST")

func perform_deflect() -> void:
	if deflect_cooldown > 0.0 or dialogue_open or module_pending or dead or paused:
		return
	deflect_time = deflect_window_length()
	deflect_cooldown = 0.52
	flash_status("DEFLECT WINDOW")

func try_interact() -> void:
	if dead:
		restart_from_checkpoint()
		return
	if not dialogue_open:
		return
	if choice_pending:
		return
	if dialogue_index < dialogue_lines.size() - 1:
		dialogue_index += 1
		return
	match dialogue_context:
		"pre_choice":
			choice_pending = true
		"choice_result":
			dialogue_open = false
			dialogue_context = ""
			stage = "wave_b"
			spawn_campaign_wave(1)
		"act_complete":
			dialogue_open = false
			if current_act < 5:
				open_module_selection()
			else:
				resolve_final_ending()

func restart_from_checkpoint() -> void:
	SaveManager.load_campaign()
	current_act = clampi(GameState.act, 1, 5)
	begin_act_from_checkpoint()
	flash_status("FRAME REKINDLED")

func flash_status(text: String) -> void:
	status_flash = text
	status_time = 0.85

func clamp_to_arena(pos: Vector2, margin: float) -> Vector2:
	return Vector2(clampf(pos.x, ARENA.position.x + margin, ARENA.end.x - margin), clampf(pos.y, ARENA.position.y + margin, ARENA.end.y - margin))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_mode = true
		handle_pointer(event.position, event.pressed, event.index)
	elif event is InputEventScreenDrag:
		touch_mode = true
		handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			handle_pointer(mouse.position, true, -99)
	elif event is InputEventJoypadButton:
		handle_joy_button(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion:
		handle_joy_motion(event as InputEventJoypadMotion)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if ui_mode == "title":
		handle_menu_key(key.keycode)
		return
	if ui_mode == "settings":
		handle_settings_key(key.keycode)
		return
	if ui_mode == "ending":
		if key.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]: advance_ending()
		elif key.keycode == KEY_ESCAPE: ui_mode = "title"
		return
	if ui_mode != "play": return
	if key.keycode == KEY_ESCAPE:
		paused = not paused
		pause_selection = 0
		return
	if paused:
		handle_pause_key(key.keycode)
		return
	match key.keycode:
		KEY_SPACE: perform_attack()
		KEY_SHIFT: perform_boost()
		KEY_F: perform_deflect()
		KEY_E: try_interact()
		KEY_1: choose_context_choice(0)
		KEY_2: choose_context_choice(1)
		KEY_R:
			if dead: restart_from_checkpoint()

func handle_joy_button(event: InputEventJoypadButton) -> void:
	if not event.pressed:
		return
	var button := int(event.button_index)
	if ui_mode == "title":
		if button == 0: activate_title_selection()
		return
	if ui_mode == "settings":
		if button == 0: adjust_current_setting(1)
		elif button == 1: leave_settings()
		return
	if ui_mode == "ending":
		if button == 0: advance_ending()
		return
	if ui_mode != "play": return
	if button == 7:
		paused = not paused
		pause_selection = 0
		return
	if paused:
		if button == 0: activate_pause_selection()
		elif button == 1: paused = false
		return
	match button:
		0: perform_attack()
		1: perform_boost()
		2: perform_deflect()
		3: try_interact()

func handle_joy_motion(event: InputEventJoypadMotion) -> void:
	if menu_nav_cooldown > 0.0 or absf(event.axis_value) < 0.72:
		return
	if int(event.axis) == int(JOY_AXIS_LEFT_Y):
		var delta := 1 if event.axis_value > 0.0 else -1
		if ui_mode == "title": menu_selection = wrapi(menu_selection + delta, 0, title_options().size())
		elif ui_mode == "settings": settings_selection = wrapi(settings_selection + delta, 0, settings_entries().size())
		elif ui_mode == "play" and paused: pause_selection = wrapi(pause_selection + delta, 0, pause_options().size())
		menu_nav_cooldown = 0.18
	elif int(event.axis) == int(JOY_AXIS_LEFT_X) and ui_mode == "settings":
		adjust_current_setting(1 if event.axis_value > 0.0 else -1)
		menu_nav_cooldown = 0.18

func handle_pointer(pos: Vector2, pressed: bool, pointer_id: int) -> void:
	if not pressed:
		if pointer_id == touch_move_id:
			touch_move_id = -1
			touch_move = Vector2.ZERO
		return
	if ui_mode == "title":
		handle_title_pointer(pos)
		return
	if ui_mode == "settings":
		handle_settings_pointer(pos)
		return
	if ui_mode == "ending":
		advance_ending()
		return
	if ui_mode != "play": return
	if paused:
		handle_pause_pointer(pos)
		return
	if dead:
		restart_from_checkpoint()
		return
	if module_pending:
		choose_module(0 if pos.x < 320.0 else 1)
		return
	if dialogue_open:
		if choice_pending: choose_context_choice(0 if pos.x < 320.0 else 1)
		else: try_interact()
		return
	if pos.distance_to(TOUCH_ATTACK_CENTER) <= TOUCH_BUTTON_RADIUS + 12.0:
		perform_attack(); return
	if pos.distance_to(TOUCH_BOOST_CENTER) <= TOUCH_BUTTON_RADIUS + 12.0:
		perform_boost(); return
	if pos.distance_to(TOUCH_UTILITY_CENTER) <= TOUCH_BUTTON_RADIUS + 12.0:
		perform_deflect(); return
	if pos.x < 260.0 and pointer_id >= 0:
		touch_move_id = pointer_id
		touch_origin = pos
		touch_move = Vector2.ZERO

func handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != touch_move_id or ui_mode != "play" or paused:
		return
	var delta := event.position - touch_origin
	if delta.length() > TOUCH_STICK_RADIUS:
		delta = delta.normalized() * TOUCH_STICK_RADIUS
	touch_move = delta / TOUCH_STICK_RADIUS

func choose_context_choice(index: int) -> void:
	if module_pending:
		choose_module(index)
	elif choice_pending:
		choose_path(index + 1)

func handle_menu_key(keycode: Key) -> void:
	var options := title_options()
	if keycode in [KEY_UP, KEY_W]: menu_selection = wrapi(menu_selection - 1, 0, options.size())
	elif keycode in [KEY_DOWN, KEY_S]: menu_selection = wrapi(menu_selection + 1, 0, options.size())
	elif keycode in [KEY_ENTER, KEY_SPACE, KEY_E]: activate_title_selection()

func activate_title_selection() -> void:
	var options := title_options()
	if options.is_empty(): return
	menu_selection = clampi(menu_selection, 0, options.size() - 1)
	var selected := options[menu_selection]
	match selected:
		"CONTINUE": continue_game()
		"NEW GAME": start_new_game()
		"SETTINGS":
			settings_return = "title"
			ui_mode = "settings"
			settings_selection = 0
		"QUIT": get_tree().quit()

func handle_title_pointer(pos: Vector2) -> void:
	var options := title_options()
	for i in range(options.size()):
		var rect := Rect2(205, 178 + i * 36, 230, 28)
		if rect.has_point(pos):
			menu_selection = i
			activate_title_selection()
			return

func settings_entries() -> Array[String]:
	return ["MASTER", "MUSIC", "SFX", "SCREEN SHAKE", "HIGH CONTRAST", "FULLSCREEN", "BACK"]

func handle_settings_key(keycode: Key) -> void:
	var entries := settings_entries()
	if keycode in [KEY_UP, KEY_W]: settings_selection = wrapi(settings_selection - 1, 0, entries.size())
	elif keycode in [KEY_DOWN, KEY_S]: settings_selection = wrapi(settings_selection + 1, 0, entries.size())
	elif keycode in [KEY_LEFT, KEY_A]: adjust_current_setting(-1)
	elif keycode in [KEY_RIGHT, KEY_D, KEY_ENTER, KEY_SPACE]: adjust_current_setting(1)
	elif keycode == KEY_ESCAPE: leave_settings()

func adjust_current_setting(direction: int) -> void:
	match settings_selection:
		0: SettingsManager.set_master(SettingsManager.master_volume + 0.1 * float(direction))
		1: SettingsManager.set_music(SettingsManager.music_volume + 0.1 * float(direction))
		2: SettingsManager.set_sfx(SettingsManager.sfx_volume + 0.1 * float(direction))
		3: SettingsManager.toggle_screen_shake()
		4: SettingsManager.toggle_high_contrast()
		5: SettingsManager.toggle_fullscreen()
		6: leave_settings()

func handle_settings_pointer(pos: Vector2) -> void:
	var entries := settings_entries()
	for i in range(entries.size()):
		var rect := Rect2(150, 102 + i * 32, 340, 25)
		if rect.has_point(pos):
			settings_selection = i
			adjust_current_setting(1)
			return

func leave_settings() -> void:
	if settings_return == "pause":
		ui_mode = "play"
		paused = true
	else:
		ui_mode = "title"

func pause_options() -> Array[String]:
	return ["RESUME", "SETTINGS", "RETURN TO TITLE"]

func handle_pause_key(keycode: Key) -> void:
	var options := pause_options()
	if keycode in [KEY_UP, KEY_W]: pause_selection = wrapi(pause_selection - 1, 0, options.size())
	elif keycode in [KEY_DOWN, KEY_S]: pause_selection = wrapi(pause_selection + 1, 0, options.size())
	elif keycode in [KEY_ENTER, KEY_SPACE, KEY_E]: activate_pause_selection()
	elif keycode == KEY_ESCAPE: paused = false

func activate_pause_selection() -> void:
	match pause_selection:
		0: paused = false
		1:
			settings_return = "pause"
			ui_mode = "settings"
			settings_selection = 0
		2:
			paused = false
			ui_mode = "title"
			menu_selection = 0

func handle_pause_pointer(pos: Vector2) -> void:
	for i in range(pause_options().size()):
		var rect := Rect2(205, 155 + i * 38, 230, 30)
		if rect.has_point(pos):
			pause_selection = i
			activate_pause_selection()
			return

func advance_ending() -> void:
	if ending_index < ending_lines.size() - 1:
		ending_index += 1
	else:
		ui_mode = "title"
		menu_selection = 0

func _draw() -> void:
	match ui_mode:
		"title": draw_title()
		"settings": draw_settings()
		"ending": draw_ending()
		"play":
			draw_game()
			if paused: draw_pause()

func draw_title() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("07080c"))
	var font := ThemeDB.fallback_font
	var pulse := 4.0 + sin(elapsed * 1.3) * 3.0
	draw_circle(Vector2(320, 105), 45.0 + pulse, Color("382515"))
	draw_circle(Vector2(320, 105), 27.0, Color("d28a3e"))
	draw_circle(Vector2(320, 105), 14.0, Color("ffe1a0"))
	draw_arc(Vector2(320, 105), 62.0, elapsed * 0.12, elapsed * 0.12 + PI * 1.5, 48, Color("77644b"), 2.0)
	draw_string(font, Vector2(0, 40), "DYING SUN", HORIZONTAL_ALIGNMENT_CENTER, 640, 30, Color("f0e8d8"))
	draw_string(font, Vector2(0, 62), "a machine-city remembers what it burned", HORIZONTAL_ALIGNMENT_CENTER, 640, 12, Color("9c968c"))
	var options := title_options()
	menu_selection = clampi(menu_selection, 0, maxi(0, options.size() - 1))
	for i in range(options.size()):
		var rect := Rect2(205, 178 + i * 36, 230, 28)
		var selected := i == menu_selection
		draw_rect(rect, Color("2b241b") if selected else Color("11151e"), true)
		draw_rect(rect, Color("d8a44f") if selected else Color("3a4352"), false, 2.0)
		draw_string(font, rect.position + Vector2(0, 19), options[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, Color("f4e5c7") if selected else Color("aeb5bf"))
	draw_string(font, Vector2(0, 343), "keyboard // controller // touch", HORIZONTAL_ALIGNMENT_CENTER, 640, 10, Color("626b78"))

func draw_settings() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("080a0f"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 48), "SETTINGS", HORIZONTAL_ALIGNMENT_CENTER, 640, 24, Color("f0e8d8"))
	var entries := settings_entries()
	var values := [
		"%d%%" % int(SettingsManager.master_volume * 100.0),
		"%d%%" % int(SettingsManager.music_volume * 100.0),
		"%d%%" % int(SettingsManager.sfx_volume * 100.0),
		"ON" if SettingsManager.screen_shake else "OFF",
		"ON" if SettingsManager.high_contrast else "OFF",
		"ON" if SettingsManager.fullscreen else "OFF",
		"",
	]
	for i in range(entries.size()):
		var rect := Rect2(150, 102 + i * 32, 340, 25)
		var selected := i == settings_selection
		draw_rect(rect, Color("242019") if selected else Color("10141c"), true)
		draw_rect(rect, Color("d8a44f") if selected else Color("343c49"), false, 1.0)
		draw_string(font, rect.position + Vector2(12, 17), entries[i], HORIZONTAL_ALIGNMENT_LEFT, 190, 11, Color("eee5d5"))
		draw_string(font, rect.position + Vector2(205, 17), values[i], HORIZONTAL_ALIGNMENT_RIGHT, 120, 11, Color("91c2cc"))
	draw_string(font, Vector2(0, 338), "ARROWS / A-D adjust   ESC back", HORIZONTAL_ALIGNMENT_CENTER, 640, 10, Color("6d7480"))

func draw_pause() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.02, 0.03, 0.78), true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 105), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, 640, 24, Color("f0e8d8"))
	var options := pause_options()
	for i in range(options.size()):
		var rect := Rect2(205, 155 + i * 38, 230, 30)
		var selected := i == pause_selection
		draw_rect(rect, Color("2b241b") if selected else Color("11151e"), true)
		draw_rect(rect, Color("d8a44f") if selected else Color("3a4352"), false, 2.0)
		draw_string(font, rect.position + Vector2(0, 20), options[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, Color("f4e5c7"))

func draw_ending() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("06070a"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 46), Campaign.ending_title(ending_id), HORIZONTAL_ALIGNMENT_CENTER, 640, 21, Color("efcf87"))
	var line := ""
	if not ending_lines.is_empty(): line = ending_lines[ending_index]
	draw_multiline_string(font, Vector2(92, 132), line, HORIZONTAL_ALIGNMENT_CENTER, 456, 16, 24, Color("eee8dc"))
	draw_string(font, Vector2(0, 322), "CONTINUE", HORIZONTAL_ALIGNMENT_CENTER, 640, 11, Color("8f98a6"))
	draw_string(font, Vector2(0, 344), "Ending %d / %d" % [ending_index + 1, ending_lines.size()], HORIZONTAL_ALIGNMENT_CENTER, 640, 9, Color("606875"))

func draw_game() -> void:
	var palette := Campaign.act_palette(current_act)
	draw_rect(Rect2(0, 0, 640, 360), Color(str(palette["bg"])))
	draw_rect(ARENA, Color(str(palette["floor"])), true)
	draw_rect(ARENA, Color(str(palette["edge"])), false, 2.0)
	for x in range(48, 620, 48):
		draw_line(Vector2(x, 32), Vector2(x - 56, 328), Color(Color(str(palette["edge"])), 0.25), 1.0)
	draw_environment_motif(palette)
	for projectile in projectiles: draw_projectile(projectile, palette)
	for enemy in enemies: draw_enemy(enemy, palette)
	draw_player(palette)
	draw_hud(palette)
	if touch_mode and not dialogue_open and not module_pending and not dead:
		draw_touch_controls(palette)
	if act_banner_time > 0.0:
		draw_act_banner(palette)

func draw_environment_motif(palette: Dictionary) -> void:
	var accent := Color(str(palette["accent"]))
	var pulse := 3.0 + sin(elapsed * 2.1) * 2.0
	var sun_scale := 1.0 + float(current_act - 1) * 0.08
	draw_circle(SUN_POS, (45.0 + pulse) * sun_scale, Color(accent.r * 0.25, accent.g * 0.20, accent.b * 0.13, 0.7))
	draw_circle(SUN_POS, 27.0 + pulse * 0.4, accent)
	draw_circle(SUN_POS, 15.0, Color("fff0bd"))
	draw_arc(SUN_POS, 61.0 + current_act * 3.0, elapsed * 0.15, elapsed * 0.15 + PI * 1.35, 42, accent, 2.0)
	if current_act == 2:
		for y in [95.0, 145.0, 195.0, 245.0]: draw_line(Vector2(70, y), Vector2(210, y), Color(accent.r, accent.g, accent.b, 0.25), 2.0)
	elif current_act == 3:
		for p in [Vector2(120, 90), Vector2(180, 250), Vector2(500, 275)]: draw_arc(p, 18, elapsed, elapsed + PI * 1.5, 16, Color(accent.r, accent.g, accent.b, 0.35), 2.0)
	elif current_act == 4:
		draw_arc(Vector2(320, 180), 125, 0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.16), 3.0)
	elif current_act == 5:
		for j in range(8):
			var angle := elapsed * 0.08 + TAU * float(j) / 8.0
			draw_line(SUN_POS, SUN_POS + Vector2.RIGHT.rotated(angle) * 88.0, Color(accent.r, accent.g, accent.b, 0.15), 1.0)

func draw_projectile(projectile: Dictionary, palette: Dictionary) -> void:
	var pos: Vector2 = projectile["pos"]
	var accent := Color(str(palette["accent"]))
	draw_circle(pos, 5.0, accent)
	draw_circle(pos, 9.0, Color(accent.r, accent.g, accent.b, 0.18))

func draw_enemy(enemy: Dictionary, palette: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var kind := str(enemy["kind"])
	var hazard := Color(str(palette["hazard"]))
	var accent := Color(str(palette["accent"]))
	var body := Color("f4eee2") if float(enemy["flash"]) > 0.0 else hazard
	var radius := 12.0
	if kind in ["HUSK", "ARCHIVIST", "RELAY-DRONE"]: radius = 15.0
	if kind in ["SUN-HUSK", "CROWN-GUARD", "ECHO-WARDEN"]: radius = 17.0
	if is_boss_kind(kind): radius = 25.0
	if str(enemy["state"]) == "telegraph" or str(enemy["state"]) == "charge_telegraph":
		draw_arc(pos, radius + 10.0, 0.0, TAU, 32, accent, 3.0)
		if kind == "SUN-HUSK":
			var dir := (player_pos - pos).normalized()
			draw_line(pos, pos + dir * 90.0, Color(accent.r, accent.g, accent.b, 0.55), 3.0)
	draw_circle(pos, radius, body)
	if kind in ["ARCHIVIST", "THE-ARCHIVIST"]:
		draw_arc(pos, radius + 5, elapsed, elapsed + PI * 1.55, 18, accent, 2.0)
	elif kind in ["RELAY-DRONE", "RELAY-SAINT"]:
		draw_line(pos + Vector2(-radius, 0), pos + Vector2(radius, 0), accent, 2.0)
		draw_line(pos + Vector2(0, -radius), pos + Vector2(0, radius), accent, 2.0)
	elif kind in ["CROWN-GUARD", "CROWN-CUSTODIAN"]:
		draw_arc(pos, radius + 6, 0, PI, 18, accent, 3.0)
	draw_circle(pos, 4.0 if not is_boss_kind(kind) else 7.0, Color("07080b"))
	var width := 34.0 if not is_boss_kind(kind) else 70.0
	var hp_ratio := float(enemy["hp"]) / float(enemy["max_hp"])
	draw_rect(Rect2(pos + Vector2(-width * 0.5, -radius - 12), Vector2(width, 4)), Color("2b1a1b"), true)
	draw_rect(Rect2(pos + Vector2(-width * 0.5, -radius - 12), Vector2(width * hp_ratio, 4)), accent, true)
	var stagger_ratio := float(enemy["stagger"]) / float(enemy["stagger_max"])
	draw_rect(Rect2(pos + Vector2(-width * 0.5, -radius - 7), Vector2(width * stagger_ratio, 2)), Color("93d0d7"), true)
	if float(enemy["stunned"]) > 0.0:
		draw_arc(pos, radius + 6.0, elapsed * 2.0, elapsed * 2.0 + PI * 1.6, 18, Color("9de0e7"), 2.0)

func draw_player(palette: Dictionary) -> void:
	var flicker := hurt_cooldown > 0.0 and int(elapsed * 20.0) % 2 == 0
	var armor := Color("f1eadb") if not flicker else Color("8f4b45")
	if SettingsManager.high_contrast: armor = Color.WHITE if not flicker else Color.RED
	var accent := Color(str(palette["accent"]))
	var forward := last_move.normalized()
	var right := Vector2(-forward.y, forward.x)
	var nose := player_pos + forward * 15.0
	var back := player_pos - forward * 11.0
	var poly := PackedVector2Array([nose, back + right * 10.0, player_pos - forward * 4.0, back - right * 10.0])
	draw_colored_polygon(poly, armor)
	draw_circle(player_pos + forward * 4.0, 4.0, accent)
	if dash_time > 0.0: draw_line(back, back - forward * 22.0, accent, 5.0)
	if deflect_time > 0.0: draw_arc(player_pos, 21.0, -PI, PI, 32, Color("8fd3dc"), 3.0)
	if attack_time > 0.0:
		var center := player_pos + forward * 17.0
		var angle := forward.angle()
		draw_arc(center, 34.0 + float(combo_step) * 3.0, angle - 0.9, angle + 0.9, 18, Color("ffe6a3"), 3.0 + float(combo_step))

func draw_hud(palette: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var accent := Color(str(palette["accent"]))
	draw_string(font, Vector2(34, 20), "ACT %d // %s" % [current_act, Campaign.act_title(current_act)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dedfe3"))
	for i in range(max_hp()):
		var c := accent if i < player_hp else Color("313846")
		draw_rect(Rect2(Vector2(34 + i * 18, 34), Vector2(13, 6)), c, true)
	draw_rect(Rect2(34, 46, 110, 4), Color("28303d"), true)
	draw_rect(Rect2(34, 46, 110 * (player_charge / max_charge()), 4), Color("83bcc9"), true)
	var objective := objective_text()
	draw_string(font, Vector2(34, 65), objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent)
	if status_time > 0.0: draw_string(font, Vector2(230, 50), status_flash, HORIZONTAL_ALIGNMENT_CENTER, 230, 12, Color("f2d89e"))
	if not touch_mode:
		draw_string(font, Vector2(34, 350), "WASD move  SPACE strike  SHIFT boost  F parry  E advance  ESC pause", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("7d8795"))
	if dialogue_open and not dialogue_lines.is_empty(): draw_dialogue(accent)
	if module_pending: draw_module_choice(accent)
	if dead:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.02, 0.03, 0.76), true)
		draw_string(font, Vector2(0, 164), "FRAME EXTINGUISHED", HORIZONTAL_ALIGNMENT_CENTER, 640, 24, Color("d46d55"))
		draw_string(font, Vector2(0, 192), "R / TAP // REKINDLE FROM CHECKPOINT", HORIZONTAL_ALIGNMENT_CENTER, 640, 12, Color("d7d9df"))

func objective_text() -> String:
	match stage:
		"wave_a": return "BREACH THE SECTOR"
		"choice": return "SOL // DECISION PENDING"
		"wave_b": return "SURVIVE THE CONSEQUENCE"
		"boss": return "BREAK // " + boss_name
		"act_complete": return "SECTOR CLEARED"
		"module": return "FRAME RECONFIGURATION"
	return "KEEP MOVING"

func draw_dialogue(accent: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(46, 214, 548, 116), Color(0.035, 0.045, 0.075, 0.96), true)
	draw_rect(Rect2(46, 214, 548, 116), accent, false, 2.0)
	draw_multiline_string(font, Vector2(62, 239), dialogue_lines[dialogue_index], HORIZONTAL_ALIGNMENT_LEFT, 515, 13, 18, Color("eee9df"))
	if choice_pending:
		var labels := Campaign.choice_labels(current_act)
		draw_rect(Rect2(58, 276, 250, 40), Color(0.20, 0.19, 0.13, 0.86), true)
		draw_rect(Rect2(332, 276, 250, 40), Color(0.18, 0.12, 0.16, 0.86), true)
		draw_string(font, Vector2(68, 300), "1 // " + labels[0], HORIZONTAL_ALIGNMENT_LEFT, 230, 9, Color("f5d68b"))
		draw_string(font, Vector2(342, 300), "2 // " + labels[1], HORIZONTAL_ALIGNMENT_LEFT, 230, 9, Color("edc3c6"))
	else:
		draw_string(font, Vector2(470, 314), "E / TAP // CONTINUE", HORIZONTAL_ALIGNMENT_RIGHT, 105, 9, Color("8993a5"))

func draw_module_choice(accent: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.025, 0.035, 0.90), true)
	draw_string(font, Vector2(0, 72), "FRAME RECONFIGURATION", HORIZONTAL_ALIGNMENT_CENTER, 640, 19, Color("eee5d5"))
	for i in range(module_choices.size()):
		var rect := Rect2(48 + i * 278, 120, 266, 120)
		var choice: Dictionary = module_choices[i]
		draw_rect(rect, Color("111923"), true)
		draw_rect(rect, accent, false, 2.0)
		draw_string(font, rect.position + Vector2(12, 26), "%d // %s" % [i + 1, str(choice.get("name", "MODULE"))], HORIZONTAL_ALIGNMENT_LEFT, 240, 13, Color("f3dfb8"))
		draw_multiline_string(font, rect.position + Vector2(12, 55), str(choice.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, 240, 11, 17, Color("bac0c8"))
	draw_string(font, Vector2(0, 280), "Choose a combat tool. This does not decide what kind of person you are.", HORIZONTAL_ALIGNMENT_CENTER, 640, 10, Color("838b98"))

func draw_touch_controls(palette: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var accent := Color(str(palette["accent"]))
	var stick_center := touch_origin if touch_move_id >= 0 else TOUCH_STICK_CENTER
	var knob := stick_center + touch_move * TOUCH_STICK_RADIUS if touch_move_id >= 0 else stick_center
	draw_circle(stick_center, TOUCH_STICK_RADIUS, Color(0.11, 0.14, 0.20, 0.50), true)
	draw_arc(stick_center, TOUCH_STICK_RADIUS, 0.0, TAU, 32, Color(0.48, 0.52, 0.61, 0.78), 2.0)
	draw_circle(knob, 18.0, Color(accent.r, accent.g, accent.b, 0.72), true)
	draw_circle(TOUCH_ATTACK_CENTER, TOUCH_BUTTON_RADIUS, Color(0.36, 0.12, 0.14, 0.68), true)
	draw_arc(TOUCH_ATTACK_CENTER, TOUCH_BUTTON_RADIUS, 0.0, TAU, 32, accent, 2.0)
	draw_string(font, TOUCH_ATTACK_CENTER + Vector2(-24, 5), "STRIKE", HORIZONTAL_ALIGNMENT_CENTER, 48, 10, Color("fff0cf"))
	draw_circle(TOUCH_BOOST_CENTER, TOUCH_BUTTON_RADIUS - 4.0, Color(0.15, 0.20, 0.30, 0.72), true)
	draw_string(font, TOUCH_BOOST_CENTER + Vector2(-22, 5), "BOOST", HORIZONTAL_ALIGNMENT_CENTER, 44, 9, Color("d8e6f5"))
	draw_circle(TOUCH_UTILITY_CENTER, TOUCH_BUTTON_RADIUS - 6.0, Color(0.10, 0.24, 0.28, 0.72), true)
	draw_string(font, TOUCH_UTILITY_CENTER + Vector2(-22, 5), "PARRY", HORIZONTAL_ALIGNMENT_CENTER, 44, 9, Color("d7f0f2"))

func draw_act_banner(palette: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var accent := Color(str(palette["accent"]))
	var alpha := clampf(act_banner_time / 0.6, 0.0, 1.0)
	draw_rect(Rect2(0, 118, 640, 92), Color(0.02, 0.02, 0.03, 0.78 * alpha), true)
	draw_string(font, Vector2(0, 151), "ACT %d" % current_act, HORIZONTAL_ALIGNMENT_CENTER, 640, 12, Color(accent.r, accent.g, accent.b, alpha))
	draw_string(font, Vector2(0, 184), Campaign.act_title(current_act), HORIZONTAL_ALIGNMENT_CENTER, 640, 24, Color(0.95, 0.92, 0.86, alpha))
