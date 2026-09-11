extends Node

func fail(message: String) -> void:
	push_error("WEB_STABILITY FAILED: " + message)
	get_tree().quit(1)

func _ready() -> void:
	await get_tree().process_frame
	print("WEB_STABILITY // START")
	SaveManager.clear_campaign()
	GameState.reset_campaign()

	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		fail("main scene did not load")
		return
	var game = packed.instantiate()
	add_child(game)
	await get_tree().process_frame

	game.ui_mode = "play"
	game.paused = false
	game.dead = false
	game.dialogue_open = false
	game.module_pending = false
	game.current_act = 1
	game.stage = "wave_a"
	game.player_pos = Vector2(110.0, 180.0)
	game.last_move = Vector2.RIGHT

	var melee = game.get_node_or_null("MeleeContactGuard")
	if melee == null:
		fail("MeleeContactGuard missing")
		return

	# Accelerated six-minute projectile/combat churn. This is not a substitute
	# for iOS/WebKit evidence; it is a guard against obvious unbounded runtime
	# growth before another real-device stability check.
	var simulated_seconds := 0.0
	var max_projectiles := 0
	for frame in range(7200):
		var dt := 0.05
		simulated_seconds += dt

		# Sustain multiple projectile streams so expiry/out-of-bounds cleanup is
		# continuously exercised instead of only checking a quiet launch.
		if frame % 2 == 0:
			for lane in range(3):
				var angle := float((frame + lane * 37) % 360) * PI / 180.0
				game.spawn_projectile(Vector2(320.0, 180.0), Vector2.RIGHT.rotated(angle), 135.0 + lane * 18.0, 1, "STRESS")
		game.update_projectiles(dt)
		max_projectiles = maxi(max_projectiles, game.projectiles.size())
		if game.projectiles.size() > 120:
			fail("projectile population grew beyond expected bounded lifetime")
			return

		# Repeatedly exercise normal melee contact and dictionary removal/update
		# without advancing campaign state.
		if frame % 30 == 0:
			game.attack_time = 0.0
			game.attack_cooldown = 0.0
			game.combo_step = 0
			game.combo_window = 0.0
			melee._process(dt)
			game.enemies.clear()
			game.enemies.append(game.make_enemy(Vector2(174.0, 180.0), 3, "WARDEN"))
			game.perform_attack()
			melee._process(dt)
			game.enemies.clear()

	# Procedural audio should reuse a small fixed cache and a fixed player pool,
	# not allocate a new stream/player every combat frame.
	var sfx_ids := ["strike", "impact", "boost", "parry", "hurt", "death", "boss", "signal", "module", "act", "breaker_charge", "breaker", "relay_lock", "relay_pulse", "crown_truth", "crown_phase"]
	for id in sfx_ids:
		for repeat in range(8):
			AudioManager.play_sfx(id)
	if AudioManager.cached_sfx.size() > sfx_ids.size():
		fail("procedural SFX cache grew beyond requested IDs")
		return
	if AudioManager.sfx_players.size() != 6:
		fail("SFX player pool changed size during stress run")
		return

	for act in range(1, 6):
		AudioManager.set_act_ambience(act)
	if AudioManager.cached_ambience.size() > 5:
		fail("ambience cache grew beyond five acts")
		return

	print("WEB_STABILITY // simulated %.1fs // peak projectiles %d" % [simulated_seconds, max_projectiles])
	game.queue_free()
	SaveManager.clear_campaign()
	print("Dying Sun accelerated Web stability smoke passed")
	get_tree().quit(0)
