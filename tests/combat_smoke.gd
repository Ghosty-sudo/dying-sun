extends SceneTree

func fail(message: String) -> void:
	push_error("COMBAT_SMOKE FAILED: " + message)
	quit(1)

func _init() -> void:
	var packed = load("res://scenes/main.tscn")
	if packed == null:
		fail("could not load main scene")
		return
	var game = packed.instantiate()
	root.add_child(game)
	var breaker = game.get_node_or_null("BreakerController")
	if breaker == null:
		fail("BreakerController missing from main scene")
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

	game.free()
	print("Dying Sun combat kit smoke passed")
	quit(0)
