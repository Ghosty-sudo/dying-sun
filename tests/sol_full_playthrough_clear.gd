extends "res://tests/sol_full_playthrough_breaker.gd"

# Campaign-clear policy layer. Keep the live-input contract while turning the
# boss lessons from prior runs into deliberate, human-readable combat choices.

func relay_saint_tactic(enemy: Dictionary) -> bool:
	var state := str(enemy.get("state", ""))
	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	var remaining := float(enemy.get("telegraph", 9.0))
	var pattern := int(enemy.get("pattern", 0))
	var recovery := float(enemy.get("attack_cd", 0.0))
	var stunned := float(enemy.get("stunned", 0.0))

	# The clean punish is Breaker during the obvious post-pattern recovery. It
	# travels through the real touch binding, costs real charge, and gives Relay
	# Saint substantially less time to refill the arena with projectiles.
	if state != "telegraph" and game.player_charge >= 18.0 and game.attack_cooldown <= 0.0:
		if (recovery > 0.48 or stunned > 0.40) and distance <= 72.0:
			drive_toward(target, 0.012, false)
			if failed or game.dead:
				return true
			if quick_breaker(0.38):
				return true

	# Cross+fan and lunge both resolve at telegraph release. Stay mobile while
	# reading, then spend Boost late enough to cover the actual release frame.
	if state == "telegraph":
		if remaining <= 0.075:
			var tangent := evade_vector_from(target)
			if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
				tap_boost()
			drive_toward(Vector2(game.player_pos) + tangent * (145.0 if pattern % 2 == 0 else 125.0), 0.16, false)
			return true
		var circle := evade_vector_from(target)
		drive_toward(Vector2(game.player_pos) + circle * 35.0, 0.04, false)
		return true

	# Ordinary recovery is the melee window. Disengage before the next tell so a
	# fresh projectile cross does not spawn on top of the player.
	if recovery > 0.28 or stunned > 0.0:
		if distance > 50.0:
			drive_toward(target, 0.05, false)
		else:
			drive_toward(target, 0.012, false)
			if not failed and game.attack_cooldown <= 0.0:
				tap_attack()
				simulate_seconds(0.09)
		return true

	if distance < 110.0:
		var away := (Vector2(game.player_pos) - target).normalized()
		if away.length_squared() <= 0.001:
			away = Vector2.LEFT
		drive_toward(Vector2(game.player_pos) + away * 95.0, 0.065, false)
		return true
	simulate_seconds(0.035)
	return true
