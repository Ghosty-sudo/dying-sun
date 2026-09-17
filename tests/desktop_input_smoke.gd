extends Node

func fail(message: String) -> void:
	push_error("DESKTOP_INPUT FAILED: " + message)
	SaveManager.clear_campaign()
	get_tree().quit(1)

func key_event(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = false
	return event

func joy_button(index: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event

func send(router, event: InputEvent) -> void:
	router._input(event)
	router._process(0.0)

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
	var router = game.get_node_or_null("InputRouter")
	if router == null:
		fail("InputRouter missing")
		return

	# Controller navigation must work before gameplay without relying on the
	# retired controller adapter.
	game.menu_selection = 0
	send(router, joy_button(JOY_BUTTON_DPAD_DOWN))
	if game.menu_selection != 1:
		fail("controller D-pad did not move title selection")
		return
	send(router, joy_button(JOY_BUTTON_DPAD_UP))
	if game.menu_selection != 0:
		fail("controller D-pad did not move title selection back")
		return
	send(router, joy_button(JOY_BUTTON_A))
	await get_tree().process_frame
	if game.ui_mode != "play" or str(game.stage) != "sector_intake_walk":
		fail("controller confirm did not start a new campaign")
		return

	# Keyboard combat routes through InputRouter.
	game.attack_cooldown = 0.0
	send(router, key_event(KEY_SPACE))
	if game.attack_cooldown <= 0.0:
		fail("keyboard strike did not reach combat")
		return

	# Pause/resume must scrub transient input and remain symmetrical on keyboard.
	game.touch_move_id = 8
	game.touch_move = Vector2.RIGHT
	send(router, key_event(KEY_ESCAPE))
	if not game.paused:
		fail("keyboard Escape did not pause")
		return
	if game.touch_move_id != -1 or game.touch_move != Vector2.ZERO:
		fail("keyboard pause did not clear transient movement")
		return
	send(router, key_event(KEY_ESCAPE))
	if game.paused:
		fail("keyboard Escape did not resume")
		return

	# Controller pause/resume is owned by the same router.
	send(router, joy_button(JOY_BUTTON_START))
	if not game.paused:
		fail("controller Start did not pause")
		return
	send(router, joy_button(JOY_BUTTON_B))
	if game.paused:
		fail("controller B did not resume from pause")
		return

	# Controller face buttons route to the combat kit without the old adapter.
	game.attack_cooldown = 0.0
	send(router, joy_button(JOY_BUTTON_A))
	if game.attack_cooldown <= 0.0:
		fail("controller A did not strike")
		return

	# Breaker press/release is centralized for both keyboard and controller.
	game.current_act = 2
	GameState.act = 2
	game.attack_cooldown = 0.0
	game.player_charge = 100.0
	var breaker = game.get_node_or_null("BreakerController")
	if breaker == null:
		fail("BreakerController missing")
		return
	send(router, key_event(KEY_Q, true))
	if not breaker.charging:
		fail("keyboard Q did not begin Breaker charge")
		return
	breaker.charge_time = 0.40
	var before_keyboard_breaker: float = game.player_charge
	send(router, key_event(KEY_Q, false))
	if breaker.charging or game.player_charge >= before_keyboard_breaker:
		fail("keyboard Q release did not fire Breaker")
		return

	game.attack_cooldown = 0.0
	game.player_charge = 100.0
	send(router, joy_button(JOY_BUTTON_LEFT_SHOULDER, true))
	if not breaker.charging:
		fail("controller left shoulder did not begin Breaker charge")
		return
	breaker.charge_time = 0.40
	var before_controller_breaker: float = game.player_charge
	send(router, joy_button(JOY_BUTTON_LEFT_SHOULDER, false))
	if breaker.charging or game.player_charge >= before_controller_breaker:
		fail("controller shoulder release did not fire Breaker")
		return

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun desktop input smoke passed")
	get_tree().quit(0)
