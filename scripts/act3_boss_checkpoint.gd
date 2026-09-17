extends Node

# Act III's route objective is meaningful once. After Relay Saint is earned,
# retries should test the boss rather than replaying the civilian feed / lattice
# push. Preserve the route-specific boss consequence while restoring a clean
# combat frame for each attempt.

const CHECKPOINT_FLAG := "act3_relay_saint_checkpoint"
const BOSS_START := Vector2(102.0, 180.0)

var prepared_attempt := false

func game():
	return get_parent()

func _ready() -> void:
	# Intercept wave_b before Act3Director (-90) rebuilds the route consequence.
	process_priority = -110

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	if int(parent.current_act) != 3:
		prepared_attempt = false
		return
	if parent.ui_mode != "play" or parent.paused or parent.dead:
		return

	if str(parent.stage) == "wave_b" and GameState.has_flag(CHECKPOINT_FLAG):
		restore_relay_saint(parent)
		return

	if str(parent.stage) == "boss" and str(parent.boss_name) == "RELAY SAINT":
		if not GameState.has_flag(CHECKPOINT_FLAG):
			GameState.set_flag(CHECKPOINT_FLAG)
			SaveManager.save_campaign()
		if not prepared_attempt:
			stabilize_frame(parent)
			prepared_attempt = true
		return

	prepared_attempt = false

func restore_relay_saint(parent) -> void:
	var director = parent.get_node_or_null("Act3Director")
	if director != null:
		director.room_id = "relay_chamber"
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = BOSS_START
	parent.boss_announced = false
	parent.boss_name = ""
	stabilize_frame(parent)
	parent.spawn_boss()
	apply_route_consequence(parent)
	prepared_attempt = true
	if director != null:
		if GameState.has_flag("defense_lattice_powered"):
			director.announce(parent, "RELAY SAINT // LATTICE CUTS ITS SHIELD // CHECKPOINT")
		else:
			director.announce(parent, "RELAY SAINT // DEFENSE GRID DARK // CHECKPOINT")
	else:
		parent.flash_status("RELAY SAINT CHECKPOINT // FRAME STABILIZED")

func apply_route_consequence(parent) -> void:
	if not GameState.has_flag("defense_lattice_powered") or parent.enemies.is_empty():
		return
	var saint: Dictionary = parent.enemies[0]
	if str(saint.get("kind", "")) != "RELAY-SAINT":
		return
	saint["hp"] = maxi(1, int(saint["hp"]) - 4)
	saint["stagger"] = minf(float(saint["stagger_max"]) - 0.1, float(saint["stagger"]) + 2.5)
	parent.enemies[0] = saint

func stabilize_frame(parent) -> void:
	parent.player_hp = parent.max_hp()
	parent.player_charge = parent.max_charge()
	parent.hurt_cooldown = 0.0
	parent.dash_time = 0.0
	parent.dash_cooldown = 0.0
	parent.attack_time = 0.0
	parent.attack_cooldown = 0.0
	parent.deflect_time = 0.0
	parent.deflect_cooldown = 0.0
	parent.combo_step = 0
	parent.combo_window = 0.0
