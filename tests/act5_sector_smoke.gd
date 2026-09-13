extends Node

func fail(message: String) -> void:
	push_error("ACT5_SECTOR_SMOKE FAILED: " + message)
	get_tree().quit(1)

func advance_to_choice(game) -> bool:
	if game.dialogue_lines.is_empty():
		fail("expected Act V pre-choice dialogue")
		return false
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	if not game.choice_pending:
		fail("Act V dialogue did not expose STAY/SEVER choice")
		return false
	return true

func close_choice_result(game) -> bool:
	if game.dialogue_lines.is_empty():
		fail("expected Act V result dialogue")
		return false
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	if str(game.stage) != "wave_b":
		fail("Act V choice result did not return to route handoff")
		return false
	await get_tree().process_frame
	return true

func prepare_last_light(flags: Array[String], trust: int, defiance: int, curiosity: int):
	SaveManager.clear_campaign()
	GameState.reset_campaign()
	for flag in flags:
		GameState.set_flag(flag)
	if trust > 0: GameState.record_relationship("trust", trust)
	if defiance > 0: GameState.record_relationship("defiance", defiance)
	if curiosity > 0: GameState.record_relationship("curiosity", curiosity)
	GameState.set_checkpoint("last_light_start", 5)
	SaveManager.save_campaign()
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		fail("could not load main scene")
		return null
	var game = packed.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.ui_mode = "play"
	game.current_act = 5
	game.begin_act_from_checkpoint()
	await get_tree().process_frame
	return game

func reach_final_choice(game, director) -> bool:
	if str(game.stage) != "sector_last_light_entry":
		fail("Act V did not replace generic wave_a with Last Light descent")
		return false
	game.player_pos = Vector2(205, 180)
	await get_tree().process_frame
	if str(game.stage) != "sector_echo_convergence":
		fail("Last Light entry did not reach echo convergence")
		return false
	for expected in range(1, 4):
		game.player_pos = director.ECHO_NODES[int(director.echo_index)]
		director.echo_hold = director.ECHO_HOLD_GOAL
		await get_tree().process_frame
		if expected < 3 and int(director.echo_index) != expected:
			fail("echo convergence did not advance echo %d" % expected)
			return false
	if str(game.stage) != "choice" or not GameState.has_flag("last_light_echoes_resolved"):
		fail("echo convergence did not reach final relational choice")
		return false
	return advance_to_choice(game)

func run_stay_route() -> bool:
	var game = await prepare_last_light(["archive_preserved", "civilian_grid_preserved", "crown_truth_found", "sol_core_recovered"], 2, 0, 2)
	if game == null: return false
	var director = game.get_node_or_null("Act5Director")
	if director == null:
		fail("Act V director missing")
		return false
	if not await reach_final_choice(game, director): return false
	game.choose_path(1)
	if not await close_choice_result(game): return false
	if str(game.stage) != "sector_shared_descent" or not GameState.has_flag("final_together"):
		fail("STAY choice did not become shared descent")
		return false
	game.player_charge = 0.0
	game.player_pos = director.link_pos
	director.link_pulse_clock = 0.0
	director.update_shared_descent(game, 0.10)
	if game.player_charge <= 0.0:
		fail("Sol core link did not restore Frame Charge")
		return false
	director.link_pos = Vector2(director.CORE_EXIT_X, 180)
	game.player_pos = director.link_pos
	director.update_shared_descent(game, 0.05)
	if str(game.stage) != "boss" or str(game.boss_name) != "LAST LIGHT":
		fail("shared descent did not reach Last Light boss")
		return false
	if not GameState.has_flag("last_light_link_carried") or not bool(director.reconciliation_ready):
		fail("STAY route did not carry its earned reconciliation state into boss")
		return false
	game.player_charge = 0.0
	director.boss_support_clock = 0.0
	director.update_last_light_boss(game, 0.05)
	if game.player_charge <= 0.0:
		fail("Sol did not mechanically assist during STAY boss route")
		return false
	game.queue_free()
	await get_tree().process_frame
	return true

func run_sever_route() -> bool:
	var game = await prepare_last_light(["archive_burned", "defense_lattice_powered", "crown_truth_deferred"], 0, 2, 0)
	if game == null: return false
	var director = game.get_node_or_null("Act5Director")
	if director == null:
		fail("Act V director missing on SEVER route")
		return false
	if not await reach_final_choice(game, director): return false
	game.choose_path(2)
	if not await close_choice_result(game): return false
	if str(game.stage) != "sector_sever_spine" or not GameState.has_flag("final_sever"):
		fail("SEVER choice did not become authority-lock route")
		return false
	for expected in range(1, 4):
		game.player_pos = director.SEVER_NODES[int(director.sever_index)]
		director.try_sever_lock(game, 1.0)
		if expected < 3 and int(director.sever_index) != expected:
			fail("authority lock %d did not sever" % expected)
			return false
	if str(game.stage) != "boss" or not GameState.has_flag("last_light_authority_severed"):
		fail("SEVER route did not reach boss with authority removed")
		return false
	if game.enemies.is_empty() or float(game.enemies[0].get("stagger", 0.0)) < 2.9:
		fail("severed authority did not expose Last Light break state")
		return false
	var before_stagger := float(game.enemies[0].get("stagger", 0.0))
	director.boss_fracture_clock = 0.0
	director.update_last_light_boss(game, 0.05)
	if float(game.enemies[0].get("stagger", 0.0)) <= before_stagger:
		fail("SEVER route did not desynchronize Last Light during boss")
		return false
	game.queue_free()
	await get_tree().process_frame
	return true

func _ready() -> void:
	await get_tree().process_frame
	if not await run_stay_route(): return
	if not await run_sever_route(): return
	SaveManager.clear_campaign()
	print("Dying Sun authored Act V sector smoke passed")
	get_tree().quit(0)