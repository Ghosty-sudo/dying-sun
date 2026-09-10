class_name CampaignData
extends RefCounted

static func act_title(act: int) -> String:
	match act:
		1: return "ASH INTAKE"
		2: return "THE MEMORY WORKS"
		3: return "BLACK RELAY"
		4: return "THE CROWN ENGINE"
		5: return "LAST LIGHT"
	return "UNKNOWN SECTOR"

static func act_palette(act: int) -> Dictionary:
	match act:
		1:
			return {"bg": "090b12", "floor": "121826", "edge": "3f495d", "accent": "d99b42", "hazard": "812f39"}
		2:
			return {"bg": "080d12", "floor": "101b21", "edge": "31515b", "accent": "77c3c8", "hazard": "7d4162"}
		3:
			return {"bg": "0b0a11", "floor": "171421", "edge": "554968", "accent": "b493d6", "hazard": "944452"}
		4:
			return {"bg": "0e0b0a", "floor": "211713", "edge": "6f4f3b", "accent": "e8b458", "hazard": "a54034"}
		5:
			return {"bg": "070707", "floor": "17120d", "edge": "725d42", "accent": "ffd06a", "hazard": "c84e37"}
	return {"bg": "090b12", "floor": "121826", "edge": "3f495d", "accent": "d99b42", "hazard": "812f39"}

static func wave(act: int, index: int) -> Array[Dictionary]:
	var waves := {
		1: [
			[
				{"kind": "WARDEN", "pos": Vector2(285, 100), "hp": 3},
				{"kind": "WARDEN", "pos": Vector2(335, 245), "hp": 3},
				{"kind": "HUSK", "pos": Vector2(430, 175), "hp": 4},
			],
			[
				{"kind": "WARDEN", "pos": Vector2(350, 90), "hp": 4},
				{"kind": "HUSK", "pos": Vector2(405, 275), "hp": 4},
				{"kind": "SUN-HUSK", "pos": Vector2(545, 245), "hp": 6},
			],
		],
		2: [
			[
				{"kind": "HUSK", "pos": Vector2(260, 95), "hp": 5},
				{"kind": "ARCHIVIST", "pos": Vector2(410, 95), "hp": 5},
				{"kind": "WARDEN", "pos": Vector2(360, 265), "hp": 4},
			],
			[
				{"kind": "ARCHIVIST", "pos": Vector2(260, 105), "hp": 6},
				{"kind": "ARCHIVIST", "pos": Vector2(440, 250), "hp": 6},
				{"kind": "SUN-HUSK", "pos": Vector2(530, 160), "hp": 7},
			],
		],
		3: [
			[
				{"kind": "RELAY-DRONE", "pos": Vector2(270, 95), "hp": 5},
				{"kind": "WARDEN", "pos": Vector2(370, 245), "hp": 5},
				{"kind": "HUSK", "pos": Vector2(500, 110), "hp": 5},
			],
			[
				{"kind": "RELAY-DRONE", "pos": Vector2(250, 250), "hp": 6},
				{"kind": "RELAY-DRONE", "pos": Vector2(450, 90), "hp": 6},
				{"kind": "SUN-HUSK", "pos": Vector2(535, 245), "hp": 8},
			],
		],
		4: [
			[
				{"kind": "CROWN-GUARD", "pos": Vector2(270, 95), "hp": 7},
				{"kind": "ARCHIVIST", "pos": Vector2(435, 105), "hp": 7},
				{"kind": "WARDEN", "pos": Vector2(355, 270), "hp": 6},
			],
			[
				{"kind": "CROWN-GUARD", "pos": Vector2(250, 105), "hp": 8},
				{"kind": "CROWN-GUARD", "pos": Vector2(450, 250), "hp": 8},
				{"kind": "RELAY-DRONE", "pos": Vector2(535, 155), "hp": 7},
			],
		],
		5: [
			[
				{"kind": "ECHO-WARDEN", "pos": Vector2(270, 95), "hp": 7},
				{"kind": "ARCHIVIST", "pos": Vector2(430, 95), "hp": 7},
				{"kind": "RELAY-DRONE", "pos": Vector2(360, 270), "hp": 7},
			],
			[
				{"kind": "ECHO-WARDEN", "pos": Vector2(245, 105), "hp": 9},
				{"kind": "CROWN-GUARD", "pos": Vector2(440, 250), "hp": 9},
				{"kind": "SUN-HUSK", "pos": Vector2(535, 155), "hp": 9},
			],
		],
	}
	var act_waves: Array = waves.get(act, [])
	if index < 0 or index >= act_waves.size():
		return []
	var result: Array[Dictionary] = []
	for entry in act_waves[index]:
		result.append(Dictionary(entry).duplicate(true))
	return result

