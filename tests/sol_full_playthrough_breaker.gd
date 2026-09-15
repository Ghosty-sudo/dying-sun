extends "res://tests/sol_full_playthrough_tactical.gd"

# Final player-policy layer: use Breaker as an actual combat tool instead of
# treating it as an Act II door key. This still presses and releases the live
# touch binding through InputRouter; the bot never calls perform_breaker().

func simulate_frame() -> void:
	if failed:
		return

	# Mirror the live scene's explicit process ordering. The accelerated harness
	# drives processors manually, so every checkpoint/pacing node added to the
	# shipped scene must also participate here or retries diverge from real play.
	router._process(DT)

	var act3_checkpoint = game.get_node_or_null("Act3BossCheckpoint")
	if act3_checkpoint != null:
		act3_checkpoint._process(DT)

	var act4_checkpoint = game.get_node_or_null("Act4BossCheckpoint")
	if act4_checkpoint != null:
		act4_checkpoint._process(DT)

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

	var archivist_pacing = game.get_node_or_null("ArchivistPacing")
	if archivist_pacing != null:
		archivist_pacing._process(DT)

	sim_time += DT
	observe_metrics()
	observe_transition()

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

func relay_saint_tactic(enemy: Dictionary) -> bool:
	var state := str(enemy.get("state", ""))
	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	var remaining := float(enemy.get("telegraph", 9.0))
	var pattern := int(enemy.get("pattern", 0))
	var recovery := float(enemy.get("attack_cd", 0.0))

	# Relay Saint alternates a cross+fan projectile burst and an instantaneous
	# two-damage lunge. Defending at release is the intended read. Use mobility
	# for both patterns here; Mirror Lattice reflection can legitimately kill a
	# boss inside its own update callback, a runtime edge case tracked separately.
	if state == "telegraph":
		if remaining <= 0.075:
			var tangent := evade_vector_from(target)
			if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
				tap_boost()
				drive_toward(Vector2(game.player_pos) + tangent * (140.0 if pattern % 2 == 0 else 120.0), 0.16, false)
			return true
		var circle := evade_vector_from(target)
		drive_toward(Vector2(game.player_pos) + circle * 34.0, 0.04, false)
		return true

	# Spend the early recovery window attacking, then disengage before the next
	# tell so the player is not standing inside the cross/fan origin at release.
	if recovery > 0.30:
		if distance > 52.0:
			drive_toward(target, 0.055, false)
		else:
			drive_toward(target, 0.012, false)
			if not failed and game.attack_cooldown <= 0.0:
				tap_attack()
				simulate_seconds(0.095)
		return true

	if distance < 105.0:
		var away := (Vector2(game.player_pos) - target).normalized()
		if away.length_squared() <= 0.001:
			away = Vector2.LEFT
		drive_toward(Vector2(game.player_pos) + away * 90.0, 0.065, false)
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
	var director = game.get_node_or_null("Act4Director")
	var profile := str(director.counter_profile) if director != null else "balanced"

	# A boost-counter profile projects a cross-shaped mobility grid through the
	# arena. Keep off the two center axes between attack reads; the counter is
	# announced and drawn, so this is information available to a human player.
	if profile == "boost" and game.dash_time <= 0.0:
		var center := Vector2(365.0, 180.0)
		if absf(game.player_pos.y - center.y) < 28.0:
			var safe_y := 132.0 if game.player_pos.y <= center.y else 228.0
			drive_toward(Vector2(game.player_pos.x, safe_y), 0.06, false)
			return true
		if absf(game.player_pos.x - center.x) < 28.0:
			var safe_x := 320.0 if game.player_pos.x <= center.x else 410.0
			drive_toward(Vector2(safe_x, game.player_pos.y), 0.05, false)
			return true

	# Crown Custodian cycles ring, lunge, wide fan. All three are safest when
	# read at release: ring/fan get a lateral Boost, lunge gets the same late
	# displacement rather than an early parry whose window can expire.
	if state == "telegraph":
		if remaining <= 0.075:
			var tangent := evade_vector_from(target)
			if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
				tap_boost()
			var travel := 145.0 if pattern % 3 != 1 else 120.0
			drive_toward(Vector2(game.player_pos) + tangent * travel, 0.16, false)
			return true
		var circle := evade_vector_from(target)
		drive_toward(Vector2(game.player_pos) + circle * 34.0, 0.04, false)
		return true

	# Proof extraction starts the boss close to a stagger break. Commit during
	# the first half of recovery, then get back out before the next read.
	if recovery > 0.32:
		if distance > 52.0:
			drive_toward(target, 0.055, false)
		else:
			drive_toward(target, 0.012, false)
			if not failed and game.attack_cooldown <= 0.0:
				tap_attack()
				simulate_seconds(0.095)
		return true

	if distance < 105.0:
		var away := (Vector2(game.player_pos) - target).normalized()
		if away.length_squared() <= 0.001:
			away = Vector2.LEFT
		drive_toward(Vector2(game.player_pos) + away * 90.0, 0.06, false)
		return true
	simulate_seconds(0.035)
	return true

func boss_tactic(enemy: Dictionary) -> void:
	var kind := str(enemy.get("kind", ""))
	var state := str(enemy.get("state", ""))
	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	var recovery := float(enemy.get("attack_cd", 0.0))
	var stunned := float(enemy.get("stunned", 0.0))

	if kind == "RELAY-SAINT" and relay_saint_tactic(enemy):
		return
	if kind == "CROWN-CUSTODIAN" and crown_custodian_tactic(enemy):
		return

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
