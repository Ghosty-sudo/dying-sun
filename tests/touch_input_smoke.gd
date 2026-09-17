extends Node

func fail(message: String) -> void:
	push_error("TOUCH_INPUT FAILED: " + message)
	get_tree().quit(1)

func send_to_runtime(router, event: InputEvent) -> void:
	router._input(event)
	router._process(0.0)

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

func key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

func joy_motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
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

	var router = game.get_node_or_null("InputRouter")
	if router == null:
		fail("InputRouter missing from main scene")
		return
	if game.get_node_or_null("TouchInputAdapter") != null or game.get_node_or_null("ControllerAdapter") != null:
		fail("legacy input adapters are still mounted")
		return
	if str(game.stage) != "sector_intake_walk":
		fail("Act I did not reach traversal before input test")
		return

	# Desktop/headless starts with keyboard presentation even if a browser reports
	# touchscreen capability. The HUD should only enter touch mode after real touch.
	if not OS.has_feature("mobile"):
		router._process(0.0)
		if str(router.presentation_mode) != "keyboard" or game.touch_mode:
			fail("desktop default exposed touch presentation before real touch input")
			return

	# Normal real-screen movement still works through the one live input owner and
	# switches the presentation to touch.
	var start_pos: Vector2 = game.player_pos
	send_to_runtime(router, screen_touch(3, Vector2(88, 286), true))
	if str(router.presentation_mode) != "touch" or not game.touch_mode:
		fail("real screen input did not enable touch presentation")
		return
	send_to_runtime(router, screen_drag(3, Vector2(140, 286), Vector2(52, 0)))
	game.update_player(0.25)
	if game.player_pos.x <= start_pos.x:
		fail("screen touch + drag did not move player")
		return
	if game.touch_move_id != 3 or str(router.active_source) != "screen":
		fail("real screen pointer did not own virtual stick")
		return

	# A second finger can attack while movement ownership stays with the left
	# finger. This is the primary multi-touch combat path on mobile.
	var before_action_move: Vector2 = game.touch_move
	game.attack_cooldown = 0.0
	send_to_runtime(router, screen_touch(20, Vector2(562, 282), true))
	if game.attack_cooldown <= 0.0:
		fail("second-finger attack did not reach combat action")
		return
	if game.touch_move_id != 3 or game.touch_move.distance_to(before_action_move) > 0.01:
		fail("second-finger attack changed virtual-stick ownership")
		return
	send_to_runtime(router, screen_touch(20, Vector2(562, 282), false))

	# iOS/WebKit can emit a synthetic mouse copy of the same finger gesture. It
	# must not steal ownership or replay an action.
	var before_mouse_copy: Vector2 = game.touch_move
	send_to_runtime(router, mouse_button(Vector2(92, 286), true))
	send_to_runtime(router, mouse_motion(Vector2(42, 235), Vector2(-50, -51)))
	if game.touch_move_id != 3 or str(router.active_source) != "screen":
		fail("touch-derived mouse stream stole real screen pointer")
		return
	if game.touch_move.distance_to(before_mouse_copy) > 0.01:
		fail("touch-derived mouse motion changed real screen movement")
		return
	if str(router.presentation_mode) != "touch":
		fail("synthetic mouse copy incorrectly changed touch presentation")
		return

	# A second finger in the left half must not hijack the active stick, and it
	# must remain blocked from late drag recovery until that finger is released.
	send_to_runtime(router, screen_touch(4, Vector2(120, 260), true))
	send_to_runtime(router, screen_drag(4, Vector2(75, 220), Vector2(-45, -40)))
	if game.touch_move_id != 3:
		fail("secondary finger hijacked active virtual stick")
		return
	if game.touch_move.x <= 0.0:
		fail("secondary finger changed active movement direction")
		return

	# Releasing the owning finger must immediately zero the stick. Late drags
	# from the movement finger, an action finger, or a blocked second finger must
	# not resurrect movement.
	send_to_runtime(router, screen_touch(3, Vector2(140, 286), false))
	if game.touch_move_id != -1 or game.touch_move != Vector2.ZERO:
		fail("screen touch release left joystick captured")
		return
	send_to_runtime(router, screen_drag(3, Vector2(148, 286), Vector2(8, 0)))
	if game.touch_move_id != -1 or game.touch_move != Vector2.ZERO:
		fail("late drag resurrected released joystick")
		return
	send_to_runtime(router, screen_drag(20, Vector2(160, 240), Vector2(-402, -42)))
	if game.touch_move_id != -1:
		fail("late drag from released action finger became movement")
		return
	send_to_runtime(router, screen_drag(4, Vector2(70, 210), Vector2(-5, -10)))
	if game.touch_move_id != -1:
		fail("blocked secondary finger recovered movement after owner release")
		return
	send_to_runtime(router, screen_touch(4, Vector2(70, 210), false))

	# A genuinely lost initial screen press can still be recovered from a new
	# drag stream, preserving the iOS/Web recovery behavior.
	game.player_pos = Vector2(86, 182)
	start_pos = game.player_pos
	send_to_runtime(router, screen_drag(9, Vector2(150, 286), Vector2(48, 0)))
	game.update_player(0.25)
	if game.player_pos.x <= start_pos.x:
		fail("lost-press recovery drag did not move player")
		return
	send_to_runtime(router, screen_touch(9, Vector2(150, 286), false))

	# Keyboard and controller input immediately replace touch presentation. This
	# is what keeps mobile buttons off desktop/controller play while allowing a
	# player to swap devices without a settings toggle.
	send_to_runtime(router, key_event(KEY_W))
	if str(router.presentation_mode) != "keyboard" or game.touch_mode:
		fail("keyboard input did not hide touch presentation")
		return
	send_to_runtime(router, joy_motion(JOY_AXIS_LEFT_X, 0.5))
	if str(router.presentation_mode) != "controller" or game.touch_mode:
		fail("controller input did not select controller presentation")
		return
	send_to_runtime(router, screen_touch(11, Vector2(90, 286), true))
	if str(router.presentation_mode) != "touch" or not game.touch_mode:
		fail("touch input could not reclaim touch presentation after keyboard/controller")
		return
	send_to_runtime(router, screen_touch(11, Vector2(90, 286), false))

	# Preserve the Web mouse-compatible fallback, including iOS motion events
	# whose button_mask is zero. Headless CI forces this surface explicitly.
	router.last_screen_event_ms = -1000000
	router.force_mouse_touch_fallback = true
	game.player_pos = Vector2(86, 182)
	start_pos = game.player_pos
	send_to_runtime(router, mouse_button(Vector2(90, 286), true))
	send_to_runtime(router, mouse_motion(Vector2(145, 286), Vector2(55, 0)))
	game.update_player(0.25)
	if game.player_pos.x <= start_pos.x:
		fail("mouse-compatible Web drag without button mask did not move player")
		return
	if str(router.active_source) != "mouse":
		fail("mouse-compatible fallback did not own stick")
		return
	if str(router.presentation_mode) != "touch" or not game.touch_mode:
		fail("forced mobile Web fallback did not present touch controls")
		return

	# If a real screen event appears after fallback capture, it must supersede
	# the fallback deterministically.
	send_to_runtime(router, screen_touch(12, Vector2(95, 286), true))
	send_to_runtime(router, screen_drag(12, Vector2(95, 238), Vector2(0, -48)))
	if game.touch_move_id != 12 or str(router.active_source) != "screen":
		fail("real screen stream did not supersede mouse fallback")
		return
	if game.touch_move.y >= -0.5:
		fail("real screen stream did not control movement after superseding fallback")
		return

	# Pausing is part of the same router and must scrub movement immediately.
	send_to_runtime(router, screen_touch(30, Vector2(590, 45), true))
	if not game.paused:
		fail("touch pause did not pause gameplay")
		return
	if game.touch_move_id != -1 or game.touch_move != Vector2.ZERO:
		fail("pause did not clear movement ownership")
		return
	send_to_runtime(router, screen_touch(30, Vector2(590, 45), false))

	# Touch restart from pause is routed centrally and leaves no stale pointer.
	game.player_pos = Vector2(300, 180)
	send_to_runtime(router, screen_touch(31, Vector2(320, 300), true))
	if game.paused:
		fail("checkpoint restart left game paused")
		return
	if game.player_pos.distance_to(Vector2(92, 182)) > 1.0 and str(game.stage) != "sector_intake_walk":
		fail("checkpoint restart did not rebuild gameplay state")
		return
	send_to_runtime(router, screen_touch(31, Vector2(320, 300), false))

	# Dialogue/non-gameplay states scrub movement before gameplay can resume.
	send_to_runtime(router, screen_touch(40, Vector2(88, 286), true))
	send_to_runtime(router, screen_drag(40, Vector2(136, 286), Vector2(48, 0)))
	game.dialogue_open = true
	router._process(0.0)
	if game.touch_move_id != -1 or game.touch_move != Vector2.ZERO:
		fail("non-gameplay state did not clear stale joystick ownership")
		return
	game.dialogue_open = false
	send_to_runtime(router, screen_touch(40, Vector2(136, 286), false))

	# Breaker hold/release also routes through the same owner. A breaker finger
	# is blocked from becoming movement if it drifts left before release.
	game.current_act = 2
	GameState.act = 2
	game.player_charge = 100.0
	var breaker = game.get_node_or_null("BreakerController")
	if breaker == null:
		fail("BreakerController missing")
		return
	send_to_runtime(router, screen_touch(50, Vector2(562, 218), true))
	if not breaker.charging:
		fail("touch breaker press did not begin charge")
		return
	breaker.charge_time = 0.40
	send_to_runtime(router, screen_drag(50, Vector2(180, 218), Vector2(-382, 0)))
	if game.touch_move_id != -1:
		fail("breaker pointer became movement while held")
		return
	var charge_before_release: float = game.player_charge
	send_to_runtime(router, screen_touch(50, Vector2(180, 218), false))
	if breaker.charging:
		fail("touch breaker release did not end charge")
		return
	if game.player_charge >= charge_before_release:
		fail("charged breaker release did not spend frame charge")
		return

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun touch input smoke passed")
	get_tree().quit(0)
