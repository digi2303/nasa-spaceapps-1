extends Node
# Autoload "Sfx": every sound in the game goes through here.
#   Sfx.play("coin")              one short sound
#   Sfx.loop("wind_loop", true)   a sound that repeats while something is going on
#                                 (call it every frame with true or false)
#   Sfx.music("music_day")        background music (changes smoothly)
# The sound files are in assets/sounds. Where each one comes from: assets/sounds/CREDITS.txt

const DIR := "res://assets/sounds/"

# How loud each sound is, in decibels (0 = as loud as the file, -6 = about half).
# Change a number here to make one sound louder or quieter.
const VOLUME := {
	"ui_click": -6.0, "ui_select": -8.0, "ui_move": -8.0, "ui_confirm": -8.0,
	"blip": -12.0, "paper": -4.0, "paper_flip": -6.0, "chime": -8.0, "news": -12.0,
	"toast": -14.0, "coin": -8.0, "success": -8.0, "step": -30.0, "whoosh": -8.0,
	"switch_on": -6.0, "switch_off": -6.0, "power_down": -8.0, "workshop": -8.0,
	"tape": -6.0, "metal_hit": -4.0, "impact": -3.0, "breakdown": -10.0, "spark": -8.0,
	"air_leak": -6.0, "gust": -6.0, "alarm": -14.0, "shield": -8.0, "warn": -12.0,
	"blackout": -6.0, "rocket": -3.0, "touchdown": -3.0, "door": -8.0,
	"win": -8.0, "lose": -8.0,
	"rover_loop": -14.0, "repair_loop": -8.0, "build_loop": -10.0, "wipe_loop": -8.0,
	"wind_loop": -8.0, "geiger_loop": -14.0,
	"music_day": -18.0, "music_calm": -14.0,
}

var enabled := true
var streams := {}
var pool: Array = []           # players for short sounds
var pool_started: Array = []
var loops := {}                # name -> player, for the sounds that repeat
var music_player: AudioStreamPlayer
var music_old: AudioStreamPlayer
var music_name := ""
var music_tweens: Array = []
var last_played := {}          # name -> time, so one sound never plays twice in the same moment


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
		pool_started.append(0.0)
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_old = AudioStreamPlayer.new()
	add_child(music_old)


func _stream(sound: String) -> AudioStream:
	if streams.has(sound):
		return streams[sound]
	var s: AudioStream = null
	var path: String = DIR + sound + ".wav"
	if ResourceLoader.exists(path):
		s = load(path)
	streams[sound] = s
	return s


func _db(sound: String) -> float:
	return float(VOLUME.get(sound, -8.0))


func play(sound: String, pitch: float = 1.0, extra_db: float = 0.0) -> void:
	if not enabled:
		return
	var s: AudioStream = _stream(sound)
	if s == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(sound, -9.0)) < 0.06:
		return
	last_played[sound] = now
	var pick := -1
	for i in pool.size():
		if not pool[i].playing:
			pick = i
			break
	if pick < 0:
		pick = 0
		for i in pool.size():
			if float(pool_started[i]) < float(pool_started[pick]):
				pick = i
	pool_started[pick] = now
	var free_player: AudioStreamPlayer = pool[pick]
	free_player.stream = s
	free_player.volume_db = _db(sound) + extra_db
	free_player.pitch_scale = pitch
	free_player.play()


func loop(sound: String, on: bool, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = loops.get(sound)
	if on and enabled:
		if p == null:
			var s: AudioStream = _stream(sound)
			if s == null:
				return
			p = AudioStreamPlayer.new()
			p.stream = s
			p.volume_db = _db(sound)
			add_child(p)
			loops[sound] = p
		if not p.playing:
			p.pitch_scale = pitch
			p.play()
	elif p != null and p.playing:
		p.stop()


func stop_loops() -> void:
	for key in loops:
		var p: AudioStreamPlayer = loops[key]
		p.stop()


func music(sound: String) -> void:
	if sound == music_name:
		return
	music_name = sound
	for tw in music_tweens:
		if tw.is_valid():
			tw.kill()
	music_tweens.clear()
	var leaving: AudioStreamPlayer = music_player
	music_player = music_old
	music_old = leaving
	music_player.stop()
	if leaving.playing:
		var out := create_tween()
		out.tween_method(_fade.bind(leaving, leaving.volume_db), 1.0, 0.0, 1.0)
		out.tween_callback(leaving.stop)
		music_tweens.append(out)
	if sound == "" or not enabled:
		return
	var s: AudioStream = _stream(sound)
	if s == null:
		return
	music_player.stream = s
	_fade(0.0, music_player, _db(sound))
	music_player.play()
	var fade_in := create_tween()
	fade_in.tween_method(_fade.bind(music_player, _db(sound)), 0.0, 1.0, 1.0)
	music_tweens.append(fade_in)


func _fade(k: float, player: AudioStreamPlayer, full_db: float) -> void:
	player.volume_db = full_db + linear_to_db(maxf(k, 0.001))


func banner(title: String) -> void:
	# the big messages at the top of the screen each get a fitting sound
	if title.contains("WARNING"):
		play("news")
	elif title.contains("POWER OUT"):
		play("blackout")
	elif title.contains("LOW"):
		play("warn")
	elif title.contains("STORM!") or title.contains("FREEZING") or title.contains("NO FOOD") or title.contains("METEORITE") or title.contains("NO SIGNAL"):
		play("alarm")
	else:
		play("chime")
