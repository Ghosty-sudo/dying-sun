extends "res://tests/sol_full_playthrough_clear.gd"

# The full-playthrough harness runs the live processors deterministically inside
# one test frame. Include every checkpoint/pacing controller that the shipped
# scene normally receives from Godot's process scheduler.

func simulate_frame() -> void:
	if failed:
		return

	router._process(DT)

	var act5_checkpoint = game.get_node_or_null("Act5BossCheckpoint")
	if act5_checkpoint != null:
		act5_checkpoint._process(DT)

	var act3_checkpoint = game.get_node_or_null("Act3BossCheckpoint")
	if act3_checkpoint != null:
		act3_checkpoint._process(DT)

	var act4_checkpoint = game.get_node_or_null("Act4BossCheckpoint")
	if act4_checkpoint != null:
		act4_checkpoint._process(DT)

	var act2_checkpoint = game.get_node_or_null("Act2BossCheckpoint")
	if act2_checkpoint != null:
		act2_checkpoint._process(DT)

	sector._process(DT)
	act3._process(DT)
	act4._process(DT)
	act5._process(DT)
	if crown_boost != null:
		crown_boost._process(DT)
	breaker._process(DT)
	game._process(DT)

	var archivist_pacing = game.get_node_or_null("ArchivistPacing")
	if archivist_pacing != null:
		archivist_pacing._process(DT)
	var crown_pacing = game.get_node_or_null("CrownPacing")
	if crown_pacing != null:
		crown_pacing._process(DT)

	sim_time += DT
	observe_metrics()
	observe_transition()
