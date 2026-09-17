extends Node

# Act II's preserve/burn consequence is a real encounter, not a tax the player
# should replay every time The Archivist wins. Once the boss is reached, this
# controller turns that moment into a durable retry checkpoint and stabilizes
# the frame for the boss attempt. It never advances the route before the player
# earns the boss room normally.

const CHECKPOINT_FLAG := "act2_archivist_checkpoint"
const BOSS_START := Vector2(102.0, 180.0)

var prepared_attempt := false

func game():
	return get_parent()

func _ready() -> void:
	# On reload, intercept wave_b before SectorDirector rebuilds the consequence
	# room. SectorDirector itself runs at -100.
	process_priority = -110

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	if int(parent.current_act) != 2:
		prepared_attempt = false
		return
	if parent.ui_mode != "play" or parent.paused or parent.dead:
		return

	if str(parent.stage) == "wave_b" and GameState.has_flag(CHECKPOINT_FLAG):
		restore_archivist(parent)
		return

	if str(parent.stage) == "boss" and str(parent.boss_name) == "THE ARCHIVIST":
		if not GameState.has_flag(CHECKPOINT_FLAG):
			GameState.set_flag(CHECKPOINT_FLAG)
			SaveManager.save_campaign()
		if not prepared_attempt:
			stabilize_frame(parent)
			prepared_attempt = true
		return

	prepared_attempt = false

func restore_archivist(parent) -> void:
	var sector = parent.get_node_or_null("SectorDirector")
	if sector != null:
		sector.room_id = "archivist_chamber"
		sector.memory_suppression = 0.0
		sector.memory_grace = 0.0
	parent.enemies.clear()
	parent.projectiles.clear()
	parent.player_pos = BOSS_START
	parent.boss_announced = false
	parent.boss_name = ""
	stabilize_frame(parent)
	parent.spawn_boss()
	prepared_attempt = true
	if sector != null:
		if GameState.has_flag("archive_burned"):
			sector.announce(parent, "THE ARCHIVIST // PURGE-DAMAGED // CHECKPOINT")
		else:
			sector.announce(parent, "THE ARCHIVIST // ARCHIVE INTACT // CHECKPOINT")
	else:
		parent.flash_status("ARCHIVIST CHECKPOINT // FRAME STABILIZED")

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
