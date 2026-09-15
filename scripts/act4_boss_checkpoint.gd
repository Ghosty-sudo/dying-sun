extends Node

# Crown Engine route objectives are meaningful once. After the player earns the
# Crown Custodian chamber, retries should test the adaptive boss rather than
# replaying record extraction / overdrive traversal. Preserve the authored route
# consequence and the counter-profile chosen from the completed route.

const CHECKPOINT_FLAG := "act4_crown_custodian_checkpoint"
const BOSS_START := Vector2(102.0, 180.0)

var prepared_attempt := false

func game():
	return get_parent()

func _ready() -> void:
	# Act4Director runs at -80. Intercept wave_b first on checkpoint retries.
	process_priority = -100

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	if int(parent.current_act) != 4:
		prepared_attempt = false
		return
	if parent.ui_mode != "play" or parent.paused or parent.dead:
		return

	if str(parent.stage) == "wave_b" and GameState.has_flag(CHECKPOINT_FLAG):
		restore_crown_custodian(parent)
		return

	if str(parent.stage) == "boss" and str(parent.boss_name) == "CROWN CUSTODIAN":
		if not GameState.has_flag(CHECKPOINT_FLAG):
			GameState.set_flag(CHECKPOINT_FLAG)
			SaveManager.save_campaign()
		if not prepared_attempt:
			stabilize_frame(parent)
			prepared_attempt = true
		return

	prepared_attempt = false

func restore_crown_custodian(parent) -> void:
	var director = parent.get_node_or_null("Act4Director")
	if director != null:
		director.room_id = "crown_chamber"
		director.counter_clock = 0.0
		director.breaker_phase_cooldown = 0.0
		director.counter_profile = str(GameState.flags.get("crown_counter_profile", "balanced"))

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
		director.announce(parent, "CROWN CUSTODIAN // CHECKPOINT // COUNTER: " + str(director.counter_profile).to_upper())
	else:
		parent.flash_status("CROWN CUSTODIAN CHECKPOINT // FRAME STABILIZED")

func apply_route_consequence(parent) -> void:
	if GameState.has_flag("crown_record_extracted") and not parent.enemies.is_empty():
		var boss: Dictionary = parent.enemies[0]
		if str(boss.get("kind", "")) == "CROWN-CUSTODIAN":
			boss["stagger"] = minf(float(boss["stagger_max"]) - 0.1, float(boss["stagger"]) + 4.0)
			parent.enemies[0] = boss
	elif GameState.has_flag("crown_truth_deferred"):
		parent.player_charge = parent.max_charge()

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
