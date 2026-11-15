extends Control
# Opening: newspapers land on the screen and tell the story from 2026 to 3030.
# Every one is laid out like a real front page: the paper's name, the date, a big
# headline, a picture, columns of small print and a side box.

const PAPER_SIZE := Vector2(900, 640)

# Edit this list to change the story. Each entry is one newspaper.
# "{sols}" is replaced by the number of sols the President is away.
const PAPERS := [
	{
		"name": "THE EARTH TIMES", "motto": "All the news from the blue planet",
		"number": "No. 59,823", "date": "Friday, 3 July 2026", "price": "Price: 2 dollars",
		"headline": "HUMANS AIM FOR THE MOON AGAIN - AND THEN MARS",
		"deck": "Space agencies say the Moon is only the first step",
		"lead": "One day, people may live on the Red Planet.",
		"story": "Rockets are being built to carry astronauts back to the Moon for the first time in more than fifty years. Engineers say that everything they learn there, from growing food to making air, will be needed for the much longer trip to Mars.",
		"quote": "\"The Moon is our training ground.\"",
		"photo": "moon", "caption": "The Moon: the first stop on the long road to Mars.",
		"box": "MARS FACTS",
		"items": ["A day on Mars is called a sol. It lasts 24 hours and 39 minutes.", "The air is thin and nobody can breathe it.", "Nights are colder than -70 C.", "Dust storms can hide the Sun for days."],
		"small": "WEATHER ON EARTH: sunny and warm. Bring a hat.",
	},
	{
		"name": "THE EARTH TIMES", "motto": "All the news from a very full planet",
		"number": "No. 119,702", "date": "Tuesday, 12 March 2190", "price": "Price: 3 credits",
		"headline": "EARTH IS GETTING CROWDED: 20 BILLION PEOPLE",
		"deck": "The cities are full, and they keep growing",
		"lead": "Clean water, food and energy are harder to share every year.",
		"story": "The twenty-billionth person was born last night. In the biggest cities, families live in towers two hundred floors high, and parks have been turned into farms. Scientists warn that the planet cannot give everyone enough food, water and energy for much longer.",
		"quote": "\"We must share better, and we must look for more room.\"",
		"photo": "city", "caption": "Rush hour never ends in the mega-cities.",
		"box": "IN NUMBERS",
		"items": ["20 billion people live on Earth.", "200 floors: the tallest home towers.", "9 out of 10 parks are now farms.", "0 empty cities are left."],
		"small": "FOR RENT: one quiet room. Sorry, already taken.",
	},
	{
		"name": "THE EARTH TIMES", "motto": "All the news from a very full planet",
		"number": "No. 237,410", "date": "Saturday, 9 October 2512", "price": "Price: 5 credits",
		"headline": "NO MORE ROOM! LEADERS LOOK TO MARS",
		"deck": "The whole world agrees on one plan",
		"lead": "Build a new home on another planet.",
		"story": "After weeks of talks, the leaders of every country signed the Mars Plan today. Robots will fly first and build the towns. People will follow when there is air to breathe, food to eat and power to keep warm. The work will take hundreds of years.",
		"quote": "\"It will take a long time. So we start now.\"",
		"photo": "plan", "caption": "From the blue planet to the red one.",
		"box": "THE MARS PLAN",
		"items": ["1. Send robots to build.", "2. Put up domes and solar panels.", "3. Make oxygen and grow food.", "4. Send the first families."],
		"small": "ALSO TODAY: the world's longest traffic jam turns 40.",
	},
	{
		"name": "THE MARS NEWS", "motto": "The newspaper of the Red Planet",
		"number": "No. 12", "date": "Spring 3030", "price": "Free for settlers",
		"headline": "NEW HOPE: A BRAND-NEW TOWN ON MARS",
		"deck": "Only a few people live there so far",
		"lead": "Hundreds more on Earth are packing their bags to move in.",
		"story": "New Hope has homes, a greenhouse, a field of solar panels and a machine that makes oxygen out of Mars air. Life is not easy there: nobody can breathe the air outside, and the nights are freezing. But the first families say the blue sunsets are worth it.",
		"quote": "\"Every plant we grow here feels like a small miracle.\"",
		"photo": "town", "caption": "New Hope, the newest town on Mars.",
		"box": "HOW WE GOT HERE",
		"items": ["2841: Robots start building on Mars.", "2994: The first Mars towns open their doors.", "3030: New Hope welcomes its first families."],
		"small": "WANTED: farmers, miners and one brave Operator.",
	},
	{
		"name": "THE MARS NEWS", "motto": "The newspaper of the Red Planet",
		"number": "No. 31", "date": "Today", "price": "Free for settlers",
		"headline": "PRESIDENT FLIES TO EARTH TO BRING THE NEW SETTLERS",
		"deck": "A young Operator runs New Hope for {sols} sols",
		"lead": "That Operator is YOU! Energy, oxygen and food are limited. Every choice has a cost.",
		"story": "President Orion's rocket leaves the pad this morning. He will be back with the new settlers in {sols} sols. Until then one young Operator is in charge of the whole town: the power, the air, the food and every repair.",
		"quote": "\"I know the Operator can do it.\"",
		"photo": "rocket", "caption": "The President's rocket is ready on the pad.",
		"box": "THE OPERATOR'S JOBS",
		"items": ["Keep the battery charged.", "Keep the air fresh.", "Keep the food growing.", "Listen to the colonists.", "Think before you choose!"],
		"small": "NEXT ROCKET: lands in {sols} sols, with the President and the new settlers.",
	},
]


