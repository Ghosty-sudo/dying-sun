extends Node

func fail(message: String) -> void:
	push_error("ACT3_SECTOR_SMOKE FAILED: " + message)
	get_tree().quit(1)

func enemy_hp_total(game) -> int:
	var total := 0
	for enemy in game.enemies:
		total += int(enemy.get("hp", 0))
	return total

func _ready() -> void:
	await get_tree().process_frame
	SaveManager.clear_campaign()
	GameState.reset_campaign()
	GameState.set_checkpoint("black_relay_start", 3)
	SaveManager.save_campaign()

	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		fail("could not load main scene")
		return
	var game = packed.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.ui_mode = "play"
	game.current_act = 3
	game.begin_act_from_checkpoint()
	await get_tree().process_frame

	var director = game.get_node_or_null("Act3Director")
	if director == null:
		fail("Act3Director missing from main scene")
		return
	if str(game.stage) != "sector_relay_entry" or not game.enemies.is_empty():
		fail("Act III did not replace generic wave_a with relay traversal")
		return

	game.player_pos = Vector2(205, 180)
	await get_tree().process_frame
	if str(game.stage) != "sector_relay_sync" or int(director.relay_index) != 0:
		fail("relay entry did not reach routing-spine sync")
		return

	for expected_completed in range(1, 4):
		game.player_pos = director.RELAY_NODES[int(director.relay_index)]
		director.relay_hold = director.RELAY_HOLD_GOAL
		await get_tree().process_frame
		if expected_completed < 3:
			if str(game.stage) != "sector_relay_sync" or int(director.relay_index) != expected_completed:
				fail("relay sync did not advance node %d" % expected_completed)
				return

	if str(game.stage) != "choice" or not game.dialogue_open:
		fail("three routed relays did not lead to the Black Relay choice")
		return
	if not GameState.has_flag("black_relay_spine_online"):
		fail("routing-spine completion was not persisted")
		return

	# Civilian route: the objective is escort, not enemy clearance. The defense
	# grid stays dark and Relay Saint arrives at full integrity.
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	if not game.choice_pending:
		fail("Black Relay dialogue did not expose route choice")
		return
	game.choose_path(1)
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	await get_tree().process_frame
	if not GameState.has_flag("civilian_grid_preserved"):
		fail("civilian routing choice did not persist")
		return
	if str(game.stage) != "sector_civilian_feed":
		fail("civilian choice did not become an escort objective")
		return

	director.escort_pos = Vector2(director.RELAY_EXIT_X, 180)
	await get_tree().process_frame
	if str(game.stage) != "boss" or str(game.boss_name) != "RELAY SAINT":
		fail("civilian feed did not reach Relay Saint")
		return
	if game.enemies.size() != 1 or int(game.enemies[0].get("hp", 0)) != 28:
		fail("civilian route should face Relay Saint at full integrity")
		return
	if not GameState.has_flag("civilian_feed_completed"):
		fail("civilian feed completion was not persisted")
		return

	# Defense route: the lattice should actively damage threats during the push
	# and visibly cut Relay Saint's starting health rather than only changing copy.
	game.enemies.clear()
	game.projectiles.clear()
	game.dialogue_open = false
	game.module_pending = false
	game.dead = false
	GameState.flags.erase("civilian_grid_preserved")
	GameState.flags.erase("civilian_feed_completed")
	GameState.set_flag("defense_lattice_powered")
	game.stage = "wave_b"
	await get_tree().process_frame
	if str(game.stage) != "sector_defense_push" or game.enemies.size() < 3:
		fail("defense choice did not become a lattice-supported push")
		return

	var before_hp := enemy_hp_total(game)
	director.defense_pulse = 0.0
	director.update_defense_push(game, 0.10)
	var after_hp := enemy_hp_total(game)
	if after_hp >= before_hp:
		fail("powered defense lattice did not mechanically assist combat")
		return

	director.route_elapsed = director.DEFENSE_MIN_TIME
	game.player_pos = Vector2(570, 180)
	await get_tree().process_frame
	if str(game.stage) != "boss" or str(game.boss_name) != "RELAY SAINT":
		fail("defense push did not reach Relay Saint")
		return
	if game.enemies.size() != 1:
		fail("Relay Saint boss state malformed after defense push")
		return
	if int(game.enemies[0].get("hp", 0)) != 24 or int(game.enemies[0].get("max_hp", 0)) != 28:
		fail("defense lattice consequence did not visibly cut Relay Saint's shield")
		return
	if not GameState.has_flag("defense_push_completed"):
		fail("defense push completion was not persisted")
		return

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun authored Act III sector smoke passed")
	get_tree().quit(0)
