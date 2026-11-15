extends Node
# "Explore and learn": on some sols a "?" appears on the map. The player picks it up,
# finds a real space tool, carries it to the colonist who knows about it, and that
# colonist explains it. Then it is added to the Discovery Notebook (N key).
#
# Everything about the items comes from data/learn_items.json. To add an item, add one
# entry to that file and put its picture in assets/learn. Nothing here needs to change.

const NpcScript = preload("res://scripts/npc.gd")
const WorldData = preload("res://scripts/world_data.gd")

const DATA_PATH := "res://data/learn_items.json"
const ART_DIR := "res://assets/learn/"
const LANG := "en"                 # the game is in English; the "tr" texts stay in the file as a spare
const FREE_AFTER := 20.0           # the "?" never appears in the first seconds of a sol
const LATEST := 150.0              # if the player is busy all day, it appears at this time anyway
const EXTRA_WARNING := 60.0        # how much earlier flares are announced once the detector is known
const GOLD := Color(1.0, 0.85, 0.4)
# places where a "?" can appear
const SPOTS := [Vector2(2100, 800), Vector2(3900, 3000), Vector2(5000, 2700), Vector2(1200, 1300), Vector2(700, 2700), Vector2(1500, 2700), Vector2(2100, 3400)]
# picture sheets for the extra experts (colonists that the items need and the colony did not have yet)
const SHEETS := ["town2", "town4", "town6", "town1", "town3", "town5"]


# The "?" on the ground.
class Find extends Node2D:
	var what := "learn"
	var title := "?"
	var mark: Sprite2D
	var t := 0.0

	func _ready() -> void:
		mark = Sprite2D.new()
		mark.texture = load("res://assets/learn/learn_question.png")
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mark.hframes = 2
		mark.scale = Vector2(3, 3)
		mark.offset = Vector2(0, -12)
		add_child(mark)
		z_index = 4

	func _process(delta: float) -> void:
		# a two-frame bounce
		t += delta
		mark.frame = int(t / 0.35) % 2


# The notebook button in the bottom left corner: a little picture of an open book.
# It is drawn from small squares ("art pixels"), so it matches the pixel art of the game.
class BookIcon extends Control:
	const PX := 3.0                # the size of one art pixel on the screen
	var hover := false

	func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
		draw_rect(Rect2(x * PX, y * PX, w * PX, h * PX), color)

	func _draw() -> void:
		var line := Color(0.16, 0.1, 0.1)
		var cover := Color(0.52, 0.27, 0.14)
		var cover_dark := Color(0.36, 0.18, 0.1)
		var paper := Color(0.99, 0.96, 0.87)
		var paper_shade := Color(0.86, 0.81, 0.7)
		var ink := Color(0.35, 0.42, 0.62)
		if hover:
			paper = Color(1, 1, 0.94)
		# the cover, with a dark outline
		_box(0, 3, 28, 17, line)
		_box(1, 4, 26, 15, cover)
		_box(1, 17, 26, 2, cover_dark)
		# the two pages
		_box(2, 1, 11, 16, line)
		_box(15, 1, 11, 16, line)
		_box(13, 2, 2, 16, line)
		_box(3, 2, 10, 14, paper)
		_box(15, 2, 10, 14, paper)
		_box(12, 3, 1, 14, paper_shade)
		_box(15, 3, 1, 14, paper_shade)
		_box(13, 3, 2, 14, Color(0.7, 0.63, 0.52))
		# the writing
		for row in 5:
			var y: float = 4.0 + float(row) * 2.0
			_box(4, y, [7, 6, 7, 5, 6][row], 1, ink)
			_box(17, y, [6, 7, 5, 7, 4][row], 1, ink)
		# a red ribbon to mark the page
		_box(13, 16, 2, 4, Color(0.85, 0.2, 0.2))
		_box(13, 19, 1, 1, line)