# ------------------------------------------------------------------ the sheet of paper

class Sheet extends Control:
	var grain := 1

	func _draw() -> void:
		var ink := Color(0.11, 0.1, 0.09)
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(10, 12, w, h), Color(0, 0, 0, 0.4))            # shadow
		draw_rect(Rect2(0, 0, w, h), Color(0.93, 0.9, 0.82))
		var rnd := RandomNumberGenerator.new()
		rnd.seed = grain
		for i in 140:
			var p := Vector2(rnd.randf() * w, rnd.randf() * h)
			draw_rect(Rect2(p, Vector2(rnd.randf_range(1.0, 4.0), rnd.randf_range(1.0, 2.0))), Color(0.35, 0.28, 0.2, rnd.randf_range(0.03, 0.08)))
		for i in 7:
			var a: float = 0.07 - 0.01 * float(i)
			var d: float = float(i) * 4.0
			draw_rect(Rect2(d, 0, 4, h), Color(0.35, 0.25, 0.12, a))
			draw_rect(Rect2(w - d - 4.0, 0, 4, h), Color(0.35, 0.25, 0.12, a))
			draw_rect(Rect2(0, d, w, 4), Color(0.35, 0.25, 0.12, a))
			draw_rect(Rect2(0, h - d - 4.0, w, 4), Color(0.35, 0.25, 0.12, a))
		draw_rect(Rect2(0, h * 0.5, w, 1.5), Color(0.3, 0.25, 0.2, 0.1))      # the fold
		# printed lines
		draw_rect(Rect2(24, 31, w - 48, 2), ink)
		draw_rect(Rect2(24, 119, w - 48, 1), ink)
		draw_rect(Rect2(24, 123, w - 48, 4), ink)
		draw_rect(Rect2(24, 275, w - 48, 1), ink)
		draw_rect(Rect2(308, 288, 1, h - 312), ink)
		draw_rect(Rect2(600, 288, 1, h - 312), ink)
		draw_rect(Rect2(24, h - 20, w - 48, 1), ink)
		draw_rect(Rect2(0, 0, w, h), Color(0.25, 0.2, 0.15), false, 2.0)


# ------------------------------------------------------------------ the black-and-white picture

