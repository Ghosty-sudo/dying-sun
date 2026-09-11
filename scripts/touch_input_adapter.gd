extends Node

const LEFT_ZONE_X := 300.0
const STICK_RADIUS := 48.0
const MOUSE_POINTER_ID := -2

func game():
	return get_parent()

func gameplay_accepts_movement(parent) -> bool:
	return parent != null and parent.ui_mode == "play" and not parent.paused and not parent.dead and not parent.dialogue_open and not parent.module_pending

func _input(event: InputEvent) -> void:
	var parent = game()
	if parent == null:
		return

	if event is InputEventScreenTouch:
		parent.touch_mode = true
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if gameplay_accepts_movement(parent) and touch.position.x < LEFT_ZONE_X:
				claim_pointer(parent, touch.index, touch.position)
		elif touch.index == parent.touch_move_id:
			release_pointer(parent)
		return

	if event is InputEventScreenDrag:
		parent.touch_mode = true
		var drag := event as InputEventScreenDrag
		if not gameplay_accepts_movement(parent):
			return
		# Mobile browsers can occasionally deliver drag motion after the original
		# press was lost during focus/canvas changes. Recover the joystick instead
		# of leaving the player frozen.
		if parent.touch_move_id < 0 and drag.position.x < LEFT_ZONE_X:
			claim_pointer(parent, drag.index, drag.position - drag.relative)
		if drag.index == parent.touch_move_id:
			update_vector(parent, drag.position)
		return

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		# Godot Web/iOS can expose a finger gesture through the mouse-compatible
		# path. The core game already handles button taps there, but historically
		# it could not create a movement pointer because it rejected negative IDs.
		parent.touch_mode = true
		if mouse.pressed:
			if gameplay_accepts_movement(parent) and mouse.position.x < LEFT_ZONE_X:
				claim_pointer(parent, MOUSE_POINTER_ID, mouse.position)
		elif parent.touch_move_id == MOUSE_POINTER_ID:
			release_pointer(parent)
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if parent.touch_move_id == MOUSE_POINTER_ID and gameplay_accepts_movement(parent):
			# Touch-derived mouse motion in iOS Web can arrive with button_mask == 0
			# even while the finger is still down. Once we have captured a pointer,
			# trust the capture until the explicit mouse-up event instead of treating
			# a missing mask as a release. This keeps the virtual stick alive on the
			# real browser path while preserving normal mouse-up cleanup.
			update_vector(parent, motion.position)

func claim_pointer(parent, pointer_id: int, origin: Vector2) -> void:
	parent.touch_move_id = pointer_id
	parent.touch_origin = origin
	parent.touch_move = Vector2.ZERO

func update_vector(parent, position: Vector2) -> void:
	var delta := position - Vector2(parent.touch_origin)
	if delta.length() > STICK_RADIUS:
		delta = delta.normalized() * STICK_RADIUS
	parent.touch_move = delta / STICK_RADIUS

func release_pointer(parent) -> void:
	parent.touch_move_id = -1
	parent.touch_move = Vector2.ZERO
