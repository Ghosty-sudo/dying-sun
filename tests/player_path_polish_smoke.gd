extends Node

func fail(message: String) -> void:
	push_error("PLAYER_PATH_POLISH FAILED: " + message)
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

	var polish = game.get_node_or_null("PlayerPathPolish")
	if polish == null:
		fail("PlayerPathPolish missing from main scene")
		return

	var opening_objective := str(polish.objective_text(game))
	if "INNER SEAL" not in opening_objective:
		fail("opening authored traversal lacks persistent player direction")
		return

	game.current_act = 2
	game.stage = "sector_memory_seal"
	var breaker_objective := str(polish.objective_text(game))
	if "BREAKER REQUIRED" not in breaker_objective or "Q / LB / BRK" not in breaker_objective:
		fail("Breaker gate does not explain the required cross-input control")
		return

	game.current_act = 3
	game.stage = "sector_relay_entry"
	var relay_objective := str(polish.objective_text(game))
	if "ROUTING SPINE" not in relay_objective:
		fail("Act III authored traversal lacks persistent objective text")
		return

	# The mobile Web surface must have an explicit pause affordance instead of
	# relying on a keyboard-only escape path.
	game.current_act = 1
	game.stage = "sector_intake_walk"
	game.touch_mode = true
	game.paused = false
	var pause_touch := InputEventScreenTouch.new()
	pause_touch.index = 11
	pause_touch.position = polish.TOUCH_PAUSE_CENTER
	pause_touch.pressed = true
	polish._input(pause_touch)
	if not game.paused:
		fail("touch pause affordance did not pause gameplay")
		return

	game.player_hp = 1
	var restart_touch := InputEventScreenTouch.new()
	restart_touch.index = 12
	restart_touch.position = polish.TOUCH_RESTART_RECT.get_center()
	restart_touch.pressed = true
	polish._input(restart_touch)
	if game.paused:
		fail("touch checkpoint restart left game paused")
		return
	if game.player_hp != game.max_hp():
		fail("touch checkpoint restart did not restore player state")
		return

	# Paused controller recovery should not require navigating back to title.
	game.player_hp = 1
	game.paused = true
	var controller_restart := InputEventJoypadButton.new()
	controller_restart.button_index = JOY_BUTTON_Y
	controller_restart.pressed = true
	polish._input(controller_restart)
	if game.paused or game.player_hp != game.max_hp():
		fail("controller Y checkpoint restart failed from pause")
		return

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun player-path polish smoke passed")
	get_tree().quit(0)
