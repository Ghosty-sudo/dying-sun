extends Node

func fail(message: String) -> void:
	push_error("SAVE_RECOVERY FAILED: " + message)
	SaveManager.clear_campaign()
	get_tree().quit(1)

func write_corrupt_primary() -> bool:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("{ definitely-not-valid-json")
	file.flush()
	return true

func _ready() -> void:
	SaveManager.clear_campaign()
	GameState.reset_campaign()

	# First save becomes the recovery point after the next successful write.
	GameState.set_checkpoint("ash_intake_start", 1)
	GameState.record_relationship("trust", 1)
	if not SaveManager.save_campaign():
		fail("could not create initial campaign save")
		return

	# A second save should atomically promote a new primary while preserving the
	# previous valid campaign snapshot as the backup.
	GameState.set_checkpoint("memory_works_start", 2)
	GameState.record_relationship("curiosity", 1)
	if not SaveManager.save_campaign():
		fail("could not create second campaign save")
		return
	if not FileAccess.file_exists(SaveManager.SAVE_BACKUP_PATH):
		fail("second save did not preserve a backup")
		return

	# Corrupt the primary and prove load falls back to the last known valid
	# backup instead of accepting bad data or resetting silently.
	if not write_corrupt_primary():
		fail("could not corrupt primary for recovery test")
		return
	GameState.reset_campaign()
	if not SaveManager.load_campaign():
		fail("backup recovery failed")
		return
	if GameState.act != 1 or GameState.checkpoint != "ash_intake_start":
		fail("backup did not restore the previous valid checkpoint")
		return
	if GameState.relationship_value("trust") != 1:
		fail("backup did not restore relationship state")
		return

	# Recovery should heal the primary without destroying the known-good backup.
	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		fail("backup recovery did not heal primary save")
		return
	if not FileAccess.file_exists(SaveManager.SAVE_BACKUP_PATH):
		fail("backup was destroyed during primary healing")
		return
	GameState.reset_campaign()
	if not SaveManager.load_campaign():
		fail("healed primary could not be loaded")
		return
	if GameState.act != 1 or GameState.checkpoint != "ash_intake_start":
		fail("healed primary did not preserve recovered state")
		return

	SaveManager.clear_campaign()
	print("Dying Sun save recovery smoke passed")
	get_tree().quit(0)