# A big red arrow that bounces up and down above the notebook button when there is
# something new to read.
class RedArrow extends Control:
	var t := 0.0

	func _process(delta: float) -> void:
		if visible:
			t += delta
			queue_redraw()

	func _draw() -> void:
		var bob: float = sin(t * 6.0) * 10.0
		# the arrow points down at the book: a thick shaft and a wide head
		var shape := PackedVector2Array([Vector2(-15, -92), Vector2(15, -92), Vector2(15, -44), Vector2(36, -44), Vector2(0, 0), Vector2(-36, -44), Vector2(-15, -44)])
		var shadow := PackedVector2Array()
		var outline := PackedVector2Array()
		var fill := PackedVector2Array()
		var centre := Vector2(0, -50)
		for p in shape:
			var moved: Vector2 = p + Vector2(0, bob)
			fill.append(moved)
			outline.append(centre + Vector2(0, bob) + (p - centre) * 1.16)
			shadow.append(moved + Vector2(5, 6))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
		draw_colored_polygon(outline, Color(0.3, 0.02, 0.02))
		draw_colored_polygon(fill, Color(0.95, 0.12, 0.1))
		# a lighter stripe, so the arrow looks shiny
		draw_rect(Rect2(-10, -88 + bob, 6, 40), Color(1.0, 0.5, 0.45))


# The open notebook: a brown cover, two pages of lined paper and a spiral in the middle.
class Pages extends Control:
	var left := Rect2()
	var right := Rect2()
	var first_line := 60.0         # how far below the top of a page the first line is
	var gap := 26.0                # the distance between two lines
	var margin := 44.0             # where the red margin line is

	func _draw() -> void:
		var cover := StyleBoxFlat.new()
		cover.bg_color = Color(0.45, 0.24, 0.13)
		cover.border_color = Color(0.25, 0.12, 0.07)
		cover.set_border_width_all(4)
		cover.set_corner_radius_all(16)
		draw_style_box(cover, Rect2(Vector2.ZERO, size))
		for page in [left, right]:
			var r: Rect2 = page
			# a few sheets under the top one
			draw_rect(Rect2(r.position + Vector2(-3, 5), r.size), Color(0.8, 0.76, 0.66))
			draw_rect(Rect2(r.position + Vector2(-1, 2), r.size), Color(0.9, 0.87, 0.78))
			draw_rect(r, Color(0.99, 0.96, 0.87))
			var y: float = r.position.y + first_line
			while y < r.end.y - 14.0:
				draw_line(Vector2(r.position.x + 6.0, y), Vector2(r.end.x - 6.0, y), Color(0.55, 0.7, 0.9, 0.75), 1.0)
				y += gap
			draw_line(Vector2(r.position.x + margin, r.position.y + 4.0), Vector2(r.position.x + margin, r.end.y - 4.0), Color(0.95, 0.45, 0.45, 0.8), 1.5)
		# the paper is a little darker where it bends into the middle
		for i in 5:
			var shade := Color(0.4, 0.3, 0.2, 0.05 * float(5 - i))
			draw_rect(Rect2(left.end.x - 8.0 * float(i + 1), left.position.y, 8.0, left.size.y), shade)
			draw_rect(Rect2(right.position.x + 8.0 * float(i), right.position.y, 8.0, right.size.y), shade)
		# the spiral that holds the pages together
		var mid: float = (left.end.x + right.position.x) / 2.0
		draw_rect(Rect2(left.end.x, left.position.y, right.position.x - left.end.x, left.size.y), Color(0.3, 0.16, 0.09))
		var ring_y: float = left.position.y + 20.0
		while ring_y < left.end.y - 10.0:
			draw_circle(Vector2(left.end.x - 9.0, ring_y), 4.0, Color(0.25, 0.2, 0.18))
			draw_circle(Vector2(right.position.x + 9.0, ring_y), 4.0, Color(0.25, 0.2, 0.18))
			draw_line(Vector2(left.end.x - 9.0, ring_y - 1.0), Vector2(right.position.x + 9.0, ring_y - 1.0), Color(0.55, 0.57, 0.62), 5.0)
			draw_line(Vector2(left.end.x - 8.0, ring_y - 2.5), Vector2(right.position.x + 8.0, ring_y - 2.5), Color(0.88, 0.9, 0.94), 1.5)
			draw_circle(Vector2(mid, ring_y - 1.0), 1.0, Color(0.88, 0.9, 0.94))
			ring_y += 34.0


