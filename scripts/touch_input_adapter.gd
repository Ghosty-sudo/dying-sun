extends Node

const LEFT_ZONE_X := 300.0
const STICK_RADIUS := 48.0
const MOUSE_POINTER_ID := -2
const SCREEN_MOUSE_SUPPRESS_MS := 650
const RELEASE_RECOVERY_GUARD_MS := 180

var active_pointer_id := -1
var active_source := "none"
var authority_origin := Vector2.ZERO
var authority_move := Vector2.ZERO
var last_screen_event_ms := -1000000
var last_released_screen_id := -999
var last_release_ms := -1000000

func _ready() -> void:
	# This adapter owns the final movement state. Run before the parent gameplay
	# loop so duplicate/synthetic browser input cannot leave a stale vector that
	# the player moves on for a frame.
	process_priority = -200
	sync_parent()

func game():
	return get_parent()

func gameplay_accepts_movement(parent) -> bool:
	return parent != null and parent.ui_mode == "play" and not parent.paused and not parent.dead and not parent.dialogue_open and not parent.module_pending

func now_ms() -> int:
	return Time.get_ticks_msec()

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	if not gameplay_accepts_movement(parent):
		clear_authority()
	sync_parent()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		clear_authority()
		sync_parent()

func _input(event: InputEvent) -> void:
	var parent = game()
	if parent == null:
		return

	if event is InputEventScreenTouch:
		parent.touch_mode = true
		var touch := event as InputEventScreenTouch
		mark_screen_event()
		if touch.pressed:
			if gameplay_accepts_movement(parent) and touch.position.x < LEFT_ZONE_X:
				# A real screen pointer always outranks the mouse-compatible fallback,
				# but a second finger must never steal an already-owned stick.
				if active_source == "none" or active_source == "mouse":
					claim_screen_pointer(touch.index, touch.position)
		elif active_source == "screen" and touch.index == active_pointer_id:
			last_released_screen_id = touch.index
			last_release_ms = now_ms()
			clear_authority()
		sync_parent()
		return

	if event is InputEventScreenDrag:
		parent.touch_mode = true
		var drag := event as InputEventScreenDrag
		mark_screen_event()
		if not gameplay_accepts_movement(parent):
			clear_authority()
			sync_parent()
			return
		if active_source == "screen" and drag.index == active_pointer_id:
			update_authority_vector(drag.position)
		elif active_source == "none" and drag.position.x < LEFT_ZONE_X and can_recover_drag(drag.index):
			# Recover genuinely lost presses, but do not let a late drag immediately
			# resurrect a stick that was just released.
			claim_screen_pointer(drag.index, drag.position - drag.relative)
			update_authority_vector(drag.position)
		sync_parent()
		return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		parent.touch_mode = true
		# iOS/WebKit can emit a mouse-compatible copy of a real finger gesture.
		# Ignore that copy while a real screen stream is active/recent so it
		# cannot replace the real pointer and create ghost movement.
		if screen_stream_recent():
			if not mouse.pressed and active_source == "mouse":
				clear_authority()
			sync_parent()
			return
		if mouse.pressed:
			if gameplay_accepts_movement(parent) and mouse.position.x < LEFT_ZONE_X and active_source == "none":
				claim_mouse_pointer(mouse.position)
		elif active_source == "mouse":
			clear_authority()
		sync_parent()
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if active_source == "mouse" and gameplay_accepts_movement(parent) and not screen_stream_recent():
			# Some iOS Web paths report button_mask == 0 while the finger is still
			# down. Ownership is ended by mouse-up/focus loss, not by that mask.
			update_authority_vector(motion.position)
		sync_parent()

func mark_screen_event() -> void:
	last_screen_event_ms = now_ms()

func screen_stream_recent() -> bool:
	return now_ms() - last_screen_event_ms <= SCREEN_MOUSE_SUPPRESS_MS

func can_recover_drag(pointer_id: int) -> bool:
	return not (pointer_id == last_released_screen_id and now_ms() - last_release_ms <= RELEASE_RECOVERY_GUARD_MS)

func claim_screen_pointer(pointer_id: int, origin: Vector2) -> void:
	active_source = "screen"
	active_pointer_id = pointer_id
	authority_origin = origin
	authority_move = Vector2.ZERO

func claim_mouse_pointer(origin: Vector2) -> void:
	active_source = "mouse"
	active_pointer_id = MOUSE_POINTER_ID
	authority_origin = origin
	authority_move = Vector2.ZERO

func update_authority_vector(position: Vector2) -> void:
	var delta := position - authority_origin
	if delta.length() > STICK_RADIUS:
		delta = delta.normalized() * STICK_RADIUS
	authority_move = delta / STICK_RADIUS

func clear_authority() -> void:
	active_source = "none"
	active_pointer_id = -1
	authority_origin = Vector2.ZERO
	authority_move = Vector2.ZERO

func sync_parent() -> void:
	var parent = game()
	if parent == null:
		return
	parent.touch_move_id = active_pointer_id
	parent.touch_origin = authority_origin
	parent.touch_move = authority_move
