extends Node

# This is a player-bot, not a state-skipping campaign smoke.
# It starts from a deleted save and reaches an ending by sending runtime input
# through InputRouter. It may READ live positions/objectives to decide where to
# move, but it never writes player_pos, stage, enemy arrays, HP, route progress,
# director counters, or ending state.

const DT := 1.0 / 60.0
const MAX_SIM_SECONDS := 420.0
const MAX_DEATHS := 10
const MAX_STAGE_SECONDS := 70.0

const MOVE_TOUCH := 41
const ATTACK_TOUCH := 42
const DEFLECT_TOUCH := 43
const BOOST_TOUCH := 44
const BREAKER_TOUCH := 45

const JOYSTICK_START := Vector2(92.0, 287.0)
const ATTACK_POS := Vector2(562.0, 282.0)
const DEFLECT_POS := Vector2(438.0, 312.0)
const BOOST_POS := Vector2(500.0, 312.0)
const BREAKER_POS := Vector2(562.0, 218.0)

var game
var router
var sector
var act3
var act4
var act5
var breaker
var crown_boost

var sim_time := 0.0
var stage_started := 0.0
var last_stage := ""
var last_act := 0
var last_enemy_count := 0
var last_hp := 0
var damage_taken := 0
var bypassed_hostiles := 0
var attacks := 0
var deflects := 0
var boosts := 0
var breakers := 0
var movement_bursts := 0
var stage_visits: Dictionary = {}
var stage_time: Dictionary = {}
var act_start_time: Dictionary = {}
var act_time: Dictionary = {}
var route_choices: Array[String] = []
var module_choices: Array[String] = []
var death_recoveries := 0
var failed := false

func fail(message: String) -> void:
	if failed:
		return
	failed = true
	flush_current_timing()
	print_report("FAILED // " + message)
	push_error("SOL_PLAYTHROUGH FAILED: " + message)
	get_tree().quit(1)