# A photo stuck into the notebook with tape. While the tool has not been found yet,
# it is an empty dashed frame with a "?" in it.
class Photo extends Control:
	var found := false

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		if found:
			draw_rect(Rect2(box.position + Vector2(3, 4), box.size), Color(0, 0, 0, 0.18))
			draw_rect(box, Color(1, 1, 1))
			draw_rect(Rect2(4, 4, size.x - 8.0, size.y - 8.0), Color(0.86, 0.91, 0.97))
			draw_rect(box, Color(0.7, 0.68, 0.62), false, 1.0)
			# two pieces of tape
			draw_rect(Rect2(size.x / 2.0 - 16.0, -7.0, 32.0, 13.0), Color(0.95, 0.9, 0.55, 0.85))
		else:
			var grey := Color(0.55, 0.55, 0.6)
			var x := 0.0
			while x < size.x:
				draw_line(Vector2(x, 0), Vector2(minf(x + 6.0, size.x), 0), grey, 2.0)
				draw_line(Vector2(x, size.y), Vector2(minf(x + 6.0, size.x), size.y), grey, 2.0)
				x += 11.0
			var y := 0.0
			while y < size.y:
				draw_line(Vector2(0, y), Vector2(0, minf(y + 6.0, size.y)), grey, 2.0)
				draw_line(Vector2(size.x, y), Vector2(size.x, minf(y + 6.0, size.y)), grey, 2.0)
				y += 11.0


var main
var items: Array = []              # the entries of the JSON file
var state := {}                    # item id -> "hidden", "out", "carried", "learned" or "missed"
var teachers := {}                 # item id -> the colonist who explains it
var today = null                   # the item that can appear this sol (or null)
var find: Find = null              # the "?" lying on the map right now
var find_item: Dictionary = {}
var book_open := false

var layer: CanvasLayer
var button: Button                 # an invisible button on top of the book picture
var icon: BookIcon
var count_tag: Label               # the little "2/6" next to the book picture
var arrow: RedArrow
var unread := false                # something new is in the notebook that the player has not looked at yet
var fresh := {}                    # item id -> true for entries that still get a "NEW!" stamp
var carry_icon: TextureRect
var book: Pages
var book_title: Label
var book_count: Label
var cells: Array = []              # one dictionary of controls for each entry in the notebook
var hand: FontVariation            # slanted letters that look a bit like handwriting
var hand_bold: FontVariation


func setup(p_main) -> void:
	main = p_main
	_load_items()
	_find_teachers()
	_build_ui()
	_refresh_ui()


