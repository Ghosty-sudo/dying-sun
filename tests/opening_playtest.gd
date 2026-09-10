extends Node

const DT := 1.0 / 60.0
const JOYSTICK_START := Vector2(92, 287)
const ATTACK_POS := Vector2(562, 282)
const PLAYER_TOUCH := 11
const ATTACK_TOUCH := 12

var game
var touch_adapter
var director

func fail(message: String) -> void:
	push_error("OPENING_PLAYTEST FAILED: " + message)
	get_tree().quit(1)

func dispatch(event: InputEvent) -> void:
	game._input(event)
	if touch_adapter != null:
		touch_adapter._input(event)

func send_touch(index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	dispatch(event)

func send_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	event.relative = relative
	dispatch(event)

func simulate_frame() -> void:
	# SectorDirector has negative process priority in the live scene, so it must
	# establish authored room state before the parent campaign loop each frame.
	director._process(DT)
	game._process(DT)

func simulate_seconds(seconds: float) -> void:
	var frames := maxi(1, int(ceil(seconds / DT)))
	for _i in range(frames):
		simulate_frame()

func tap(pos: Vector2, index: int = ATTACK_TOUCH) -> void:
	send_touch(index, pos, true)
	send_touch(index, pos, false)

func release_move() -> void:
	send_touch(PLAYER_TOUCH, JOYSTICK_START, false)

func move_for(direction: Vector2, seconds: float) -> void:
	var dir := direction.normalized()
	var target := JOYSTICK_START + dir * 46.0
	send_touch(PLAYER_TOUCH, JOYSTICK_START, true)
	send_drag(PLAYER_TOUCH, target, target - JOYSTICK_START)
	simulate_seconds(seconds)
	release_move()

func enemy_index(kind: String) -> int:
	for i in range(game.enemies.size()):
		if str(game.enemies[i]["kind"]) == kind:
			return i
	return -1

func move_to_enemy(kind: String, stop_distance: float = 40.0, max_seconds: float = 2.0) -> bool:
	var elapsed := 0.0
	while elapsed < max_seconds and not game.dead:
		var index := enemy_index(kind)
		if index < 0:
			return true
		var target: Vector2 = game.enemies[index]["pos"]
		if game.player_pos.distance_to(target) <= stop_distance:
			return true
		var direction: Vector2 = target - game.player_pos
		var step_time := minf(0.12, max_seconds - elapsed)
		move_for(direction, step_time)
		elapsed += step_time
	return enemy_index(kind) < 0 or game.player_pos.distance_to(Vector2(game.enemies[enemy_index(kind)]["pos"])) <= stop_distance

func fight_furnace_phase(kind: String, phase: int, max_swings: int = 10) -> bool:
	for _swing in range(max_swings):
		if game.dead:
			return false
		if str(game.stage) != "sector_furnace" or int(director.furnace_phase) != phase:
			return true
		var index := enemy_index(kind)
		if index < 0:
			simulate_seconds(0.05)
			continue
		if not move_to_enemy(kind, 42.0, 1.8):
			return false
		index = enemy_index(kind)
		if index < 0:
			simulate_seconds(0.05)
			continue
		# Movement establishes facing just as it would for a player closing on a target.
		tap(ATTACK_POS)
		simulate_seconds(0.42)
	return str(game.stage) != "sector_furnace" or int(director.furnace_phase) != phase

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
	touch_adapter = game.get_node_or_null("TouchInputAdapter")
	director = game.get_node_or_null("SectorDirector")
	if touch_adapter == null or director == null:
		fail("required runtime input/sector controllers are missing")
		return

	# Stop wall-clock processing. From here the playtest advances the exact live
	# runtime deterministically at 60 Hz, including enemy AI, hazards and cooldowns.
	game.set_process(false)
	director.set_process(false)

	# Enter via the same touch handler used by the title screen.
	tap(Vector2(320, 192), 2)
	simulate_frame()
	if game.ui_mode != "play" or str(game.stage) != "sector_intake_walk":
		fail("touch NEW GAME did not enter Act I traversal")
		return
	print("OPENING_PLAYTEST // TITLE OK")

	# Prove sustained touch movement before crossing the room transition.
	var start_x: float = game.player_pos.x
	move_for(Vector2.RIGHT, 1.0)
	if game.player_pos.x <= start_x + 90.0 or str(game.stage) != "sector_intake_walk":
		fail("touch joystick could not sustain traversal movement")
		return
	move_for(Vector2.RIGHT, 2.0)
	if str(game.stage) != "sector_furnace":
		fail("touch traversal did not cross the inner seal into the furnace")
		return
	if game.enemies.size() != 1 or str(game.enemies[0]["kind"]) != "WARDEN":
		fail("furnace did not begin with the solo Warden lesson")
		return
	print("OPENING_PLAYTEST // TRAVERSAL OK")

	var hp_at_furnace: int = game.player_hp
	if not fight_furnace_phase("WARDEN", 0, 8):
		fail("touch player could not defeat the opening Warden")
		return
	if game.dead or int(director.furnace_phase) != 1:
		fail("Warden lesson did not survive into ranged phase")
		return
	if game.enemies.size() != 1 or str(game.enemies[0]["kind"]) != "HUSK":
		fail("Warden clear did not stage the solo Husk lesson")
		return
	if director.furnace_grace <= 0.0 or director.furnace_hot():
		fail("furnace hazard was not safely gated when the Husk appeared")
		return
	print("OPENING_PLAYTEST // WARDEN OK // ARMOR %d/%d" % [game.player_hp, game.max_hp()])

	# The second phase may shoot back; the standard is survival and progression,
	# not a no-hit bot run.
	if not fight_furnace_phase("HUSK", 1, 10):
		fail("touch player could not defeat the opening Husk")
		return
	if game.dead:
		fail("player died during the staged opening combat lesson")
		return
	if str(game.stage) != "sector_coolant":
		simulate_seconds(0.1)
	if str(game.stage) != "sector_coolant":
		fail("opening furnace clear did not reach coolant sector")
		return
	if game.player_hp <= 0 or game.player_hp > hp_at_furnace:
		fail("opening combat ended with invalid armor state")
		return
	print("OPENING_PLAYTEST // HUSK OK // ARMOR %d/%d" % [game.player_hp, game.max_hp()])
	print("OPENING_PLAYTEST // COOLANT REACHED")

	# Verify the touch restart path from a real death state still returns control.
	game.hurt_cooldown = 0.0
	game.hurt_player(999)
	if not game.dead:
		fail("forced recovery check did not enter death state")
		return
	tap(Vector2(320, 180), 14)
	simulate_frame()
	if game.dead or str(game.stage) != "sector_intake_walk":
		fail("tap-to-rekindle did not restore playable Act I traversal")
		return
	var restart_x: float = game.player_pos.x
	move_for(Vector2.RIGHT, 0.35)
	if game.player_pos.x <= restart_x + 25.0:
		fail("movement did not recover after touch checkpoint restart")
		return
	print("OPENING_PLAYTEST // RESTART OK")

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun scripted opening playtest passed")
	get_tree().quit(0)
