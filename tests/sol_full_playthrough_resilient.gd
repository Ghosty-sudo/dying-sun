extends "res://tests/sol_full_playthrough_breaker.gd"

# Keep the accelerated player-bot faithful to the live process order for
# checkpoint controllers introduced after the original tactical harness.
# This file only changes deterministic test scheduling; gameplay logic remains
# owned by the mounted runtime nodes in scenes/main.tscn.

func simulate_frame() -> void:
	if failed:
		return

	router._process(DT)

	var act2_checkpoint = game.get_node_or_null("Act2BossCheckpoint")
	if act2_checkpoint != null:
		act2_checkpoint._process(DT)

	var act3_checkpoint = game.get_node_or_null("Act3BossCheckpoint")
	if act3_checkpoint != null:
		act3_checkpoint._process(DT)

	sector._process(DT)
	act3._process(DT)
	act4._process(DT)
	act5._process(DT)
	if crown_boost != null:
		crown_boost._process(DT)
	breaker._process(DT)
	game._process(DT)

	sim_time += DT
	observe_metrics()
	observe_transition()