static func boss_spec(act: int) -> Dictionary:
	match act:
		1: return {"kind": "GATE-CUSTODIAN", "name": "GATE CUSTODIAN", "hp": 18}
		2: return {"kind": "THE-ARCHIVIST", "name": "THE ARCHIVIST", "hp": 24}
		3: return {"kind": "RELAY-SAINT", "name": "RELAY SAINT", "hp": 28}
		4: return {"kind": "CROWN-CUSTODIAN", "name": "CROWN CUSTODIAN", "hp": 32}
		5: return {"kind": "LAST-LIGHT", "name": "LAST LIGHT", "hp": 38}
	return {"kind": "GATE-CUSTODIAN", "name": "UNKNOWN CUSTODIAN", "hp": 18}

static func pre_choice_dialogue(act: int) -> Array[String]:
	match act:
		1:
			return [
				"SOL: You took long enough. The city noticed you before I did.",
				"SOL: I am bound to the artificial sun above us. You are currently harder to classify.",
				"SOL: Before I open the inner gate, decide what kind of problem you intend to be.",
			]
		2:
			return [
				"SOL: The Memory Works are still indexing dead people. Efficient, if you ignore everything that sentence means.",
				"SOL: One archive contains intact civilian memories. Burning it will stabilize the sector faster.",
				"SOL: I have a preference. You are not required to share it.",
			]
		3:
			return [
				"SOL: Black Relay has enough power for one grid. The civilian vaults or the defense lattice. Not both.",
				"SOL: Choose who gets to believe the lights will stay on.",
			]
		4:
			return [
				"SOL: The Crown Engine is where they taught me the difference between preserving a city and preserving the people inside it.",
				"SOL: There is a sealed record here. I can open the path without it.",
				"SOL: If you open the record, you may like me less. That is not a reason to leave it closed.",
			]
		5:
			return [
				"SOL: This is the last descent.",
				"SOL: Whatever we save now becomes the story everyone else gets to call inevitable.",
				"SOL: I would prefer that we earn it instead.",
			]
	return []

static func choice_labels(act: int) -> Array[String]:
	match act:
		1: return ["TRUST // tell me the truth", "DEFIANCE // I don't trust you"]
		2: return ["PRESERVE // save the archive", "BURN // stabilize the sector"]
		3: return ["CIVILIANS // power the vaults", "DEFENSE // arm the lattice"]
		4: return ["OPEN // show me what you did", "FOLLOW // we finish this first"]
		5: return ["STAY // we decide together", "SEVER // no system owns either of us"]
	return ["LEFT", "RIGHT"]

static func choice_result_dialogue(act: int, choice: int) -> Array[String]:
	match act:
		1:
			if choice == 1:
				return ["YOU: Then trust me enough to tell me the truth.", "SOL: Dangerous opening move. I like it.", "SOL: The sun is dying because the city is feeding it memories. Mine included."]
			return ["YOU: I do not take orders from voices trapped in stars.", "SOL: Good. Obedience would have made you considerably less useful.", "SOL: Keep distrusting me. Just try to survive long enough to be right."]
		2:
			if choice == 1:
				return ["YOU: We preserve the archive.", "SOL: Then we take the slower route and fight for every watt.", "SOL: Thank you. Do not expect me to become agreeable about it."]
			return ["YOU: Burn it. Stabilize the sector.", "SOL: Efficient.", "SOL: I hate that the city taught both of us how useful that word can be."]
		3:
			if choice == 1:
				return ["YOU: Keep the civilian vaults alive.", "SOL: Defense grid goes dark. Expect company.", "SOL: Still the right call. Probably. I reserve the right to complain while proving it."]
			return ["YOU: Arm the lattice.", "SOL: Then we survive the next corridor more easily.", "SOL: Somewhere behind us, people are learning what that choice costs."]
		4:
			if choice == 1:
				return ["YOU: Open the record.", "SOL: ...Fine.", "SOL: I ordered the first memory purge. I thought losing pieces of them was better than losing everyone.", "SOL: I was wrong about how cleanly sacrifice stays in the past."]
			return ["YOU: We finish this first. You can tell me when we live through it.", "SOL: That is either trust or terrible prioritization.", "SOL: I will remember which one it becomes."]
		5:
			if choice == 1:
				return ["YOU: We decide what survives together.", "SOL: Careful. That's dangerously close to a promise.", "SOL: All right. Together, then."]
			return ["YOU: We sever the system. No more owners.", "SOL: Including me.", "SOL: Good. If freedom only counts when I benefit, it was never freedom."]
	return []

static func act_complete_dialogue(act: int) -> Array[String]:
	match act:
		1: return ["SOL: The Gate Custodian is dead. The city will pretend that was impossible.", "SOL: Beyond this gate are the Memory Works. That's where the city keeps the things it couldn't afford to forget."]
		2: return ["SOL: The Archivist is quiet.", "SOL: I expected relief. Apparently I am capable of disappointing myself in new ways."]
		3: return ["SOL: Black Relay is ours for the moment.", "SOL: The Crown Engine is next. I am going to tell you now that I do not want to go there."]
		4: return ["SOL: Crown containment is gone. There is nothing between us and the sun now.", "SOL: If you were planning to abandon me, this would be an extremely dramatic time to do it."]
		5: return ["SOL: It's over.", "SOL: No. That's not right.", "SOL: It changed. We get to find out what that means."]
	return []
