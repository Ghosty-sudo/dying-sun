extends Node2D

const ARENA := Rect2(24.0, 24.0, 592.0, 312.0)
const SUN_POS := Vector2(510.0, 145.0)
const CONSOLE_POS := Vector2(475.0, 282.0)
const PLAYER_SPEED := 118.0
const DASH_SPEED := 330.0
const ATTACK_RANGE := 54.0

var player_pos := Vector2(92.0, 182.0)
var player_hp := 5
var last_move := Vector2.RIGHT
var dash_time := 0.0
var dash_cooldown := 0.0
var attack_time := 0.0
var attack_cooldown := 0.0
var hurt_cooldown := 0.0
var elapsed := 0.0

var enemies: Array[Dictionary] = []
var phase := 0
var dead := false
var complete := false

var dialogue_open := false
var choice_pending := false
var dialogue_lines: Array[String] = []
var dialogue_index := 0
var sol_trust := 0
var remembered_choice := ""
var status_flash := ""
var status_time := 0.0

func _ready() -> void:
	spawn_opening_wave()
	queue_redraw()

func spawn_opening_wave() -> void:
	enemies = [
		make_enemy(Vector2(285.0, 100.0), 2, "WARDEN"),
		make_enemy(Vector2(335.0, 245.0), 2, "WARDEN"),
		make_enemy(Vector2(405.0, 175.0), 3, "HUSK")
	]
	phase = 0

func spawn_after_choice_wave() -> void:
	enemies = [
		make_enemy(Vector2(390.0, 90.0), 2, "WARDEN"),
		make_enemy(Vector2(410.0, 275.0), 2, "WARDEN"),
		make_enemy(Vector2(550.0, 255.0), 4, "SUN-HUSK")
	]
	phase = 1

func make_enemy(pos: Vector2, hp: int, kind: String) -> Dictionary:
	return {
		"pos": pos,
		"hp": hp,
		"max_hp": hp,
		"kind": kind,
		"flash": 0.0,
		"attack_cd": 0.0
	}

