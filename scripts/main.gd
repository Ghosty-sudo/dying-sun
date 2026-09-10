extends Node2D

const ARENA := Rect2(24.0, 24.0, 592.0, 312.0)
const SUN_POS := Vector2(510.0, 145.0)
const CONSOLE_POS := Vector2(475.0, 282.0)
const PLAYER_SPEED := 122.0
const DASH_SPEED := 345.0
const MAX_CHARGE := 100.0
const BOOST_COST := 30.0
const CHARGE_REGEN := 23.0
const TOUCH_STICK_CENTER := Vector2(92.0, 287.0)
const TOUCH_STICK_RADIUS := 48.0
const TOUCH_ATTACK_CENTER := Vector2(562.0, 282.0)
const TOUCH_BOOST_CENTER := Vector2(500.0, 312.0)
const TOUCH_UTILITY_CENTER := Vector2(438.0, 312.0)
const TOUCH_BUTTON_RADIUS := 32.0

var player_pos := Vector2(92.0, 182.0)
var player_hp := 6
var player_charge := MAX_CHARGE
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

var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var phase := 0
var dead := false
var complete := false
var boss_announced := false

var dialogue_open := false
var choice_pending := false
var dialogue_lines: Array[String] = []
var dialogue_index := 0
var remembered_choice := ""
var status_flash := ""
var status_time := 0.0

var touch_move_id := -1
var touch_origin := Vector2.ZERO
var touch_current := Vector2.ZERO
var touch_move := Vector2.ZERO
var touch_mode := false

func _ready() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web")
	SaveManager.load_campaign()
	restore_encounter_state()
	queue_redraw()

func restore_encounter_state() -> void:
	reset_combat_runtime()
	if GameState.has_flag("first_contact_trust"):
		remembered_choice = "TRUST"
		phase = 1
		player_pos = Vector2(420.0, 270.0)
		spawn_after_choice_wave()
		flash_status("CHECKPOINT // TRUST REMEMBERED")
	elif GameState.has_flag("first_contact_defiance"):
		remembered_choice = "DEFIANCE"
		phase = 1
		player_pos = Vector2(420.0, 270.0)
		spawn_after_choice_wave()
		flash_status("CHECKPOINT // DEFIANCE REMEMBERED")
	else:
		spawn_opening_wave()

func reset_combat_runtime() -> void:
	player_pos = Vector2(92.0, 182.0)
	player_hp = 6
	player_charge = MAX_CHARGE
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
	dead = false
	complete = false
	boss_announced = false
	dialogue_open = false
	choice_pending = false
	dialogue_lines.clear()
	dialogue_index = 0
	touch_move_id = -1
	touch_move = Vector2.ZERO
	enemies.clear()
	projectiles.clear()

func spawn_opening_wave() -> void:
	enemies = [
		make_enemy(Vector2(285.0, 100.0), 3, "WARDEN"),
		make_enemy(Vector2(335.0, 245.0), 3, "WARDEN"),
		make_enemy(Vector2(430.0, 175.0), 4, "HUSK")
	]
	phase = 0

func spawn_after_choice_wave() -> void:
	enemies = [
		make_enemy(Vector2(370.0, 90.0), 3, "WARDEN"),
		make_enemy(Vector2(405.0, 275.0), 4, "HUSK"),
		make_enemy(Vector2(545.0, 245.0), 6, "SUN-HUSK")
	]
	phase = 1

func spawn_gate_custodian() -> void:
	enemies = [make_enemy(Vector2(505.0, 160.0), 18, "CUSTODIAN")]
	phase = 2
	boss_announced = true
	flash_status("GATE CUSTODIAN // ONLINE")

func make_enemy(pos: Vector2, hp: int, kind: String) -> Dictionary:
	var stagger_max := 3.0
	if kind == "SUN-HUSK":
		stagger_max = 5.0
	elif kind == "CUSTODIAN":
		stagger_max = 8.0
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
	}

