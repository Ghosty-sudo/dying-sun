extends Node

# One input owner for keyboard, controller, touch, and Web mouse-compatible
# streams. The main game keeps gameplay logic; this node owns event routing and
# transient pointer state so duplicate input handlers cannot fight each other.

const LEFT_ZONE_X := 300.0
const STICK_RADIUS := 48.0
const MOUSE_POINTER_ID := -2
const SCREEN_MOUSE_SUPPRESS_MS := 650
const RELEASE_RECOVERY_GUARD_MS := 180
const JOY_NAV_THRESHOLD := 0.72

const TOUCH_ATTACK_CENTER := Vector2(562.0, 282.0)
const TOUCH_BOOST_CENTER := Vector2(500.0, 312.0)
const TOUCH_DEFLECT_CENTER := Vector2(438.0, 312.0)
const TOUCH_BREAKER_CENTER := Vector2(562.0, 218.0)
const TOUCH_PAUSE_CENTER := Vector2(590.0, 45.0)
const TOUCH_RESTART_RECT := Rect2(205.0, 286.0, 230.0, 30.0)
const TOUCH_BUTTON_RADIUS := 44.0
const TOUCH_BREAKER_RADIUS := 40.0
const TOUCH_PAUSE_RADIUS := 28.0

var active_pointer_id := -1
var active_source := "none"
var authority_origin := Vector2.ZERO
var authority_move := Vector2.ZERO
var breaker_pointer_id := -1
var blocked_drag_ids: Dictionary = {}
var last_screen_event_ms := -1000000
var last_released_screen_id := -999
var last_release_ms := -1000000

# Test-only escape hatch used by headless smoke coverage. Runtime never toggles it.
var force_mouse_touch_fallback := false

func _ready() -> void:
	process_priority = -300
	_disable_legacy_input_owners()
	sync_parent()

func game():
	return get_parent()

func _disable_legacy_input_owners() -> void:
	var parent = game()
	if parent == null:
		return
	# game.gd still contains compatibility handlers while the core is migrated,
	# but they are intentionally dormant. All live events enter through here.
	parent.set_process_input(false)
	parent.set_process_unhandled_key_input(false)
	for node_name in ["BreakerController", "PlayerPathPolish", "ControllerAdapter", "TouchInputAdapter"]:
		var node = parent.get_node_or_null(node_name)
		if node != null:
			node.set_process_input(false)
			node.set_process_unhandled_input(false)
			node.set_process_unhandled_key_input(false)

func now_ms() -> int:
	return Time.get_ticks_msec()

func gameplay_accepts_movement(parent = null) -> bool:
	if parent == null:
		parent = game()
	return parent != null and parent.ui_mode == "play" and not parent.paused and not parent.dead and not parent.dialogue_open and not parent.module_pending

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	if not gameplay_accepts_movement(parent):
		clear_movement_authority()
	elif active_source != "none" and int(parent.touch_move_id) == -1 and Vector2(parent.touch_move) == Vector2.ZERO:
		# The gameplay runtime intentionally clears its compatibility mirror when
		# resetting a checkpoint/act. Treat that as a request to clear ownership
		# instead of resurrecting an old vector on the next frame.
		clear_movement_authority()
	sync_parent()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_transient_input()

func _input(event: InputEvent) -> void:
	var parent = game()
	if parent == null:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		parent.touch_mode = true
		mark_screen_event()
		if touch.pressed:
			route_pointer_press(parent, touch.position, touch.index, "screen")
		else:
			route_pointer_release(parent, touch.index, "screen")
		sync_parent()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		parent.touch_mode = true
		mark_screen_event()
		handle_screen_drag(parent, drag)
		sync_parent()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		handle_mouse_button(parent, event as InputEventMouseButton)
		return

	if event is InputEventMouseMotion:
		handle_mouse_motion(parent, event as InputEventMouseMotion)
		return

	if event is InputEventKey:
		handle_key(parent, event as InputEventKey)
		return

	if event is InputEventJoypadButton:
		handle_joy_button(parent, event as InputEventJoypadButton)
		return

	if event is InputEventJoypadMotion:
		handle_joy_motion(parent, event as InputEventJoypadMotion)

func mark_screen_event() -> void:
	last_screen_event_ms = now_ms()
	if active_source == "mouse":
		clear_movement_authority()
	if breaker_pointer_id == MOUSE_POINTER_ID:
		breaker_pointer_id = -1
		cancel_breaker()

func screen_stream_recent() -> bool:
	return now_ms() - last_screen_event_ms <= SCREEN_MOUSE_SUPPRESS_MS

func can_recover_drag(pointer_id: int) -> bool:
	if blocked_drag_ids.has(pointer_id):
		return false
	return not (pointer_id == last_released_screen_id and now_ms() - last_release_ms <= RELEASE_RECOVERY_GUARD_MS)