func _process(delta: float) -> void:
	elapsed += delta
	dash_time = maxf(0.0, dash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	attack_time = maxf(0.0, attack_time - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	status_time = maxf(0.0, status_time - delta)

	if dead or complete:
		queue_redraw()
		return

	if not dialogue_open:
		update_player(delta)
		update_enemies(delta)

	if phase == 1 and enemies.is_empty():
		phase = 2
		complete = true
		dialogue_open = true
		choice_pending = false
		dialogue_lines = [
			"SOL: Good. You survived your first disagreement with the city.",
			final_sol_line(),
			"PROTOTYPE 0.1 COMPLETE — I remember what you chose."
		]
		dialogue_index = 0

	queue_redraw()

func update_player(delta: float) -> void:
	var move := Vector2.ZERO
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
		var enemy_pos: Vector2 = enemy["pos"]
		var toward := player_pos - enemy_pos
		var distance := toward.length()
		var enemy_speed := 44.0 if str(enemy["kind"]) == "WARDEN" else 33.0
		if str(enemy["kind"]) == "SUN-HUSK":
			enemy_speed = 52.0
		if distance > 27.0:
			enemy_pos += toward.normalized() * enemy_speed * delta
			enemy["pos"] = enemy_pos
		elif float(enemy["attack_cd"]) <= 0.0 and hurt_cooldown <= 0.0:
			player_hp -= 1
			hurt_cooldown = 0.75
			enemy["attack_cd"] = 1.1
			flash_status("ARMOR BREACH")
			if player_hp <= 0:
				dead = true
		enemies[i] = enemy

func perform_attack() -> void:
	if attack_cooldown > 0.0 or dialogue_open or dead or complete:
		return
	attack_time = 0.16
	attack_cooldown = 0.34
	var hit_any := false
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		var to_enemy: Vector2 = enemy["pos"] - player_pos
		if to_enemy.length() <= ATTACK_RANGE:
			var facing_score := last_move.normalized().dot(to_enemy.normalized())
			if facing_score > -0.05:
				enemy["hp"] = int(enemy["hp"]) - 1
				enemy["flash"] = 0.12
				hit_any = true
				if int(enemy["hp"]) <= 0:
					enemies.remove_at(i)
			else:
					enemies[i] = enemy
	if hit_any:
		flash_status("IMPACT")

func try_interact() -> void:
	if dead:
		restart_run()
		return
	if dialogue_open:
		if choice_pending:
			return
		if dialogue_index < dialogue_lines.size() - 1:
			dialogue_index += 1
		else:
			if phase == 0:
				choice_pending = true
			else:
				dialogue_open = false
		return

	if phase == 0 and enemies.is_empty() and player_pos.distance_to(CONSOLE_POS) < 60.0:
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
		sol_trust = 1
		remembered_choice = "TRUST"
		dialogue_lines = [
			"YOU: Then trust me enough to tell me the truth.",
			"SOL: Dangerous opening move. I like it.",
			"SOL: The sun is dying because the city is feeding it memories. Mine included."
		]
	else:
		sol_trust = -1
		remembered_choice = "DEFIANCE"
		dialogue_lines = [
			"YOU: I do not take orders from voices trapped in stars.",
			"SOL: Good. Obedience would have made you considerably less useful.",
			"SOL: Keep distrusting me. Just try to survive long enough to be right."
		]
	phase = 1
	spawn_after_choice_wave()

func final_sol_line() -> String:
	if remembered_choice == "TRUST":
		return "SOL: You asked for truth first. I haven't forgotten. That may become inconvenient for both of us."
	return "SOL: Still don't trust the voice in the star? Sensible. Unfortunately, I'm growing on you."

func restart_run() -> void:
	player_pos = Vector2(92.0, 182.0)
	player_hp = 5
	last_move = Vector2.RIGHT
	dash_time = 0.0
	dash_cooldown = 0.0
	attack_time = 0.0
	attack_cooldown = 0.0
	hurt_cooldown = 0.0
	phase = 0
	dead = false
	complete = false
	dialogue_open = false
	choice_pending = false
	dialogue_lines.clear()
	dialogue_index = 0
	sol_trust = 0
	remembered_choice = ""
	spawn_opening_wave()
	flash_status("FRAME REKINDLED")

func flash_status(text: String) -> void:
	status_flash = text
	status_time = 0.7

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
			if dash_cooldown <= 0.0 and not dialogue_open and not dead:
				dash_time = 0.15
				dash_cooldown = 0.8
				flash_status("BOOST")
		KEY_E:
			try_interact()
		KEY_1:
			choose_path(1)
		KEY_2:
			choose_path(2)
		KEY_R:
			if dead or complete:
				restart_run()

func _draw() -> void:
	# Machine-city chamber.
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color("090b12"))
	draw_rect(ARENA, Color("121826"), true)
	draw_rect(ARENA, Color("3f495d"), false, 2.0)
	for x in range(48, 620, 48):
		draw_line(Vector2(x, 32), Vector2(x - 56, 328), Color(0.13, 0.16, 0.23, 0.35), 1.0)

	# Dying artificial sun and containment rings.
	var pulse := 3.0 + sin(elapsed * 2.1) * 2.0
	draw_circle(SUN_POS, 48.0 + pulse, Color("3d2717"))
	draw_circle(SUN_POS, 35.0 + pulse * 0.45, Color("b96b2c"))
	draw_circle(SUN_POS, 23.0, Color("ffd37a"))
	draw_arc(SUN_POS, 63.0, 0.0, TAU, 64, Color("6f778d"), 2.0)
	draw_arc(SUN_POS, 75.0, elapsed * 0.15, elapsed * 0.15 + PI * 1.35, 42, Color("d28a3e"), 2.0)
	draw_line(Vector2(510, 210), Vector2(475, 272), Color("6b7485"), 3.0)

	# Sol terminal.
	var terminal_color := Color("d99b42") if enemies.is_empty() and phase == 0 else Color("566072")
	draw_rect(Rect2(CONSOLE_POS - Vector2(12, 9), Vector2(24, 18)), Color("171e2b"), true)
	draw_rect(Rect2(CONSOLE_POS - Vector2(12, 9), Vector2(24, 18)), terminal_color, false, 2.0)

	for enemy in enemies:
		draw_enemy(enemy)
	draw_player()
	draw_hud()

func draw_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var kind := str(enemy["kind"])
	var body := Color("e1e5e9") if float(enemy["flash"]) > 0.0 else Color("812f39")
	if kind == "SUN-HUSK":
		body = Color("e07a32") if float(enemy["flash"]) <= 0.0 else Color("fff2c2")
	elif kind == "HUSK":
		body = Color("9f493f") if float(enemy["flash"]) <= 0.0 else Color("fff2c2")
	draw_circle(pos, 12.0 if kind == "WARDEN" else 15.0, body)
	draw_circle(pos, 4.0, Color("080a0f"))
	var hp_ratio := float(enemy["hp"]) / float(enemy["max_hp"])
	draw_rect(Rect2(pos + Vector2(-14, -21), Vector2(28, 3)), Color("301a1d"), true)
	draw_rect(Rect2(pos + Vector2(-14, -21), Vector2(28 * hp_ratio, 3)), Color("e5a84c"), true)

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
		draw_line(back, back - forward * 20.0, Color("efb553"), 5.0)
	if attack_time > 0.0:
		var attack_center := player_pos + forward * 17.0
		var angle := forward.angle()
		draw_arc(attack_center, 35.0, angle - 0.9, angle + 0.9, 18, Color("ffe6a3"), 4.0)

func draw_hud() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(34, 20), "DYING SUN // PROTOTYPE 0.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d7d9df"))
	draw_string(font, Vector2(34, 350), "WASD move   SHIFT boost   SPACE strike   E interact", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8993a5"))

	for i in range(5):
		var c := Color("e5a84c") if i < player_hp else Color("313846")
		draw_rect(Rect2(Vector2(34 + i * 18, 34), Vector2(13, 6)), c, true)

	var objective := "PURGE THE WARDENS"
	if phase == 0 and enemies.is_empty():
		objective = "APPROACH TERMINAL // E"
	elif phase == 1:
		objective = "SURVIVE SOL'S INNER GATE"
	elif phase == 2:
		objective = "SUN CHAMBER STABILIZED"
	draw_string(font, Vector2(34, 59), objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d49b4c"))

	if status_time > 0.0:
		draw_string(font, Vector2(270, 50), status_flash, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color("f2d89e"))

	if phase == 0 and enemies.is_empty() and not dialogue_open:
		draw_string(font, CONSOLE_POS + Vector2(-72, 32), "E // UNKNOWN SIGNAL", HORIZONTAL_ALIGNMENT_CENTER, 144, 11, Color("e5a84c"))

	if dialogue_open and not dialogue_lines.is_empty():
		draw_rect(Rect2(46, 238, 548, 82), Color(0.035, 0.045, 0.075, 0.96), true)
		draw_rect(Rect2(46, 238, 548, 82), Color("9b733b"), false, 2.0)
		draw_multiline_string(font, Vector2(62, 260), dialogue_lines[dialogue_index], HORIZONTAL_ALIGNMENT_LEFT, 515, 13, 18, Color("eee9df"))
		if choice_pending:
			draw_string(font, Vector2(62, 296), "[1] Tell me the truth.     [2] I don't trust voices in stars.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e5a84c"))
		elif complete and dialogue_index == dialogue_lines.size() - 1:
			draw_string(font, Vector2(62, 310), "R // RESTART PROTOTYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8993a5"))
		else:
			draw_string(font, Vector2(535, 310), "E // CONTINUE", HORIZONTAL_ALIGNMENT_RIGHT, 44, 10, Color("8993a5"))

	if dead:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.02, 0.03, 0.72), true)
		draw_string(font, Vector2(0, 164), "FRAME EXTINGUISHED", HORIZONTAL_ALIGNMENT_CENTER, 640, 24, Color("d46d55"))
		draw_string(font, Vector2(0, 192), "R or E // REKINDLE", HORIZONTAL_ALIGNMENT_CENTER, 640, 13, Color("d7d9df"))
