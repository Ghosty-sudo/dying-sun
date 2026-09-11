extends Node

# Keeps melee hit registration aligned with the visible strike arc. The core
# attack resolves instantly; this guard adds the enemy's visible body radius
# and keeps the swing live for the same short window that is drawn on screen.

var observed_attack := false
var swing_serial := 0
var swing_step := 0
var swing_range := 0.0
var swing_damage := 0
var swing_stagger := 0.0

func _ready() -> void:
	process_priority = 20

func game():
	return get_parent()

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null:
		observed_attack = false
		return
	if parent.ui_mode != "play" or parent.paused or parent.dead or parent.dialogue_open or parent.module_pending:
		observed_attack = false
		return

	var active := float(parent.attack_time) > 0.0 and int(parent.combo_step) > 0
	if active and not observed_attack:
		begin_swing(parent)
	if active:
		resolve_visible_contacts(parent)
	observed_attack = active

func begin_swing(parent) -> void:
	swing_serial += 1
	swing_step = clampi(int(parent.combo_step), 1, 3)
	swing_range = 52.0 + float(swing_step - 1) * 6.0
	swing_damage = 1 if swing_step < 3 else 2
	if swing_step == 3 and GameState.has_module("sol_echo"):
		swing_damage += 1
	swing_stagger = (1.0 if swing_step == 1 else (1.3 if swing_step == 2 else 2.4)) * float(parent.stagger_multiplier())

	# The base attack has already resolved by the time this node processes.
	# Mark everything the original center-point test would have hit so this
	# guard can never double-damage a valid normal hit.
	for i in range(parent.enemies.size()):
		var enemy: Dictionary = parent.enemies[i]
		if base_attack_contains(parent, enemy):
			enemy["melee_swing_serial"] = swing_serial
			parent.enemies[i] = enemy

func base_attack_contains(parent, enemy: Dictionary) -> bool:
	var to_enemy := Vector2(enemy["pos"]) - Vector2(parent.player_pos)
	if to_enemy.length() > swing_range:
		return false
	if to_enemy.length_squared() <= 0.001:
		return true
	var facing := Vector2(parent.last_move).normalized().dot(to_enemy.normalized())
	return facing > -0.10

func visible_contact_radius(kind: String, parent) -> float:
	if parent.is_boss_kind(kind):
		return 25.0
	if kind in ["SUN-HUSK", "CROWN-GUARD", "ECHO-WARDEN"]:
		return 17.0
	if kind in ["HUSK", "ARCHIVIST", "RELAY-DRONE"]:
		return 15.0
	return 12.0

func resolve_visible_contacts(parent) -> void:
	var hit_any := false
	for i in range(parent.enemies.size() - 1, -1, -1):
		var enemy: Dictionary = parent.enemies[i]
		if int(enemy.get("melee_swing_serial", -1)) == swing_serial:
			continue
		var to_enemy := Vector2(enemy["pos"]) - Vector2(parent.player_pos)
		var contact_range := swing_range + visible_contact_radius(str(enemy["kind"]), parent)
		if to_enemy.length() > contact_range:
			continue
		if to_enemy.length_squared() > 0.001:
			var facing := Vector2(parent.last_move).normalized().dot(to_enemy.normalized())
			if facing <= -0.10:
				continue

		enemy["melee_swing_serial"] = swing_serial
		var damage := swing_damage
		if parent.is_boss_kind(str(enemy["kind"])) and GameState.has_module("crown_spike"):
			damage += 1
		enemy["hp"] = int(enemy["hp"]) - damage
		enemy["flash"] = maxf(float(enemy.get("flash", 0.0)), 0.12)
		parent.apply_stagger(enemy, swing_stagger)
		hit_any = true
		if int(enemy["hp"]) <= 0:
			parent.enemies.remove_at(i)
			parent.wave_kills += 1
		else:
			parent.enemies[i] = enemy

	if hit_any:
		parent.flash_status("CHAIN %d // CONTACT" % swing_step)