func route_pointer_press(parent, pos: Vector2, pointer_id: int, source: String) -> void:
	# Menus and narrative states are exclusive. A touch used to select/advance
	# one of these must never later become a recovered movement pointer.
	if parent.ui_mode == "title":
		blocked_drag_ids[pointer_id] = true
		parent.handle_title_pointer(pos)
		return
	if parent.ui_mode == "settings":
		blocked_drag_ids[pointer_id] = true
		parent.handle_settings_pointer(pos)
		return
	if parent.ui_mode == "ending":
		blocked_drag_ids[pointer_id] = true
		parent.advance_ending()
		return
	if parent.ui_mode != "play":
		blocked_drag_ids[pointer_id] = true
		return

	if not parent.dead and pos.distance_to(TOUCH_PAUSE_CENTER) <= TOUCH_PAUSE_RADIUS:
		blocked_drag_ids[pointer_id] = true
		set_paused(parent, not bool(parent.paused))
		return

	if parent.paused:
		blocked_drag_ids[pointer_id] = true
		if TOUCH_RESTART_RECT.has_point(pos):
			restart_checkpoint(parent)
		else:
			parent.handle_pause_pointer(pos)
		return

	if parent.dead:
		blocked_drag_ids[pointer_id] = true
		restart_checkpoint(parent)
		return

	if parent.module_pending:
		blocked_drag_ids[pointer_id] = true
		parent.choose_module(0 if pos.x < 320.0 else 1)
		return

	if parent.dialogue_open:
		blocked_drag_ids[pointer_id] = true
		if parent.choice_pending:
			parent.choose_context_choice(0 if pos.x < 320.0 else 1)
		else:
			parent.try_interact()
		return

	if pos.distance_to(TOUCH_BREAKER_CENTER) <= TOUCH_BREAKER_RADIUS:
		blocked_drag_ids[pointer_id] = true
		if begin_breaker(parent):
			breaker_pointer_id = pointer_id
		return

	if pos.distance_to(TOUCH_ATTACK_CENTER) <= TOUCH_BUTTON_RADIUS:
		blocked_drag_ids[pointer_id] = true
		parent.perform_attack()
		return
	if pos.distance_to(TOUCH_BOOST_CENTER) <= TOUCH_BUTTON_RADIUS:
		blocked_drag_ids[pointer_id] = true
		parent.perform_boost()
		return
	if pos.distance_to(TOUCH_DEFLECT_CENTER) <= TOUCH_BUTTON_RADIUS:
		blocked_drag_ids[pointer_id] = true
		parent.perform_deflect()
		return

	if pos.x < LEFT_ZONE_X:
		if active_source == "none" or (active_source == "mouse" and source == "screen"):
			claim_movement_pointer(pointer_id, pos, source)
		else:
			# A second finger that arrived while the stick was already owned cannot
			# become movement later if the original finger releases first.
			blocked_drag_ids[pointer_id] = true
	else:
		blocked_drag_ids[pointer_id] = true

func route_pointer_release(_parent, pointer_id: int, source: String) -> void:
	if pointer_id == breaker_pointer_id:
		breaker_pointer_id = -1
		release_breaker()
	if source == "screen" and active_source == "screen" and pointer_id == active_pointer_id:
		last_released_screen_id = pointer_id
		last_release_ms = now_ms()
		clear_movement_authority()
	elif source == "mouse" and active_source == "mouse" and pointer_id == MOUSE_POINTER_ID:
		clear_movement_authority()
	blocked_drag_ids.erase(pointer_id)

func handle_screen_drag(parent, drag: InputEventScreenDrag) -> void:
	if not gameplay_accepts_movement(parent):
		clear_movement_authority()
		return
	if active_source == "screen" and drag.index == active_pointer_id:
		update_movement_vector(drag.position)
		return
	if active_source == "none" and drag.position.x < LEFT_ZONE_X and can_recover_drag(drag.index):
		# Recover a genuinely lost initial press. The release guard and blocked-ID
		# set prevent late/action drags from becoming ghost movement.
		claim_movement_pointer(drag.index, drag.position - drag.relative, "screen")
		update_movement_vector(drag.position)

func claim_movement_pointer(pointer_id: int, origin: Vector2, source: String) -> void:
	active_source = source
	active_pointer_id = pointer_id
	authority_origin = origin
	authority_move = Vector2.ZERO

func update_movement_vector(position: Vector2) -> void:
	var delta := position - authority_origin
	if delta.length() > STICK_RADIUS:
		delta = delta.normalized() * STICK_RADIUS
	authority_move = delta / STICK_RADIUS

func clear_movement_authority() -> void:
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