func _load_items() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("learn: %s is missing" % DATA_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("learn: %s could not be read" % DATA_PATH)
		return
	for entry in parsed:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("id"):
			items.append(entry)
			state[str(entry["id"])] = "hidden"


func _tr(item: Dictionary, key: String):
	# the text of an item in the game's language ("en"), or any other language as a spare
	var v = item.get(key)
	if typeof(v) != TYPE_DICTIONARY:
		return v
	if v.has(LANG):
		return v[LANG]
	for k in v:
		return v[k]
	return ""


func item_name(item: Dictionary) -> String:
	return str(_tr(item, "ad"))


func _picture(item: Dictionary) -> Texture2D:
	var path: String = ART_DIR + str(item.get("sprite", ""))
	if ResourceLoader.exists(path):
		return load(path)
	return load(ART_DIR + "learn_question.png")


func _find_teachers() -> void:
	# a colonist with the right job explains the item; if nobody has that job,
	# a new colonist with that job moves into the town
	var extra := 0
	for item in items:
		var job: String = str(_tr(item, "npc"))
		var who = null
		for n in main.npcs:
			if str(n.role).to_lower() == job.to_lower() and not teachers.values().has(n):
				who = n
				break
		if who == null:
			who = NpcScript.new()
			main.world.add_child(who)
			who.setup_npc("learn_" + str(item["id"]), job, "explorer", SHEETS[extra % SHEETS.size()])
			who.position = _free_place(extra)
			who.solid = true
			main.npcs.append(who)
			main.npc_by_id[who.npc_id] = who
			main.solids.append(who)
			extra += 1
		teachers[str(item["id"])] = who


func _free_place(i: int) -> Vector2:
	# a ring of places around the town square; take the first ones nothing stands on
	var centre := Vector2(3000, 2130)
	var found := 0
	for ring in [330.0, 420.0, 520.0, 640.0]:
		for k in 12:
			var a: float = TAU * float(k) / 12.0 + 0.26
			var p: Vector2 = centre + Vector2(cos(a) * ring * 1.5, sin(a) * ring)
			if not main._spot_free(p):
				continue
			var clear := true
			for n in main.npcs:
				if n.position.distance_to(p) < 170.0:
					clear = false
			for v in WorldData.VENDORS:
				var at: Vector2 = v[0]
				if at.distance_to(p) < 200.0:
					clear = false
			if not clear:
				continue
			if found == i:
				return p
			found += 1
	return centre + Vector2(120.0 * float(i), 0)


# ---------------------------------------------------------------------
#  The day
# ---------------------------------------------------------------------

func on_new_sol(sol_index: int) -> void:
	# yesterday's "?" was only there for one sol
	if find != null:
		state[str(find_item["id"])] = "missed"
		find.queue_free()
		find = null
		find_item = {}
		main.hud.toast("Yesterday's ? is gone. A new sol, a new chance!")
	today = null
	for item in items:
		if int(item.get("gun", 0)) == sol_index + 1 and state[str(item["id"])] == "hidden":
			today = item
			break
	_refresh_ui()


func tick() -> void:
	# called while the game is running: put today's "?" on the map when the player has time
	if today == null or find != null:
		return
	if main.sol_time < FREE_AFTER or main._phase() != "day":
		return
	var busy: bool = not main.quests.is_empty() or not main.decisions.is_empty() or main.storm_left > 0.0 or main.flare_left > 0.0
	if busy and main.sol_time < LATEST:
		return
	_put_out(today)
	today = null


func _put_out(item: Dictionary) -> void:
	var places := SPOTS.duplicate()
	places.shuffle()
	var spot: Vector2 = places[0]
	for p in places:
		if main._spot_free(p) and main.player.position.distance_to(p) > 500.0:
			spot = p
			break
	find = Find.new()
	find.position = spot
	main.world.add_child(find)
	find_item = item
	state[str(item["id"])] = "out"
	main.hud.show_banner("WHAT IS THAT?", "Something from an old space mission is lying out there! Follow the ? on your %s and pick it up before this sol ends." % main._map_word(), 10.0)


func pick_up() -> void:
	if find == null:
		return
	var item: Dictionary = find_item
	state[str(item["id"])] = "carried"
	find.queue_free()
	find = null
	find_item = {}
	Sfx.play("coin")
	main.hud.toast("You found something! Take it to %s to learn what it is." % _who(item))
	main._refresh_quests()
	_refresh_ui()


func _who(item: Dictionary) -> String:
	# "Engineer Mira" for a colonist with a name, "the Pilot" for one known by the job
	var npc = teachers[str(item["id"])]
	if npc.role == "explorer":
		return "the " + str(npc.npc_name)
	return str(npc.npc_name)


func _carried() -> Array:
	var list := []
	for item in items:
		if state[str(item["id"])] == "carried":
			list.append(item)
	return list


func wants(npc) -> bool:
	for item in _carried():
		if teachers[str(item["id"])] == npc:
			return true
	return false


func mark_alerts() -> void:
	for item in _carried():
		teachers[str(item["id"])].set_alert(true)


func talk(npc) -> bool:
	# the colonist explains the thing the player brought; true if there was something to explain
	var said := false
	for item in _carried():
		if teachers[str(item["id"])] != npc:
			continue
		said = true
		for line in _tr(item, "satirlar"):
			main._say(npc.npc_name, str(line))
		state[str(item["id"])] = "learned"
		main.after_dialog.append(_learned.bind(item))
	return said


func _learned(item: Dictionary) -> void:
	Sfx.play("success")
	# a big red arrow points at the notebook until the player opens it
	unread = true
	fresh[str(item["id"])] = true
	var n: int = count()
	if n >= items.size():
		main.hud.show_banner("NOTEBOOK COMPLETE!", "You discovered all %d space tools. You are a real space explorer! Press N or click the book to read your Discovery Notebook." % items.size(), 12.0)
	else:
		main.hud.toast("New in your notebook: %s (%d of %d). Press N or click the book." % [item_name(item), n, items.size()])
	main._refresh_quests()
	_refresh_ui()


func count() -> int:
	var n := 0
	for item in items:
		if state[str(item["id"])] == "learned":
			n += 1
	return n


func knows(id: String) -> bool:
	return str(state.get(id, "")) == "learned"


func tasks() -> Array:
	var t := []
	if find != null:
		t.append("Explore: find the ? on your %s" % main._map_word())
	for item in _carried():
		t.append("Explore: show your find to %s (!)" % _who(item))
	return t


func idle_lines() -> Array:
	return ["Hello, Operator! If you find something from an old space mission, bring it to the right expert. We love explaining!"]


# ---------------------------------------------------------------------
#  The Discovery Notebook
# ---------------------------------------------------------------------

# Colours of the writing in the notebook.
const INK := Color(0.1, 0.16, 0.5)             # blue pen: titles and names
const INK_DARK := Color(0.14, 0.14, 0.2)       # dark pen: what you learned
const PENCIL := Color(0.42, 0.42, 0.48)        # pencil: hints and small notes
const STAMP := Color(0.85, 0.12, 0.1)          # the red "NEW!" stamp

# Where the notebook and its two pages are on the screen.
const BOOK_POS := Vector2(90, 30)
const BOOK_SIZE := Vector2(1100, 660)
const PAGE_LEFT := Rect2(22, 18, 520, 624)
const PAGE_RIGHT := Rect2(558, 18, 520, 624)
const FIRST_LINE := 60.0           # the first line of a page, measured from its top
const LINE_GAP := 26.0             # the distance between two lines
const WRITE_X := 56.0              # writing starts here, just right of the red margin line
const ENTRY_LINES := 5             # every entry takes this many lines of the page
const PER_PAGE := 3                # entries on one page


func _label(parent: Control, text: String, font_size: int, color: Color, pos: Vector2, box: Vector2, wrap: bool = false) -> Label:
	var l := Label.new()
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.position = pos
	l.size = box
	l.text = text
	l.size = box
	return l


func _line_y(page: Rect2, line: int) -> float:
	# how far down the notebook a line of a page is (line 0 is the first one)
	return page.position.y + FIRST_LINE + LINE_GAP * float(line)


func _write(page: Rect2, line: int, x: float, width: float, text: String, font_size: int, color: Color, font: Font, lines: int = 1) -> Label:
	# writes on the paper so that the letters stand exactly on a line, like real handwriting
	var l := _label(book, text, font_size, color, Vector2.ZERO, Vector2(width, LINE_GAP * float(lines)), lines > 1)
	l.add_theme_font_override("font", font)
	l.add_theme_constant_override("line_spacing", int(round(LINE_GAP - font.get_height(font_size))))
	l.position = Vector2(page.position.x + x, _line_y(page, line) - font.get_ascent(font_size) - 3.0)
	l.size = Vector2(width, LINE_GAP * float(lines))
	return l


func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 11
	add_child(layer)

	var base: Font = ThemeDB.fallback_font
	hand = FontVariation.new()
	hand.base_font = base
	hand.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)
	hand_bold = FontVariation.new()
	hand_bold.base_font = base
	hand_bold.variation_embolden = 0.6
	hand_bold.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)

	# ---- bottom left: the picture of an open book. Click it (or press N) to read the notebook.
	icon = BookIcon.new()
	icon.position = Vector2(12, 646)
	icon.size = Vector2(84, 60)
	icon.pivot_offset = Vector2(42, 60)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(icon)
	button = Button.new()
	button.flat = true
	button.position = icon.position
	button.size = icon.size
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Discovery Notebook (N)"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var none := StyleBoxEmpty.new()
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, none)
	button.pressed.connect(toggle_book)
	button.mouse_entered.connect(_on_hover.bind(true))
	button.mouse_exited.connect(_on_hover.bind(false))
	layer.add_child(button)
	# how many tools are in the notebook, as a little tag on the corner of the book
	count_tag = _label(icon, "", 13, Color(1, 1, 1), Vector2(58, 44), Vector2(38, 20))
	count_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tag := StyleBoxFlat.new()
	tag.bg_color = Color(0.07, 0.06, 0.1, 0.9)
	tag.border_color = GOLD
	tag.set_border_width_all(2)
	tag.set_corner_radius_all(9)
	count_tag.add_theme_stylebox_override("normal", tag)

	# the big red arrow that shows up when something new is in the notebook
	arrow = RedArrow.new()
	arrow.position = Vector2(54, 634)          # the tip of the arrow, just above the book
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.visible = false
	layer.add_child(arrow)

	# the thing the player is carrying, next to the book
	carry_icon = TextureRect.new()
	carry_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	carry_icon.stretch_mode = TextureRect.STRETCH_SCALE
	carry_icon.position = Vector2(122, 658)
	carry_icon.size = Vector2(48, 48)
	carry_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(carry_icon)

	# ---- the open notebook: two pages of lined paper with handwriting on them
	book = Pages.new()
	book.position = BOOK_POS
	book.size = BOOK_SIZE
	book.left = PAGE_LEFT
	book.right = PAGE_RIGHT
	book.first_line = FIRST_LINE
	book.gap = LINE_GAP
	book.margin = WRITE_X - 12.0
	book.visible = false
	layer.add_child(book)

	var write_w: float = PAGE_LEFT.size.x - WRITE_X - 22.0
	book_title = _write(PAGE_LEFT, 1, WRITE_X, write_w, "My Discovery Notebook", 30, INK, hand_bold)
	book_count = _write(PAGE_LEFT, 2, WRITE_X, write_w, "", 17, PENCIL, hand)
	# the title is underlined twice, like a child would do it
	for k in 2:
		var under := ColorRect.new()
		under.color = INK
		under.position = Vector2(PAGE_LEFT.position.x + WRITE_X, _line_y(PAGE_LEFT, 1) + 3.0 + 4.0 * float(k))
		under.size = Vector2(318.0 - 26.0 * float(k), 2.0)
		under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		book.add_child(under)
	var close := _write(PAGE_LEFT, 20, WRITE_X, write_w, "N, ESC or a click outside: close the notebook", 15, PENCIL, hand)
	close.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for i in items.size():
		var page: Rect2 = PAGE_LEFT
		var first := 4                 # the left page starts lower: the title is above
		if i / PER_PAGE % 2 == 1:
			page = PAGE_RIGHT
			first = 1
		var line: int = first + (i % PER_PAGE) * ENTRY_LINES
		# the photo, stuck in a little crooked
		var photo := Photo.new()
		photo.size = Vector2(76, 76)
		photo.pivot_offset = photo.size / 2.0
		photo.position = Vector2(page.position.x + WRITE_X + 2.0, _line_y(page, line) - 24.0)
		photo.rotation = [-0.06, 0.05, -0.03, 0.06, -0.05, 0.04][i % 6]
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		book.add_child(photo)
		var pic := TextureRect.new()
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.position = Vector2(6, 6)
		pic.size = Vector2(64, 64)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo.add_child(pic)
		var big := _label(photo, "?", 44, PENCIL, Vector2(0, 6), Vector2(76, 60))
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big.add_theme_font_override("font", hand_bold)
		# the writing next to the photo
		var text_x: float = WRITE_X + 96.0
		var text_w: float = page.size.x - text_x - 22.0
		var head := _write(page, line, text_x, text_w, "", 21, INK, hand_bold)
		var body := _write(page, line + 1, text_x, text_w, "", 17, INK_DARK, hand, 3)
		var stamp := _label(book, "NEW!", 20, STAMP, Vector2(page.position.x + WRITE_X - 18.0, _line_y(page, line) + 40.0), Vector2(74, 28))
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.add_theme_font_override("font", hand_bold)
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(1, 1, 1, 0.7)
		ring.border_color = STAMP
		ring.set_border_width_all(3)
		ring.set_corner_radius_all(6)
		stamp.add_theme_stylebox_override("normal", ring)
		stamp.pivot_offset = Vector2(37, 14)
		stamp.rotation = -0.2
		cells.append({"photo": photo, "pic": pic, "big": big, "head": head, "body": body, "stamp": stamp})

	# where the facts come from, in small print at the bottom of the right page
	var note := _write(PAGE_RIGHT, 16, WRITE_X, write_w, "Where these facts come from (real space missions):", 15, INK, hand_bold)
	note.clip_text = true
	var lines := PackedStringArray()
	for item in items:
		lines.append("%s: %s" % [item_name(item), str(item.get("kaynak", ""))])
	var src := _label(book, "\n".join(lines), 11, PENCIL, Vector2(PAGE_RIGHT.position.x + WRITE_X, _line_y(PAGE_RIGHT, 16) + 6.0), Vector2(write_w, PAGE_RIGHT.end.y - _line_y(PAGE_RIGHT, 16) - 12.0), true)
	src.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	src.add_theme_constant_override("line_spacing", -1)
	src.clip_text = true


