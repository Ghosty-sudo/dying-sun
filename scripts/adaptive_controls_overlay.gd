extends Node2D

# Presentation-only control legend. Input ownership stays in InputRouter; this
# node reads the router's active presentation mode and shows only the controls
# that make sense for the device/input source the player is actually using.

func _ready() -> void:
	z_index = 90
	process_priority = 90
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var parent = get_parent()
	if parent == null:
		return
	var router = parent.get_node_or_null("InputRouter")
	var mode := "touch" if bool(parent.touch_mode) else "keyboard"
	if router != null:
		mode = str(router.presentation_mode)

	var font := ThemeDB.fallback_font
	if parent.ui_mode == "title":
		draw_rect(Rect2(112, 330, 416, 22), Color(0.02, 0.025, 0.04, 0.80), true)
		draw_string(font, Vector2(126, 345), "INPUT AUTO-DETECT // keyboard + mouse // controller // touch", HORIZONTAL_ALIGNMENT_CENTER, 388, 9, Color(0.64, 0.71, 0.80, 0.90))
		return

	if parent.ui_mode != "play":
		return

	# The first real desktop report read the coolant rails as arena-boundary
	# damage. Keep the mechanic, but label it continuously while the room is live
	# so damage has a visible cause instead of feeling like an invisible wall.
	if str(parent.stage) == "sector_coolant":
		draw_rect(Rect2(34, 72, 244, 23), Color(0.02, 0.05, 0.07, 0.88), true)
		draw_string(font, Vector2(42, 87), "CYAN TOP / BOTTOM RAILS = DAMAGE", HORIZONTAL_ALIGNMENT_CENTER, 228, 9, Color(0.48, 0.90, 0.98, 0.96))

	if mode == "touch":
		return

	# Cover the legacy one-line hint with a clearer two-line legend without
	# consuming meaningful arena space.
	draw_rect(Rect2(18, 326, 604, 32), Color(0.015, 0.02, 0.032, 0.90), true)
	draw_line(Vector2(24, 327), Vector2(616, 327), Color(0.35, 0.43, 0.55, 0.45), 1.0)

	if mode == "controller":
		draw_string(font, Vector2(28, 340), "LS MOVE   A STRIKE   B BOOST   X PARRY   LB BREAKER", HORIZONTAL_ALIGNMENT_CENTER, 584, 10, Color(0.76, 0.82, 0.90, 0.96))
		draw_string(font, Vector2(28, 353), "Y INTERACT   A/B CHOOSE   MENU PAUSE   Y RESTART WHEN PAUSED", HORIZONTAL_ALIGNMENT_CENTER, 584, 9, Color(0.57, 0.66, 0.77, 0.92))
	else:
		draw_string(font, Vector2(28, 340), "WASD / ARROWS MOVE   SPACE STRIKE   SHIFT BOOST   F PARRY", HORIZONTAL_ALIGNMENT_CENTER, 584, 10, Color(0.76, 0.82, 0.90, 0.96))
		draw_string(font, Vector2(28, 353), "Q HOLD + RELEASE BREAKER   E INTERACT   1 / 2 CHOOSE   ESC PAUSE", HORIZONTAL_ALIGNMENT_CENTER, 584, 9, Color(0.57, 0.66, 0.77, 0.92))
