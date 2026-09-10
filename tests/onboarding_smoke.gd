extends Node

func fail(message: String) -> void:
	push_error("ONBOARDING_SMOKE FAILED: " + message)
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
	get_tree().root.add_child(game)
	var onboarding = game.get_node_or_null("OnboardingController")
	if onboarding == null:
		fail("OnboardingController missing from main scene")
		game.free()
		return

	game.ui_mode = "play"
	game.current_act = 1
	game.stage = "wave_a"
	game.paused = false
	game.dead = false
	game.dialogue_open = false
	game.module_pending = false
	game.act_banner_time = 0.0
	game.player_pos = Vector2(92.0, 182.0)
	onboarding._process(0.016)
	if onboarding.prompt_id() != "move":
		fail("orientation did not begin with movement")
		game.free()
		return

	game.player_pos += Vector2(24.0, 0.0)
	onboarding._process(0.016)
	if not onboarding.saw_move or onboarding.prompt_id() != "strike":
		fail("movement did not advance orientation to strike")
		game.free()
		return

	game.attack_time = 0.20
	onboarding._process(0.016)
	if not onboarding.saw_strike or onboarding.prompt_id() != "boost":
		fail("strike did not advance orientation to boost")
		game.free()
		return

	game.dash_time = 0.10
	onboarding._process(0.016)
	if not onboarding.saw_boost or onboarding.prompt_id() != "deflect":
		fail("boost did not advance orientation to deflect")
		game.free()
		return

	game.deflect_time = 0.10
	onboarding._process(0.016)
	if not onboarding.saw_deflect or not onboarding.orientation_complete():
		fail("deflect did not complete orientation")
		game.free()
		return
	if not GameState.has_flag("combat_orientation_complete"):
		fail("orientation completion flag missing")
		game.free()
		return

	GameState.reset_campaign()
	if not SaveManager.load_campaign() or not GameState.has_flag("combat_orientation_complete"):
		fail("orientation completion did not persist through save/load")
		game.free()
		return

	game.free()
	print("Dying Sun Act I onboarding smoke passed")
	get_tree().quit(0)