class Photo extends Control:
	var kind := "moon"
	var grey: ShaderMaterial

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat g = dot(c.rgb, vec3(0.3, 0.59, 0.11));\n\tCOLOR = vec4(vec3(g) * vec3(1.0, 0.97, 0.9), c.a);\n}\n"
		grey = ShaderMaterial.new()
		grey.shader = sh
		if kind == "moon":
			_sprite("rocket", Vector2(34, 62), 0.36)
		elif kind == "town":
			_sprite("house_a", Vector2(12, 86), 0.42)
			_sprite("dome", Vector2(78, 53), 0.42)
			_sprite("apartment", Vector2(198, 44), 0.42)
			_sprite("solar_panel", Vector2(30, 134), 0.36)
			_sprite("solar_panel", Vector2(70, 138), 0.36)
		elif kind == "rocket":
			_sprite("rocket", Vector2(112, 2), 0.55)

	func _sprite(asset: String, pos: Vector2, s: float) -> void:
		var path: String = "res://assets/world/%s.png" % asset
		if not ResourceLoader.exists(path):
			return
		var sp := Sprite2D.new()
		sp.texture = load(path)
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.position = pos
		sp.scale = Vector2(s, s)
		sp.material = grey
		sp.show_behind_parent = false
		add_child(sp)

	func _stars(rnd: RandomNumberGenerator, n: int) -> void:
		for i in n:
			var p := Vector2(rnd.randf() * size.x, rnd.randf() * size.y)
			draw_circle(p, rnd.randf_range(0.6, 1.5), Color(1, 1, 1, rnd.randf_range(0.4, 0.95)))

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var rnd := RandomNumberGenerator.new()
		rnd.seed = 7
		if kind == "moon":
			draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.1, 0.11))
			_stars(rnd, 46)
			var c := Vector2(w * 0.66, h * 0.56)
			draw_circle(c, h * 0.4, Color(0.8, 0.8, 0.78))
			for crater in [Vector2(-22, -18), Vector2(14, 8), Vector2(-6, 26), Vector2(30, -26), Vector2(-34, 12)]:
				draw_circle(c + crater, 9.0, Color(0.62, 0.62, 0.6))
				draw_circle(c + crater + Vector2(1.5, 1.5), 6.5, Color(0.7, 0.7, 0.68))
			# the flame of the rocket on its way (the rocket itself is a picture)
			draw_colored_polygon(PackedVector2Array([Vector2(43, 146), Vector2(51, 168), Vector2(59, 146)]), Color(0.95, 0.95, 0.9))
		elif kind == "city":
			draw_rect(Rect2(0, 0, w, h), Color(0.74, 0.74, 0.72))
			draw_rect(Rect2(0, 0, w, h * 0.35), Color(0.62, 0.62, 0.61))
			var x := 0.0
			while x < w:
				var bw: float = rnd.randf_range(14.0, 26.0)
				var bh: float = rnd.randf_range(h * 0.45, h * 0.85)
				draw_rect(Rect2(x, h - bh, bw, bh), Color(0.5, 0.5, 0.5))
				x += bw + 1.0
			x = -4.0
			while x < w:
				var bw2: float = rnd.randf_range(22.0, 38.0)
				var bh2: float = rnd.randf_range(h * 0.3, h * 0.72)
				draw_rect(Rect2(x, h - bh2, bw2, bh2), Color(0.2, 0.2, 0.21))
				var wy: float = h - bh2 + 5.0
				while wy < h - 26.0:
					var wx: float = x + 4.0
					while wx < x + bw2 - 4.0:
						if rnd.randf() < 0.7:
							draw_rect(Rect2(wx, wy, 3, 4), Color(0.88, 0.88, 0.82))
						wx += 6.0
					wy += 8.0
				x += bw2 + 2.0
			draw_rect(Rect2(0, h - 20.0, w, 20), Color(0.12, 0.12, 0.13))
			for i in 60:
				var hp := Vector2(rnd.randf() * w, h - rnd.randf_range(6.0, 20.0))
				draw_circle(hp, rnd.randf_range(3.0, 4.5), Color(0.3, 0.3, 0.3).lerp(Color(0.6, 0.6, 0.58), rnd.randf()))
		elif kind == "plan":
			draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.1, 0.11))
			_stars(rnd, 50)
			var earth := Vector2(w * 0.2, h * 0.64)
			draw_circle(earth, 34.0, Color(0.78, 0.78, 0.78))
			for blob in [Vector2(-10, -8), Vector2(8, 6), Vector2(-4, 16), Vector2(14, -14)]:
				draw_circle(earth + blob, 9.0, Color(0.52, 0.52, 0.52))
			var mars := Vector2(w * 0.78, h * 0.4)
			draw_circle(mars, 46.0, Color(0.6, 0.6, 0.58))
			for blob2 in [Vector2(-14, 6), Vector2(12, 14), Vector2(4, -16)]:
				draw_circle(mars + blob2, 11.0, Color(0.46, 0.46, 0.45))
			draw_circle(mars + Vector2(0, -38), 9.0, Color(0.9, 0.9, 0.9))
			# the dotted road between them
			for i in 14:
				var k: float = float(i + 1) / 15.0
				var p2: Vector2 = earth.lerp(mars, k) + Vector2(0, -34.0 * sin(k * PI))
				draw_circle(p2, 2.0, Color(1, 1, 1, 0.85))
			var mid: Vector2 = earth.lerp(mars, 0.5) + Vector2(0, -34.0)
			draw_colored_polygon(PackedVector2Array([mid + Vector2(13, -5), mid + Vector2(-9, -9), mid + Vector2(-5, 5)]), Color(1, 1, 1))
		elif kind == "town":
			draw_rect(Rect2(0, 0, w, h), Color(0.8, 0.8, 0.77))
			draw_colored_polygon(PackedVector2Array([Vector2(0, 100), Vector2(60, 70), Vector2(130, 96), Vector2(200, 62), Vector2(w, 92), Vector2(w, 140), Vector2(0, 140)]), Color(0.66, 0.66, 0.64))
			draw_rect(Rect2(0, 132, w, h - 132.0), Color(0.5, 0.5, 0.48))
			for i in 16:
				draw_circle(Vector2(rnd.randf() * w, rnd.randf_range(140.0, h)), rnd.randf_range(1.5, 4.0), Color(0.4, 0.4, 0.39))
		else:
			# the rocket leaving: sky, ground, smoke and a waving crowd
			draw_rect(Rect2(0, 0, w, h), Color(0.82, 0.82, 0.79))
			draw_rect(Rect2(0, 140, w, h - 140.0), Color(0.5, 0.5, 0.48))
			for i in 16:
				var sp2 := Vector2(138.0 + rnd.randf_range(-70.0, 70.0), 140.0 + rnd.randf_range(-16.0, 14.0))
				draw_circle(sp2, rnd.randf_range(12.0, 24.0), Color(0.95, 0.95, 0.93, 0.9))
			for i in 9:
				var cp := Vector2(14.0 + float(i) * 11.0, h - rnd.randf_range(6.0, 12.0))
				draw_circle(cp, 4.0, Color(0.2, 0.2, 0.2))
				draw_rect(Rect2(cp.x - 3.0, cp.y + 3.0, 6, 10), Color(0.2, 0.2, 0.2))
		# print lines over the picture, then its frame
		var y := 0.0
		while y < h:
			draw_rect(Rect2(0, y, w, 1), Color(1, 1, 1, 0.06))
			y += 3.0


