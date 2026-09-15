extends "res://tests/sol_full_playthrough_tactical.gd"

# Final player-policy layer: use Breaker as an actual combat tool instead of
# treating it as an Act II door key. This still presses and releases the live
# touch binding through InputRouter; the bot never calls perform_breaker().

func simulate_frame() -> void:
	super()
	if failed:
		return
	# The accelerated base loop manually drives gameplay processors. Mirror the
	# live scene's post-game ArchivistPacing priority here as well.
	var archivist_pacing = game.get_node_or_null("ArchivistPacing")
	if archivist_pacing != null:
		archivist_pacing._process(DT)

func quick_breaker(held: float) -> bool:
	if int(game.current_act) < 2 or game.player_charge < 18.0 or breaker.charging or game.attack_cooldown > 0.0:
		return false
	var before_hp := -1
	if game.enemies.size() == 1 and game.is_boss_kind(str(game.enemies[0].get("kind", ""))):
		before_hp = int(game.enemies[0].get("hp", -1))
	send_touch(BREAKER_TOUCH, BREAKER_POS, true)
	if not breaker.charging:
		send_touch(BREAKER_TOUCH, BREAKER_POS, false)
		return false
	simulate_seconds(held)
	if failed or game.dead:
		return true
	send_touch(BREAKER_TOUCH, BREAKER_POS, false)
	breakers += 1
	simulate_seconds(0.04)
	var after_hp := -1
	if game.enemies.size() == 1 and game.is_boss_kind(str(game.enemies[0].get("kind", ""))):
		after_hp = int(game.enemies[0].get("hp", -1))
	var dealt := before_hp - after_hp if before_hp >= 0 and after_hp >= 0 else before_hp if before_hp >= 0 and game.enemies.is_empty() else 0
	print("SOL_PLAYTHROUGH // BREAKER // held=%.2f dealt=%d status=%s charge=%.1f" % [held, dealt, str(game.status_flash), game.player_charge])
	return true

func boss_tactic(enemy: Dictionary) -> void:
	var kind := str(enemy.get("kind", ""))
	var state := str(enemy.get("state", ""))
	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	var recovery := float(enemy.get("attack_cd", 0.0))
	var stunned := float(enemy.get("stunned", 0.0))

	# From Act II onward the Breaker is part of the intended kit. Use it only
	# while close and during an obvious recovery/stun window so this is a player
	# decision, not an automation-only damage shortcut. Longer recovery windows
	# buy a four-damage charge; shorter ones get the minimum safe pulse.
	if kind != "GATE-CUSTODIAN" and state != "telegraph" and game.player_charge >= 18.0:
		var held := 0.0
		if (recovery > 0.66 or stunned > 0.68) and distance <= 72.0:
			held = 0.50
		elif (recovery > 0.50 or stunned > 0.45) and distance <= 64.0:
			held = 0.38
		if held > 0.0:
			drive_toward(target, 0.012, false)
			if failed or game.dead:
				return
			if quick_breaker(held):
				return

	super(enemy)
