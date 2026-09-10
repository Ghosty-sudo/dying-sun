extends Node

const SAVE_SCHEMA_VERSION := 2

var act: int = 1
var checkpoint: String = "ash_intake_start"
var relationship := {
	"trust": 0,
	"defiance": 0,
	"mercy": 0,
	"pragmatism": 0,
	"curiosity": 0,
}
var promises: Dictionary = {}
var flags: Dictionary = {}
var modules: Array[String] = []
var chassis_trait: String = "balanced"
var run_deaths: int = 0
var ending_seen: String = ""

func reset_campaign() -> void:
	act = 1
	checkpoint = "ash_intake_start"
	relationship = {
		"trust": 0,
		"defiance": 0,
		"mercy": 0,
		"pragmatism": 0,
		"curiosity": 0,
	}
	promises.clear()
	flags.clear()
	modules.clear()
	chassis_trait = "balanced"
	run_deaths = 0
	ending_seen = ""

func record_relationship(kind: String, amount: int = 1) -> void:
	if not relationship.has(kind):
		return
	relationship[kind] = int(relationship[kind]) + amount

func relationship_value(kind: String) -> int:
	return int(relationship.get(kind, 0))

func remember_promise(id: String, text: String) -> void:
	promises[id] = {
		"text": text,
		"status": "open",
	}

func resolve_promise(id: String, kept: bool) -> void:
	if not promises.has(id):
		return
	var entry: Dictionary = promises[id]
	entry["status"] = "kept" if kept else "broken"
	promises[id] = entry

func set_flag(id: String, value = true) -> void:
	flags[id] = value

func has_flag(id: String) -> bool:
	return bool(flags.get(id, false))

func add_module(id: String) -> void:
	if id.is_empty() or modules.has(id):
		return
	modules.append(id)

func has_module(id: String) -> bool:
	return modules.has(id)

func set_checkpoint(id: String, act_number: int = act) -> void:
	checkpoint = id
	act = act_number

func register_death() -> void:
	run_deaths += 1

func set_ending(id: String) -> void:
	ending_seen = id
	set_flag("campaign_complete")

func snapshot() -> Dictionary:
	return {
		"schema": SAVE_SCHEMA_VERSION,
		"act": act,
		"checkpoint": checkpoint,
		"relationship": relationship.duplicate(true),
		"promises": promises.duplicate(true),
		"flags": flags.duplicate(true),
		"modules": modules.duplicate(),
		"chassis_trait": chassis_trait,
		"run_deaths": run_deaths,
		"ending_seen": ending_seen,
	}

func load_snapshot(data: Dictionary) -> bool:
	var schema := int(data.get("schema", -1))
	if schema != 1 and schema != SAVE_SCHEMA_VERSION:
		return false
	act = clampi(int(data.get("act", 1)), 1, 5)
	checkpoint = str(data.get("checkpoint", "ash_intake_start"))
	var loaded_relationship = data.get("relationship", {})
	for key in relationship.keys():
		relationship[key] = int(loaded_relationship.get(key, 0))
	var loaded_promises = data.get("promises", {})
	promises = loaded_promises.duplicate(true) if loaded_promises is Dictionary else {}
	var loaded_flags = data.get("flags", {})
	flags = loaded_flags.duplicate(true) if loaded_flags is Dictionary else {}
	modules.clear()
	var loaded_modules = data.get("modules", [])
	if loaded_modules is Array:
		for module_id in loaded_modules:
			var clean_id := str(module_id)
			if not clean_id.is_empty() and not modules.has(clean_id):
				modules.append(clean_id)
	chassis_trait = str(data.get("chassis_trait", "balanced"))
	run_deaths = maxi(0, int(data.get("run_deaths", 0)))
	ending_seen = str(data.get("ending_seen", ""))
	return true

func available_endings() -> Array[String]:
	var endings: Array[String] = []
	if relationship_value("trust") >= 2 or has_flag("sol_core_recovered"):
		endings.append("preserve_sol")
	if has_flag("civilian_grid_preserved"):
		endings.append("preserve_city")
	if relationship_value("defiance") >= 2 or has_flag("crown_truth_found"):
		endings.append("sever_system")
	endings.append("burn_clean")
	if has_flag("sol_core_recovered") and has_flag("civilian_grid_preserved") and has_flag("crown_truth_found"):
		var broken_promise := false
		for promise in promises.values():
			if promise is Dictionary and str(promise.get("status", "")) == "broken":
				broken_promise = true
				break
		if relationship_value("curiosity") >= 2 and not broken_promise:
			endings.append("reconciliation")
	return endings
