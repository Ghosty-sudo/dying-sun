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

	# Carry damage into the choice to prove the live first after-choice attempt is
	# stabilized exactly like a checkpoint reload.
	game.player_hp = 1
	game.player_charge = 3.0
	game.choice_pending = true
	game.choose_path(1)
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	await get_tree().process_frame
	if str(game.stage) != "sector_gate_approach" or game.enemies.size() != 3:
		fail("post-choice progression did not enter the tuned three-contact gate approach")
		return
	if game.player_hp != game.max_hp() or game.player_charge < game.max_charge() - 0.01:
		fail("after-choice checkpoint did not stabilize armor and charge on the first attempt")
		return
	if director.gate_hot():
		fail("gate core hazard should remain dormant during the approach lesson")
		return

	game.enemies.clear()
	await get_tree().process_frame
	if str(game.stage) != "sector_gate_pressure" or game.enemies.size() != 2:
		fail("gate approach did not advance to the custodian antechamber")
		return
	if float(director.gate_grace) <= 0.0 or director.gate_hot():
		fail("custodian antechamber did not preserve the gate-core arming grace period")
		return

	game.player_hp = 1
	game.player_charge = 4.0
	game.enemies.clear()
	await get_tree().process_frame
	if str(game.stage) != "boss" or str(game.boss_name) != "GATE CUSTODIAN" or game.enemies.size() != 1:
		fail("antechamber did not advance to the Act I boss")
		return
	if not GameState.has_flag("act1_custodian_checkpoint"):
		fail("Gate Custodian entry did not persist its retry checkpoint")
		return
	if game.player_hp != game.max_hp() or game.player_charge < game.max_charge() - 0.01:
		fail("Gate Custodian checkpoint did not stabilize the first boss attempt")
		return

	# A boss death must return to the boss, not replay Gate Approach + Pressure.
	game.hurt_player(99)
	if not game.dead:
		fail("boss retry test could not kill the player")
		return
	game.restart_from_checkpoint()
	await get_tree().process_frame
	if str(game.stage) != "boss" or str(game.boss_name) != "GATE CUSTODIAN":
		fail("Act I boss retry replayed the gate gauntlet instead of restoring the boss checkpoint")
		return
	if game.player_hp != game.max_hp() or game.player_charge < game.max_charge() - 0.01:
		fail("Act I boss retry did not restore full combat resources")
		return

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun authored Act I sector smoke passed")
	get_tree().quit(0)
