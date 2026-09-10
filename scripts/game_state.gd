extends Node

const SAVE_SCHEMA_VERSION := 1

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
var equipped_module: String = ""
var chassis_trait: String = "balanced"
var run_deaths: int = 0

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
	equipped_module = ""
	chassis_trait = "balanced"
	run_deaths = 0

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

func set_checkpoint(id: String, act_number: int = act) -> void:
	checkpoint = id
	act = act_number

func register_death() -> void:
	run_deaths += 1

func snapshot() -> Dictionary:
	return {
		"schema": SAVE_SCHEMA_VERSION,
		"act": act,
		"checkpoint": checkpoint,
		"relationship": relationship.duplicate(true),
		"promises": promises.duplicate(true),
		"flags": flags.duplicate(true),
		"equipped_module": equipped_module,
		"chassis_trait": chassis_trait,
		"run_deaths": run_deaths,
	}

func load_snapshot(data: Dictionary) -> bool:
	if int(data.get("schema", -1)) != SAVE_SCHEMA_VERSION:
		return false
	act = clampi(int(data.get("act", 1)), 1, 5)
	checkpoint = str(data.get("checkpoint", "ash_intake_start"))
	var loaded_relationship = data.get("relationship", {})
	for key in relationship.keys():
		relationship[key] = int(loaded_relationship.get(key, 0))
	promises = Dictionary(data.get("promises", {})).duplicate(true)
	flags = Dictionary(data.get("flags", {})).duplicate(true)
	equipped_module = str(data.get("equipped_module", ""))
	chassis_trait = str(data.get("chassis_trait", "balanced"))
	run_deaths = maxi(0, int(data.get("run_deaths", 0)))
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
		if relationship_value("curiosity") >= 2 and not promises.values().any(func(p): return str(p.get("status", "")) == "broken"):
			endings.append("reconciliation")
	return endings
