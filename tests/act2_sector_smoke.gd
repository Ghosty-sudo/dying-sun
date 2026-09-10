extends Node

func fail(message: String) -> void:
	push_error("ACT2_SECTOR_SMOKE FAILED: " + message)
	get_tree().quit(1)

func _ready() -> void:
	await get_tree().process_frame
	SaveManager.clear_campaign()
	GameState.reset_campaign()
	GameState.set_checkpoint("memory_works_start", 2)
	SaveManager.save_campaign()

	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		fail("could not load main scene")
		return
	var game = packed.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.ui_mode = "play"
	game.current_act = 2
	game.begin_act_from_checkpoint()
	await get_tree().process_frame

	var director = game.get_node_or_null("SectorDirector")
	var breaker = game.get_node_or_null("BreakerController")
	if director == null or breaker == null:
		fail("Act II requires SectorDirector and BreakerController")
		return
	if str(game.stage) != "sector_memory_entry" or not game.enemies.is_empty():
		fail("Act II did not replace generic wave_a with Memory Works traversal")
		return

	game.player_pos = Vector2(300, 180)
	await get_tree().process_frame
	if str(game.stage) != "sector_memory_seal" or game.enemies.size() != 1:
		fail("Memory Works entry did not reach the Breaker seal")
		return
	if str(game.enemies[0].get("kind", "")) != "MEMORY-SEAL":
		fail("Act II traversal gate is not the intended memory seal")
		return

	# The tutorial rule must be truthful: a normal strike cannot satisfy the seal.
	game.player_pos = Vector2(340, 180)
	game.last_move = Vector2.RIGHT
	game.perform_attack()
	await get_tree().process_frame
	if str(game.stage) != "sector_memory_seal" or bool(director.memory_seal_unlocked):
		fail("ordinary strike incorrectly satisfied the Breaker-only Index Seal")
		return
	if game.enemies.is_empty() or int(game.enemies[0].get("hp", 0)) < 90:
		fail("Index Seal is not resistant enough to ordinary combat")
		return

	game.attack_cooldown = 0.0
	game.player_pos = Vector2(330, 180)
	game.last_move = Vector2.RIGHT
	game.player_charge = 100.0
	breaker.perform_breaker(0.82)
	await get_tree().process_frame
	if str(game.stage) != "sector_memory_gallery" or game.enemies.size() != 2:
		fail("Breaker did not open the index seal into the memory gallery")
		return
	var kinds := [str(game.enemies[0].get("kind", "")), str(game.enemies[1].get("kind", ""))]
	if not kinds.has("WARDEN") or not kinds.has("ARCHIVIST"):
		fail("memory gallery did not stage its mixed pressure encounter")
		return

	director.memory_grace = 0.0
	director.memory_suppression = 0.0
	game.attack_cooldown = 0.0
	game.player_charge = 100.0
	breaker.perform_breaker(0.82)
	if float(director.memory_suppression) <= 1.0:
		fail("Breaker did not suppress Memory Works field hazards")
		return

	game.enemies.clear()
	await get_tree().process_frame
	if str(game.stage) != "choice" or not game.dialogue_open:
		fail("memory gallery did not lead to the archive decision")
		return

	game.choice_pending = true
	game.choose_path(1)
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	await get_tree().process_frame
	if not GameState.has_flag("archive_preserved"):
		fail("preserve choice did not persist archive state")
		return
	if str(game.stage) != "sector_archive_hold":
		fail("preserve choice did not branch into the index-core hold objective")
		return

	game.player_pos = director.MEMORY_CORE_POS
	director.archive_hold = director.ARCHIVE_HOLD_GOAL
	await get_tree().process_frame
	if str(game.stage) != "boss" or str(game.boss_name) != "THE ARCHIVIST":
		fail("preserve route did not reach The Archivist")
		return
	if game.enemies.size() != 1 or int(game.enemies[0].get("hp", 0)) != 24:
		fail("preserved archive should leave The Archivist at full integrity")
		return

	game.enemies.clear()
	game.projectiles.clear()
	game.dialogue_open = false
	game.module_pending = false
	game.dead = false
	GameState.flags.erase("archive_preserved")
	GameState.flags.erase("archive_hold_completed")
	GameState.set_flag("archive_burned")
	game.stage = "wave_b"
	await get_tree().process_frame
	if str(game.stage) != "sector_purge_run":
		fail("burn choice did not branch into the purge-run objective")
		return
	if game.enemies.size() != 1 or str(game.enemies[0].get("kind", "")) != "SUN-HUSK":
		fail("purge route did not stage its pursuing threat")
		return

	game.player_pos = Vector2(570, 180)
	await get_tree().process_frame
	if str(game.stage) != "boss" or str(game.boss_name) != "THE ARCHIVIST":
		fail("purge run did not reach The Archivist")
		return
	if game.enemies.size() != 1 or int(game.enemies[0].get("hp", 0)) != 21:
		fail("burn route did not carry its immediate cost/advantage into the boss")
		return

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun authored Act II sector smoke passed")
	get_tree().quit(0)
