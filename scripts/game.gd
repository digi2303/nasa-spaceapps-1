extends Node
# Autoload "Game": settings and data shared by every scene.

const NasaData = preload("res://scripts/nasa_data.gd")
const WorldData = preload("res://scripts/world_data.gd")

# ---- Game length. One sol (a day on Mars) = DAY + DUSK + NIGHT + DAWN.
# Change these numbers to make the game longer or shorter.
# For a quick demo try 60, 20, 40 and 20: the whole game then takes about 16 minutes.
const DAY_SECONDS := 240.0    # full daylight: 4 minutes
const DUSK_SECONDS := 60.0    # sunset: the sky slowly turns dark (1 minute)
const NIGHT_SECONDS := 120.0  # night: 2 minutes
const DAWN_SECONDS := 60.0    # sunrise: the sky slowly turns bright again (1 minute)
const SOL_SECONDS := DAY_SECONDS + DUSK_SECONDS + NIGHT_SECONDS + DAWN_SECONDS
const TOTAL_SOLS := 7         # the President is away for 7 sols

# F9 jumps to the next part of the day (day, sunset, night, sunrise). Handy for testing
# and for showing the game quickly. Set this to false to switch the shortcut off.
const DEV_KEYS := true

const SETTINGS_PATH := "user://settings.cfg"
const TEXT_SPEEDS := {"slow": 25.0, "normal": 45.0, "instant": 0.0}

const KEYS := "Click / SPACE"
const KEYS_HOLD := "Hold click / SPACE"
const KEYS_SAY := "click or press SPACE"
const KEYS_HOLD_SAY := "hold the mouse button or SPACE"

var character := "girl"      # "girl" or "boy"
var show_tour := true        # the machine tour at the start of a game (the title screen can switch it off)
var result := {}             # filled in when a game ends, read by the end screen

# These three are updated by main.gd every frame and read by colonists and vehicles.
var paused := false          # true while a dialog is open: everything in the world waits
var shelter := false         # true at night and during storms: townspeople go home
var player_pos := Vector2.ZERO

var text_speed := "normal"
var volume := 1.0

var fade_rect: ColorRect
var changing := false

# The uneven edge of the map (from world_data.gd). Nobody can walk or drive past it.
var border := PackedVector2Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.size = Vector2(1280, 720)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)
	for p in WorldData.BORDER:
		border.append(p)
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_add_action("interact", [KEY_E, KEY_SPACE, click])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		if k is InputEvent:
			InputMap.action_add_event(action, k)
		else:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func change_scene(path: String) -> void:
	if changing:
		return
	changing = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.3)
	tw.tween_callback(_swap_scene.bind(path))


func _swap_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.35)
	tw.tween_callback(_fade_done)


func _fade_done() -> void:
	changing = false
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var speed: String = str(cfg.get_value("game", "text_speed", "normal"))
		if TEXT_SPEEDS.has(speed):
			text_speed = speed
		volume = clampf(float(cfg.get_value("audio", "volume", 1.0)), 0.0, 1.0)
	_apply_volume()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "text_speed", text_speed)
	cfg.set_value("audio", "volume", volume)
	cfg.save(SETTINGS_PATH)


func set_text_speed(speed: String) -> void:
	if not TEXT_SPEEDS.has(speed):
		return
	text_speed = speed
	save_settings()


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	save_settings()


func _apply_volume() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))


func text_cps() -> float:
	return float(TEXT_SPEEDS.get(text_speed, 45.0))


func dev_keys() -> bool:
	return DEV_KEYS and OS.is_debug_build()


func press_text(what: String) -> String:
	return "%s: %s" % [KEYS, what]


func hold_text(what: String) -> String:
	return "%s: %s" % [KEYS_HOLD, what]


func keys_fill(text: String) -> String:
	return text.replace("{press}", KEYS_SAY).replace("{hold}", KEYS_HOLD_SAY)


func inside_map(p: Vector2) -> bool:
	# true when the point is on the ground you can walk on, inside the uneven edge
	if border.size() < 3:
		return true
	return Geometry2D.is_point_in_polygon(p, border)


func weather() -> Array:
	return NasaData.WEATHER


func cold_nights() -> Array:
	return NasaData.COLD_NIGHTS


func flares() -> Array:
	return NasaData.FLARES


func weather_is_real() -> bool:
	return NasaData.WEATHER_VERIFIED


func credits_text() -> String:
	var lines := PackedStringArray()
	lines.append("Solar flares: real events from NASA's DONKI space weather database (2026).")
	if weather_is_real():
		lines.append("Mars temperatures: real measurements from NASA's Curiosity rover (REMS).")
	else:
		lines.append("Mars temperatures: sample values in the range NASA's Curiosity rover measures.")
	lines.append("Oxygen machine: based on NASA's MOXIE experiment on the Perseverance rover.")
	lines.append("Greenhouse: NASA grows lettuce and other plants under LED lights on the International Space Station ('Veggie').")
	lines.append("Art: our team, made with AI tools.")
	return "\n".join(lines)
