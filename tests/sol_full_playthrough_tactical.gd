extends "res://tests/sol_full_playthrough.gd"

# The base player-bot deliberately knows only what an attentive player could
# perceive from the live world state. This layer makes its combat policy less
# button-spammy: respect telegraphs, preserve Frame Charge, use defensive timing,
# and reposition around authored hazards rather than face-tanking them.

var tactical_calls := 0

func imminent_projectile() -> bool:
	for projectile in game.projectiles:
		if Vector2(projectile["pos"]).distance_to(game.player_pos) <= 38.0:
			return true
	return false

func escape_stage_hazard() -> bool:
	var stage_name := str(game.stage)
	if stage_name in ["sector_gate_approach", "sector_gate_pressure"] and sector.gate_hot():
		var core := Vector2(365.0, 180.0)
		if Vector2(game.player_pos).distance_to(core) < 72.0:
			var away := (Vector2(game.player_pos) - core).normalized()
			if away.length_squared() <= 0.001:
				away = Vector2.UP
			drive_toward(Vector2(game.player_pos) + away * 105.0, 0.11, false)
			return true
	return false

func timed_defense(enemy: Dictionary) -> bool:
	var state := str(enemy.get("state", ""))
	var distance := Vector2(enemy["pos"]).distance_to(game.player_pos)
	var remaining := float(enemy.get("telegraph", 9.0))
	var window := float(game.deflect_window_length())

	if imminent_projectile() and game.deflect_cooldown <= 0.0:
		tap_deflect()
		simulate_seconds(window + 0.035)
		return true

	if state == "charge_telegraph" and remaining <= window + 0.035:
		if game.deflect_cooldown <= 0.0:
			tap_deflect()
		simulate_seconds(window + 0.04)
		return true

	if state == "charge" and distance < 82.0:
		if game.deflect_cooldown <= 0.0:
			tap_deflect()
		simulate_seconds(window + 0.04)
		return true

	if state == "telegraph" and remaining <= window + 0.025 and distance <= 115.0:
		if game.deflect_cooldown <= 0.0:
			tap_deflect()
		simulate_seconds(window + 0.04)
		return true
	return false

func boss_tactic(enemy: Dictionary) -> void:
	var kind := str(enemy.get("kind", ""))
	var state := str(enemy.get("state", ""))
	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	var remaining := float(enemy.get("telegraph", 9.0))
	var pattern := int(enemy.get("pattern", 0))
	var window := float(game.deflect_window_length())

	if imminent_projectile() and game.deflect_cooldown <= 0.0:
		tap_deflect()
		simulate_seconds(window + 0.03)
		return

	if state == "telegraph":
		if kind == "GATE-CUSTODIAN" and pattern % 2 == 1:
			if remaining <= 0.07 and game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
				tap_boost()
				var radial := (Vector2(game.player_pos) - target).normalized()
				if radial.length_squared() <= 0.001:
					radial = Vector2.RIGHT
				var tangent := Vector2(-radial.y, radial.x)
				drive_toward(Vector2(game.player_pos) + tangent * 115.0, 0.16, false)
				return
		elif remaining <= window + 0.025 and game.deflect_cooldown <= 0.0:
			tap_deflect()
			simulate_seconds(window + 0.04)
			return

		var radial := (Vector2(game.player_pos) - target).normalized()
		if radial.length_squared() <= 0.001:
			radial = Vector2.RIGHT
		var tangent := Vector2(-radial.y, radial.x)
		drive_toward(Vector2(game.player_pos) + tangent * 24.0, 0.035, false)
		return

	if float(enemy.get("stunned", 0.0)) > 0.0:
		if distance > 46.0:
			drive_toward(target, 0.06, false)
		else:
			drive_toward(target, 0.012, false)
			if not failed:
				tap_attack()
				simulate_seconds(0.10)
		return

	if float(enemy.get("attack_cd", 0.0)) > 0.16:
		if distance > 47.0:
			drive_toward(target, 0.055, false)
		else:
			drive_toward(target, 0.012, false)
			if not failed and game.attack_cooldown <= 0.0:
				tap_attack()
				simulate_seconds(0.10)
		return

	if distance < 70.0:
		var away := (Vector2(game.player_pos) - target).normalized()
		if away.length_squared() <= 0.001:
			away = Vector2.LEFT
		drive_toward(Vector2(game.player_pos) + away * 45.0, 0.045, false)
	else:
		simulate_seconds(0.035)

func combat_step() -> void:
	tactical_calls += 1
	if tactical_calls % 250 == 0:
		print("SOL_PLAYTHROUGH // TACTICAL HEARTBEAT // calls=%d sim=%.1f stage=%s armor=%d enemies=%d projectiles=%d" % [tactical_calls, sim_time, str(game.stage), game.player_hp, game.enemies.size(), game.projectiles.size()])
	if tactical_calls > 5000:
		fail("tactical decision loop exceeded 5000 combat calls")
		return
	if game.enemies.is_empty():
		simulate_seconds(0.05)
		return
	if escape_stage_hazard():
		return

	var index := nearest_enemy_index()
	if index < 0:
		simulate_seconds(0.05)
		return
	var enemy: Dictionary = game.enemies[index]
	if game.is_boss_kind(str(enemy.get("kind", ""))):
		boss_tactic(enemy)
		return
	if timed_defense(enemy):
		return

	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	if distance > 47.0:
		drive_toward(target, 0.06, false)
		return

	drive_toward(target, 0.012, false)
	if failed:
		return
	if game.attack_cooldown <= 0.0:
		tap_attack()
		simulate_seconds(0.10)
	else:
		simulate_seconds(0.045)
