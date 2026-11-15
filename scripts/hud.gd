extends CanvasLayer
# Everything drawn on top of the world: the three bars, the hearts, the day strip,
# the minimap, the to-do list, news, dialogs, decision cards and the machine tour.

signal choice_picked(index: int)
signal choice_hovered(index: int)
signal tour_skip
signal pause_resume
signal pause_quit

const MinimapScript = preload("res://scripts/minimap.gd")
const GOLD := Color(1.0, 0.85, 0.5)
const DIALOG_POS := Vector2(190, 500)
const BANNER_POS := Vector2(340, 62)


class Typer extends RefCounted:
	var label: Label
	var text := ""
	var shown := 0
	var wait := 0.0
	var letters := 0

	func start(p_label: Label, p_text: String) -> void:
		label = p_label
		text = p_text
		label.text = p_text
		shown = 0
		wait = 0.0
		letters = 0
		label.visible_characters = 0

	func typing() -> bool:
		return label != null and shown < text.length()

	func finish() -> void:
		if label == null:
			return
		shown = text.length()
		label.visible_characters = -1

	func step(delta: float, speed: float) -> bool:
		if not typing():
			return false
		if speed <= 0.0:
			finish()
			return false
		var blip := false
		wait -= delta
		while wait <= 0.0 and shown < text.length():
			var c: String = text[shown]
			shown += 1
			wait += 1.0 / speed
			var next := " "
			if shown < text.length():
				next = text[shown]
			if ".!?".contains(c) and (next == " " or next == "\n"):
				wait += 0.25
			elif c == "," and next == " ":
				wait += 0.1
			if c != " " and c != "\n":
				letters += 1
				if letters % 3 == 1:
					blip = true
		if shown >= text.length():
			label.visible_characters = -1
		else:
			label.visible_characters = shown
		return blip


class NextMarker extends Control:
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(18, 16)

	func _process(delta: float) -> void:
		if visible:
			t += delta
			queue_redraw()

	func _draw() -> void:
		var y: float = 3.0 + sin(t * 6.0) * 3.0
		var tri := PackedVector2Array([Vector2(1, y), Vector2(17, y), Vector2(9, y + 10)])
		draw_colored_polygon(tri, Color(1.0, 0.85, 0.5))


# ---------------------------------------------------------------- the drawn gauges
# The bars, hearts, spare parts, machine lights and the day strip are painted straight
# onto the screen (no dark boxes behind them), so the game world stays easy to see.

