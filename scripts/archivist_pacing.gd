extends Node

# The Archivist is the first sustained projectile boss. Its original shared boss
# cadence left almost no reliable punish window once the arena filled with
# lingering projectiles. Keep the patterns intact, but give each completed cast
# a boss-specific recovery beat so Act II tests reading + commitment rather than
# nonstop evasion.

const NORMAL_RECOVERY := 1.18
const ENRAGED_RECOVERY := 0.90

var last_pattern := -1

func game():
	return get_parent()

func _ready() -> void:
	# Main gameplay processing is default priority 0. Run after it so we can
	# extend only the recovery that was just authored by execute_boss_pattern().
	process_priority = 25

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null or int(parent.current_act) != 2 or str(parent.stage) != "boss" or str(parent.boss_name) != "THE ARCHIVIST":
		last_pattern = -1
		return

	var boss_index := -1
	for i in range(parent.enemies.size()):
		if str(parent.enemies[i].get("kind", "")) == "THE-ARCHIVIST":
			boss_index = i
			break
	if boss_index < 0:
		last_pattern = -1
		return

	var enemy: Dictionary = parent.enemies[boss_index]
	var pattern := int(enemy.get("pattern", 0))
	if last_pattern < 0:
		last_pattern = pattern
		return
	if pattern == last_pattern:
		return

	last_pattern = pattern
	var enraged := int(enemy.get("hp", 1)) <= int(enemy.get("max_hp", 1)) / 2
	var recovery := ENRAGED_RECOVERY if enraged else NORMAL_RECOVERY
	enemy["attack_cd"] = maxf(float(enemy.get("attack_cd", 0.0)), recovery)
	parent.enemies[boss_index] = enemy
