extends Control
# End screen: did the colony survive, what happened, and what to try next time.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var r: Dictionary = Game.result
	var won: bool = r.get("won", false)
	Sfx.stop_loops()
	Sfx.music("")
	if won:
		Sfx.play("win")
	else:
		Sfx.play("lose")
	var reason: String = str(r.get("reason", ""))
	var stats: Dictionary = r.get("stats", {})

	var bg := ColorRect.new()
	if won:
		bg.color = Color(0.07, 0.13, 0.1)
	else:
		bg.color = Color(0.14, 0.07, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var headline: String = "THE COLONY SURVIVED!"
	var color := Color(0.55, 1.0, 0.6)
	if not won:
		headline = "MISSION OVER"
		color = Color(1.0, 0.6, 0.45)
	_label(headline, 58, color, Vector2(0, 30), Vector2(1280, 76))

	var summary: String = ""
	var sol_number: int = int(r.get("sols", 0)) + 1
	if won:
		summary = "The President landed with the new settlers! You kept New Hope running for all %d sols. Great work, Operator!" % Game.TOTAL_SOLS
	elif reason == "oxygen":
		summary = "The colony ran out of oxygen on sol %d. Everyone moved into the emergency shelter and is safe. You can try again!" % sol_number
	elif reason == "hunger":
		summary = "The colony ran out of food on sol %d, and everyone got too weak to work. Help is on the way. You can try again!" % sol_number
	elif reason == "cold":
		summary = "The freezing nights wore everyone out on sol %d. The doctor is looking after the colony. You can try again!" % sol_number
	elif reason == "radiation":
		summary = "Too much radiation made everyone sick on sol %d. The doctor is looking after the colony. You can try again!" % sol_number
	else:
		summary = "The colony got too hurt to keep working on sol %d. The doctor is looking after everyone. You can try again!" % sol_number
	_label(summary, 24, Color(1, 1, 1), Vector2(140, 108), Vector2(1000, 70))

	var lines := PackedStringArray()
	lines.append("Full repairs: %d      Quick patches: %d      Panels wiped clean: %d      Spare parts used: %d" % [int(stats.get("repairs", 0)), int(stats.get("patches", 0)), int(stats.get("cleaned", 0)), int(stats.get("parts_used", 0))])
	lines.append("Ore collected: %d      Parts built in the workshop: %d      Things you built: %d" % [int(stats.get("ore", 0)), int(stats.get("parts_built", 0)), int(stats.get("built", 0))])
	lines.append("Decisions made: %d      Favours done: %d      Space tools discovered: %d of %d      Solar panels: %d      Wind turbines: %d" % [int(stats.get("decisions", 0)), int(stats.get("side", 0)), int(r.get("discoveries", 0)), int(r.get("discoveries_total", 0)), int(r.get("panels", 0)), int(r.get("turbines", 0))])
	lines.append("Health lost to cold nights: %d      radiation: %d      flying debris: %d      hunger: %d" % [int(stats.get("cold", 0.0)), int(stats.get("radiation", 0.0)), int(stats.get("debris", 0.0)), int(stats.get("hunger", 0.0))])
	lines.append("Lowest oxygen: %d%%      Lowest food: %d%%      Time with no power: %d seconds" % [int(stats.get("lowest_oxygen", 0.0)), int(stats.get("lowest_food", 0.0)), int(stats.get("blackout", 0.0))])
	_label("\n".join(lines), 18, Color(0.9, 0.9, 0.9), Vector2(60, 184), Vector2(1160, 150))

	_label("WHAT IF...?", 24, Color(1.0, 0.85, 0.5), Vector2(140, 346), Vector2(1000, 34))
	_label(_what_if(won, reason, stats, r), 22, Color(1, 1, 1), Vector2(140, 380), Vector2(1000, 96))

	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.position = Vector2(515, 492)
	again.size = Vector2(250, 60)
	again.add_theme_font_size_override("font_size", 28)
	again.pressed.connect(_on_again)
	add_child(again)

	_label("Every game has different storms, breakdowns and decisions. Try a new plan!", 18, Color(0.8, 0.8, 0.8), Vector2(0, 560), Vector2(1280, 28))
	_label(Game.credits_text(), 14, Color(0.65, 0.7, 0.75), Vector2(140, 594), Vector2(1000, 116))


func _what_if(won: bool, reason: String, stats: Dictionary, _r: Dictionary) -> String:
	var cold: float = float(stats.get("cold", 0.0))
	var radiation: float = float(stats.get("radiation", 0.0))
	var debris: float = float(stats.get("debris", 0.0))
	var hunger: float = float(stats.get("hunger", 0.0))
	var blackout: float = float(stats.get("blackout", 0.0))
	var built: int = int(stats.get("built", 0))
	var patches: int = int(stats.get("patches", 0))
	var repairs: int = int(stats.get("repairs", 0))

	if not won and reason == "oxygen":
		if blackout > 40.0:
			return "The battery ran empty, so the oxygen machine stopped. What if you had switched the greenhouse lights off for a while to fill the battery before night?"
		return "What if you had kept the oxygen machine running more by day, and fixed air leaks as soon as someone told you about them?"
	if hunger >= cold and hunger >= radiation and hunger >= debris and hunger > 3.0:
		return "The colony went hungry. What if you had kept the greenhouse lights on longer by day, even if the battery filled more slowly?"
	if cold >= radiation and cold >= debris and cold > 5.0:
		return "Cold nights cost the most health. What if you had filled the battery before sunset, or built a wind turbine? It makes power at night, when the heater needs it."
	if radiation >= cold and radiation >= debris and radiation > 5.0:
		return "Radiation cost the most health. What if you had switched the shield on during solar flares, and switched something else off to pay for it?"
	if debris > 5.0:
		return "Flying debris hit you a lot. What if you had waited inside a rover until the dust storm had passed?"
	if blackout > 60.0:
		return "The colony lost power for a while. What if you had switched one machine off at sunset, so the battery lasted the whole night?"
	if patches > repairs + 1:
		return "You often had no spare parts, so your quick patches kept falling off. What if you had collected more ore from the miners?"
	if built == 0:
		return "You never built anything new. What if you had spent some spare parts on extra solar panels or a wind turbine?"
	return "You hardly lost any health! Can you do it again with fewer spare parts, or without a single quick patch?"


func _label(text: String, font_size: int, color: Color, pos: Vector2, box: Vector2) -> void:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	# the box first and the words after it, so long lines wrap instead of running off the screen
	l.position = pos
	l.size = box
	l.text = text
	l.size = box


func _on_again() -> void:
	Sfx.play("ui_click")
	Game.change_scene("res://scenes/title.tscn")