class Gauges extends Control:
	var font: Font
	var t := 0.0
	var energy := 0.0
	var oxygen := 0.0
	var food := 0.0
	var health := 100.0
	var trends := [0, 0, 0]             # energy, oxygen, food: +1 going up, -1 going down
	var energy_cap := 100.0
	var parts := 0
	var chips: Array = []               # [[name, state]]; state is "on", "off" or "broken"
	var sol := 0
	var total_sols := 7
	var day_frac := 0.0                 # how far through the sol we are (0 to 1)
	var marks := [0.5, 0.625, 0.875]    # where day, sunset and night end (0 to 1)
	var sun := 1.0
	var hurt := 0.0

	func _ready() -> void:
		font = ThemeDB.fallback_font
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1280, 720)

	func _process(delta: float) -> void:
		t += delta
		hurt = maxf(0.0, hurt - delta)
		queue_redraw()

	func _pill(rect: Rect2, color: Color, radius: int = -1) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		var r: int = radius
		if r < 0:
			r = int(rect.size.y / 2.0)
		sb.set_corner_radius_all(r)
		draw_style_box(sb, rect)

	func _write(pos: Vector2, text: String, fs: int, color: Color, outline: int = 4) -> void:
		if outline > 0:
			draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(0.05, 0.04, 0.08, 0.85))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	func _width(text: String, fs: int) -> float:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

	func _moved(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in points:
			out.append(p + by)
		return out

	func _icon(kind: String, c: Vector2, r: float) -> void:
		draw_circle(c, r + 2.5, Color(0.07, 0.06, 0.1, 0.85))
		if kind == "energy":
			draw_circle(c, r, Color(1.0, 0.8, 0.2))
			var bolt := PackedVector2Array([Vector2(2, -10), Vector2(-6, 2), Vector2(-1, 2), Vector2(-3, 10), Vector2(6, -3), Vector2(1, -3)])
			draw_colored_polygon(_moved(bolt, c), Color(0.28, 0.17, 0.02))
		elif kind == "oxygen":
			draw_circle(c, r, Color(0.3, 0.75, 1.0))
			var w: float = _width("O2", 13)
			draw_string(font, c + Vector2(-w / 2.0, 5.0), "O2", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.03, 0.15, 0.32))
		elif kind == "food":
			draw_circle(c, r, Color(0.5, 0.88, 0.45))
			draw_circle(c + Vector2(0, 2), 7.5, Color(0.86, 0.2, 0.2))
			draw_line(c + Vector2(0, -4), c + Vector2(1, -10), Color(0.3, 0.18, 0.08), 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(1, -8), c + Vector2(8, -11), c + Vector2(5, -5)]), Color(0.12, 0.45, 0.18))
		else:
			# a spare part: a metal nut
			draw_circle(c, r, Color(0.78, 0.8, 0.86))
			var hexagon := PackedVector2Array()
			for i in 6:
				var a: float = TAU * float(i) / 6.0
				hexagon.append(c + Vector2(cos(a), sin(a)) * 9.0)
			draw_colored_polygon(hexagon, Color(0.32, 0.35, 0.42))
			draw_circle(c, 3.6, Color(0.78, 0.8, 0.86))

	func _arrow(c: Vector2, up: bool) -> void:
		var d := -1.0
		var color := Color(0.45, 1.0, 0.5)
		if not up:
			d = 1.0
			color = Color(1.0, 0.62, 0.3)
		var big := PackedVector2Array([c + Vector2(-9, -7 * d), c + Vector2(9, -7 * d), c + Vector2(0, 9 * d)])
		var small := PackedVector2Array([c + Vector2(-6, -5 * d), c + Vector2(6, -5 * d), c + Vector2(0, 6 * d)])
		draw_colored_polygon(big, Color(0.07, 0.06, 0.1, 0.9))
		draw_colored_polygon(small, color)

	func _meter(pos: Vector2, kind: String, title: String, value: float, color: Color, trend: int, cap: float) -> void:
		var bar := Rect2(pos.x + 36.0, pos.y + 4.0, 186.0, 22.0)
		_pill(bar.grow(2.5), Color(0.07, 0.06, 0.1, 0.8))
		_pill(bar, Color(0.24, 0.23, 0.29, 0.95))
		var w: float = bar.size.x * clampf(value / 100.0, 0.0, 1.0)
		if w >= 2.0:
			var c: Color = color
			if value < 25.0:
				c = color.lerp(Color(1.0, 0.3, 0.25), 0.5 + 0.5 * sin(t * 6.0))
			_pill(Rect2(bar.position.x, bar.position.y, maxf(w, 10.0), bar.size.y), c, 11)
		if cap < 99.5:
			# the tired part of the battery (the day after a battery boost)
			var cx: float = bar.position.x + bar.size.x * cap / 100.0
			draw_rect(Rect2(cx, bar.position.y, 2.0, bar.size.y), Color(1, 1, 1, 0.8))
			draw_rect(Rect2(cx + 2.0, bar.position.y + 4.0, bar.end.x - cx - 10.0, bar.size.y - 8.0), Color(0, 0, 0, 0.45))
		_write(Vector2(bar.position.x + 10.0, bar.position.y + 16.5), "%s  %d" % [title, int(round(value))], 14, Color(1, 1, 1))
		_icon(kind, Vector2(pos.x + 16.0, pos.y + 15.0), 15.0)
		if trend != 0:
			_arrow(Vector2(bar.end.x + 16.0, pos.y + 15.0), trend > 0)

	func _heart(c: Vector2, s: float, color: Color) -> void:
		var pts := PackedVector2Array()
		for i in 28:
			var a: float = TAU * float(i) / 28.0
			var sn: float = sin(a)
			var x: float = 16.0 * sn * sn * sn
			var y: float = -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
			pts.append(c + Vector2(x, y) * (s / 16.0))
		draw_colored_polygon(pts, color)

	func _hearts(pos: Vector2) -> void:
		for i in 5:
			var c: Vector2 = pos + Vector2(13.0 + 27.0 * float(i), 12.0)
			var fill: float = clampf(health / 20.0 - float(i), 0.0, 1.0)
			_heart(c, 13.0, Color(0.07, 0.06, 0.1, 0.85))
			_heart(c, 10.5, Color(0.36, 0.2, 0.24))
			if fill > 0.04:
				var red := Color(0.96, 0.25, 0.32)
				if hurt > 0.0:
					red = red.lerp(Color(1, 1, 1), clampf(hurt * 2.0, 0.0, 1.0))
				_heart(c + Vector2(0, 1.5 * (1.0 - fill)), 10.5 * (0.4 + 0.6 * fill), red)

	func _chips(pos: Vector2) -> void:
		var x: float = pos.x
		for chip in chips:
			var text: String = str(chip[0])
			var state: String = str(chip[1])
			var w: float = _width(text, 11) + 30.0
			var color := Color(0.2, 0.2, 0.25, 0.8)
			var lamp := Color(0.5, 0.5, 0.55)
			if state == "on":
				color = Color(0.1, 0.42, 0.2, 0.9)
				lamp = Color(0.5, 1.0, 0.55)
			elif state == "broken":
				color = Color(0.6, 0.15, 0.12, 0.9)
				lamp = Color(1.0, 0.45, 0.35).lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(t * 6.0))
			_pill(Rect2(x, pos.y, w, 20.0), color)
			draw_circle(Vector2(x + 11.0, pos.y + 10.0), 4.5, lamp)
			_write(Vector2(x + 20.0, pos.y + 14.0), text, 11, Color(1, 1, 1), 0)
			x += w + 5.0

	func _day_strip() -> void:
		var r := Rect2(470.0, 8.0, 340.0, 46.0)
		_pill(r, Color(0.07, 0.06, 0.1, 0.5), 23)
		_write(Vector2(r.position.x + 20.0, r.position.y + 21.0), "SOL %d of %d" % [sol + 1, total_sols], 16, Color(1, 1, 1))
		var left: int = total_sols - sol
		var sub: String = "The President lands in %d sols" % left
		if left <= 1:
			sub = "The President lands at sunrise!"
		_write(Vector2(r.position.x + 20.0, r.position.y + 38.0), sub, 11, Color(1.0, 0.9, 0.6), 3)
		# the track: yellow = day, orange = sunset, blue = night, pink = sunrise
		var tr := Rect2(r.position.x + 196.0, r.position.y + 17.0, 124.0, 12.0)
		_pill(tr.grow(2.0), Color(0.07, 0.06, 0.1, 0.9))
		var colors := [Color(1.0, 0.86, 0.35), Color(1.0, 0.55, 0.3), Color(0.28, 0.33, 0.68), Color(1.0, 0.62, 0.6)]
		var edges := [0.0, float(marks[0]), float(marks[1]), float(marks[2]), 1.0]
		for i in 4:
			var x0: float = tr.position.x + tr.size.x * float(edges[i])
			var x1: float = tr.position.x + tr.size.x * float(edges[i + 1])
			draw_rect(Rect2(x0, tr.position.y, x1 - x0, tr.size.y), colors[i])
		var mx: float = tr.position.x + tr.size.x * clampf(day_frac, 0.0, 1.0)
		var mc := Vector2(mx, tr.position.y + tr.size.y / 2.0)
		draw_circle(mc, 11.0, Color(0.07, 0.06, 0.1, 0.9))
		if sun >= 0.35:
			draw_circle(mc, 8.5, Color(1.0, 0.82, 0.25))
			draw_circle(mc, 5.0, Color(1.0, 0.95, 0.6))
		else:
			draw_circle(mc, 8.5, Color(0.92, 0.94, 1.0))
			draw_circle(mc + Vector2(4.0, -2.0), 6.5, Color(0.07, 0.06, 0.1, 0.95))

	func _draw() -> void:
		_meter(Vector2(12, 10), "energy", "ENERGY", energy, Color(1.0, 0.8, 0.2), int(trends[0]), energy_cap)
		_meter(Vector2(12, 44), "oxygen", "OXYGEN", oxygen, Color(0.3, 0.75, 1.0), int(trends[1]), 100.0)
		_meter(Vector2(12, 78), "food", "FOOD", food, Color(0.45, 0.85, 0.4), int(trends[2]), 100.0)
		_hearts(Vector2(14, 114))
		_icon("parts", Vector2(178, 126), 12.0)
		_write(Vector2(196, 132), "x %d" % parts, 17, Color(1, 1, 1))
		_chips(Vector2(14, 146))
		_day_strip()


