extends Node

# Crown Custodian already adds an adaptive counter-profile on top of the shared
# boss pattern set. Give each completed cast a readable punish beat so the fight
# rewards recognizing the counter instead of becoming uninterrupted projectile
# pressure. This mirrors the same design principle used for The Archivist while
# keeping Crown's patterns, damage, countermeasure and enrage intact.

const NORMAL_RECOVERY := 1.12
const ENRAGED_RECOVERY := 0.86

var last_pattern := -1

func game():
	return get_parent()

func _ready() -> void:
	# Main gameplay is priority 0. Observe after the attack has actually fired.
	process_priority = 26

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null or int(parent.current_act) != 4 or str(parent.stage) != "boss" or str(parent.boss_name) != "CROWN CUSTODIAN":
		last_pattern = -1
		return

	var boss_index := -1
	for i in range(parent.enemies.size()):
		if str(parent.enemies[i].get("kind", "")) == "CROWN-CUSTODIAN":
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
