extends Node

func fail(message: String) -> void:
	push_error("TOUCH_INPUT FAILED: " + message)
	get_tree().quit(1)

func send_to_runtime(game, adapter, event: InputEvent) -> void:
	# Match the existing parent+adapter handling path, then force the adapter's
	# authoritative pre-gameplay sync so the assertion sees the state the player
	# will actually move with.
	game._input(event)
	adapter._input(event)
	adapter._process(0.0)

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

func mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event

func mouse_motion(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	event.button_mask = 0
	return event

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

	# Normal real-screen movement still works.
	var start_pos: Vector2 = game.player_pos
	send_to_runtime(game, adapter, screen_touch(3, Vector2(88, 286), true))
	send_to_runtime(game, adapter, screen_drag(3, Vector2(140, 286), Vector2(52, 0)))
	game.update_player(0.25)
	if game.player_pos.x <= start_pos.x:
		fail("screen touch + drag did not move player")
		return
	if game.touch_move_id != 3 or str(adapter.active_source) != "screen":
		fail("real screen pointer did not own virtual stick")
		return

	# iOS/WebKit can emit a synthetic mouse copy of the same finger gesture.
	# It must not steal ownership or change the movement vector.
	var before_mouse_copy: Vector2 = game.touch_move
	send_to_runtime(game, adapter, mouse_button(Vector2(92, 286), true))
	send_to_runtime(game, adapter, mouse_motion(Vector2(42, 235), Vector2(-50, -51)))
	if game.touch_move_id != 3 or str(adapter.active_source) != "screen":
		fail("touch-derived mouse stream stole real screen pointer")
		return
	if game.touch_move.distance_to(before_mouse_copy) > 0.01:
		fail("touch-derived mouse motion changed real screen movement")
		return

	# A second finger in the left half must not hijack the active stick. The
	# parent gameplay script historically wrote this state too, so this verifies
	# the adapter restores its authoritative pointer before movement integration.
	send_to_runtime(game, adapter, screen_touch(4, Vector2(120, 260), true))
	send_to_runtime(game, adapter, screen_drag(4, Vector2(75, 220), Vector2(-45, -40)))
	if game.touch_move_id != 3:
		fail("secondary finger hijacked active virtual stick")
		return
	if game.touch_move.x <= 0.0:
		fail("secondary finger changed active movement direction")
		return

	# Releasing the owning finger must immediately zero the stick. A late drag
	# for that just-released pointer must not resurrect ghost movement.
	send_to_runtime(game, adapter, screen_touch(3, Vector2(140, 286), false))
	if game.touch_move_id != -1 or game.touch_move != Vector2.ZERO:
		fail("screen touch release left joystick captured")
		return
	send_to_runtime(game, adapter, screen_drag(3, Vector2(148, 286), Vector2(8, 0)))
	if game.touch_move_id != -1 or game.touch_move != Vector2.ZERO:
		fail("late drag resurrected released joystick")
		return

	# A genuinely lost initial screen press can still be recovered from a new
	# drag stream, preserving the iOS/Web recovery behavior.
	game.player_pos = Vector2(86, 182)
	start_pos = game.player_pos
	send_to_runtime(game, adapter, screen_drag(9, Vector2(150, 286), Vector2(48, 0)))
	game.update_player(0.25)
	if game.player_pos.x <= start_pos.x:
		fail("lost-press recovery drag did not move player")
		return
	send_to_runtime(game, adapter, screen_touch(9, Vector2(150, 286), false))

	# When no real screen stream is present, preserve the Web mouse-compatible
	# fallback, including iOS motion events whose button_mask is zero.
	adapter.last_screen_event_ms = -1000000
	game.player_pos = Vector2(86, 182)
	start_pos = game.player_pos
	send_to_runtime(game, adapter, mouse_button(Vector2(90, 286), true))
	send_to_runtime(game, adapter, mouse_motion(Vector2(145, 286), Vector2(55, 0)))
	game.update_player(0.25)
	if game.player_pos.x <= start_pos.x:
		fail("mouse-compatible Web drag without button mask did not move player")
		return
	if str(adapter.active_source) != "mouse":
		fail("mouse-compatible fallback did not own stick")
		return

	# If a real screen event appears after fallback capture, it must supersede
	# the synthetic source deterministically.
	send_to_runtime(game, adapter, screen_touch(12, Vector2(95, 286), true))
	send_to_runtime(game, adapter, screen_drag(12, Vector2(95, 238), Vector2(0, -48)))
	if game.touch_move_id != 12 or str(adapter.active_source) != "screen":
		fail("real screen stream did not supersede mouse fallback")
		return
	if game.touch_move.y >= -0.5:
		fail("real screen stream did not control movement after superseding fallback")
		return

	# Entering a state that should not accept movement must scrub any stale
	# vector before gameplay can resume later.
	game.dialogue_open = true
	adapter._process(0.0)
	if game.touch_move_id != -1 or game.touch_move != Vector2.ZERO:
		fail("non-gameplay state did not clear stale joystick ownership")
		return
	game.dialogue_open = false

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun touch input smoke passed")
	get_tree().quit(0)