# ---------------------------------------------------------------- the tour arrow

class TourArrow extends Control:
	var from := Vector2(640, 536)
	var to := Vector2(640, 300)
	var show_arrow := false
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1280, 720)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if not show_arrow:
			return
		var gold := Color(1.0, 0.85, 0.3)
		var dark := Color(0.07, 0.06, 0.1, 0.9)
		var ring: float = 52.0 + 4.0 * sin(t * 4.0)
		draw_arc(to, ring, 0.0, TAU, 48, dark, 8.0, true)
		draw_arc(to, ring, 0.0, TAU, 48, gold, 4.0, true)
		var gap: Vector2 = to - from
		if gap.length() < ring + 40.0:
			return
		var dir: Vector2 = gap.normalized()
		var tip: Vector2 = to - dir * (ring + 8.0)
		var neck: Vector2 = tip - dir * 26.0
		var side: Vector2 = Vector2(-dir.y, dir.x)
		draw_line(from, neck, dark, 12.0, true)
		draw_colored_polygon(PackedVector2Array([tip + dir * 4.0, neck + side * 20.0, neck - side * 20.0]), dark)
		draw_line(from, neck, gold, 6.0, true)
		draw_colored_polygon(PackedVector2Array([tip, neck + side * 14.0, neck - side * 14.0]), gold)


# ---------------------------------------------------------------- the HUD itself

var gauges: Gauges
var minimap
var tasks_box: PanelContainer
var tasks_label: Label
var prompt_label: Label
var prompt_shown := ""
var prompt_tween: Tween
var hold_bar: ProgressBar
var toast_label: Label
var toast_left := 0.0
var toast_age := 0.0
var toast_queue: Array = []

