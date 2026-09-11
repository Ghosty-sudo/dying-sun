extends Node2D

const TRACE_DISTANCE := 92.0
const TRACE_RADIUS := 32.0
const TELEGRAPH_TIME := 0.42
const ACTIVE_TIME := 0.18

var trace_pos := Vector2.ZERO
var telegraph_time := 0.0
var active_time := 0.0
var previous_boost := false

func game():
	return get_parent()

func act4():
	var parent = game()
	return parent.get_node_or_null("Act4Director") if parent != null else null

func _ready() -> void:
	process_priority = -70
	z_index = 39
	queue_redraw()

func _process(delta: float) -> void:
	var parent = game()
	var director = act4()
	if parent == null or director == null:
		return
	if int(parent.current_act) != 4 or str(parent.stage) != "boss" or str(parent.boss_name) != "CROWN CUSTODIAN" or str(director.counter_profile) != "boost":
		reset_trace()
		return
	if parent.ui_mode != "play" or parent.paused or parent.dead:
		queue_redraw()
		return

	var boosting := float(parent.dash_time) > 0.0
	if boosting and not previous_boost and telegraph_time <= 0.0 and active_time <= 0.0:
		arm_trace(parent)
	previous_boost = boosting

	if telegraph_time > 0.0:
		telegraph_time = maxf(0.0, telegraph_time - delta)
		if telegraph_time <= 0.0:
			active_time = ACTIVE_TIME
			AudioManager.play_sfx("crown_phase")
	elif active_time > 0.0:
		active_time = maxf(0.0, active_time - delta)
		if parent.hurt_cooldown <= 0.0 and parent.dash_time <= 0.0 and parent.player_pos.distance_to(trace_pos) <= TRACE_RADIUS:
			parent.hurt_player(1)
			parent.flash_status("CROWN READ // BOOST LANDING PUNISHED")
			active_time = 0.0
	queue_redraw()

func arm_trace(parent) -> void:
	var direction: Vector2 = parent.last_move
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	trace_pos = parent.clamp_to_arena(parent.player_pos + direction * TRACE_DISTANCE, TRACE_RADIUS)
	telegraph_time = TELEGRAPH_TIME
	active_time = 0.0
	parent.flash_status("CROWN READ // LANDING TRACE // REDIRECT")
	AudioManager.play_sfx("signal")
	queue_redraw()

func reset_trace() -> void:
	trace_pos = Vector2.ZERO
	telegraph_time = 0.0
	active_time = 0.0
	previous_boost = false
	queue_redraw()

func _draw() -> void:
	var parent = game()
	var director = act4()
	if parent == null or director == null:
		return
	if int(parent.current_act) != 4 or str(parent.stage) != "boss" or str(parent.boss_name) != "CROWN CUSTODIAN" or str(director.counter_profile) != "boost":
		return
	if telegraph_time <= 0.0 and active_time <= 0.0:
		return

	var warning := Color(0.96, 0.34, 0.24, 0.88)
	var fill_alpha := 0.08 if telegraph_time > 0.0 else 0.23
	draw_circle(trace_pos, TRACE_RADIUS, Color(warning.r, warning.g, warning.b, fill_alpha), true)
	draw_arc(trace_pos, TRACE_RADIUS, 0.0, TAU, 36, warning, 3.0)
	if telegraph_time > 0.0:
		var ratio := 1.0 - clampf(telegraph_time / TELEGRAPH_TIME, 0.0, 1.0)
		draw_arc(trace_pos, TRACE_RADIUS + 8.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36, Color(1.0, 0.78, 0.48, 0.96), 4.0)
