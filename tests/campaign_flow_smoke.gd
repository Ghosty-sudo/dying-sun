extends SceneTree

func fail(message: String) -> void:
	push_error("CAMPAIGN_FLOW FAILED: " + message)
	quit(1)

func game_state():
	var state = root.get_node_or_null("GameState")
	if state == null:
		fail("GameState autoload missing from /root")
	return state

func save_manager():
	var manager = root.get_node_or_null("SaveManager")
	if manager == null:
		fail("SaveManager autoload missing from /root")
	return manager

func advance_dialogue_to_choice(game) -> void:
	if game.dialogue_lines.is_empty():
		fail("expected pre-choice dialogue")
		return
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	if not game.choice_pending:
		fail("choice did not become pending")

func close_result_dialogue(game) -> void:
	if game.dialogue_lines.is_empty():
		fail("expected result dialogue")
		return
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	if game.stage != "wave_b":
		fail("choice result did not advance to wave_b")

func close_act_dialogue(game) -> void:
	if game.dialogue_lines.is_empty():
		fail("expected act-complete dialogue")
		return
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()

func clear_current_encounter(game) -> void:
	game.enemies.clear()
	game.projectiles.clear()
	game.check_encounter_progression()

func run_branch(choices: Array[int], module_index: int, expected_ending: String) -> bool:
	var save = save_manager()
	var state = game_state()
	if save == null or state == null:
		return false
	save.clear_campaign()
	state.reset_campaign()
	var packed = load("res://scenes/main.tscn")
	if packed == null:
		fail("could not load main scene")
		return false
	var game = packed.instantiate()
	root.add_child(game)
	game.start_new_game()

	for act_number in range(1, 6):
		if game.current_act != act_number:
			fail("expected act %d, got %d" % [act_number, game.current_act])
			game.queue_free()
			return false

		clear_current_encounter(game)
		if game.stage != "choice":
			fail("act %d did not reach narrative choice" % act_number)
			game.queue_free()
			return false
		advance_dialogue_to_choice(game)
		game.choose_path(choices[act_number - 1])
		close_result_dialogue(game)

		clear_current_encounter(game)
		if game.stage != "boss" or game.enemies.size() != 1:
			fail("act %d did not spawn boss" % act_number)
			game.queue_free()
			return false

		clear_current_encounter(game)
		if game.stage != "act_complete":
			fail("act %d did not complete after boss" % act_number)
			game.queue_free()
			return false
		close_act_dialogue(game)

		if act_number < 5:
			if not game.module_pending or game.module_choices.size() != 2:
				fail("act %d did not offer two frame modules" % act_number)
				game.queue_free()
				return false
			game.choose_module(module_index)

	if game.ui_mode != "ending":
		fail("campaign did not enter ending mode")
		game.queue_free()
		return false
	if game.ending_id != expected_ending:
		fail("expected ending %s, got %s" % [expected_ending, game.ending_id])
		game.queue_free()
		return false
	if not state.has_flag("campaign_complete"):
		fail("campaign completion flag missing")
		game.queue_free()
		return false

	game.queue_free()
	return true

func _init() -> void:
	if not run_branch([1, 1, 1, 1, 1], 0, "reconciliation"):
		return
	if not run_branch([2, 2, 2, 2, 2], 1, "sever_system"):
		return
	print("Dying Sun full campaign branch smoke passed")
	quit(0)