var banner: Panel
var banner_title: Label
var banner_text: Label
var banner_left := 0.0
var banner_active := false
var banner_tween: Tween

var dialog: Panel
var dialog_name: Label
var dialog_text: Label
var dialog_marker: NextMarker
var dialog_typer := Typer.new()
var dialog_active := false
var dialog_tween: Tween
var tour_typer := Typer.new()
var choice_card: Panel
var choice_tween: Tween
var pause_layer: CanvasLayer
var speed_buttons := {}
var volume_slider: HSlider

var choice_root: Control
var choice_who: Label
var choice_title: Label
var choice_text: Label
var choice_cards: Array = []
var choice_labels: Array = []
var choice_details: Array = []
var choice_buttons: Array = []
var choice_enabled := [true, true]

var tour_root: Control
var tour_arrow: TourArrow
var tour_title: Label
var tour_text: Label
var tour_step: Label

var storm_overlay: ColorRect
var flare_overlay: ColorRect
var hurt_overlay: ColorRect
var fade_overlay: ColorRect
var hurt_alpha := 0.0
var fade_alpha := 0.0
var caption: Label             # the line of text at the top during a film
var hint: Label                # small text in the bottom movie bar
var cine_parts: Array = []     # the movie bars and texts of the film that is playing
var cine_hidden: Array = []    # what was on the screen before the film started


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	storm_overlay = _overlay(Color(0.85, 0.45, 0.2, 0.0))
	flare_overlay = _overlay(Color(0.7, 0.3, 0.9, 0.0))
	hurt_overlay = _overlay(Color(1.0, 0.1, 0.1, 0.0))

	# ---- top left and top centre: bars, hearts, spare parts, machine lights, day strip
	gauges = Gauges.new()
	add_child(gauges)

	# ---- top right: minimap and the to-do list
	var map_frame := Panel.new()
	map_frame.position = Vector2(1016, 10)
	map_frame.size = Vector2(254, 179)
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color(0.2, 0.12, 0.14)
	ms.set_corner_radius_all(4)
	map_frame.add_theme_stylebox_override("panel", ms)
	map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_frame)
	minimap = MinimapScript.new()
	minimap.position = Vector2(2, 2)
	map_frame.add_child(minimap)

	tasks_box = PanelContainer.new()
	tasks_box.position = Vector2(1016, 196)
	tasks_box.custom_minimum_size = Vector2(254, 0)
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.07, 0.06, 0.1, 0.5)
	ts.set_corner_radius_all(10)
	ts.content_margin_left = 12
	ts.content_margin_right = 10
	ts.content_margin_top = 7
	ts.content_margin_bottom = 8
	tasks_box.add_theme_stylebox_override("panel", ts)
	tasks_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tasks_box)
	tasks_label = Label.new()
	tasks_label.custom_minimum_size = Vector2(232, 0)
	tasks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tasks_label.add_theme_font_size_override("font_size", 14)
	tasks_label.add_theme_color_override("font_color", Color(1, 1, 1))
	tasks_label.add_theme_constant_override("line_spacing", 1)
	tasks_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tasks_box.add_child(tasks_label)

	# ---- news banner
	banner = _panel(BANNER_POS, Vector2(600, 108), Color(0.1, 0.12, 0.25, 0.9), GOLD, 2, 12)
	banner_title = _text(banner, "", 18, GOLD, Vector2(14, 5), Vector2(572, 24))
	banner_text = _text(banner, "", 17, Color(1, 1, 1), Vector2(14, 29), Vector2(572, 76))
	banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	banner.visible = false

	# ---- bottom: short messages, what the E key does, and the hold bar
	toast_label = _boxed_label(Vector2(340, 566), Vector2(600, 32), 18, Color(0.08, 0.2, 0.12, 0.85))
	toast_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
	prompt_label = _boxed_label(Vector2(140, 610), Vector2(1000, 34), 19, Color(0.07, 0.06, 0.1, 0.6))

	hold_bar = ProgressBar.new()
	hold_bar.position = Vector2(490, 650)
	hold_bar.size = Vector2(300, 18)
	hold_bar.max_value = 1.0
	hold_bar.step = 0.001
	hold_bar.show_percentage = false
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(0, 0, 0, 0.6)
	hb.set_corner_radius_all(9)
	var hf := StyleBoxFlat.new()
	hf.bg_color = Color(0.4, 0.9, 0.4)
	hf.set_corner_radius_all(9)
	hold_bar.add_theme_stylebox_override("background", hb)
	hold_bar.add_theme_stylebox_override("fill", hf)
	hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold_bar.visible = false
	add_child(hold_bar)

	# ---- dialog box
	dialog = _panel(DIALOG_POS, Vector2(900, 190), Color(0.06, 0.07, 0.12, 0.96), Color(1, 1, 1, 0.8), 2, 12)
	dialog_name = _text(dialog, "", 22, GOLD, Vector2(20, 10), Vector2(860, 30))
	dialog_text = _text(dialog, "", 20, Color(1, 1, 1), Vector2(20, 42), Vector2(860, 116))
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var hint := _text(dialog, "%s to continue" % Game.KEYS, 15, Color(0.75, 0.75, 0.75), Vector2(20, 160), Vector2(830, 22))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialog_marker = NextMarker.new()
	dialog_marker.position = Vector2(860, 163)
	dialog_marker.visible = false
	dialog.add_child(dialog_marker)
	dialog.visible = false

	_build_tour()
	_build_choice()
	_build_pause()

	fade_overlay = _overlay(Color(0.03, 0.02, 0.04, 0.0))