func mouse_touch_fallback_enabled(parent) -> bool:
	return force_mouse_touch_fallback or parent.touch_mode or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func handle_mouse_button(parent, mouse: InputEventMouseButton) -> void:
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return

	# Desktop mouse remains useful for menus without entering touch mode.
	if mouse.pressed and parent.ui_mode == "title":
		parent.handle_title_pointer(mouse.position)
		get_viewport().set_input_as_handled()
		return
	if mouse.pressed and parent.ui_mode == "settings":
		parent.handle_settings_pointer(mouse.position)
		get_viewport().set_input_as_handled()
		return
	if mouse.pressed and parent.ui_mode == "ending":
		parent.advance_ending()
		get_viewport().set_input_as_handled()
		return
	if parent.ui_mode != "play" or not mouse_touch_fallback_enabled(parent):
		return

	# Suppress WebKit's mouse-compatible duplicate while a real screen stream
	# is active/recent. This applies to buttons as well as movement so a single
	# finger cannot attack or pause twice.
	if screen_stream_recent():
		if not mouse.pressed:
			route_pointer_release(parent, MOUSE_POINTER_ID, "mouse")
		sync_parent()
		get_viewport().set_input_as_handled()
		return

	parent.touch_mode = true
	if mouse.pressed:
		route_pointer_press(parent, mouse.position, MOUSE_POINTER_ID, "mouse")
	else:
		route_pointer_release(parent, MOUSE_POINTER_ID, "mouse")
	sync_parent()
	get_viewport().set_input_as_handled()

func handle_mouse_motion(parent, motion: InputEventMouseMotion) -> void:
	if active_source == "mouse" and gameplay_accepts_movement(parent) and not screen_stream_recent():
		# iOS Web paths can report button_mask == 0 while the fallback finger is
		# still down. Ownership ends on mouse-up/focus loss, not that mask.
		update_movement_vector(motion.position)
		sync_parent()

func handle_key(parent, key: InputEventKey) -> void:
	# Breaker is the only keyboard action that needs both press and release.
	if parent.ui_mode == "play" and not parent.paused and key.keycode == KEY_Q and not key.echo:
		if key.pressed:
			begin_breaker(parent)
		else:
			release_breaker()
		get_viewport().set_input_as_handled()
		return

	if not key.pressed or key.echo:
		return

	if parent.ui_mode == "title":
		parent.handle_menu_key(key.keycode)
		get_viewport().set_input_as_handled()
		return
	if parent.ui_mode == "settings":
		parent.handle_settings_key(key.keycode)
		get_viewport().set_input_as_handled()
		return
	if parent.ui_mode == "ending":
		if key.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]:
			parent.advance_ending()
		elif key.keycode == KEY_ESCAPE:
			parent.ui_mode = "title"
		get_viewport().set_input_as_handled()
		return
	if parent.ui_mode != "play":
		return

	if key.keycode == KEY_ESCAPE:
		set_paused(parent, not bool(parent.paused))
		get_viewport().set_input_as_handled()
		return

	if parent.paused:
		if key.keycode == KEY_R:
			restart_checkpoint(parent)
		else:
			parent.handle_pause_key(key.keycode)
		get_viewport().set_input_as_handled()
		return

	match key.keycode:
		KEY_SPACE: parent.perform_attack()
		KEY_SHIFT: parent.perform_boost()
		KEY_F: parent.perform_deflect()
		KEY_E: parent.try_interact()
		KEY_1: parent.choose_context_choice(0)
		KEY_2: parent.choose_context_choice(1)
		KEY_R:
			if parent.dead:
				restart_checkpoint(parent)
		_: return
	get_viewport().set_input_as_handled()

