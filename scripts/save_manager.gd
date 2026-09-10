extends Node

const SAVE_PATH := "user://dying_sun_save_v1.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_campaign() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing")
		return false
	file.store_string(JSON.stringify(GameState.snapshot()))
	file.flush()
	return true

func load_campaign() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open save file for reading")
		return false
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("Ignoring invalid Dying Sun save data")
		return false
	if not GameState.load_snapshot(parsed):
		push_warning("Ignoring incompatible Dying Sun save schema")
		return false
	return true

func checkpoint(id: String, act_number: int = GameState.act) -> bool:
	GameState.set_checkpoint(id, act_number)
	return save_campaign()

func start_new_campaign() -> bool:
	if not clear_campaign():
		return false
	GameState.reset_campaign()
	return save_campaign()

func clear_campaign() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		var err := DirAccess.remove_absolute(SAVE_PATH)
		if err != OK:
			push_error("Could not remove Dying Sun save")
			return false
	GameState.reset_campaign()
	return true
