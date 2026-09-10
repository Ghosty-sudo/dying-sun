extends Node

func fail(message: String) -> void:
	push_error("TOUCH_INPUT FAILED: " + message)
	get_tree().quit(1)

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
	game.start_new_game()
	await get_tree().process_frame

	var adapter = game.get_node_or_null("TouchInputAdapter")
	if adapter == null:
		fail("TouchInputAdapter missing from main scene")
		return
	if str(game.stage) != "sector_intake_walk":
		fail("Act I did not reach traversal before touch test")
		return

	# Exercise the same screen-touch path used by a normal mobile build.
	var start_pos: Vector2 = game.player_pos
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.position = Vector2(88, 286)
	touch.pressed = true
	game._input(touch)
	adapter._input(touch)

	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(140, 286)
	drag.relative = Vector2(52, 0)
	game._input(drag)
	adapter._input(drag)
	game.update_player(0.25)
	if game.player_pos.x <= start_pos.x:
		fail("screen touch + drag did not move player")
		return

	var release := InputEventScreenTouch.new()
	release.index = 3
	release.position = drag.position
	release.pressed = false
	game._input(release)
	adapter._input(release)
	if game.touch_move_id != -1 or game.touch_move != Vector2.ZERO:
		fail("screen touch release left joystick captured")
		return

	# Exercise the Web/iOS mouse-compatible fallback. Historically this path
	# could tap buttons but could never claim the joystick.
	game.player_pos = Vector2(86, 182)
	start_pos = game.player_pos
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.position = Vector2(90, 286)
	mouse_down.pressed = true
	game._input(mouse_down)
	adapter._input(mouse_down)

	var mouse_drag := InputEventMouseMotion.new()
	mouse_drag.position = Vector2(145, 286)
	mouse_drag.relative = Vector2(55, 0)
	mouse_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	game._input(mouse_drag)
	adapter._input(mouse_drag)
	game.update_player(0.25)
	if game.player_pos.x <= start_pos.x:
		fail("mouse-compatible Web drag did not move player")
		return

	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.position = mouse_drag.position
	mouse_up.pressed = false
	game._input(mouse_up)
	adapter._input(mouse_up)
	if game.touch_move_id != -1 or game.touch_move != Vector2.ZERO:
		fail("mouse release left joystick captured")
		return

	# Finally prove a lost initial press can be recovered from drag motion.
	game.player_pos = Vector2(86, 182)
	start_pos = game.player_pos
	game.touch_move_id = -1
	game.touch_move = Vector2.ZERO
	var recovered_drag := InputEventScreenDrag.new()
	recovered_drag.index = 9
	recovered_drag.position = Vector2(150, 286)
	recovered_drag.relative = Vector2(48, 0)
	adapter._input(recovered_drag)
	game.update_player(0.25)
	if game.player_pos.x <= start_pos.x:
		fail("lost-press recovery drag did not move player")
		return

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun touch input smoke passed")
	get_tree().quit(0)
