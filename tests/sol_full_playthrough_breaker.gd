extends "res://tests/sol_full_playthrough_tactical.gd"

# Final player-policy layer: use Breaker as an actual combat tool instead of
# treating it as an Act II door key. This still presses and releases the live
# touch binding through InputRouter; the bot never calls perform_breaker().

func quick_breaker() -> bool:
	if int(game.current_act) < 2 or game.player_charge < 18.0 or breaker.charging or game.attack_cooldown > 0.0:
		return false
	send_touch(BREAKER_TOUCH, BREAKER_POS, true)
	if not breaker.charging:
		send_touch(BREAKER_TOUCH, BREAKER_POS, false)
		return false
	# Minimum-safe charge: short enough to fit inside a boss recovery window,
	# long enough to trigger real Breaker damage and stagger.
	simulate_seconds(0.38)
	if failed or game.dead:
		return true
	send_touch(BREAKER_TOUCH, BREAKER_POS, false)
	breakers += 1
	simulate_seconds(0.04)
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
	# decision, not an automation-only damage shortcut.
	if kind != "GATE-CUSTODIAN" and state != "telegraph" and distance <= 68.0 and game.player_charge >= 18.0:
		if recovery > 0.50 or stunned > 0.45:
			drive_toward(target, 0.012, false)
			if failed or game.dead:
				return
			if quick_breaker():
				return

	super(enemy)
