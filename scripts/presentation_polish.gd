extends Node2D

var last_ui_mode := ""
var last_menu_selection := -1
var last_settings_selection := -1
var last_pause_selection := -1
var initialized := false

func game():
	return get_parent()

func _ready() -> void:
	process_priority = 90
	z_index = 55
	queue_redraw()

func _process(_delta: float) -> void:
	var parent = game()
	if parent == null:
		return
	var mode: String = str(parent.ui_mode)
	var menu: int = int(parent.menu_selection)
	var settings: int = int(parent.settings_selection)
	var pause: int = int(parent.pause_selection)
	if initialized:
		if mode != last_ui_mode:
			if mode == "ending":
				AudioManager.play_sfx("solar_break")
			elif mode in ["title", "settings"]:
				AudioManager.play_sfx("signal")
		elif mode == "title" and menu != last_menu_selection:
			AudioManager.play_sfx("signal")
		elif mode == "settings" and settings != last_settings_selection:
			AudioManager.play_sfx("signal")
		elif mode == "play" and bool(parent.paused) and pause != last_pause_selection:
			AudioManager.play_sfx("signal")
	initialized = true
	last_ui_mode = mode
	last_menu_selection = menu
	last_settings_selection = settings
	last_pause_selection = pause
	queue_redraw()

func _draw() -> void:
	var parent = game()
	if parent == null:
		return
	match str(parent.ui_mode):
		"title": draw_title_polish(parent)
		"ending": draw_ending_polish(parent)
		"play": draw_play_polish(parent)

func draw_title_polish(parent) -> void:
	var t: float = float(parent.elapsed)
	var gold := Color(0.86, 0.58, 0.25, 0.28)
	var graphite := Color(0.20, 0.24, 0.31, 0.40)
	# Distant machine-city silhouette: intentionally geometric, not placeholder noise.
	for i in range(22):
		var x := 8.0 + float(i) * 30.0
		var height := 18.0 + float((i * 17) % 42)
		draw_rect(Rect2(x, 332.0 - height, 21.0, height), Color(0.08, 0.10, 0.14, 0.58), true)
		if i % 3 == 0:
			draw_rect(Rect2(x + 5.0, 321.0 - height, 2.0, 2.0), gold, true)
	# Broken orbital traces around the title sun reinforce the artificial-sun identity.
	for i in range(3):
		var radius := 70.0 + float(i) * 8.0
		var start := t * (0.08 + float(i) * 0.025) + float(i) * 1.7
		draw_arc(Vector2(320, 105), radius, start, start + PI * (0.45 + float(i) * 0.08), 28, gold, 1.0)
	# Slow ash drift, kept faint enough not to obscure menu copy.
	for i in range(14):
		var px := fmod(float(i * 79) + t * (4.0 + float(i % 3)), 640.0)
		var py := 74.0 + fmod(float(i * 41) + sin(t * 0.45 + float(i)) * 16.0, 235.0)
		draw_circle(Vector2(px, py), 1.0 + float(i % 2), graphite)

func draw_play_polish(parent) -> void:
	if bool(parent.paused) or bool(parent.dead) or bool(parent.dialogue_open) or bool(parent.module_pending):
		return
	var palette: Dictionary = Campaign.act_palette(int(parent.current_act))
	var accent := Color(str(palette["accent"]))
	var c := Color(accent.r, accent.g, accent.b, 0.22)
	# Minimal viewport brackets make the frame feel intentional without crowding combat.
	for corner in [Vector2(18, 86), Vector2(622, 86), Vector2(18, 322), Vector2(622, 322)]:
		var sx := 1.0 if corner.x < 320.0 else -1.0
		var sy := 1.0 if corner.y < 200.0 else -1.0
		draw_line(corner, corner + Vector2(12.0 * sx, 0), c, 1.0)
		draw_line(corner, corner + Vector2(0, 12.0 * sy), c, 1.0)

func draw_ending_polish(parent) -> void:
	var t: float = float(parent.elapsed)
	var id: String = str(parent.ending_id)
	var gold := Color(0.94, 0.68, 0.28, 0.24)
	var cyan := Color(0.38, 0.78, 0.88, 0.25)
	var ember := Color(0.90, 0.24, 0.16, 0.24)
	var graphite := Color(0.38, 0.42, 0.50, 0.20)
	var center := Vector2(320, 184)

	# Shared final horizon gives every ending a deliberate visual closure.
	draw_line(Vector2(72, 290), Vector2(568, 290), graphite, 1.0)
	for i in range(9):
		var x := 96.0 + float(i) * 56.0
		draw_line(Vector2(x, 290), Vector2(320, 184), Color(graphite.r, graphite.g, graphite.b, 0.08), 1.0)

	match id:
		"reconciliation":
			draw_arc(center, 118.0, t * 0.16, t * 0.16 + PI * 1.55, 64, gold, 2.0)
			draw_arc(center, 102.0, -t * 0.19 + PI, -t * 0.19 + PI * 2.55, 64, cyan, 2.0)
			draw_circle(center + Vector2(-132, 0), 4.0, cyan)
			draw_circle(center + Vector2(132, 0), 4.0, gold)
		"preserve_sol":
			var core := Vector2(104, 184)
			draw_circle(core, 11.0, cyan)
			draw_arc(core, 30.0, -t * 0.25, -t * 0.25 + PI * 1.5, 32, gold, 2.0)
			for i in range(5):
				draw_line(core + Vector2(28, float(i - 2) * 10.0), Vector2(185, 184 + float(i - 2) * 16.0), cyan, 1.0)
		"preserve_city":
			for y in range(3):
				for x in range(8):
					var p := Vector2(110 + x * 58, 258 + y * 12)
					draw_circle(p, 2.0, gold if (x + y) % 3 == 0 else graphite)
					if x < 7: draw_line(p, p + Vector2(58, 0), graphite, 1.0)
		"sever_system":
			for i in range(7):
				var a := TAU * float(i) / 7.0 + t * 0.03
				var inner := center + Vector2.RIGHT.rotated(a) * 112.0
				var outer := center + Vector2.RIGHT.rotated(a) * 144.0
				draw_line(inner, outer, ember, 3.0)
			draw_arc(center, 126.0, 0.2, 2.15, 48, graphite, 2.0)
			draw_arc(center, 126.0, 3.0, 5.2, 48, graphite, 2.0)
		"burn_clean":
			for i in range(12):
				var a := TAU * float(i) / 12.0 + t * 0.05
				var inner := center + Vector2.RIGHT.rotated(a) * 118.0
				var outer := center + Vector2.RIGHT.rotated(a) * (142.0 + float(i % 3) * 7.0)
				draw_line(inner, outer, ember, 2.0)
			draw_arc(center, 124.0, t * 0.10, t * 0.10 + PI * 1.25, 52, gold, 2.0)
		_:
			draw_arc(center, 124.0, t * 0.10, t * 0.10 + PI * 1.4, 52, gold, 2.0)