func _build_tour() -> void:
	# the machine tour at the start: an arrow to the machine and a box that explains it
	tour_root = Control.new()
	tour_root.size = Vector2(1280, 720)
	tour_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tour_root.visible = false
	add_child(tour_root)
	tour_arrow = TourArrow.new()
	tour_root.add_child(tour_arrow)
	var box := Panel.new()
	box.position = Vector2(170, 540)
	box.size = Vector2(940, 166)
	box.add_theme_stylebox_override("panel", _style(Color(0.08, 0.1, 0.2, 0.97), GOLD, 3, 14))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tour_root.add_child(box)
	tour_title = _text(box, "", 24, GOLD, Vector2(22, 10), Vector2(700, 34))
	tour_step = _text(box, "", 15, Color(0.75, 0.78, 0.85), Vector2(740, 16), Vector2(178, 24))
	tour_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tour_text = _text(box, "", 20, Color(1, 1, 1), Vector2(22, 46), Vector2(896, 84))
	tour_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tour_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var next_hint := _text(box, "%s: next" % Game.KEYS, 16, Color(0.8, 0.95, 0.8), Vector2(22, 134), Vector2(896, 24))
	next_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var skip := Button.new()
	skip.text = "Skip the tour (ESC)"
	skip.position = Vector2(22, 128)
	skip.size = Vector2(190, 30)
	skip.add_theme_font_size_override("font_size", 14)
	skip.focus_mode = Control.FOCUS_NONE
	skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip.pressed.connect(_on_tour_skip)
	box.add_child(skip)


func _build_choice() -> void:
	# a decision: two cards side by side, and both of them cost something
	choice_root = Control.new()
	choice_root.size = Vector2(1280, 720)
	choice_root.visible = false
	add_child(choice_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.06, 0.6)
	dim.size = Vector2(1280, 720)
	choice_root.add_child(dim)
	var card := Panel.new()
	card.position = Vector2(170, 92)
	card.size = Vector2(940, 520)
	card.pivot_offset = card.size / 2.0
	card.add_theme_stylebox_override("panel", _style(Color(0.09, 0.1, 0.19, 0.98), GOLD, 3, 16))
	choice_root.add_child(card)
	choice_card = card
	choice_who = _text(card, "", 18, GOLD, Vector2(28, 14), Vector2(884, 26))
	choice_title = _text(card, "", 30, Color(1, 1, 1), Vector2(28, 40), Vector2(884, 44))
	choice_text = _text(card, "", 20, Color(0.92, 0.93, 0.97), Vector2(28, 90), Vector2(884, 110))
	choice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	for i in 2:
		var opt := Panel.new()
		opt.position = Vector2(28.0 + 452.0 * float(i), 208.0)
		opt.size = Vector2(432, 250)
		opt.pivot_offset = opt.size / 2.0
		card.add_child(opt)
		var letter: String = "A"
		if i == 1:
			letter = "B"
		_text(opt, letter, 20, Color(0.07, 0.06, 0.1), Vector2(14, 12), Vector2(30, 30)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tag := ColorRect.new()
		tag.color = GOLD
		tag.position = Vector2(14, 12)
		tag.size = Vector2(30, 30)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		opt.add_child(tag)
		opt.move_child(tag, 0)
		var lab := _text(opt, "", 23, GOLD, Vector2(54, 8), Vector2(366, 62))
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var det := RichTextLabel.new()
		det.bbcode_enabled = true
		det.scroll_active = false
		det.position = Vector2(18, 82)
		det.size = Vector2(398, 160)
		det.add_theme_font_size_override("normal_font_size", 19)
		det.mouse_filter = Control.MOUSE_FILTER_IGNORE
		opt.add_child(det)
		var btn := Button.new()
		btn.flat = true
		btn.size = opt.size
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_choice_button.bind(i))
		btn.mouse_entered.connect(_on_choice_hover.bind(i))
		opt.add_child(btn)
		choice_buttons.append(btn)
		choice_cards.append(opt)
		choice_labels.append(lab)
		choice_details.append(det)
	var how := _text(card, "A / D or the arrow keys: choose          %s: decide" % Game.KEYS, 16, Color(0.75, 0.78, 0.85), Vector2(28, 476), Vector2(884, 26))
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	var speed: float = Game.text_cps()
	if dialog_typer.step(delta, speed) and dialog_active:
		Sfx.play("blip", randf_range(0.95, 1.08))
	dialog_marker.visible = dialog_active and not dialog_typer.typing()
	if tour_typer.step(delta, speed) and tour_root.visible:
		Sfx.play("blip", randf_range(0.95, 1.08))
	if banner_left > 0.0:
		banner_left -= delta
		if banner_left <= 0.0:
			_hide_banner()
	if toast_left > 0.0:
		toast_left -= delta
		toast_age += delta
		toast_label.modulate.a = clampf(toast_left, 0.0, 1.0)
		if not toast_queue.is_empty() and toast_age >= 1.2:
			_show_toast(str(toast_queue.pop_front()))
		elif toast_left <= 0.0:
			toast_label.visible = false
	if hurt_alpha > 0.0:
		hurt_alpha = maxf(0.0, hurt_alpha - delta * 1.2)
		hurt_overlay.color.a = hurt_alpha
	if fade_alpha > 0.0:
		fade_alpha = maxf(0.0, fade_alpha - delta * 2.6)
		fade_overlay.color.a = fade_alpha


