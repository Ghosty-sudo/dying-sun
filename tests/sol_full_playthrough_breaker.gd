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
	# two-damage lunge. The generic policy used to parry early in the telegraph,
	# so the deflect window expired before either attack actually released.
	if state == "telegraph":
		if pattern % 2 == 0:
			# The cross and aimed fan overlap. Leave the firing lane at release;
			# trying to parry one shard is the wrong read for a multi-shot burst.
			if remaining <= 0.075:
				var tangent := evade_vector_from(target)
				if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
					tap_boost()
					drive_toward(Vector2(game.player_pos) + tangent * 135.0, 0.16, false)
				return true
			var circle := evade_vector_from(target)
			drive_toward(Vector2(game.player_pos) + circle * 34.0, 0.04, false)
			return true
		else:
			# The lunge resolves the instant the telegraph ends. Parry late enough
			# that the live deflect window actually covers impact.
			if remaining <= 0.060:
				if game.deflect_cooldown <= 0.0:
					tap_deflect()
					simulate_seconds(0.10)
					return true
				if game.dash_cooldown <= 0.0 and game.player_charge >= game.boost_cost():
					tap_boost()
					var tangent := evade_vector_from(target)
					drive_toward(Vector2(game.player_pos) + tangent * 120.0, 0.13, false)
					return true
			var circle := evade_vector_from(target)
			drive_toward(Vector2(game.player_pos) + circle * 28.0, 0.035, false)
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

func boss_tactic(enemy: Dictionary) -> void:
	var kind := str(enemy.get("kind", ""))
	var state := str(enemy.get("state", ""))
	var target := Vector2(enemy["pos"])
	var distance := target.distance_to(game.player_pos)
	var recovery := float(enemy.get("attack_cd", 0.0))
	var stunned := float(enemy.get("stunned", 0.0))

	if kind == "RELAY-SAINT" and relay_saint_tactic(enemy):
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
