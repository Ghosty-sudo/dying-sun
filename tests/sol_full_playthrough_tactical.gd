extends "res://tests/sol_full_playthrough.gd"

# Competent player policy for the fresh-save pass. It reads only live combat
# state a player can infer from telegraphs/trajectories, then acts through the
# same InputRouter as the shipped game. No HP, enemy, stage, or progress writes.

var tactical_calls := 0
var damage_sources: Dictionary = {}

func simulate_frame() -> void:
	if failed:
		return
	# Keep the accelerated player-bot faithful to live process priority. The Act
	# II checkpoint controller runs before SectorDirector in the shipped scene.
	router._process(DT)
	var act2_checkpoint = game.get_node_or_null("Act2BossCheckpoint")
	if act2_checkpoint != null:
		act2_checkpoint._process(DT)
	sector._process(DT)
	act3._process(DT)
	act4._process(DT)
	act5._process(DT)
	if crown_boost != null:
		crown_boost._process(DT)
	breaker._process(DT)
	game._process(DT)
	sim_time += DT
	observe_metrics()
	observe_transition()

func observe_metrics() -> void:
	if last_hp > 0 and game.player_hp < last_hp:
		var lost := last_hp - int(game.player_hp)
		var source := str(game.status_flash)
		damage_sources[source] = int(damage_sources.get(source, 0)) + lost
		print("SOL_PLAYTHROUGH // HIT // %s // armor %d/%d // %s" % [str(game.stage), game.player_hp, game.max_hp(), source])
	super()

func projectile_threat(horizon: float = 0.24) -> Dictionary:
	var best: Dictionary = {}
	var best_t := 999.0
	for projectile in game.projectiles:
		var rel := Vector2(projectile["pos"]) - Vector2(game.player_pos)
		var velocity := Vector2(projectile["velocity"])
		var speed_sq := velocity.length_squared()
		if speed_sq <= 0.001:
			continue
		var t := clampf(-rel.dot(velocity) / speed_sq, 0.0, horizon)
		var closest := rel + velocity * t
		if closest.length() <= 19.0 and t < best_t:
			best_t = t
			best = {"time": t, "velocity": velocity, "pos": Vector2(projectile["pos"])}
	return best

func enemy_threat() -> Dictionary:
	var best: Dictionary = {}
	var best_remaining := 999.0
	var window := float(game.deflect_window_length())
	for enemy in game.enemies:
		if game.is_boss_kind(str(enemy.get("kind", ""))):
			continue
		var state := str(enemy.get("state", ""))
		var distance := Vector2(enemy["pos"]).distance_to(game.player_pos)
		var remaining := float(enemy.get("telegraph", 9.0))
		if state == "telegraph" and distance <= 112.0 and remaining <= window + 0.045 and remaining < best_remaining:
			best_remaining = remaining
			best = {"enemy": enemy, "remaining": remaining, "charge": false}
		elif state == "charge" and distance <= 92.0 and 0.0 < best_remaining:
			best_remaining = 0.0
			best = {"enemy": enemy, "remaining": 0.0, "charge": true}
		elif state == "charge_telegraph" and distance <= 150.0 and remaining <= 0.11 and remaining < best_remaining:
			best_remaining = remaining
			best = {"enemy": enemy, "remaining": remaining, "charge": true}
	return best

func evade_vector_from(origin: Vector2) -> Vector2:
	var radial := (Vector2(game.player_pos) - origin).normalized()
	if radial.length_squared() <= 0.001:
		radial = Vector2.RIGHT
	return Vector2(-radial.y, radial.x)

func global_defense() -> bool:
	var projectile := projectile_threat()
	if not projectile.is_empty() and float(projectile["time"]) <= 0.17:
		if game.deflect_cooldown <= 0.0:
			tap_deflect()
			simulate_seconds(game.deflect_window_length() + 0.025)
			return true
		if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
			tap_boost()
			var velocity := Vector2(projectile["velocity"]).normalized()
			var tangent := Vector2(-velocity.y, velocity.x)
			drive_toward(Vector2(game.player_pos) + tangent * 110.0, 0.13, false)
			return true

	var threat := enemy_threat()
	if not threat.is_empty():
		var enemy: Dictionary = threat["enemy"]
		if game.deflect_cooldown <= 0.0:
			tap_deflect()
			simulate_seconds(game.deflect_window_length() + 0.025)
			return true
		if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
			tap_boost()
			var tangent := evade_vector_from(Vector2(enemy["pos"]))
			drive_toward(Vector2(game.player_pos) + tangent * 115.0, 0.13, false)
			return true
		# If both active defenses are unavailable, at least move off the attack line.
		var fallback := evade_vector_from(Vector2(enemy["pos"]))
		drive_toward(Vector2(game.player_pos) + fallback * 70.0, 0.10, false)
		return true
	return false