func _build_pause() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 12
	pause_layer.visible = false
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.06, 0.65)
	dim.size = Vector2(1280, 720)
	pause_layer.add_child(dim)
	var box := Panel.new()
	box.position = Vector2(440, 160)
	box.size = Vector2(400, 400)
	box.add_theme_stylebox_override("panel", _style(Color(0.09, 0.1, 0.19, 0.98), GOLD, 3, 16))
	pause_layer.add_child(box)
	var title := _text(box, "PAUSED", 30, GOLD, Vector2(0, 16), Vector2(400, 40))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_button(box, "Resume", Vector2(60, 74), Vector2(280, 48), _on_pause_resume)
	_text(box, "Text speed", 18, Color(1, 1, 1), Vector2(60, 138), Vector2(280, 26))
	var group := ButtonGroup.new()
	var speeds := [["slow", "Slow"], ["normal", "Normal"], ["instant", "Instant"]]
	for i in speeds.size():
		var id: String = speeds[i][0]
		var b := _menu_button(box, str(speeds[i][1]), Vector2(60.0 + 96.0 * float(i), 168), Vector2(88, 38), _on_speed_picked.bind(id))
		b.toggle_mode = true
		b.button_group = group
		speed_buttons[id] = b
	_text(box, "Sound", 18, Color(1, 1, 1), Vector2(60, 222), Vector2(280, 26))
	volume_slider = HSlider.new()
	volume_slider.position = Vector2(60, 252)
	volume_slider.size = Vector2(280, 24)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.focus_mode = Control.FOCUS_NONE
	volume_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	volume_slider.value_changed.connect(_on_volume_changed)
	box.add_child(volume_slider)
	_menu_button(box, "Back to title", Vector2(60, 310), Vector2(280, 48), _on_pause_quit)


