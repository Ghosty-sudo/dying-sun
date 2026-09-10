extends Node

func fail(message: String) -> void:
	push_error("ACT4_SECTOR_SMOKE FAILED: " + message)
	get_tree().quit(1)

func set_habit_counts(director, strike: int, boost: int, deflect: int, breaker: int) -> void:
	director.strike_uses = strike
	director.boost_uses = boost
	director.deflect_uses = deflect
	director.breaker_uses = breaker

func _ready() -> void:
	await get_tree().process_frame
	SaveManager.clear_campaign()
	GameState.reset_campaign()
	GameState.record_relationship("defiance", 2)
	GameState.set_checkpoint("crown_engine_start", 4)
	SaveManager.save_campaign()

	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		fail("could not load main scene")
		return
	var game = packed.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.ui_mode = "play"
	game.current_act = 4
	game.begin_act_from_checkpoint()
	await get_tree().process_frame

	var director = game.get_node_or_null("Act4Director")
	if director == null:
		fail("Act4Director missing from main scene")
		return
	if str(game.stage) != "sector_crown_entry" or not game.enemies.is_empty():
		fail("Act IV did not replace generic wave_a with Crown Engine traversal")
		return

	game.player_pos = Vector2(205, 180)
	await get_tree().process_frame
	if str(game.stage) != "sector_crown_audit" or int(director.truth_index) != 0:
		fail("Crown entry did not reach testimony audit")
		return
	if "AUTHORITY: SOL" not in str(director.truth_line(0)):
		fail("defiant relationship state did not expose machine-record testimony")
		return

	for expected_completed in range(1, 4):
		game.player_pos = director.TRUTH_NODES[int(director.truth_index)]
		director.truth_hold = director.TRUTH_HOLD_GOAL
		await get_tree().process_frame
		if expected_completed < 3 and int(director.truth_index) != expected_completed:
			fail("Crown testimony did not advance witness %d" % expected_completed)
			return

	if str(game.stage) != "choice" or not game.dialogue_open or not GameState.has_flag("crown_audit_complete"):
		fail("Crown audit did not reach the record decision")
		return

	# OPEN route: extract evidence under the rotating Crown scan. The evidence
	# should expose a real boss break point, and a strike-heavy player should
	# receive the strike counterprofile.
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	if not game.choice_pending:
		fail("Crown dialogue did not expose OPEN/FOLLOW choice")
		return
	game.choose_path(1)
	game.dialogue_index = game.dialogue_lines.size() - 1
	game.try_interact()
	await get_tree().process_frame
	if not GameState.has_flag("crown_truth_found") or str(game.stage) != "sector_record_extraction":
		fail("OPEN choice did not become Crown proof extraction")
		return

	set_habit_counts(director, 5, 1, 1, 0)
	for expected_completed in range(1, 3):
		game.player_pos = director.RECORD_NODES[int(director.record_index)]
		director.record_hold = director.RECORD_HOLD_GOAL
		await get_tree().process_frame
		if expected_completed < 2 and int(director.record_index) != expected_completed:
			fail("Crown proof extraction did not advance record %d" % expected_completed)
			return

	if str(game.stage) != "boss" or str(game.boss_name) != "CROWN CUSTODIAN":
		fail("OPEN route did not reach Crown Custodian")
		return
	if str(director.counter_profile) != "strike":
		fail("strike-heavy history did not produce strike counterprofile")
		return
	if game.enemies.size() != 1 or float(game.enemies[0].get("stagger", 0.0)) < 3.9:
		fail("extracted Crown proof did not expose a boss break point")
		return
	if not GameState.has_flag("crown_record_extracted"):
		fail("Crown proof extraction state was not persisted")
		return

	var hp_before := game.player_hp
	game.player_pos = Vector2(game.enemies[0]["pos"]) + Vector2(40, 0)
	game.hurt_cooldown = 0.0
	game.dash_time = 0.0
	director.counter_clock = 0.0
	director.update_crown_countermeasure(game, 0.05)
	if game.player_hp >= hp_before:
		fail("strike counterprofile did not punish close-pressure habit")
		return

	# FOLLOW route: defer the record, receive charge overdrive, and verify that
	# Breaker-heavy history makes the Custodian phase away from a committed charge.
	game.enemies.clear()
	game.projectiles.clear()
	game.dialogue_open = false
	game.module_pending = false
	game.dead = false
	game.player_hp = game.max_hp()
	GameState.flags.erase("crown_truth_found")
	GameState.flags.erase("crown_record_extracted")
	GameState.flags.erase("crown_counter_profile")
	GameState.set_flag("crown_truth_deferred")
	game.stage = "wave_b"
	await get_tree().process_frame
	if str(game.stage) != "sector_crown_overdrive":
		fail("FOLLOW choice did not become the overdrive traversal")
		return

	game.player_charge = 0.0
	var charge_before := game.player_charge
	director.update_overdrive_route(game, 0.5)
	if game.player_charge <= charge_before:
		fail("Sol overdrive did not mechanically replenish Frame Charge")
		return

	set_habit_counts(director, 0, 0, 0, 4)
	director.route_elapsed = director.OVERDRIVE_MIN_TIME
	game.player_pos = Vector2(570, 180)
	await get_tree().process_frame
	if str(game.stage) != "boss" or str(director.counter_profile) != "breaker":
		fail("Breaker-heavy history did not become boss counterprofile")
		return
	if game.player_charge != game.max_charge():
		fail("FOLLOW route did not enter boss with Sol overdrive charged")
		return

	var breaker = game.get_node_or_null("BreakerController")
	if breaker == null:
		fail("BreakerController missing for Crown adaptation test")
		return
	var boss_before: Vector2 = game.enemies[0]["pos"]
	breaker.charging = true
	breaker.charge_time = 0.55
	director.breaker_phase_cooldown = 0.0
	director.update_crown_countermeasure(game, 0.05)
	var boss_after: Vector2 = game.enemies[0]["pos"]
	if boss_after.is_equal_approx(boss_before):
		fail("Breaker counterprofile did not phase away from committed charge")
		return
	breaker.charging = false

	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun authored Act IV sector smoke passed")
	get_tree().quit(0)
