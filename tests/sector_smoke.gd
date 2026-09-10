extends Node

func fail(message: String) -> void:
	push_error("SECTOR_SMOKE FAILED: " + message)
	get_tree().quit(1)

func _ready() -> void:
	await get_tree().process_frame
	SaveManager.clear_campaign()
	GameState.reset_campaign()
	var packed = load("res://scenes/main.tscn")
	if packed == null:
		fail("could not load main scene")
		return
	var game = packed.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.start_new_game()
	await get_tree().process_frame

	var director = game.get_node_or_null("SectorDirector")
	if director == null:
		fail("SectorDirector missing from main scene")
		return
	if str(game.stage) != "sector_intake_walk" or not game.enemies.is_empty():
		fail("Act I did not begin as traversal instead of a generic wave")
		return

	game.player_pos = Vector2(500, 182)
	await get_tree().process_frame
	if str(game.stage) != "sector_furnace" or game.enemies.size() != 1:
		fail("crossing the intake seal did not enter the single-target furnace lesson")
		return
	if str(game.enemies[0].get("kind", "")) != "WARDEN":
		fail("first furnace threat is not the intended melee Warden")
		return
	if int(director.furnace_phase) != 0 or director.furnace_hot():
		fail("furnace hazard activated during the first combat lesson")
		return

	game.enemies.clear()
	await get_tree().process_frame
	if str(game.stage) != "sector_furnace" or game.enemies.size() != 1:
		fail("first furnace clear did not stage the second threat")
		return
	if str(game.enemies[0].get("kind", "")) != "HUSK" or int(game.enemies[0].get("hp", 0)) != 3:
		fail("second furnace threat is not the tuned ranged Husk")
		return
	if int(director.furnace_phase) != 1 or float(director.furnace_grace) <= 0.0 or director.furnace_hot():
		fail("furnace vents did not preserve their arming grace period")
		return

	game.enemies.clear()
	await get_tree().process_frame
	if str(game.stage) != "sector_coolant" or game.enemies.size() != 2:
		fail("second furnace clear did not advance to the coolant bridge")
		return

	game.enemies.clear()
	await get_tree().process_frame
	if str(game.stage) != "choice" or not game.dialogue_open:
		fail("coolant bridge did not advance into the Sol decision")
		return

	game.choice_pending = true
	game.choose_path(1)
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	await get_tree().process_frame
	if str(game.stage) != "sector_gate_approach" or game.enemies.size() != 4:
		fail("post-choice progression did not enter the four-enemy gate approach")
		return

	game.enemies.clear()
	await get_tree().process_frame
	if str(game.stage) != "sector_gate_pressure" or game.enemies.size() != 2:
		fail("gate approach did not advance to the custodian antechamber")
		return

	game.enemies.clear()
	await get_tree().process_frame
	if str(game.stage) != "boss" or str(game.boss_name) != "GATE CUSTODIAN" or game.enemies.size() != 1:
		fail("antechamber did not advance to the Act I boss")
		return

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun authored Act I sector smoke passed")
	get_tree().quit(0)
