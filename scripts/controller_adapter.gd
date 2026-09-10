extends Node

func game():
	return get_parent()

func _input(event: InputEvent) -> void:
	if not event is InputEventJoypadButton:
		return
	var button := event as InputEventJoypadButton
	if not button.pressed:
		return
	var parent = game()
	if parent == null or parent.ui_mode != "play":
		return

	if int(button.button_index) == int(JOY_BUTTON_START):
		parent.paused = not parent.paused
		parent.pause_selection = 0
		return

	if parent.paused:
		return

	if parent.module_pending or parent.choice_pending:
		if int(button.button_index) == int(JOY_BUTTON_A):
			var selecting_module := parent.module_pending
			parent.choose_context_choice(0)
			if selecting_module:
				parent.attack_cooldown = maxf(parent.attack_cooldown, 0.12)
		elif int(button.button_index) == int(JOY_BUTTON_B):
			var selecting_module := parent.module_pending
			parent.choose_context_choice(1)
			if selecting_module:
				parent.attack_cooldown = maxf(parent.attack_cooldown, 0.12)