func _menu_button(parent: Control, text: String, pos: Vector2, box: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = box
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func show_pause() -> void:
	var b: Button = speed_buttons.get(Game.text_speed, speed_buttons["normal"])
	b.set_pressed_no_signal(true)
	volume_slider.set_value_no_signal(Game.volume)
	pause_layer.visible = true
	Sfx.play("ui_select")


func hide_pause() -> void:
	pause_layer.visible = false


func _on_pause_resume() -> void:
	Sfx.play("ui_click")
	pause_resume.emit()


func _on_pause_quit() -> void:
	Sfx.play("ui_confirm")
	pause_quit.emit()


func _on_speed_picked(id: String) -> void:
	Sfx.play("ui_move")
	Game.set_text_speed(id)


func _on_volume_changed(value: float) -> void:
	Game.set_volume(value)


# ------------------------------------------------------------------ building blocks

func _overlay(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = Vector2.ZERO
	r.size = Vector2(1280, 720)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	return sb


func _panel(pos: Vector2, panel_size: Vector2, bg: Color, border: Color, border_width: int, radius: int) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = panel_size
	p.add_theme_stylebox_override("panel", _style(bg, border, border_width, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _text(parent: Control, text: String, font_size: int, color: Color, pos: Vector2, box: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = box
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _boxed_label(pos: Vector2, box: Vector2, font_size: int, bg: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = box
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	l.add_theme_stylebox_override("normal", sb)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	add_child(l)
	return l


# ------------------------------------------------------------------ used by main.gd

func set_bars(energy: float, oxygen: float, food: float, health: float, trends: Array, energy_cap: float) -> void:
	gauges.energy = energy
	gauges.oxygen = oxygen
	gauges.food = food
	gauges.health = health
	gauges.trends = trends
	gauges.energy_cap = energy_cap


func set_parts(count: int) -> void:
	gauges.parts = count


func set_machines(chips: Array) -> void:
	# the little lights under the hearts: [[name, "on" / "off" / "broken"], ...]
	gauges.chips = chips


func set_day(sol: int, total: int, day_frac: float, marks: Array, sun: float) -> void:
	gauges.sol = sol
	gauges.total_sols = total
	gauges.day_frac = day_frac
	gauges.marks = marks
	gauges.sun = sun


func set_tasks(lines: Array) -> void:
	var out := PackedStringArray()
	var shown := 0
	for line in lines:
		if shown >= 5:
			out.append("...and %d more" % (lines.size() - shown))
			break
		out.append("- " + str(line))
		shown += 1
	tasks_label.text = "\n".join(out)
	tasks_box.reset_size()


func set_prompt(text: String) -> void:
	if text == prompt_shown:
		return
	var was: String = prompt_shown
	prompt_shown = text
	_kill(prompt_tween)
	prompt_tween = create_tween()
	if was != "" and prompt_label.visible:
		prompt_tween.tween_property(prompt_label, "modulate:a", 0.0, 0.08)
	if text == "":
		prompt_tween.tween_callback(prompt_label.hide)
		return
	prompt_tween.tween_callback(_swap_prompt.bind(text))
	prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.12)


func _swap_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.modulate.a = 0.0
	prompt_label.visible = true


func set_hold(progress: float) -> void:
	# pass a negative number to hide the bar
	hold_bar.visible = progress >= 0.0
	if progress >= 0.0:
		hold_bar.value = progress


func toast(text: String) -> void:
	# a short message near the bottom that fades away by itself
	var line: String = Game.keys_fill(text)
	if toast_left > 0.0 and toast_label.text == line:
		toast_left = 3.2
		toast_label.modulate.a = 1.0
		return
	if toast_queue.has(line):
		return
	if toast_left > 0.0 and toast_age < 1.2:
		if toast_queue.size() < 4:
			toast_queue.append(line)
		return
	_show_toast(line)


func _show_toast(line: String) -> void:
	toast_label.text = line
	toast_age = 0.0
	Sfx.play("toast")
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	toast_left = 3.2


func show_banner(title: String, text: String, seconds: float = 9.0) -> void:
	banner_title.text = title
	Sfx.banner(title)
	banner_text.text = Game.keys_fill(text)
	banner_left = seconds
	if banner_active:
		return
	banner_active = true
	_kill(banner_tween)
	banner.visible = true
	banner.modulate.a = 0.0
	banner.position = BANNER_POS - Vector2(0, 16)
	banner_tween = create_tween().set_parallel(true)
	banner_tween.tween_property(banner, "modulate:a", 1.0, 0.22)
	banner_tween.tween_property(banner, "position", BANNER_POS, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _hide_banner() -> void:
	banner_active = false
	_kill(banner_tween)
	banner_tween = create_tween().set_parallel(true)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.25)
	banner_tween.tween_property(banner, "position", BANNER_POS - Vector2(0, 16), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	banner_tween.chain().tween_callback(banner.hide)


func _kill(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()


func show_dialog(speaker: String, text: String) -> void:
	dialog_name.text = speaker
	dialog_typer.start(dialog_text, Game.keys_fill(text))
	if dialog_active:
		return
	dialog_active = true
	_kill(dialog_tween)
	dialog.visible = true
	dialog.modulate.a = 0.0
	dialog.position = DIALOG_POS + Vector2(0, 12)
	dialog_tween = create_tween().set_parallel(true)
	dialog_tween.tween_property(dialog, "modulate:a", 1.0, 0.15)
	dialog_tween.tween_property(dialog, "position", DIALOG_POS, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func hide_dialog() -> void:
	dialog_typer.finish()
	if not dialog_active:
		return
	dialog_active = false
	_kill(dialog_tween)
	dialog_tween = create_tween()
	dialog_tween.tween_property(dialog, "modulate:a", 0.0, 0.1)
	dialog_tween.tween_callback(dialog.hide)


func is_typing() -> bool:
	return dialog_active and dialog_typer.typing()


func finish_typing() -> void:
	dialog_typer.finish()


func tour_typing() -> bool:
	return tour_root.visible and tour_typer.typing()


func finish_tour_typing() -> void:
	tour_typer.finish()


func set_weather(storm: float, flare: float) -> void:
	storm_overlay.color.a = storm
	flare_overlay.color.a = flare


func flash_hurt() -> void:
	hurt_alpha = 0.45
	Sfx.play("metal_hit")
	hurt_overlay.color.a = hurt_alpha
	gauges.hurt = 0.6


func fade_in() -> void:
	# a quick blink to black, used when a film starts or ends
	fade_alpha = 1.0
	Sfx.play("whoosh")
	fade_overlay.color.a = 1.0


func set_minimap(player_pos: Vector2, markers: Array, offline: bool) -> void:
	minimap.player_pos = player_pos
	minimap.markers = markers
	minimap.offline = offline


# ---- decisions

func show_choice(speaker: String, title: String, text: String, options: Array, selected: int) -> void:
	choice_who.text = speaker
	Sfx.play("chime")
	choice_title.text = title
	choice_text.text = text
	for i in 2:
		var o: Dictionary = options[i]
		var lab: Label = choice_labels[i]
		lab.text = str(o["label"])
		var det: RichTextLabel = choice_details[i]
		var lines: Array = o["lines"]
		var bb := PackedStringArray()
		for line in lines:
			var s: String = str(line)
			if s.begins_with("+"):
				bb.append("[color=#8dffa0]%s[/color]" % s)
			elif s.begins_with("-"):
				bb.append("[color=#ffb07a]%s[/color]" % s)
			else:
				bb.append(s)
		det.text = "\n".join(bb)
		choice_enabled[i] = bool(o.get("enabled", true))
		var b: Button = choice_buttons[i]
		if choice_enabled[i]:
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			b.mouse_default_cursor_shape = Control.CURSOR_ARROW
	choice_root.visible = true
	set_choice_selected(selected)
	_kill(choice_tween)
	choice_root.modulate.a = 0.0
	choice_card.scale = Vector2(0.96, 0.96)
	choice_tween = create_tween().set_parallel(true)
	choice_tween.tween_property(choice_root, "modulate:a", 1.0, 0.18)
	choice_tween.tween_property(choice_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_choice_selected(index: int) -> void:
	for i in 2:
		var opt: Panel = choice_cards[i]
		if i == index:
			opt.add_theme_stylebox_override("panel", _style(Color(0.17, 0.2, 0.36), GOLD, 5, 14))
			opt.scale = Vector2(1.03, 1.03)
		else:
			opt.add_theme_stylebox_override("panel", _style(Color(0.12, 0.13, 0.22), Color(0.45, 0.47, 0.58), 2, 14))
			opt.scale = Vector2(1, 1)
		if choice_enabled[i]:
			opt.modulate = Color(1, 1, 1)
		else:
			opt.modulate = Color(0.55, 0.55, 0.6)


func hide_choice() -> void:
	_kill(choice_tween)
	choice_root.modulate.a = 1.0
	choice_card.scale = Vector2.ONE
	choice_root.visible = false


func _on_choice_button(index: int) -> void:
	if choice_root.visible and choice_enabled[index]:
		choice_picked.emit(index)


func _on_choice_hover(index: int) -> void:
	if choice_root.visible and choice_enabled[index]:
		choice_hovered.emit(index)


# ---- the machine tour

func show_tour(title: String, text: String, step: int, total: int) -> void:
	tour_title.text = title
	Sfx.play("ui_click")
	tour_typer.start(tour_text, Game.keys_fill(text))
	tour_step.text = "%d / %d" % [step, total]
	tour_root.visible = true
	tour_arrow.show_arrow = false


func set_tour_target(screen_pos: Vector2, show_arrow: bool) -> void:
	tour_arrow.to = screen_pos
	tour_arrow.show_arrow = show_arrow


func hide_tour() -> void:
	tour_typer.finish()
	tour_root.visible = false


func _on_tour_skip() -> void:
	tour_skip.emit()


# ---- the ending

func start_cinematic() -> void:
	# hide the game screen, add black movie bars, a caption line and a small hint
	if not cine_parts.is_empty():
		return
	for c in get_children():
		if c == dialog or c == fade_overlay:
			continue
		if c.visible:
			cine_hidden.append(c)
			c.visible = false
	var top := ColorRect.new()
	top.color = Color(0, 0, 0)
	top.size = Vector2(1280, 70)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	move_child(top, 0)
	var bottom := ColorRect.new()
	bottom.color = Color(0, 0, 0)
	bottom.position = Vector2(0, 650)
	bottom.size = Vector2(1280, 70)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	move_child(bottom, 0)
	caption = Label.new()
	caption.position = Vector2(0, 18)
	caption.size = Vector2(1280, 34)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	move_child(caption, 2)
	hint = Label.new()
	hint.position = Vector2(0, 688)
	hint.size = Vector2(1264, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	move_child(hint, 2)
	cine_parts = [top, bottom, caption, hint]


func end_cinematic() -> void:
	# the film is over: take the movie bars away and show the game screen again
	for c in cine_parts:
		c.queue_free()
	cine_parts.clear()
	caption = null
	hint = null
	for c in cine_hidden:
		if is_instance_valid(c):
			c.visible = true
	cine_hidden.clear()


func set_hint(text: String) -> void:
	# small grey text in the bottom movie bar (for example "ESC: skip the film")
	if hint != null:
		hint.text = text


func set_caption(text: String) -> void:
	if caption != null:
		caption.text = text
