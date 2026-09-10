extends Node2D

const TOUCH_BREAKER_CENTER := Vector2(562.0, 218.0)
const TOUCH_BREAKER_RADIUS := 30.0
const MIN_CHARGE_TIME := 0.32
const FULL_CHARGE_TIME := 0.82
const BREAKER_COST := 18.0

var charging := false
var charge_time := 0.0
var touch_id := -1
var flash_time := 0.0
var flash_power := 0.0

func game():
	return get_parent()

func breaker_available() -> bool:
	var parent = game()
	return parent != null and int(parent.current_act) >= 2

func _process(delta: float) -> void:
	flash_time = maxf(0.0, flash_time - delta)
	if charging:
		var parent = game()
		if parent == null or not breaker_available() or parent.ui_mode != "play" or parent.paused or parent.dead or parent.dialogue_open or parent.module_pending:
			cancel_charge()
		else:
			charge_time = minf(FULL_CHARGE_TIME, charge_time + delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	var parent = game()
	if parent == null or parent.ui_mode != "play" or parent.paused:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_Q and not key.echo:
			if key.pressed:
				if breaker_available():
					begin_charge()
				else:
					parent.flash_status("BREAKER // UNLOCKS ACT II")
			else:
				release_charge()
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if int(button.button_index) == 4:
			if button.pressed:
				if breaker_available():
					begin_charge()
				else:
					parent.flash_status("BREAKER // UNLOCKS ACT II")
			else:
				release_charge()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not breaker_available():
			return
		if touch.pressed and touch.position.distance_to(TOUCH_BREAKER_CENTER) <= TOUCH_BREAKER_RADIUS + 10.0:
			touch_id = touch.index
			if not begin_charge():
				touch_id = -1
		elif not touch.pressed and touch.index == touch_id:
			touch_id = -1
			release_charge()

func begin_charge() -> bool:
	var parent = game()
	if parent == null or not breaker_available() or charging or parent.dead or parent.dialogue_open or parent.module_pending or parent.attack_cooldown > 0.0:
		return false
	if float(parent.player_charge) < BREAKER_COST:
		parent.flash_status("BREAKER // CHARGE LOW")
		return false
	charging = true
	charge_time = 0.0
	AudioManager.play_sfx("breaker_charge")
	return true

func release_charge() -> void:
	if not charging:
		return
	var held := charge_time
	charging = false
	charge_time = 0.0
	if held < MIN_CHARGE_TIME:
		return
	perform_breaker(held)

func cancel_charge() -> void:
	charging = false
	charge_time = 0.0
	touch_id = -1

func perform_breaker(held: float) -> void:
	var parent = game()
	if parent == null or not breaker_available() or parent.dead or parent.dialogue_open or parent.module_pending:
		return
	if float(parent.player_charge) < BREAKER_COST:
		parent.flash_status("BREAKER // CHARGE LOW")
		return
	var ratio := clampf((held - MIN_CHARGE_TIME) / (FULL_CHARGE_TIME - MIN_CHARGE_TIME), 0.0, 1.0)
	var damage := 3 + int(round(ratio * 2.0))
	var stagger := 4.0 + ratio * 2.5
	var attack_range := 70.0 + ratio * 16.0
	parent.player_charge -= BREAKER_COST
	parent.attack_time = 0.34
	parent.attack_cooldown = 0.58
	parent.combo_step = 0
	parent.combo_window = 0.0
	var hit_any := false
	for i in range(parent.enemies.size() - 1, -1, -1):
		var enemy: Dictionary = parent.enemies[i]
		var to_enemy := Vector2(enemy["pos"]) - Vector2(parent.player_pos)
		if to_enemy.length() > attack_range:
			continue
		var facing := Vector2(parent.last_move).normalized().dot(to_enemy.normalized())
		if facing < -0.28:
			continue
		var hit_damage := damage
		if parent.is_boss_kind(str(enemy["kind"])) and GameState.has_module("crown_spike"):
			hit_damage += 1
		enemy["hp"] = int(enemy["hp"]) - hit_damage
		enemy["flash"] = 0.20
		parent.apply_stagger(enemy, stagger)
		hit_any = true
		if int(enemy["hp"]) <= 0:
			parent.enemies.remove_at(i)
			parent.wave_kills += 1
		else:
			parent.enemies[i] = enemy
	flash_power = ratio
	flash_time = 0.28
	if hit_any:
		parent.flash_status("BREAKER // SYSTEM SHOCK")
	else:
		parent.flash_status("BREAKER // WHIFF")
	AudioManager.play_sfx("breaker")
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(int(device), 0.38 + ratio * 0.18, 0.72 + ratio * 0.20, 0.16)

func _draw() -> void:
	var parent = game()
	if parent == null or parent.ui_mode != "play" or parent.paused or not breaker_available():
		return
	var pos := Vector2(parent.player_pos)
	var forward := Vector2(parent.last_move).normalized()
	if parent.touch_mode and not parent.dialogue_open and not parent.module_pending and not parent.dead:
		var button_fill := Color(0.12, 0.14, 0.18, 0.84)
		var button_edge := Color(0.88, 0.61, 0.25, 0.92)
		if charging:
			button_fill = Color(0.34, 0.22, 0.10, 0.92)
		draw_circle(TOUCH_BREAKER_CENTER, TOUCH_BREAKER_RADIUS, button_fill)
		draw_arc(TOUCH_BREAKER_CENTER, TOUCH_BREAKER_RADIUS, 0.0, TAU, 28, button_edge, 2.0)
		var font := ThemeDB.fallback_font
		draw_string(font, TOUCH_BREAKER_CENTER + Vector2(-21.0, 4.0), "BRK", HORIZONTAL_ALIGNMENT_CENTER, 42.0, 10, Color("f4dfb4"))
	if charging:
		var ratio := clampf(charge_time / FULL_CHARGE_TIME, 0.0, 1.0)
		var color := Color(0.55 + ratio * 0.35, 0.72, 0.82, 0.40 + ratio * 0.50)
		draw_arc(pos, 23.0 + ratio * 7.0, -PI, PI, 32, color, 2.0 + ratio * 2.0)
		draw_line(pos - forward * 7.0, pos - forward * (16.0 + ratio * 9.0), color, 3.0)
		draw_arc(TOUCH_BREAKER_CENTER, TOUCH_BREAKER_RADIUS + 5.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, Color(1.0, 0.84, 0.48, 0.95), 3.0)
	if flash_time > 0.0:
		var center := pos + forward * 24.0
		var angle := forward.angle()
		var alpha := clampf(flash_time / 0.28, 0.0, 1.0)
		draw_arc(center, 52.0 + flash_power * 10.0, angle - 1.10, angle + 1.10, 24, Color(1.0, 0.86, 0.52, alpha), 6.0)
