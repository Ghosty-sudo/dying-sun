extends Node

# Once the player has legitimately carried Sol's link through the shared descent
# (or severed the authority spine), a death at Last Light should retry the final
# boss itself. Replaying the route objective after every boss death was turning
# the finale into repetition instead of mastery.

const CHECKPOINT_FLAG := "act5_last_light_checkpoint"

var prepared_attempt := false

func game():
	return get_parent()

func _ready() -> void:
	# Intercept wave_b before Act5Director rebuilds the already-cleared route.
	process_priority = -120

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	if int(parent.current_act) != 5:
		prepared_attempt = false
		return
	if parent.ui_mode != "play" or parent.paused or parent.dead:
		return

	if str(parent.stage) == "wave_b" and GameState.has_flag(CHECKPOINT_FLAG):
		restore_last_light(parent)
		return

	if str(parent.stage) == "boss" and str(parent.boss_name) == "LAST LIGHT":
		if not GameState.has_flag(CHECKPOINT_FLAG):
			GameState.set_flag(CHECKPOINT_FLAG)
			SaveManager.save_campaign()
		if not prepared_attempt:
			stabilize_frame(parent)
			prepared_attempt = true
		return

	prepared_attempt = false

func restore_last_light(parent) -> void:
	var director = parent.get_node_or_null("Act5Director")
	if director == null:
		return
	parent.enemies.clear()
	parent.projectiles.clear()
	stabilize_frame(parent)
	director.begin_last_light_boss(parent)
	prepared_attempt = true
	director.announce(parent, "LAST LIGHT // CHECKPOINT // FINAL FRAME RESTORED")

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
