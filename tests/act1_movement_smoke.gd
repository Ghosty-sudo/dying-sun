extends Node

func fail(message: String) -> void:
	push_error("ACT1_MOVEMENT FAILED: " + message)
	get_tree().quit(1)

func screen_touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event

func screen_drag(index: int, position: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	return event

func _ready() -> void:
	print("ACT1_MOVEMENT // START")
	GameState.reset_campaign()
	GameState.set_checkpoint("ash_intake_start", 1)
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		fail("main scene did not load")
		return
	var game = packed.instantiate()
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	await get_tree().process_frame
	game.ui_mode = "play"
	game.begin_act_from_checkpoint()
	await get_tree().process_frame
	if str(game.stage) != "sector_intake_walk":
		fail("Act I did not enter intake traversal on its first playable frame; stage=" + str(game.stage))
		return
	if game.dialogue_open:
		fail("Act I opened dialogue before traversal input")
		return
	var router = game.get_node_or_null("InputRouter")
	if router == null:
		fail("InputRouter missing")
		return
	var start_pos: Vector2 = game.player_pos
	router._input(screen_touch(1, Vector2(90, 286), true))
	router._input(screen_drag(1, Vector2(138, 286), Vector2(48, 0)))
	router._process(0.0)
	game.update_player(0.25)
	router._input(screen_touch(1, Vector2(138, 286), false))
	router._process(0.0)
	if game.player_pos.x <= start_pos.x:
		fail("player position did not advance during Act I traversal")
		return
	if game.touch_move != Vector2.ZERO:
		fail("movement vector did not clear after release")
		return
	game.check_encounter_progression()
	if str(game.stage) != "sector_intake_walk":
		fail("legacy empty-wave progression hijacked authored traversal")
		return
	print("Dying Sun Act I movement smoke passed")
	get_tree().quit(0)