func _process(delta: float) -> void:
	elapsed += delta
	dash_time = maxf(0.0, dash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	attack_time = maxf(0.0, attack_time - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	deflect_time = maxf(0.0, deflect_time - delta)
	deflect_cooldown = maxf(0.0, deflect_cooldown - delta)
	combo_window = maxf(0.0, combo_window - delta)
	status_time = maxf(0.0, status_time - delta)

	if combo_window <= 0.0:
		combo_step = 0
	if dash_time <= 0.0:
		player_charge = minf(MAX_CHARGE, player_charge + CHARGE_REGEN * delta)

	if dead or complete:
		queue_redraw()
		return

	if not dialogue_open:
		update_player(delta)
		update_enemies(delta)
		update_projectiles(delta)

	if phase == 1 and enemies.is_empty() and not dialogue_open:
		spawn_gate_custodian()
	elif phase == 2 and enemies.is_empty() and boss_announced:
		finish_act_one()

	queue_redraw()

func update_player(delta: float) -> void:
	var move := touch_move
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0

	if move.length_squared() > 0.0:
		move = move.normalized()
		last_move = move

	var speed := DASH_SPEED if dash_time > 0.0 else PLAYER_SPEED
	player_pos += move * speed * delta
	player_pos.x = clampf(player_pos.x, ARENA.position.x + 12.0, ARENA.end.x - 12.0)
	player_pos.y = clampf(player_pos.y, ARENA.position.y + 12.0, ARENA.end.y - 12.0)

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

		match str(enemy["kind"]):
			"WARDEN":
				update_warden(enemy, delta)
			"HUSK":
				update_husk(enemy, delta)
			"SUN-HUSK":
				update_sun_husk(enemy, delta)
			"CUSTODIAN":
				update_custodian(enemy, delta)
		enemies[i] = enemy

func update_warden(enemy: Dictionary, delta: float) -> void:
	var pos: Vector2 = enemy["pos"]
	var toward := player_pos - pos
	var distance := toward.length()
	if str(enemy["state"]) == "telegraph":
		if float(enemy["telegraph"]) <= 0.0:
			enemy["state"] = "idle"
			enemy["attack_cd"] = 0.95
			if distance < 72.0:
				pos += toward.normalized() * minf(38.0, distance)
				enemy["pos"] = pos
				attempt_enemy_hit(pos, 31.0, 1, 2.2)
		return
	if distance > 42.0:
		pos += toward.normalized() * 45.0 * delta
		enemy["pos"] = pos
	elif float(enemy["attack_cd"]) <= 0.0:
		enemy["state"] = "telegraph"
		enemy["telegraph"] = 0.34

func update_husk(enemy: Dictionary, delta: float) -> void:
	var pos: Vector2 = enemy["pos"]
	var toward := player_pos - pos
	var distance := toward.length()
	if distance < 105.0:
		pos -= toward.normalized() * 34.0 * delta
	elif distance > 185.0:
		pos += toward.normalized() * 28.0 * delta
	enemy["pos"] = clamp_to_arena(pos, 14.0)
	if float(enemy["attack_cd"]) <= 0.0 and distance < 235.0:
		spawn_projectile(pos, toward.normalized(), 105.0, 1, "MEMORY BOLT")
		enemy["attack_cd"] = 1.35
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
			attempt_enemy_hit(pos, 30.0, 2, 3.0)
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
	if float(enemy["attack_cd"]) <= 0.0 and toward.length() < 220.0:
		enemy["state"] = "charge_telegraph"
		enemy["telegraph"] = 0.58

func update_custodian(enemy: Dictionary, delta: float) -> void:
	var pos: Vector2 = enemy["pos"]
	var toward := player_pos - pos
	var distance := toward.length()
	var state := str(enemy["state"])
	var enraged := int(enemy["hp"]) <= int(enemy["max_hp"]) / 2

	if state == "telegraph":
		if float(enemy["telegraph"]) <= 0.0:
			enemy["state"] = "idle"
			enemy["pattern"] = int(enemy["pattern"]) + 1
			if int(enemy["pattern"]) % 2 == 0:
				fire_custodian_arc(pos, 7 if enraged else 5)
			else:
				pos += toward.normalized() * minf(58.0, distance)
				enemy["pos"] = clamp_to_arena(pos, 20.0)
				attempt_enemy_hit(pos, 40.0, 2 if enraged else 1, 3.8)
			enemy["attack_cd"] = 0.62 if enraged else 0.90
		return

	if distance > 82.0:
		pos += toward.normalized() * (47.0 if enraged else 39.0) * delta
		enemy["pos"] = pos
	elif distance < 58.0:
		pos -= toward.normalized() * 20.0 * delta
		enemy["pos"] = pos

	if float(enemy["attack_cd"]) <= 0.0:
		enemy["state"] = "telegraph"
		enemy["telegraph"] = 0.40 if enraged else 0.55

func fire_custodian_arc(origin: Vector2, count: int) -> void:
	var base_angle := (player_pos - origin).angle()
	var spread := 1.30
	for j in range(count):
		var t := 0.5 if count == 1 else float(j) / float(count - 1)
		var angle := base_angle + lerpf(-spread * 0.5, spread * 0.5, t)
		spawn_projectile(origin, Vector2.RIGHT.rotated(angle), 125.0, 1, "SOLAR ARC")

func spawn_projectile(origin: Vector2, direction: Vector2, speed: float, damage: int, kind: String) -> void:
	projectiles.append({
		"pos": origin,
		"velocity": direction.normalized() * speed,
		"damage": damage,
		"life": 2.8,
		"kind": kind,
	})

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
				player_charge = minf(MAX_CHARGE, player_charge + 14.0)
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
		player_charge = minf(MAX_CHARGE, player_charge + 18.0)
		stagger_nearby_enemy(origin, stagger_return)
		flash_status("PERFECT DEFLECT")
		return
	hurt_player(damage)

func hurt_player(damage: int) -> void:
	if hurt_cooldown > 0.0:
		return
	player_hp -= damage
	hurt_cooldown = 0.72
	combo_step = 0
	combo_window = 0.0
	flash_status("ARMOR BREACH")
	if player_hp <= 0:
		player_hp = 0
		dead = true
		GameState.register_death()
		SaveManager.save_campaign()

func stagger_nearby_enemy(origin: Vector2, amount: float) -> void:
	for i in range(enemies.size()):
		var enemy := enemies[i]
		if Vector2(enemy["pos"]).distance_to(origin) < 48.0:
			apply_stagger(enemy, amount)
			enemies[i] = enemy
			return

func perform_attack() -> void:
	if attack_cooldown > 0.0 or dialogue_open or dead or complete:
		return
	combo_step = combo_step + 1 if combo_window > 0.0 else 1
	if combo_step > 3:
		combo_step = 1
	combo_window = 0.48
	attack_time = 0.15 if combo_step < 3 else 0.22
	attack_cooldown = 0.24 if combo_step < 3 else 0.38
	var attack_range := 52.0 + float(combo_step - 1) * 6.0
	var damage := 1 if combo_step < 3 else 2
	var stagger_damage := 1.0 if combo_step == 1 else (1.3 if combo_step == 2 else 2.4)
	var hit_any := false
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		var to_enemy := Vector2(enemy["pos"]) - player_pos
		if to_enemy.length() <= attack_range:
			var facing_score := last_move.normalized().dot(to_enemy.normalized())
			if facing_score > -0.10:
				enemy["hp"] = int(enemy["hp"]) - damage
				enemy["flash"] = 0.12
				apply_stagger(enemy, stagger_damage)
				hit_any = true
				if int(enemy["hp"]) <= 0:
					enemies.remove_at(i)
				else:
					enemies[i] = enemy
	if hit_any:
		flash_status("CHAIN %d // IMPACT" % combo_step)

func apply_stagger(enemy: Dictionary, amount: float) -> void:
	enemy["stagger"] = float(enemy["stagger"]) + amount
	if float(enemy["stagger"]) >= float(enemy["stagger_max"]):
		enemy["stagger"] = 0.0
		enemy["stunned"] = 0.95 if str(enemy["kind"]) != "CUSTODIAN" else 1.25
		enemy["state"] = "idle"
		enemy["telegraph"] = 0.0
		flash_status("SYSTEM BREAK")

func perform_boost() -> void:
	if dash_cooldown > 0.0 or dialogue_open or dead or complete:
		return
	if player_charge < BOOST_COST:
		flash_status("CHARGE LOW")
		return
	player_charge -= BOOST_COST
	dash_time = 0.16
	dash_cooldown = 0.24
	flash_status("BOOST")

func perform_deflect() -> void:
	if deflect_cooldown > 0.0 or dialogue_open or dead or complete:
		return
	deflect_time = 0.17
	deflect_cooldown = 0.52
	flash_status("DEFLECT WINDOW")

func can_link_terminal() -> bool:
	return phase == 0 and enemies.is_empty() and player_pos.distance_to(CONSOLE_POS) < 60.0

func try_interact() -> void:
	if dead:
		restart_from_checkpoint()
		return
	if dialogue_open:
		if choice_pending:
			return
		if dialogue_index < dialogue_lines.size() - 1:
			dialogue_index += 1
		else:
			if phase == 0:
				choice_pending = true
			elif complete:
				dialogue_open = false
			else:
				dialogue_open = false
		return

	if can_link_terminal():
		dialogue_open = true
		dialogue_index = 0
		dialogue_lines = [
			"SOL: You took long enough. The city noticed you before I did.",
			"SOL: I am bound to the artificial sun above us. You are currently harder to classify.",
			"SOL: Before I open the inner gate, decide what kind of problem you intend to be."
		]

func choose_path(choice: int) -> void:
	if not choice_pending or phase != 0:
		return
	choice_pending = false
	dialogue_index = 0
	if choice == 1:
		remembered_choice = "TRUST"
		GameState.record_relationship("trust", 1)
		GameState.record_relationship("curiosity", 1)
		GameState.set_flag("first_contact_trust")
		GameState.set_flag("first_contact_defiance", false)
		dialogue_lines = [
			"YOU: Then trust me enough to tell me the truth.",
			"SOL: Dangerous opening move. I like it.",
			"SOL: The sun is dying because the city is feeding it memories. Mine included."
		]
	else:
		remembered_choice = "DEFIANCE"
		GameState.record_relationship("defiance", 1)
		GameState.set_flag("first_contact_defiance")
		GameState.set_flag("first_contact_trust", false)
		dialogue_lines = [
			"YOU: I do not take orders from voices trapped in stars.",
			"SOL: Good. Obedience would have made you considerably less useful.",
			"SOL: Keep distrusting me. Just try to survive long enough to be right."
		]
	GameState.set_checkpoint("ash_intake_inner_gate", 1)
	SaveManager.save_campaign()
	spawn_after_choice_wave()

func finish_act_one() -> void:
	complete = true
	dialogue_open = true
	choice_pending = false
	GameState.set_flag("ash_intake_cleared")
	GameState.set_checkpoint("memory_works_entry", 2)
	SaveManager.save_campaign()
	dialogue_lines = [
		"SOL: The Gate Custodian is dead. The city will pretend that was impossible.",
		final_sol_line(),
		"SOL: Beyond this gate are the Memory Works. If you still want answers, that's where the city keeps the ones it couldn't afford to forget.",
		"INTERNAL ACT I SLICE COMPLETE"
	]
	dialogue_index = 0

func final_sol_line() -> String:
	if remembered_choice == "TRUST":
		return "SOL: You asked for truth first. I haven't forgotten. That may become inconvenient for both of us."
	return "SOL: You began by distrusting me. Keep that instinct. Just learn when it deserves updating."

func restart_from_checkpoint() -> void:
	restore_encounter_state()
	flash_status("FRAME REKINDLED")

func flash_status(text: String) -> void:
	status_flash = text
	status_time = 0.85

func clamp_to_arena(pos: Vector2, margin: float) -> Vector2:
	return Vector2(
		clampf(pos.x, ARENA.position.x + margin, ARENA.end.x - margin),
		clampf(pos.y, ARENA.position.y + margin, ARENA.end.y - margin)
	)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		handle_drag(event as InputEventScreenDrag)

func handle_touch(event: InputEventScreenTouch) -> void:
	var pos := event.position
	if not event.pressed:
		if event.index == touch_move_id:
			touch_move_id = -1
			touch_move = Vector2.ZERO
		return

	if dead:
		restart_from_checkpoint()
		return

	if dialogue_open:
		if choice_pending:
			choose_path(1 if pos.x < 320.0 else 2)
		else:
			try_interact()
		return

	if pos.distance_to(TOUCH_ATTACK_CENTER) <= TOUCH_BUTTON_RADIUS + 12.0:
		perform_attack()
		return
	if pos.distance_to(TOUCH_BOOST_CENTER) <= TOUCH_BUTTON_RADIUS + 12.0:
		perform_boost()
		return
	if pos.distance_to(TOUCH_UTILITY_CENTER) <= TOUCH_BUTTON_RADIUS + 12.0:
		if can_link_terminal():
			try_interact()
		else:
			perform_deflect()
		return

	if pos.x < 260.0:
		touch_move_id = event.index
		touch_origin = pos
		touch_current = pos
		touch_move = Vector2.ZERO
		return

	if can_link_terminal():
		try_interact()

func handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != touch_move_id:
		return
	touch_current = event.position
	var delta := touch_current - touch_origin
	if delta.length() > TOUCH_STICK_RADIUS:
		delta = delta.normalized() * TOUCH_STICK_RADIUS
	touch_move = delta / TOUCH_STICK_RADIUS

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_SPACE:
			perform_attack()
		KEY_SHIFT:
			perform_boost()
		KEY_F:
			perform_deflect()
		KEY_E:
			try_interact()
		KEY_1:
			choose_path(1)
		KEY_2:
			choose_path(2)
		KEY_R:
			if dead:
				restart_from_checkpoint()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color("090b12"))
	draw_rect(ARENA, Color("121826"), true)
	draw_rect(ARENA, Color("3f495d"), false, 2.0)
	for x in range(48, 620, 48):
		draw_line(Vector2(x, 32), Vector2(x - 56, 328), Color(0.13, 0.16, 0.23, 0.35), 1.0)

	var pulse := 3.0 + sin(elapsed * 2.1) * 2.0
	draw_circle(SUN_POS, 48.0 + pulse, Color("3d2717"))
	draw_circle(SUN_POS, 35.0 + pulse * 0.45, Color("b96b2c"))
	draw_circle(SUN_POS, 23.0, Color("ffd37a"))
	draw_arc(SUN_POS, 63.0, 0.0, TAU, 64, Color("6f778d"), 2.0)
	draw_arc(SUN_POS, 75.0, elapsed * 0.15, elapsed * 0.15 + PI * 1.35, 42, Color("d28a3e"), 2.0)
	draw_line(Vector2(510, 210), Vector2(475, 272), Color("6b7485"), 3.0)

	var terminal_color := Color("d99b42") if can_link_terminal() else Color("566072")
	draw_rect(Rect2(CONSOLE_POS - Vector2(12, 9), Vector2(24, 18)), Color("171e2b"), true)
	draw_rect(Rect2(CONSOLE_POS - Vector2(12, 9), Vector2(24, 18)), terminal_color, false, 2.0)

	for projectile in projectiles:
		draw_projectile(projectile)
	for enemy in enemies:
		draw_enemy(enemy)
	draw_player()
	draw_hud()
	if touch_mode and not dialogue_open and not dead and not complete:
		draw_touch_controls()

func draw_projectile(projectile: Dictionary) -> void:
	var pos: Vector2 = projectile["pos"]
	var color := Color("d9a85a") if str(projectile["kind"]) == "MEMORY BOLT" else Color("f0c765")
	draw_circle(pos, 5.0, color)
	draw_circle(pos, 9.0, Color(color.r, color.g, color.b, 0.18))

func draw_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var kind := str(enemy["kind"])
	var body := Color("e1e5e9") if float(enemy["flash"]) > 0.0 else Color("812f39")
	var radius := 12.0
	if kind == "HUSK":
		body = Color("9f493f") if float(enemy["flash"]) <= 0.0 else Color("fff2c2")
		radius = 15.0
	elif kind == "SUN-HUSK":
		body = Color("e07a32") if float(enemy["flash"]) <= 0.0 else Color("fff2c2")
		radius = 17.0
	elif kind == "CUSTODIAN":
		body = Color("b36a32") if float(enemy["flash"]) <= 0.0 else Color("fff2c2")
		radius = 24.0

	if str(enemy["state"]) == "telegraph" or str(enemy["state"]) == "charge_telegraph":
		draw_arc(pos, radius + 9.0, 0.0, TAU, 32, Color("f4c46a"), 3.0)
		if kind == "SUN-HUSK":
			var dir := (player_pos - pos).normalized()
			draw_line(pos, pos + dir * 88.0, Color(0.94, 0.55, 0.25, 0.55), 3.0)

	draw_circle(pos, radius, body)
	draw_circle(pos, 4.0 if kind != "CUSTODIAN" else 7.0, Color("080a0f"))
	var hp_ratio := float(enemy["hp"]) / float(enemy["max_hp"])
	var width := 34.0 if kind != "CUSTODIAN" else 64.0
	draw_rect(Rect2(pos + Vector2(-width * 0.5, -radius - 11), Vector2(width, 4)), Color("301a1d"), true)
	draw_rect(Rect2(pos + Vector2(-width * 0.5, -radius - 11), Vector2(width * hp_ratio, 4)), Color("e5a84c"), true)
	var stagger_ratio := float(enemy["stagger"]) / float(enemy["stagger_max"])
	draw_rect(Rect2(pos + Vector2(-width * 0.5, -radius - 6), Vector2(width * stagger_ratio, 2)), Color("8fc1cb"), true)
	if float(enemy["stunned"]) > 0.0:
		draw_arc(pos, radius + 5.0, elapsed * 2.0, elapsed * 2.0 + PI * 1.6, 18, Color("9de0e7"), 2.0)

func draw_player() -> void:
	var flicker := hurt_cooldown > 0.0 and int(elapsed * 20.0) % 2 == 0
	var armor := Color("f1eadb") if not flicker else Color("8f4b45")
	var forward := last_move.normalized()
	var right := Vector2(-forward.y, forward.x)
	var nose := player_pos + forward * 15.0
	var back := player_pos - forward * 11.0
	var poly := PackedVector2Array([
		nose,
		back + right * 10.0,
		player_pos - forward * 4.0,
		back - right * 10.0
	])
	draw_colored_polygon(poly, armor)
	draw_circle(player_pos + forward * 4.0, 4.0, Color("d89b45"))
	if dash_time > 0.0:
		draw_line(back, back - forward * 22.0, Color("efb553"), 5.0)
	if deflect_time > 0.0:
		draw_arc(player_pos, 21.0, -PI, PI, 32, Color("8fd3dc"), 3.0)
	if attack_time > 0.0:
		var attack_center := player_pos + forward * 17.0
		var angle := forward.angle()
		var radius := 34.0 + float(combo_step) * 3.0
		draw_arc(attack_center, radius, angle - 0.9, angle + 0.9, 18, Color("ffe6a3"), 3.0 + float(combo_step))

func draw_touch_controls() -> void:
	var font := ThemeDB.fallback_font
	var stick_center := touch_origin if touch_move_id >= 0 else TOUCH_STICK_CENTER
	var knob := stick_center
	if touch_move_id >= 0:
		knob += touch_move * TOUCH_STICK_RADIUS
	draw_circle(stick_center, TOUCH_STICK_RADIUS, Color(0.11, 0.14, 0.20, 0.50), true)
	draw_arc(stick_center, TOUCH_STICK_RADIUS, 0.0, TAU, 32, Color(0.48, 0.52, 0.61, 0.78), 2.0)
	draw_circle(knob, 18.0, Color(0.85, 0.65, 0.30, 0.72), true)

	draw_circle(TOUCH_ATTACK_CENTER, TOUCH_BUTTON_RADIUS, Color(0.36, 0.12, 0.14, 0.68), true)
	draw_arc(TOUCH_ATTACK_CENTER, TOUCH_BUTTON_RADIUS, 0.0, TAU, 32, Color("e7a44c"), 2.0)
	draw_string(font, TOUCH_ATTACK_CENTER + Vector2(-24, 5), "STRIKE", HORIZONTAL_ALIGNMENT_CENTER, 48, 10, Color("fff0cf"))

	var boost_color := Color(0.15, 0.20, 0.30, 0.72) if player_charge >= BOOST_COST else Color(0.10, 0.11, 0.14, 0.48)
	draw_circle(TOUCH_BOOST_CENTER, TOUCH_BUTTON_RADIUS - 4.0, boost_color, true)
	draw_arc(TOUCH_BOOST_CENTER, TOUCH_BUTTON_RADIUS - 4.0, 0.0, TAU, 32, Color("8ba4c7"), 2.0)
	draw_string(font, TOUCH_BOOST_CENTER + Vector2(-22, 5), "BOOST", HORIZONTAL_ALIGNMENT_CENTER, 44, 9, Color("d8e6f5"))

	var utility_label := "LINK" if can_link_terminal() else "PARRY"
	var utility_color := Color(0.43, 0.31, 0.11, 0.80) if can_link_terminal() else Color(0.10, 0.24, 0.28, 0.72)
	draw_circle(TOUCH_UTILITY_CENTER, TOUCH_BUTTON_RADIUS - 6.0, utility_color, true)
	draw_arc(TOUCH_UTILITY_CENTER, TOUCH_BUTTON_RADIUS - 6.0, 0.0, TAU, 32, Color("9fd3d8") if not can_link_terminal() else Color("f2c86b"), 2.0)
	draw_string(font, TOUCH_UTILITY_CENTER + Vector2(-20, 5), utility_label, HORIZONTAL_ALIGNMENT_CENTER, 40, 9, Color("fff0c5"))

func draw_hud() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(34, 20), "DYING SUN // INTERNAL COMBAT BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d7d9df"))
	if touch_mode:
		draw_string(font, Vector2(230, 350), "left stick // strike // boost // parry", HORIZONTAL_ALIGNMENT_CENTER, 382, 10, Color("8993a5"))
	else:
		draw_string(font, Vector2(34, 350), "WASD move   SHIFT boost   SPACE strike   F parry   E interact", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8993a5"))

	for i in range(6):
		var c := Color("e5a84c") if i < player_hp else Color("313846")
		draw_rect(Rect2(Vector2(34 + i * 18, 34), Vector2(13, 6)), c, true)

	draw_rect(Rect2(34, 46, 110, 4), Color("28303d"), true)
	draw_rect(Rect2(34, 46, 110 * (player_charge / MAX_CHARGE), 4), Color("83bcc9"), true)
	draw_string(font, Vector2(150, 51), "CHARGE %d" % int(player_charge), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("9ccbd3"))

	var objective := "PURGE THE INTAKE"
	if phase == 0 and enemies.is_empty():
		objective = "APPROACH TERMINAL // LINK"
	elif phase == 1:
		objective = "SURVIVE THE INNER GATE"
	elif phase == 2:
		objective = "BREAK THE GATE CUSTODIAN"
	if complete:
		objective = "ACT I // ASH INTAKE CLEARED"
	draw_string(font, Vector2(34, 65), objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d49b4c"))

	if status_time > 0.0:
		draw_string(font, Vector2(255, 50), status_flash, HORIZONTAL_ALIGNMENT_CENTER, 190, 13, Color("f2d89e"))

	if can_link_terminal() and not dialogue_open:
		draw_string(font, CONSOLE_POS + Vector2(-72, 32), "LINK // UNKNOWN SIGNAL", HORIZONTAL_ALIGNMENT_CENTER, 144, 11, Color("e5a84c"))

	if dialogue_open and not dialogue_lines.is_empty():
		draw_rect(Rect2(46, 218, 548, 112), Color(0.035, 0.045, 0.075, 0.96), true)
		draw_rect(Rect2(46, 218, 548, 112), Color("9b733b"), false, 2.0)
		draw_multiline_string(font, Vector2(62, 242), dialogue_lines[dialogue_index], HORIZONTAL_ALIGNMENT_LEFT, 515, 13, 18, Color("eee9df"))
		if choice_pending:
			draw_rect(Rect2(58, 276, 250, 38), Color(0.29, 0.22, 0.10, 0.70), true)
			draw_rect(Rect2(332, 276, 250, 38), Color(0.20, 0.12, 0.16, 0.72), true)
			draw_string(font, Vector2(72, 299), "TRUST // tell me the truth", HORIZONTAL_ALIGNMENT_LEFT, 220, 10, Color("f5d68b"))
			draw_string(font, Vector2(346, 299), "DEFIANCE // I don't trust you", HORIZONTAL_ALIGNMENT_LEFT, 220, 10, Color("edc3c6"))
		else:
			draw_string(font, Vector2(492, 314), "TAP/E // CONTINUE", HORIZONTAL_ALIGNMENT_RIGHT, 86, 10, Color("8993a5"))

	if dead:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.02, 0.03, 0.72), true)
		draw_string(font, Vector2(0, 164), "FRAME EXTINGUISHED", HORIZONTAL_ALIGNMENT_CENTER, 640, 24, Color("d46d55"))
		draw_string(font, Vector2(0, 192), "TAP / R // REKINDLE FROM CHECKPOINT", HORIZONTAL_ALIGNMENT_CENTER, 640, 13, Color("d7d9df"))