class Frame extends Control:
	# a thin black frame drawn on top of the picture
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.11, 0.1, 0.09), false, 2.0)


# ------------------------------------------------------------------ the scene

var index := -1
var busy := false
var stack: Array = []
var f_name: FontVariation
var f_head: FontVariation
var f_bold: FontVariation
var f_slant: FontVariation


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.music("music_calm")
	_make_fonts()

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var hint := Label.new()
	hint.text = "Press SPACE or click to read the next newspaper"
	hint.position = Vector2(0, 688)
	hint.size = Vector2(1280, 26)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	hint.z_index = 50
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	var skip := Button.new()
	skip.text = "Skip"
	skip.position = Vector2(1166, 14)
	skip.size = Vector2(100, 38)
	skip.focus_mode = Control.FOCUS_NONE
	skip.z_index = 50
	skip.pressed.connect(_start_game)
	add_child(skip)

	_next()


func _make_fonts() -> void:
	var base: Font = ThemeDB.fallback_font
	f_name = FontVariation.new()
	f_name.base_font = base
	f_name.variation_embolden = 1.0
	f_name.spacing_glyph = 4
	f_head = FontVariation.new()
	f_head.base_font = base
	f_head.variation_embolden = 0.9
	f_bold = FontVariation.new()
	f_bold.base_font = base
	f_bold.variation_embolden = 0.55
	f_slant = FontVariation.new()
	f_slant.base_font = base
	f_slant.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.2, 1.0), Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_next()


func _next() -> void:
	if busy:
		return
	index += 1
	if index >= PAPERS.size():
		Sfx.play("ui_confirm")
		_start_game()
		return
	if index > 0:
		Sfx.play("paper_flip")
	Sfx.play("paper")
	_show_paper(PAPERS[index])


func _fill(text: String) -> String:
	return text.replace("{sols}", str(Game.TOTAL_SOLS))


