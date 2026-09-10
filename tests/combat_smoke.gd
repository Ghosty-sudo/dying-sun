extends Node

func fail(message: String) -> void:
	push_error("COMBAT_SMOKE FAILED: " + message)
	get_tree().quit(1)

func joy_button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event

func _ready() -> void:
	SaveManager.clear_campaign()
	GameState.reset_campaign()
	var packed = load("res://scenes/main.tscn")
	if packed == null:
		fail("could not load main scene")
		return
	var game = packed.instantiate()
	get_tree().root.add_child(game)
	var breaker = game.get_node_or_null("BreakerController")
	var controller = game.get_node_or_null("ControllerAdapter")
	if breaker == null:
		fail("BreakerController missing from main scene")
		game.free()
		return
	if controller == null:
		fail("ControllerAdapter missing from main scene")
		game.free()
		return

	game.ui_mode = "play"
	game.current_act = 1
	if breaker.breaker_available():
		fail("breaker available before Act II")
		game.free()
		return

	game.current_act = 2
	if not breaker.breaker_available():
		fail("breaker unavailable in Act II")
		game.free()
		return

	game.player_pos = Vector2(100.0, 180.0)
	game.last_move = Vector2.RIGHT
	game.player_charge = 100.0
	game.enemies = [game.make_enemy(Vector2(160.0, 180.0), 10, "WARDEN")]
	breaker.perform_breaker(0.82)

	if absf(game.player_charge - 82.0) > 0.01:
		fail("breaker did not consume expected Frame Charge")
		game.free()
		return
	if game.enemies.size() != 1 or int(game.enemies[0]["hp"]) != 5:
		fail("full breaker did not deal expected damage")
		game.free()
		return
	if float(game.enemies[0]["stunned"]) <= 0.0:
		fail("breaker did not trigger expected stagger break")
		game.free()
		return
	if game.attack_cooldown <= 0.0:
		fail("breaker did not commit attack recovery")
		game.free()
		return

	game.paused = false
	controller._input(joy_button(JOY_BUTTON_START))
	if not game.paused:
		fail("standard controller Start did not pause")
		game.free()
		return
	controller._input(joy_button(JOY_BUTTON_START))
	if game.paused:
		fail("standard controller Start did not resume")
		game.free()
		return

	GameState.reset_campaign()
	game.current_act = 1
	game.stage = "choice"
	game.choice_pending = true
	game.dialogue_open = true
	controller._input(joy_button(JOY_BUTTON_A))
	if game.choice_pending or not GameState.has_flag("first_contact_trust"):
		fail("controller A did not resolve the left narrative choice")
		game.free()
		return

	GameState.reset_campaign()
	game.current_act = 1
	game.stage = "choice"
	game.choice_pending = true
	game.dialogue_open = true
	controller._input(joy_button(JOY_BUTTON_B))
	if game.choice_pending or not GameState.has_flag("first_contact_defiance"):
		fail("controller B did not resolve the right narrative choice")
		game.free()
		return

	GameState.reset_campaign()
	game.current_act = 1
	game.stage = "module"
	game.choice_pending = false
	game.dialogue_open = false
	game.module_pending = true
	game.module_choices.clear()
	game.module_choices.append({"id": "impact_servo", "name": "Impact Servo", "desc": "test"})
	game.module_choices.append({"id": "phase_coil", "name": "Phase Coil", "desc": "test"})
	game.dash_cooldown = 0.0
	controller._input(joy_button(JOY_BUTTON_B))
	if not GameState.has_module("phase_coil") or game.current_act != 2:
		fail("controller B did not install the right module option")
		game.free()
		return
	if game.dash_cooldown < 0.11:
		fail("module choice did not suppress same-event boost bleed")
		game.free()
		return

	game.free()
	print("Dying Sun combat kit smoke passed")
	get_tree().quit(0)
