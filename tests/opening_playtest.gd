extends Node

const JOYSTICK_START := Vector2(92, 287)
const ATTACK_POS := Vector2(562, 282)
const PLAYER_TOUCH := 11
const ATTACK_TOUCH := 12

func fail(message: String) -> void:
	push_error("OPENING_PLAYTEST FAILED: " + message)
	get_tree().quit(1)

func send_touch(index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	Input.parse_input_event(event)

func send_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	event.relative = relative
	Input.parse_input_event(event)

func tap(pos: Vector2, index: int = ATTACK_TOUCH) -> void:
	send_touch(index, pos, true)
	await get_tree().process_frame
	send_touch(index, pos, false)
	await get_tree().process_frame

func release_move() -> void:
	send_touch(PLAYER_TOUCH, JOYSTICK_START, false)
	await get_tree().process_frame

func move_for(direction: Vector2, seconds: float) -> void:
	var dir := direction.normalized()
	var target := JOYSTICK_START + dir * 46.0
	send_touch(PLAYER_TOUCH, JOYSTICK_START, true)
	await get_tree().process_frame
	send_drag(PLAYER_TOUCH, target, target - JOYSTICK_START)
	var frames := maxi(1, int(ceil(seconds * 60.0)))
	for _i in range(frames):
		await get_tree().process_frame
	await release_move()

func move_toward(game, target: Vector2, stop_distance: float = 34.0, max_seconds: float = 5.0) -> bool:
	var elapsed := 0.0
	while game.player_pos.distance_to(target) > stop_distance and elapsed < max_seconds and not game.dead:
		var direction: Vector2 = target - game.player_pos
		var step_time := minf(0.22, max_seconds - elapsed)
		await move_for(direction, step_time)
		elapsed += step_time
	return not game.dead and game.player_pos.distance_to(target) <= stop_distance

func attack_until_kind_gone(game, kind: String, max_swings: int = 10) -> bool:
	for _i in range(max_swings):
		var target_index := -1
		for j in range(game.enemies.size()):
			if str(game.enemies[j]["kind"]) == kind:
				target_index = j
				break
		if target_index < 0:
			return true
		var target: Vector2 = game.enemies[target_index]["pos"]
		if not await move_toward(game, target, 38.0, 1.5):
			return false
		game.last_move = (target - game.player_pos).normalized()
		await tap(ATTACK_POS)
		for _frame in range(18):
			await get_tree().process_frame
	return false

func _ready() -> void:
	await get_tree().process_frame
	SaveManager.clear_campaign()
	GameState.reset_campaign()
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		fail("main scene did not load")
		return
	var game = packed.instantiate()
	add_child(game)
	await get_tree().process_frame

	# Enter through the real touch title-screen path.
	await tap(Vector2(320, 192), 2)
	await get_tree().process_frame
	if game.ui_mode != "play":
		fail("touch NEW GAME did not enter play")
		return
	if str(game.stage) != "sector_intake_walk":
		fail("new game did not begin in intake traversal")
		return

	# Traverse with SceneTree-dispatched touch input rather than direct state mutation.
	var start_x: float = game.player_pos.x
	await move_for(Vector2.RIGHT, 3.1)
	if game.player_pos.x <= start_x + 150.0:
		fail("sustained touch joystick movement was too small")
		return
	if str(game.stage) != "sector_furnace":
		fail("touch traversal did not reach the furnace")
		return
	if game.enemies.size() != 1 or str(game.enemies[0]["kind"]) != "WARDEN":
		fail("furnace did not begin with the solo Warden lesson")
		return
	var hp_at_furnace: int = game.player_hp

	# Fight through the same touch controls a player uses.
	if not await attack_until_kind_gone(game, "WARDEN", 8):
		fail("reasonable touch combat could not defeat opening Warden")
		return
	if game.dead:
		fail("player died during opening Warden lesson")
		return

	for _i in range(6):
		await get_tree().process_frame
	if game.enemies.size() != 1 or str(game.enemies[0]["kind"]) != "HUSK":
		fail("Warden clear did not stage the solo Husk lesson")
		return
	var hp_before_grace: int = game.player_hp
	for _i in range(60):
		await get_tree().process_frame
	if game.player_hp < hp_before_grace:
		fail("player took damage during the intended furnace hazard grace window")
		return

	if not await attack_until_kind_gone(game, "HUSK", 10):
		fail("reasonable touch combat could not defeat opening Husk")
		return
	if game.dead:
		fail("player died during opening Husk lesson")
		return
	if game.player_hp <= 0 or game.player_hp > hp_at_furnace:
		fail("opening combat ended with invalid armor state")
		return

	for _i in range(10):
		await get_tree().process_frame
	if str(game.stage) != "sector_coolant":
		fail("opening furnace clear did not reach coolant sector")
		return

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun scripted opening playtest passed")
	get_tree().quit(0)