func _show_paper(data: Dictionary) -> void:
	busy = true
	var ink := Color(0.11, 0.1, 0.09)
	var soft := Color(0.27, 0.25, 0.23)
	var paper := Sheet.new()
	paper.grain = index + 3
	paper.size = PAPER_SIZE
	paper.position = Vector2((1280.0 - PAPER_SIZE.x) / 2.0, 24.0)
	paper.pivot_offset = PAPER_SIZE / 2.0
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	stack.append(paper)
	if stack.size() > 3:
		var old: Control = stack.pop_front()
		old.queue_free()

	var w: float = PAPER_SIZE.x
	# ---- the top line and the paper's name
	_text(paper, str(data["number"]), null, 12, soft, Rect2(26, 10, 250, 18), HORIZONTAL_ALIGNMENT_LEFT)
	_text(paper, str(data["date"]), null, 12, soft, Rect2(250, 10, w - 500.0, 18), HORIZONTAL_ALIGNMENT_CENTER)
	_text(paper, str(data["price"]), null, 12, soft, Rect2(w - 276.0, 10, 250, 18), HORIZONTAL_ALIGNMENT_RIGHT)
	_text(paper, str(data["name"]), f_name, 54, ink, Rect2(24, 30, w - 48.0, 70), HORIZONTAL_ALIGNMENT_CENTER)
	_text(paper, str(data["motto"]), f_slant, 13, soft, Rect2(24, 98, w - 48.0, 20), HORIZONTAL_ALIGNMENT_CENTER)

	# ---- the headline: tall, heavy, squeezed letters like a real front page
	var squeeze := 0.78
	var head := _text(paper, str(data["headline"]), f_head, 42, ink, Rect2(24, 128, (w - 48.0) / squeeze, 108), HORIZONTAL_ALIGNMENT_CENTER, true)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_theme_constant_override("line_spacing", -6)
	head.scale = Vector2(squeeze, 1.0)
	_text(paper, _fill(str(data["deck"])), f_slant, 20, soft, Rect2(24, 243, w - 48.0, 30), HORIZONTAL_ALIGNMENT_CENTER)

	# ---- column 1: the picture, its caption and a quote
	var photo := Photo.new()
	photo.kind = str(data["photo"])
	photo.position = Vector2(24, 290)
	photo.size = Vector2(272, 170)
	paper.add_child(photo)
	var frame := Frame.new()
	frame.position = photo.position
	frame.size = photo.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(frame)
	_text(paper, str(data["caption"]), f_slant, 12, soft, Rect2(24, 464, 272, 36), HORIZONTAL_ALIGNMENT_LEFT, true)
	var quote := _text(paper, str(data["quote"]), f_slant, 19, ink, Rect2(30, 508, 260, 104), HORIZONTAL_ALIGNMENT_CENTER, true)
	quote.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# ---- column 2: the story (the first lines are big enough to read at a glance)
	var lead_text: String = _fill(str(data["lead"]))
	var lead := _text(paper, lead_text, f_bold, 19, ink, Rect2(320, 288, 270, 140), HORIZONTAL_ALIGNMENT_LEFT, true)
	lead.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var lead_lines: int = maxi(lead.get_line_count(), int(ceil(float(lead_text.length()) / 26.0)))
	var story_y: float = 288.0 + float(lead_lines) * 27.0 + 12.0
	var story := _text(paper, _fill(str(data["story"])), null, 14, soft, Rect2(320, story_y, 270, 616.0 - story_y), HORIZONTAL_ALIGNMENT_FILL, true)
	story.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	story.add_theme_constant_override("line_spacing", 2)

	# ---- column 3: a side box, and a tiny advert under it
	var box := Panel.new()
	box.position = Vector2(612, 290)
	box.size = Vector2(264, 232)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.89, 0.86, 0.77)
	sb.border_color = ink
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(box)
	var bar := ColorRect.new()
	bar.color = ink
	bar.position = Vector2(0, 0)
	bar.size = Vector2(264, 30)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	_text(box, str(data["box"]), f_bold, 16, Color(0.95, 0.92, 0.84), Rect2(0, 3, 264, 24), HORIZONTAL_ALIGNMENT_CENTER)
	var items: Array = data["items"]
	var lines := PackedStringArray()
	for item in items:
		lines.append("- " + str(item))
	var list := _text(box, "\n".join(lines), null, 14, ink, Rect2(12, 38, 242, 188), HORIZONTAL_ALIGNMENT_LEFT, true)
	list.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	list.add_theme_constant_override("line_spacing", 3)
	var advert := Panel.new()
	advert.position = Vector2(612, 534)
	advert.size = Vector2(264, 82)
	var ab := StyleBoxFlat.new()
	ab.bg_color = Color(0, 0, 0, 0)
	ab.border_color = soft
	ab.set_border_width_all(1)
	advert.add_theme_stylebox_override("panel", ab)
	advert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(advert)
	var small := _text(advert, _fill(str(data["small"])), f_slant, 13, soft, Rect2(10, 6, 244, 70), HORIZONTAL_ALIGNMENT_CENTER, true)
	small.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# ---- the paper spins onto the pile
	var tilt := deg_to_rad(-2.2 + 1.5 * float(index % 4))
	paper.scale = Vector2(0.12, 0.12)
	paper.rotation = tilt - TAU
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(paper, "scale", Vector2(1, 1), 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(paper, "rotation", tilt, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_paper_done)


func _paper_done() -> void:
	busy = false


func _text(parent: Control, text: String, font: Font, font_size: int, color: Color, box: Rect2, align: HorizontalAlignment, wrap: bool = false) -> Label:
	var l := Label.new()
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	# the box first and the words after it: a label that gets its words first grows
	# to fit them, and then the columns of the page fall apart
	l.position = box.position
	l.size = box.size
	l.text = text
	l.size = box.size
	return l


func _start_game() -> void:
	Game.change_scene("res://scenes/main.tscn")