func send_touch(index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	router._input(event)

func send_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	event.relative = relative
	router._input(event)

func send_key(keycode: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = false
	router._input(event)

func tap_action(pos: Vector2, pointer_id: int) -> void:
	send_touch(pointer_id, pos, true)
	send_touch(pointer_id, pos, false)

func tap_attack() -> void:
	if game.attack_cooldown > 0.0:
		return
	tap_action(ATTACK_POS, ATTACK_TOUCH)
	attacks += 1

func tap_deflect() -> void:
	if game.deflect_cooldown > 0.0:
		return
	tap_action(DEFLECT_POS, DEFLECT_TOUCH)
	deflects += 1

func tap_boost() -> void:
	if game.dash_cooldown > 0.0 or game.player_charge < game.boost_cost():
		return
	tap_action(BOOST_POS, BOOST_TOUCH)
	boosts += 1

func full_breaker() -> void:
	if int(game.current_act) < 2 or game.player_charge < 18.0:
		return
	send_touch(BREAKER_TOUCH, BREAKER_POS, true)
	simulate_seconds(0.84)
	if failed:
		return
	send_touch(BREAKER_TOUCH, BREAKER_POS, false)
	breakers += 1
	simulate_seconds(0.04)

func simulate_frame() -> void:
	if failed:
		return
	# Manual deterministic ordering mirrors the live process priorities closely
	# enough for authored progression while avoiding real-time waits in CI.
	router._process(DT)
	sector._process(DT)
	act3._process(DT)
	act4._process(DT)
	act5._process(DT)
	if crown_boost != null:
		crown_boost._process(DT)
	breaker._process(DT)
	game._process(DT)
	sim_time += DT
	observe_metrics()
	observe_transition()

func simulate_seconds(seconds: float) -> void:
	var frames := maxi(1, int(ceil(seconds / DT)))
	for _i in range(frames):
		if failed:
			return
		simulate_frame()

func drive_toward(target: Vector2, seconds: float = 0.09, allow_boost: bool = true) -> void:
	var delta: Vector2 = target - Vector2(game.player_pos)
	if delta.length() <= 3.0:
		simulate_seconds(seconds)
		return
	if allow_boost and delta.length() > 125.0 and game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost() + 20.0:
		tap_boost()
	var direction := delta.normalized()
	var target_stick := JOYSTICK_START + direction * 46.0
	send_touch(MOVE_TOUCH, JOYSTICK_START, true)
	send_drag(MOVE_TOUCH, target_stick, target_stick - JOYSTICK_START)
	movement_bursts += 1
	simulate_seconds(seconds)
	if failed:
		return
	send_touch(MOVE_TOUCH, JOYSTICK_START, false)

func nearest_enemy_index() -> int:
	var best := -1
	var best_distance := INF
	for i in range(game.enemies.size()):
		var distance := Vector2(game.enemies[i]["pos"]).distance_to(game.player_pos)
		if distance < best_distance:
			best = i
			best_distance = distance
	return best

func danger_is_imminent() -> bool:
	for projectile in game.projectiles:
		if Vector2(projectile["pos"]).distance_to(game.player_pos) <= 30.0:
			return true
	for enemy in game.enemies:
		var distance := Vector2(enemy["pos"]).distance_to(game.player_pos)
		var state := str(enemy.get("state", ""))
		if state == "telegraph" and float(enemy.get("telegraph", 1.0)) <= 0.14 and distance <= 105.0:
			return true
		if state == "charge" and distance <= 78.0:
			return true
	return false

func defensive_action() -> void:
	if danger_is_imminent() and game.deflect_cooldown <= 0.0:
		tap_deflect()

func combat_step() -> void:
	if game.enemies.is_empty():
		simulate_seconds(0.05)
		return
	defensive_action()
	var index := nearest_enemy_index()
	if index < 0:
		simulate_seconds(0.05)
		return
	var target := Vector2(game.enemies[index]["pos"])
	var distance := target.distance_to(game.player_pos)

	if game.player_hp <= 2 and distance < 95.0 and game.dash_cooldown <= 0.0:
		tap_boost()
		var away := (Vector2(game.player_pos) - target).normalized()
		if away.length_squared() <= 0.001:
			away = Vector2.LEFT
		drive_toward(Vector2(game.player_pos) + away * 110.0, 0.12, false)
		return

	if distance > 47.0:
		drive_toward(target, 0.08)
		return

	# Tiny facing correction is still real movement input; it keeps melee tests
	# honest instead of directly writing last_move.
	drive_toward(target, 0.018, false)
	if failed:
		return
	if game.attack_cooldown <= 0.0:
		tap_attack()
		simulate_seconds(0.12)
	else:
		simulate_seconds(0.06)

func objective_hold_step(target: Vector2, radius: float = 30.0) -> void:
	var distance := Vector2(game.player_pos).distance_to(target)
	if distance > radius:
		drive_toward(target, 0.08)
		return
	defensive_action()
	var index := nearest_enemy_index()
	if index >= 0:
		var enemy_pos := Vector2(game.enemies[index]["pos"])
		if enemy_pos.distance_to(game.player_pos) <= 54.0 and game.attack_cooldown <= 0.0:
			drive_toward(enemy_pos, 0.012, false)
			if failed:
				return
			tap_attack()
			simulate_seconds(0.08)
			return
	simulate_seconds(0.08)

func follow_objective_step(target: Vector2, radius: float = 44.0) -> void:
	if Vector2(game.player_pos).distance_to(target) > radius:
		drive_toward(target, 0.08)
		return
	defensive_action()
	var index := nearest_enemy_index()
	if index >= 0:
		var enemy_pos := Vector2(game.enemies[index]["pos"])
		if enemy_pos.distance_to(game.player_pos) <= 56.0 and game.attack_cooldown <= 0.0:
			drive_toward(enemy_pos, 0.012, false)
			if failed:
				return
			tap_attack()
			simulate_seconds(0.08)
			return
	simulate_seconds(0.08)

func handle_memory_seal() -> void:
	var seal_pos := Vector2(390.0, 180.0)
	var firing_pos := seal_pos - Vector2(58.0, 0.0)
	if Vector2(game.player_pos).distance_to(firing_pos) > 18.0:
		drive_toward(firing_pos, 0.08)
		return
	# Face the seal using real movement, then charge and release the required tool.
	drive_toward(seal_pos, 0.02, false)
	if failed:
		return
	full_breaker()

func handle_dialogue() -> void:
	if game.choice_pending:
		var choice_label := ""
		match int(game.current_act):
			1: choice_label = "TRUST"
			2: choice_label = "PRESERVE ARCHIVE"
			3: choice_label = "CIVILIANS"
			4: choice_label = "OPEN RECORD"
			5: choice_label = "STAY TOGETHER"
		route_choices.append("ACT %d // %s" % [game.current_act, choice_label])
		send_key(KEY_1)
		simulate_seconds(0.04)
		return
	send_key(KEY_E)
	simulate_seconds(0.04)

func handle_module() -> void:
	var key := KEY_1
	var label := ""
	match int(game.current_act):
		1:
			key = KEY_2
			label = "IMPACT SERVO"
		2:
			key = KEY_2
			label = "MEMORY SINK"
		3:
			key = KEY_2
			label = "GHOST CHASSIS"
		4:
			key = KEY_1
			label = "CROWN SPIKE"
		_:
			key = KEY_1
			label = "DEFAULT"
	module_choices.append("ACT %d // %s" % [game.current_act, label])
	send_key(key)
	simulate_seconds(0.05)

func recover_from_death() -> void:
	death_recoveries += 1
	print("SOL_PLAYTHROUGH // DEATH %d // ACT %d // %s // t=%.1f" % [death_recoveries, game.current_act, game.stage, sim_time])
	if death_recoveries > MAX_DEATHS:
		fail("bot exceeded %d checkpoint recoveries" % MAX_DEATHS)
		return
	send_key(KEY_E)
	simulate_seconds(0.08)

func authored_stage_step() -> void:
	match str(game.stage):
		"wave_a", "wave_b":
			simulate_seconds(0.05)
		"sector_intake_walk":
			drive_toward(Vector2(455.0, 182.0), 0.10)
		"sector_furnace", "sector_coolant", "sector_gate_approach", "sector_gate_pressure", "sector_memory_gallery", "boss":
			combat_step()
		"sector_memory_entry":
			drive_toward(Vector2(285.0, 180.0), 0.10)
		"sector_memory_seal":
			handle_memory_seal()
		"sector_archive_hold":
			objective_hold_step(Vector2(350.0, 180.0), 28.0)
		"sector_purge_run":
			drive_toward(Vector2(570.0, 180.0), 0.10)
		"sector_relay_entry":
			drive_toward(Vector2(205.0, 180.0), 0.08)
		"sector_relay_sync":
			if int(act3.relay_index) < act3.RELAY_NODES.size():
				objective_hold_step(Vector2(act3.RELAY_NODES[int(act3.relay_index)]), 27.0)
			else:
				simulate_seconds(0.05)
		"sector_civilian_feed":
			follow_objective_step(Vector2(act3.escort_pos), 48.0)
		"sector_defense_push":
			drive_toward(Vector2(570.0, 180.0), 0.10)
		"sector_crown_entry":
			drive_toward(Vector2(205.0, 180.0), 0.08)
		"sector_crown_audit":
			if int(act4.truth_index) < act4.TRUTH_NODES.size():
				objective_hold_step(Vector2(act4.TRUTH_NODES[int(act4.truth_index)]), 26.0)
			else:
				simulate_seconds(0.05)
		"sector_record_extraction":
			if int(act4.record_index) < act4.RECORD_NODES.size():
				objective_hold_step(Vector2(act4.RECORD_NODES[int(act4.record_index)]), 27.0)
			else:
				simulate_seconds(0.05)
		"sector_crown_overdrive":
			drive_toward(Vector2(570.0, 180.0), 0.10)
		"sector_last_light_entry":
			drive_toward(Vector2(205.0, 180.0), 0.08)
		"sector_echo_convergence":
			if int(act5.echo_index) < act5.ECHO_NODES.size():
				objective_hold_step(Vector2(act5.ECHO_NODES[int(act5.echo_index)]), 27.0)
			else:
				simulate_seconds(0.05)
		"sector_shared_descent":
			follow_objective_step(Vector2(act5.link_pos), 50.0)
		"sector_sever_spine":
			if int(act5.sever_index) < act5.SEVER_NODES.size():
				var lock_pos := Vector2(act5.SEVER_NODES[int(act5.sever_index)])
				if Vector2(game.player_pos).distance_to(lock_pos) > 55.0:
					drive_toward(lock_pos, 0.08)
				else:
					drive_toward(lock_pos, 0.02, false)
					if not failed:
						full_breaker()
			else:
				simulate_seconds(0.05)
		"act_complete":
			if game.dialogue_open:
				handle_dialogue()
			else:
				simulate_seconds(0.05)
		"choice":
			if game.dialogue_open:
				handle_dialogue()
			else:
				simulate_seconds(0.05)
		"module":
			if game.module_pending:
				handle_module()
			else:
				simulate_seconds(0.05)
		_:
			fail("unhandled runtime stage: %s" % str(game.stage))

func objective_stage(stage_name: String) -> bool:
	return stage_name in [
		"sector_archive_hold",
		"sector_relay_sync",
		"sector_civilian_feed",
		"sector_crown_audit",
		"sector_record_extraction",
		"sector_echo_convergence",
		"sector_shared_descent",
	]

func transition_key(act_number: int, stage_name: String) -> String:
	return "A%d/%s" % [act_number, stage_name]

func observe_transition() -> void:
	if failed:
		return
	var act_number := int(game.current_act)
	var stage_name := str(game.stage)
	if last_act == 0:
		last_act = act_number
		last_stage = stage_name
		stage_started = sim_time
		act_start_time[act_number] = sim_time
		stage_visits[transition_key(act_number, stage_name)] = 1
		last_enemy_count = game.enemies.size()
		print("SOL_PLAYTHROUGH // ACT %d // %s" % [act_number, stage_name])
		return

	if act_number != last_act or stage_name != last_stage:
		var elapsed_stage := sim_time - stage_started
		var old_key := transition_key(last_act, last_stage)
		stage_time[old_key] = float(stage_time.get(old_key, 0.0)) + elapsed_stage
		if objective_stage(last_stage) and last_enemy_count > 0:
			bypassed_hostiles += last_enemy_count
			print("SOL_PLAYTHROUGH // PRESSURE BYPASS // %s // %d hostiles still active" % [old_key, last_enemy_count])
		if act_number != last_act:
			act_time[last_act] = sim_time - float(act_start_time.get(last_act, 0.0))
			act_start_time[act_number] = sim_time
			print("SOL_PLAYTHROUGH // ACT %d COMPLETE // %.1fs" % [last_act, float(act_time[last_act])])
		last_act = act_number
		last_stage = stage_name
		stage_started = sim_time
		var new_key := transition_key(act_number, stage_name)
		stage_visits[new_key] = int(stage_visits.get(new_key, 0)) + 1
		print("SOL_PLAYTHROUGH // ACT %d // %s // armor %d/%d // t=%.1f" % [act_number, stage_name, game.player_hp, game.max_hp(), sim_time])

	last_enemy_count = game.enemies.size()
	if sim_time - stage_started > MAX_STAGE_SECONDS:
		fail("stage exceeded %.0fs without progression: %s" % [MAX_STAGE_SECONDS, transition_key(act_number, stage_name)])

func observe_metrics() -> void:
	if last_hp > 0 and game.player_hp < last_hp:
		damage_taken += last_hp - int(game.player_hp)
	last_hp = int(game.player_hp)

func flush_current_timing() -> void:
	if last_act <= 0 or last_stage.is_empty():
		return
	var key := transition_key(last_act, last_stage)
	stage_time[key] = float(stage_time.get(key, 0.0)) + maxf(0.0, sim_time - stage_started)
	if not act_time.has(last_act):
		act_time[last_act] = maxf(0.0, sim_time - float(act_start_time.get(last_act, 0.0)))

func print_report(prefix: String) -> void:
	print("SOL_PLAYTHROUGH // REPORT // " + prefix)
	print("SOL_PLAYTHROUGH // SIM TIME // %.1fs" % sim_time)
	print("SOL_PLAYTHROUGH // ENDING // %s" % str(game.ending_id if game != null else ""))
	print("SOL_PLAYTHROUGH // DEATHS // %d" % int(GameState.run_deaths))
	print("SOL_PLAYTHROUGH // DAMAGE TAKEN // %d" % damage_taken)
	print("SOL_PLAYTHROUGH // ACTIONS // attacks=%d deflects=%d boosts=%d breakers=%d movement=%d" % [attacks, deflects, boosts, breakers, movement_bursts])
	print("SOL_PLAYTHROUGH // PRESSURE HOSTILES BYPASSED // %d" % bypassed_hostiles)
	print("SOL_PLAYTHROUGH // ROUTES // %s" % " | ".join(route_choices))
	print("SOL_PLAYTHROUGH // MODULES // %s" % " | ".join(module_choices))
	for act_number in range(1, 6):
		print("SOL_PLAYTHROUGH // ACT %d TIME // %.1fs" % [act_number, float(act_time.get(act_number, 0.0))])
	var keys := stage_time.keys()
	keys.sort()
	for key in keys:
		print("SOL_PLAYTHROUGH // STAGE // %s // %.1fs // visits=%d" % [str(key), float(stage_time[key]), int(stage_visits.get(key, 0))])

func _ready() -> void:
	await get_tree().process_frame
	SaveManager.clear_campaign()
	GameState.reset_campaign()

	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		fail("main scene did not load")
		return
	game = packed.instantiate()
	add_child(game)
	await get_tree().process_frame

	router = game.get_node_or_null("InputRouter")
	sector = game.get_node_or_null("SectorDirector")
	act3 = game.get_node_or_null("Act3Director")
	act4 = game.get_node_or_null("Act4Director")
	act5 = game.get_node_or_null("Act5Director")
	breaker = game.get_node_or_null("BreakerController")
	crown_boost = game.get_node_or_null("CrownBoostCounter")
	if router == null or sector == null or act3 == null or act4 == null or act5 == null or breaker == null:
		fail("required live runtime controllers are missing")
		return

	# From here, no wall-clock gameplay. We call the same live runtime methods
	# deterministically so a full campaign can be played quickly and repeatably.
	game.set_process(false)
	router.set_process(false)
	sector.set_process(false)
	act3.set_process(false)
	act4.set_process(false)
	act5.set_process(false)
	breaker.set_process(false)
	if crown_boost != null:
		crown_boost.set_process(false)

	# Fresh save -> title -> NEW GAME through real title input.
	last_hp = int(game.player_hp)
	send_touch(2, Vector2(320.0, 192.0), true)
	send_touch(2, Vector2(320.0, 192.0), false)
	simulate_seconds(0.05)
	if failed:
		return
	if game.ui_mode != "play" or int(game.current_act) != 1:
		fail("fresh title input did not start a new campaign")
		return

	observe_transition()
	while not failed and game.ui_mode != "ending" and sim_time < MAX_SIM_SECONDS:
		if game.dead:
			recover_from_death()
			continue
		if game.dialogue_open:
			handle_dialogue()
			continue
		if game.module_pending:
			handle_module()
			continue
		authored_stage_step()

	if failed:
		return
	if game.ui_mode != "ending":
		fail("campaign did not reach an ending within %.0f simulated seconds" % MAX_SIM_SECONDS)
		return
	flush_current_timing()
	if not GameState.has_flag("campaign_complete"):
		fail("ending reached without campaign_complete persistence")
		return
	if str(game.ending_id) != "reconciliation":
		fail("Sol route expected reconciliation, got %s" % str(game.ending_id))
		return

	print_report("COMPLETE")
	SaveManager.clear_campaign()
	print("Dying Sun Sol fresh-save full playthrough passed")
	get_tree().quit(0)