func handle_joy_button(parent, button: InputEventJoypadButton) -> void:
	var index := int(button.button_index)

	# Breaker shoulder needs press + release, just like Q.
	if parent.ui_mode == "play" and not parent.paused and index == int(JOY_BUTTON_LEFT_SHOULDER):
		if button.pressed:
			begin_breaker(parent)
		else:
			release_breaker()
		get_viewport().set_input_as_handled()
		return

	if not button.pressed:
		return

	if parent.ui_mode == "title":
		if index == int(JOY_BUTTON_A): parent.activate_title_selection()
		elif index == int(JOY_BUTTON_DPAD_UP): parent.menu_selection = wrapi(parent.menu_selection - 1, 0, parent.title_options().size())
		elif index == int(JOY_BUTTON_DPAD_DOWN): parent.menu_selection = wrapi(parent.menu_selection + 1, 0, parent.title_options().size())
		else: return
		get_viewport().set_input_as_handled()
		return

	if parent.ui_mode == "settings":
		if index == int(JOY_BUTTON_A): parent.adjust_current_setting(1)
		elif index == int(JOY_BUTTON_B): parent.leave_settings()
		elif index == int(JOY_BUTTON_DPAD_UP): parent.settings_selection = wrapi(parent.settings_selection - 1, 0, parent.settings_entries().size())
		elif index == int(JOY_BUTTON_DPAD_DOWN): parent.settings_selection = wrapi(parent.settings_selection + 1, 0, parent.settings_entries().size())
		elif index == int(JOY_BUTTON_DPAD_LEFT): parent.adjust_current_setting(-1)
		elif index == int(JOY_BUTTON_DPAD_RIGHT): parent.adjust_current_setting(1)
		else: return
		get_viewport().set_input_as_handled()
		return

	if parent.ui_mode == "ending":
		if index in [int(JOY_BUTTON_A), int(JOY_BUTTON_Y)]:
			parent.advance_ending()
		elif index == int(JOY_BUTTON_B):
			parent.ui_mode = "title"
		else:
			return
		get_viewport().set_input_as_handled()
		return

	if parent.ui_mode != "play":
		return

	if index == int(JOY_BUTTON_START):
		set_paused(parent, not bool(parent.paused))
		get_viewport().set_input_as_handled()
		return

	if parent.paused:
		if index == int(JOY_BUTTON_A): parent.activate_pause_selection()
		elif index == int(JOY_BUTTON_B): set_paused(parent, false)
		elif index == int(JOY_BUTTON_Y): restart_checkpoint(parent)
		elif index == int(JOY_BUTTON_DPAD_UP): parent.pause_selection = wrapi(parent.pause_selection - 1, 0, parent.pause_options().size())
		elif index == int(JOY_BUTTON_DPAD_DOWN): parent.pause_selection = wrapi(parent.pause_selection + 1, 0, parent.pause_options().size())
		else: return
		get_viewport().set_input_as_handled()
		return

	if parent.module_pending or parent.choice_pending:
		if index == int(JOY_BUTTON_A):
			parent.choose_context_choice(0)
		elif index == int(JOY_BUTTON_B):
			parent.choose_context_choice(1)
		else:
			return
		get_viewport().set_input_as_handled()
		return

	match index:
		JOY_BUTTON_A: parent.perform_attack()
		JOY_BUTTON_B: parent.perform_boost()
		JOY_BUTTON_X: parent.perform_deflect()
		JOY_BUTTON_Y: parent.try_interact()
		_: return
	get_viewport().set_input_as_handled()

func handle_joy_motion(parent, motion: InputEventJoypadMotion) -> void:
	if float(parent.menu_nav_cooldown) > 0.0 or absf(motion.axis_value) < JOY_NAV_THRESHOLD:
		return
	if int(motion.axis) == int(JOY_AXIS_LEFT_Y):
		var direction := 1 if motion.axis_value > 0.0 else -1
		if parent.ui_mode == "title":
			parent.menu_selection = wrapi(parent.menu_selection + direction, 0, parent.title_options().size())
		elif parent.ui_mode == "settings":
			parent.settings_selection = wrapi(parent.settings_selection + direction, 0, parent.settings_entries().size())
		elif parent.ui_mode == "play" and parent.paused:
			parent.pause_selection = wrapi(parent.pause_selection + direction, 0, parent.pause_options().size())
		else:
			return
		parent.menu_nav_cooldown = 0.18
		get_viewport().set_input_as_handled()
	elif int(motion.axis) == int(JOY_AXIS_LEFT_X) and parent.ui_mode == "settings":
		parent.adjust_current_setting(1 if motion.axis_value > 0.0 else -1)
		parent.menu_nav_cooldown = 0.18
		get_viewport().set_input_as_handled()

func begin_breaker(parent) -> bool:
	var breaker = parent.get_node_or_null("BreakerController")
	if breaker == null:
		return false
	if not breaker.breaker_available():
		parent.flash_status("BREAKER // UNLOCKS ACT II")
		return false
	return bool(breaker.begin_charge())

func release_breaker() -> void:
	var parent = game()
	if parent == null:
		return
	var breaker = parent.get_node_or_null("BreakerController")
	if breaker != null:
		breaker.release_charge()

func cancel_breaker() -> void:
	var parent = game()
	if parent == null:
		return
	var breaker = parent.get_node_or_null("BreakerController")
	if breaker != null:
		breaker.cancel_charge()

func set_paused(parent, value: bool) -> void:
	parent.paused = value
	parent.pause_selection = 0
	clear_movement_authority()
	if value:
		cancel_breaker()
	sync_parent()

func restart_checkpoint(parent) -> void:
	clear_movement_authority()
	breaker_pointer_id = -1
	blocked_drag_ids.clear()
	cancel_breaker()
	parent.paused = false
	parent.pause_selection = 0
	parent.restart_from_checkpoint()
	sync_parent()

func cancel_transient_input() -> void:
	clear_movement_authority()
	breaker_pointer_id = -1
	blocked_drag_ids.clear()
	cancel_breaker()
	sync_parent()
