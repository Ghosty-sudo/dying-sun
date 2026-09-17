extends "res://tests/sol_full_playthrough_paced.gd"

# Final Last Light policy. The collapse ring is visible gameplay information, so
# treat its radius as a telegraph: cross it under Boost before it reaches the
# player instead of repeatedly tanking the ring while following an objective.

func collapse_cycle() -> float:
	match str(game.stage):
		"sector_echo_convergence": return 2.85
		"sector_shared_descent": return 2.70
		"sector_sever_spine": return 2.45
		"boss":
			if int(game.current_act) == 5 and str(game.boss_name) == "LAST LIGHT":
				return 2.45 if bool(act5.reconciliation_ready) else 2.20
	return 0.0

func collapse_time_to_hit() -> float:
	var cycle := collapse_cycle()
	if cycle <= 0.0 or int(game.current_act) != 5 or float(act5.hazard_grace) > 0.0:
		return 99.0
	var radial := Vector2(game.player_pos).distance_to(Vector2(act5.CORE_CENTER))
	# The ring begins at radius 42 and only expands. Sitting well inside its
	# origin is safe until the player deliberately leaves the core.
	if radial <= 28.0:
		return 99.0
	var radius := float(act5.collapse_radius(cycle))
	var speed := (220.0 - 42.0) / cycle
	if radius <= radial:
		return maxf(0.0, (radial - radius - 11.5) / speed)
	var until_reset := cycle - fmod(float(act5.hazard_clock), cycle)
	if radial <= 42.0:
		return 99.0
	return until_reset + maxf(0.0, (radial - 42.0 - 11.5) / speed)

func evade_collapse() -> bool:
	if int(game.current_act) != 5:
		return false
	if str(game.stage) not in ["sector_echo_convergence", "sector_shared_descent", "sector_sever_spine", "boss"]:
		return false
	var time_to_hit := collapse_time_to_hit()
	if time_to_hit > 0.48:
		return false

	var center := Vector2(act5.CORE_CENTER)
	var radial := Vector2(game.player_pos) - center
	if radial.length_squared() <= 0.001:
		radial = Vector2.LEFT
	# The wave expands outward. Cross inward under invulnerability and let the
	# ring continue away from us; objective movement resumes on the next decision.
	var target := center + radial.normalized() * maxf(18.0, radial.length() - 105.0)
	if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
		tap_boost()
		drive_toward(target, 0.18, false)
		return true
	# If Boost is unavailable, start moving before contact instead of standing on
	# the objective marker and accepting guaranteed damage.
	if time_to_hit <= 0.30:
		drive_toward(target, 0.14, false)
		return true
	return false

func escape_stage_hazard() -> bool:
	if evade_collapse():
		return true
	return super()

func authored_stage_step() -> void:
	# Objective handlers do not normally call combat_step(), so give the visible
	# collapse ring the same priority while carrying Sol's link / memory echoes.
	if evade_collapse():
		return
	super()

func last_light_tactic(enemy: Dictionary) -> void:
	var state := str(enemy.get("state", ""))
	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	var remaining := float(enemy.get("telegraph", 9.0))
	var pattern := int(enemy.get("pattern", 0))
	var recovery := float(enemy.get("attack_cd", 0.0))
	var stunned := float(enemy.get("stunned", 0.0))

	if evade_collapse():
		return

	# Crown Spike turns Breaker into the intended high-commitment finale punish.
	# Only start the charge when the collapse telegraph leaves enough time to
	# finish it safely.
	if state != "telegraph" and game.player_charge >= 18.0 and game.attack_cooldown <= 0.0:
		if (recovery > 0.54 or stunned > 0.50) and distance <= 74.0 and collapse_time_to_hit() > 0.62:
			drive_toward(target, 0.012, false)
			if not failed and not game.dead and quick_breaker(0.38):
				return

	if state == "telegraph":
		# Ring, lunge, cross+fan, wide fan: all resolve when the tell expires. The
		# lunge is a clean late-parry; projectile patterns are safer to sidestep.
		if remaining <= 0.075:
			if pattern % 4 == 1 and game.deflect_cooldown <= 0.0:
				tap_deflect()
				simulate_seconds(0.11)
				return
			var tangent := evade_vector_from(target)
			if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
				tap_boost()
			drive_toward(Vector2(game.player_pos) + tangent * 145.0, 0.17, false)
			return
		var circle := evade_vector_from(target)
		drive_toward(Vector2(game.player_pos) + circle * 34.0, 0.04, false)
		return

	# Attack during recovery, but keep a small safety margin for the next collapse
	# crossing rather than greedily finishing a combo into the ring.
	if recovery > 0.28 or stunned > 0.0:
		if collapse_time_to_hit() < 0.46:
			evade_collapse()
			return
		if distance > 50.0:
			drive_toward(target, 0.055, false)
		else:
			drive_toward(target, 0.012, false)
			if not failed and game.attack_cooldown <= 0.0:
				tap_attack()
				simulate_seconds(0.09)
		return

	# Between reads, bias toward the inner core. It is naturally behind the
	# expanding collapse ring and gives more room to read the next projectile fan.
	var center := Vector2(act5.CORE_CENTER)
	if Vector2(game.player_pos).distance_to(center) > 58.0:
		drive_toward(center, 0.065, false)
	else:
		simulate_seconds(0.04)

func boss_tactic(enemy: Dictionary) -> void:
	if str(enemy.get("kind", "")) == "LAST-LIGHT":
		last_light_tactic(enemy)
		return
	super(enemy)
