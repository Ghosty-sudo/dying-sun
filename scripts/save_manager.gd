extends Node

const SAVE_PATH := "user://dying_sun_save_v1.json"
const SAVE_TEMP_PATH := "user://dying_sun_save_v1.tmp"
const SAVE_BACKUP_PATH := "user://dying_sun_save_v1.bak"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	return true

func _remove_if_present(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		push_error("Could not remove Dying Sun save artifact: " + path)
		return false
	return true

func save_campaign() -> bool:
	var payload := JSON.stringify(GameState.snapshot())
	if not _write_text(SAVE_TEMP_PATH, payload):
		push_error("Could not write temporary Dying Sun save")
		return false

	# Preserve the last known on-disk payload before replacing it. The backup is
	# intentionally simple JSON so recovery works on desktop and Web user stores.
	if FileAccess.file_exists(SAVE_PATH):
		var previous := _read_text(SAVE_PATH)
		if not previous.is_empty() and not _write_text(SAVE_BACKUP_PATH, previous):
			push_warning("Could not refresh Dying Sun save backup")

	if not _remove_if_present(SAVE_PATH):
		_remove_if_present(SAVE_TEMP_PATH)
		return false

	var rename_err := DirAccess.rename_absolute(SAVE_TEMP_PATH, SAVE_PATH)
	if rename_err != OK:
		push_error("Could not promote temporary Dying Sun save")
		# Best-effort restore of the previous valid payload.
		var backup := _read_text(SAVE_BACKUP_PATH)
		if not backup.is_empty():
			_write_text(SAVE_PATH, backup)
		_remove_if_present(SAVE_TEMP_PATH)
		return false
	return true

func _load_from_path(path: String) -> bool:
	var text := _read_text(path)
	if text.is_empty():
		return false
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return false
	return GameState.load_snapshot(parsed)

func load_campaign() -> bool:
	if _load_from_path(SAVE_PATH):
		return true

	if FileAccess.file_exists(SAVE_PATH):
		push_warning("Primary Dying Sun save is invalid; trying backup")
	if _load_from_path(SAVE_BACKUP_PATH):
		push_warning("Recovered Dying Sun campaign from backup")
		# Heal the primary path from the recovered in-memory snapshot.
		save_campaign()
		return true

	if has_save() or FileAccess.file_exists(SAVE_BACKUP_PATH):
		push_warning("Ignoring invalid or incompatible Dying Sun save data")
	return false

func checkpoint(id: String, act_number: int = GameState.act) -> bool:
	GameState.set_checkpoint(id, act_number)
	return save_campaign()

func start_new_campaign() -> bool:
	if not clear_campaign():
		return false
	GameState.reset_campaign()
	return save_campaign()

func clear_campaign() -> bool:
	var ok := true
	for path in [SAVE_PATH, SAVE_TEMP_PATH, SAVE_BACKUP_PATH]:
		if not _remove_if_present(path):
			ok = false
	GameState.reset_campaign()
	return ok
