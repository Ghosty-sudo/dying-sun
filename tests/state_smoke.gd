extends SceneTree

func fail(message: String) -> void:
	push_error("STATE_SMOKE FAILED: " + message)
	quit(1)

func _init() -> void:
	var state_script = load("res://scripts/game_state.gd")
	if state_script == null:
		fail("could not load GameState script")
		return

	var state = state_script.new()
	state.record_relationship("trust", 2)
	state.record_relationship("curiosity", 2)
	state.record_relationship("defiance", 2)
	state.remember_promise("test", "Do not forget the test")
	state.resolve_promise("test", true)
	state.set_flag("sol_core_recovered")
	state.set_flag("civilian_grid_preserved")
	state.set_flag("crown_truth_found")
	state.set_checkpoint("last_light", 5)

	var snapshot: Dictionary = state.snapshot()
	if int(snapshot.get("act", 0)) != 5:
		fail("act did not serialize")
		return
	if str(snapshot.get("checkpoint", "")) != "last_light":
		fail("checkpoint did not serialize")
		return

	var restored = state_script.new()
	if not restored.load_snapshot(snapshot):
		fail("valid snapshot rejected")
		return
	if restored.relationship_value("trust") != 2:
		fail("relationship state did not restore")
		return
	if str(restored.promises["test"].get("status", "")) != "kept":
		fail("promise state did not restore")
		return
	if not restored.available_endings().has("reconciliation"):
		fail("earned reconciliation ending unavailable")
		return

	var incompatible := snapshot.duplicate(true)
	incompatible["schema"] = 999
	if restored.load_snapshot(incompatible):
		fail("incompatible schema accepted")
		return

	print("Dying Sun campaign state smoke passed")
	quit(0)
