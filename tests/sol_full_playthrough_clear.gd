extends "res://tests/sol_full_playthrough_breaker.gd"

# Campaign-clear policy layer. Keep the live-input contract while turning the
# boss lessons from prior runs into deliberate, human-readable combat choices.

func global_defense() -> bool:
	# Crown Custodian learns the route's boost-heavy habit and telegraphs the
	# landing point of every new Boost. Respect that counter instead of brute
	# forcing through it: parry isolated projectiles and sidestep clusters using
	# ordinary movement until the profile changes or the boss dies.
	if int(game.current_act) == 4 and str(game.stage) == "boss" and str(game.boss_name) == "CROWN CUSTODIAN":
		var director = game.get_node_or_null("Act4Director")
		if director != null and str(director.counter_profile) == "boost":
			var projectile := projectile_threat()
			if not projectile.is_empty() and float(projectile["time"]) <= 0.17:
				var velocity := Vector2(projectile["velocity"]).normalized()
				var tangent := Vector2(-velocity.y, velocity.x)
				if nearby_projectile_count() <= 2 and game.deflect_cooldown <= 0.0:
					tap_deflect()
					simulate_seconds(game.deflect_window_length() + 0.025)
					return true
				drive_toward(Vector2(game.player_pos) + tangent * 120.0, 0.18, false)
				return true
			return false
	return super()

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

func crown_custodian_tactic(enemy: Dictionary) -> bool:
	var state := str(enemy.get("state", ""))
	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	var remaining := float(enemy.get("telegraph", 9.0))
	var pattern := int(enemy.get("pattern", 0))
	var recovery := float(enemy.get("attack_cd", 0.0))
	var stunned := float(enemy.get("stunned", 0.0))
	var director = game.get_node_or_null("Act4Director")
	var profile := str(director.counter_profile) if director != null else "balanced"

	# This run arrives with the boost counterprofile. Stop feeding it. Reposition
	# off the center axes with ordinary movement and answer the three boss tells
	# without starting a new Boost landing trace.
	if profile == "boost" and game.dash_time <= 0.0:
		var center := Vector2(365.0, 180.0)
		if absf(game.player_pos.y - center.y) < 26.0:
			var safe_y := 126.0 if game.player_pos.y <= center.y else 234.0
			drive_toward(Vector2(game.player_pos.x, safe_y), 0.10, false)
			return true
		if absf(game.player_pos.x - center.x) < 24.0:
			var safe_x := 315.0 if game.player_pos.x <= center.x else 415.0
			drive_toward(Vector2(safe_x, game.player_pos.y), 0.09, false)
			return true

	if state == "telegraph":
		if remaining <= 0.075:
			# Lunge can be parried late. Ring/fan are multi-projectile reads, so
			# rotate around the boss through release rather than eating a trace.
			if pattern % 3 == 1 and game.deflect_cooldown <= 0.0:
				tap_deflect()
				simulate_seconds(0.11)
				return true
			var tangent := evade_vector_from(target)
			drive_toward(Vector2(game.player_pos) + tangent * 135.0, 0.22, false)
			return true
		var circle := evade_vector_from(target)
		drive_toward(Vector2(game.player_pos) + circle * 38.0, 0.045, false)
		return true

	# The OPEN route exposes a stagger break point. Spend Breaker only in a clear
	# recovery window; it is a real charge commitment and never arms boost trace.
	if state != "telegraph" and game.player_charge >= 18.0 and game.attack_cooldown <= 0.0:
		if (recovery > 0.50 or stunned > 0.45) and distance <= 72.0:
			drive_toward(target, 0.012, false)
			if failed or game.dead:
				return true
			if quick_breaker(0.38):
				return true

	if recovery > 0.28 or stunned > 0.0:
		if distance > 50.0:
			drive_toward(target, 0.055, false)
		else:
			drive_toward(target, 0.012, false)
			if not failed and game.attack_cooldown <= 0.0:
				tap_attack()
				simulate_seconds(0.09)
		return true

	if distance < 105.0:
		var away := (Vector2(game.player_pos) - target).normalized()
		if away.length_squared() <= 0.001:
			away = Vector2.LEFT
		drive_toward(Vector2(game.player_pos) + away * 95.0, 0.07, false)
		return true
	simulate_seconds(0.04)
	return true