func escape_stage_hazard() -> bool:
	var stage_name := str(game.stage)
	if stage_name in ["sector_gate_approach", "sector_gate_pressure"] and sector.gate_hot():
		var core := Vector2(365.0, 180.0)
		if Vector2(game.player_pos).distance_to(core) < 68.0:
			var away := (Vector2(game.player_pos) - core).normalized()
			if away.length_squared() <= 0.001:
				away = Vector2.UP
			drive_toward(Vector2(game.player_pos) + away * 95.0, 0.10, false)
			return true
	return false

func priority_enemy_index() -> int:
	var best := -1
	var best_score := INF
	for i in range(game.enemies.size()):
		var enemy: Dictionary = game.enemies[i]
		var kind := str(enemy.get("kind", ""))
		var distance := Vector2(enemy["pos"]).distance_to(game.player_pos)
		var score := distance + float(enemy.get("hp", 1)) * 4.0
		match kind:
			"SUN-HUSK": score -= 75.0
			"HUSK", "ARCHIVIST", "RELAY-DRONE": score -= 45.0
			"CROWN-GUARD": score -= 20.0
			_:
				if distance < 68.0:
					score -= 55.0
		if score < best_score:
			best_score = score
			best = i
	return best

func boss_tactic(enemy: Dictionary) -> void:
	var kind := str(enemy.get("kind", ""))
	var state := str(enemy.get("state", ""))
	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	var remaining := float(enemy.get("telegraph", 9.0))
	var pattern := int(enemy.get("pattern", 0))
	var window := float(game.deflect_window_length())

	var projectile := projectile_threat()
	if not projectile.is_empty() and float(projectile["time"]) <= 0.17:
		if game.deflect_cooldown <= 0.0:
			tap_deflect()
			simulate_seconds(window + 0.025)
			return
		if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
			tap_boost()
			var velocity := Vector2(projectile["velocity"]).normalized()
			var tangent := Vector2(-velocity.y, velocity.x)
			drive_toward(Vector2(game.player_pos) + tangent * 115.0, 0.13, false)
			return

	if state == "telegraph":
		# The Gate Custodian visibly alternates lunge / fan. Deflect the lunge;
		# sidestep the fan at release so Frame Charge is spent intentionally.
		if kind == "GATE-CUSTODIAN" and pattern % 2 == 1 and remaining <= 0.075:
			if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
				tap_boost()
				var tangent := evade_vector_from(target)
				drive_toward(Vector2(game.player_pos) + tangent * 120.0, 0.15, false)
				return
		if remaining <= window + 0.035:
			if game.deflect_cooldown <= 0.0:
				tap_deflect()
				simulate_seconds(window + 0.03)
				return
			if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
				tap_boost()
				var tangent := evade_vector_from(target)
				drive_toward(Vector2(game.player_pos) + tangent * 110.0, 0.13, false)
				return
		var tangent := evade_vector_from(target)
		drive_toward(Vector2(game.player_pos) + tangent * 28.0, 0.04, false)
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

	# Recovery windows are offense windows. Outside them, keep enough space to
	# read the next tell instead of mashing attacks at point-blank range.
	if float(enemy.get("attack_cd", 0.0)) > 0.18:
		if distance > 48.0:
			drive_toward(target, 0.055, false)
		else:
			drive_toward(target, 0.012, false)
			if not failed and game.attack_cooldown <= 0.0:
				tap_attack()
				simulate_seconds(0.10)
		return

	if distance < 76.0:
		var tangent := evade_vector_from(target)
		drive_toward(Vector2(game.player_pos) + tangent * 52.0, 0.05, false)
	else:
		simulate_seconds(0.04)

func combat_step() -> void:
	tactical_calls += 1
	if tactical_calls % 300 == 0:
		print("SOL_PLAYTHROUGH // TACTICAL HEARTBEAT // calls=%d sim=%.1f stage=%s armor=%d enemies=%d projectiles=%d" % [tactical_calls, sim_time, str(game.stage), game.player_hp, game.enemies.size(), game.projectiles.size()])
	if tactical_calls > 6000:
		fail("tactical decision loop exceeded 6000 combat calls")
		return
	if game.enemies.is_empty():
		simulate_seconds(0.05)
		return
	if escape_stage_hazard():
		return
	if global_defense():
		return

	var index := priority_enemy_index()
	if index < 0:
		simulate_seconds(0.05)
		return
	var enemy: Dictionary = game.enemies[index]
	if game.is_boss_kind(str(enemy.get("kind", ""))):
		boss_tactic(enemy)
		return

	var state := str(enemy.get("state", ""))
	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	if state == "charge_telegraph":
		var tangent := evade_vector_from(target)
		drive_toward(Vector2(game.player_pos) + tangent * 65.0, 0.07, false)
		return
	if distance > 47.0:
		drive_toward(target, 0.055, false)
		return

	drive_toward(target, 0.012, false)
	if failed:
		return
	if game.attack_cooldown <= 0.0:
		tap_attack()
		simulate_seconds(0.095)
	else:
		simulate_seconds(0.04)

func print_report(prefix: String) -> void:
	super(prefix)
	var keys := damage_sources.keys()
	keys.sort()
	for key in keys:
		print("SOL_PLAYTHROUGH // DAMAGE SOURCE // %s // %d" % [str(key), int(damage_sources[key])])