func _on_hover(on: bool) -> void:
	# the book grows a little under the mouse, so it is clear that you can click it
	icon.hover = on
	if on:
		icon.scale = Vector2(1.1, 1.1)
	else:
		icon.scale = Vector2(1, 1)
	icon.queue_redraw()


func _refresh_ui() -> void:
	if button == null:
		return
	count_tag.text = "%d/%d" % [count(), items.size()]
	book_count.text = "Space tools I found: %d of %d" % [count(), items.size()]
	arrow.visible = unread and not book_open
	var held: Array = _carried()
	carry_icon.visible = not held.is_empty()
	if not held.is_empty():
		carry_icon.texture = _picture(held[0])
	for i in cells.size():
		var item: Dictionary = items[i]
		var c: Dictionary = cells[i]
		var st: String = state[str(item["id"])]
		var open: bool = st == "learned"
		c["photo"].found = open
		c["photo"].queue_redraw()
		c["pic"].visible = open
		c["big"].visible = not open
		c["stamp"].visible = open and fresh.has(str(item["id"]))
		if open:
			c["pic"].texture = _picture(item)
			c["head"].text = item_name(item)
			c["head"].add_theme_color_override("font_color", INK)
			c["body"].text = str(_tr(item, "ozet"))
			c["body"].add_theme_color_override("font_color", INK_DARK)
		else:
			# not found yet: a pencil note about where to look
			c["head"].text = "? ? ?"
			c["head"].add_theme_color_override("font_color", PENCIL)
			if st == "missed":
				c["body"].text = "I missed this one on sol %d." % int(item.get("gun", 0))
			elif st == "carried":
				c["body"].text = "I have it! Show it to %s." % _who(item)
			else:
				c["body"].text = "Look for a ? on sol %d." % int(item.get("gun", 0))
			c["body"].add_theme_color_override("font_color", PENCIL)


func _can_open() -> bool:
	return not (main.game_over or main.cinematic or main.film.active or main.dialog_open or main.choice_open or main.touring or main.menu_open)


func toggle_book() -> void:
	if not book_open and not _can_open():
		return
	book_open = not book_open
	book.visible = book_open
	Sfx.play("paper")
	if book_open:
		unread = false                 # the player is looking: the red arrow can go
	else:
		fresh.clear()                  # the "NEW!" stamps were seen, so they are gone next time
	_refresh_ui()


func hide_ui() -> void:
	# the ending film: no buttons on the screen
	book_open = false
	layer.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if book_open and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not Rect2(BOOK_POS, BOOK_SIZE).has_point(event.position):
			toggle_book()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if book_open:
		if event.keycode == KEY_N or event.keycode == KEY_ESCAPE or event.is_action_pressed("interact"):
			toggle_book()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_N and _can_open():
		toggle_book()
		get_viewport().set_input_as_handled()
