extends Node
## Sound effects (autoload `Sfx`) and haptics.
## Recorded sounds from the Kenney packs (CC0, see CREDITS.md), prepared by
## tools/import_assets.py: trimmed, faded and matched to one loudness, so the
## gains below are the mix. Each sound has several takes; a play picks one
## that differs from the last, with a small random pitch drift, so repeats
## never sound mechanical. A light high-shelf roll-off, a compressor and a
## small dark room on the Sfx bus glue everything together.

const POOL := 14
const MIN_GAP := 0.05           # same sound can't retrigger faster than this
const LEVEL_DB := [-80.0, -19.0, -13.0, -8.0]   # off, low, medium, high
const DIR := "res://assets/sfx/"

# name: [gain dB, pitch drift (±), takes]
const MIX := {
	# play field: frequent, kept low
	"release": [-11.0, 0.03, 2],
	"hit": [-9.0, 0.05, 5],
	"thud": [-11.0, 0.05, 5],
	"knock": [-17.0, 0.06, 5],
	"snap": [-15.0, 0.06, 5],
	"twang": [-19.0, 0.04, 2],
	"clank": [-11.0, 0.04, 5],
	"cut": [-9.0, 0.04, 2],
	"burst": [-10.0, 0.05, 5],
	"whoosh": [-19.0, 0.06, 3],
	"reel": [-18.0, 0.04, 3],
	"fade": [-16.0, 0.04, 3],
	"token": [-22.0, 0.05, 2],
	"tick": [-18.0, 0.0, 1],
	"reload": [-18.0, 0.04, 1],
	"beat": [-13.0, 0.0, 5],
	# accents: rarer, allowed to speak
	"breach": [-8.0, 0.04, 5],
	"death": [-7.0, 0.0, 5],
	"streak": [-13.0, 0.0, 3],
	"boss": [-11.0, 0.0, 1],
	"intro": [-11.0, 0.0, 1],
	"clear": [-11.0, 0.0, 1],
	"record": [-8.0, 0.0, 1],
	"lose": [-10.0, 0.0, 1],
	"reveal": [-10.0, 0.0, 1],
	# interface
	"click": [-15.0, 0.03, 4],
	"panel": [-17.0, 0.03, 3],
	"pause": [-13.0, 0.0, 1],
	"resume": [-13.0, 0.0, 1],
	"countdown": [-11.0, 0.0, 1],
	"count": [-22.0, 0.0, 2],
	"restart": [-13.0, 0.0, 1],
	"deny": [-13.0, 0.0, 1],
	# enemy evasion (Kenney RPG Audio)
	"slide": [-21.0, 0.06, 3],
	"creak": [-20.0, 0.05, 3],
	# an enemy mocking a near miss (kept rare and quiet)
	"tease": [-19.0, 0.0, 3],
	# materials: jelly (freesound CC0) and rigid shells (Kenney)
	"squish": [-11.0, 0.06, 5],
	"splat": [-10.0, 0.05, 3],
	"wood": [-12.0, 0.05, 5],
	"metal": [-12.0, 0.05, 5],
	# overload: a chord swelling in, and falling away (made by the import tool)
	"rise": [-10.0, 0.0, 1],
	"fall": [-13.0, 0.0, 1],
}

# Tuned tines, one per step of the ladder the kills climb (C D Eb G over
# the octaves, the play track's key). Played at their own pitch, no drift.
const NOTE_COUNT := 9
const NOTE_DB := -14.0

var _takes := {}
var _notes: Array[AudioStream] = []
var _last := {}
var _last_take := {}
var _players: Array[AudioStreamPlayer] = []
var _started: Array[float] = []
var _bus := 0
var _rng := RandomNumberGenerator.new()
# Headless runs (CI smoke test) have no audio output; a sound still playing
# at exit is held by the dummy driver and reported as a leak.
var _headless := DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_bus = AudioServer.bus_count
	AudioServer.add_bus(_bus)
	AudioServer.set_bus_name(_bus, "Sfx")
	AudioServer.set_bus_send(_bus, &"Master")
	# Glue: take the sharpest air off, hold peaks, a small dark room.
	var shelf := AudioEffectHighShelfFilter.new()
	shelf.cutoff_hz = 7000.0
	shelf.gain = 0.6
	AudioServer.add_bus_effect(_bus, shelf)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -22.0
	comp.ratio = 3.5
	comp.attack_us = 3000.0
	comp.release_ms = 160.0
	AudioServer.add_bus_effect(_bus, comp)
	var room := AudioEffectReverb.new()
	room.room_size = 0.3
	room.damping = 0.75
	room.spread = 0.6
	room.hipass = 0.25
	room.dry = 1.0
	room.wet = 0.08
	AudioServer.add_bus_effect(_bus, room)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(_bus, lim)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"Sfx"
		add_child(p)
		_players.append(p)
		_started.append(-1.0)
	for name: String in MIX:
		var list: Array[AudioStream] = []
		for i: int in MIX[name][2]:
			var path := "%s%s_%d.ogg" % [DIR, name, i]
			if ResourceLoader.exists(path):
				list.append(load(path))
		if list.is_empty():
			push_warning("Sfx: no takes for %s" % name)
		else:
			_takes[name] = list
	for i in NOTE_COUNT:
		_notes.append(load("%snote_%d.ogg" % [DIR, i]))
	apply_volume()
	Prefs.changed.connect(apply_volume)


func _exit_tree() -> void:
	for p in _players:
		p.stop()
		p.stream = null
	_takes.clear()
	_notes.clear()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(_bus, LEVEL_DB[clampi(Prefs.sfx_volume, 0, 3)])
	AudioServer.set_bus_mute(_bus, Prefs.sfx_volume == 0)


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if _headless or not _takes.has(name) or Prefs.sfx_volume == 0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -1.0)) < MIN_GAP:
		return
	_last[name] = now
	var list: Array = _takes[name]
	var take := _rng.randi() % list.size()
	if list.size() > 1 and take == int(_last_take.get(name, -1)):
		take = (take + 1) % list.size()
	_last_take[name] = take
	var mix: Array = MIX[name]
	var drift: float = mix[1]
	var p := _players[_voice()]
	p.stream = list[take]
	p.pitch_scale = clampf(pitch * (1.0 + _rng.randf_range(-drift, drift)), 0.7, 1.35)
	p.volume_db = float(mix[0]) + minf(volume_db, 0.0)
	p.play()
	_started[_players.find(p)] = now


## Step `i` of the note ladder (clamped; steps past the top wrap to its
## last octave so long runs keep climbing within reach).
func note(i: int, volume_db := 0.0) -> void:
	if _headless or Prefs.sfx_volume == 0 or _notes.is_empty():
		return
	if i >= NOTE_COUNT:
		i = NOTE_COUNT - 4 + (i - NOTE_COUNT) % 4
	var p := _players[_voice()]
	p.stream = _notes[maxi(i, 0)]
	p.pitch_scale = 1.0
	p.volume_db = NOTE_DB + minf(volume_db, 0.0)
	p.play()
	_started[_players.find(p)] = Time.get_ticks_msec() / 1000.0


## A short run of ladder steps, `gap` seconds apart (real time): the
## signature of a skill shot.
func phrase(steps: Array, gap := 0.07, volume_db := 0.0) -> void:
	for k in steps.size():
		var i: int = steps[k]
		if k == 0:
			note(i, volume_db)
		else:
			Motion.after(gap * k, func() -> void: note(i, volume_db - 1.5 * k))


## A free voice, or the one that has played the longest.
func _voice() -> int:
	var oldest := 0
	for i in POOL:
		if not _players[i].playing:
			return i
		if _started[i] < _started[oldest]:
			oldest = i
	return oldest


## Short vibration; amplitude 0..1 (ignored on devices without amplitude control).
func haptic(ms: int, amplitude := 0.5) -> void:
	if OS.has_feature("mobile") and Prefs.haptics:
		Input.vibrate_handheld(ms, amplitude * 0.8)


## Named haptic vocabulary, used consistently across the game:
## light (buttons), soft (pause/resume), impact (death), record (two
## rising pulses), error (two quick low ticks).
func haptic_pattern(name: String) -> void:
	match name:
		"light":
			haptic(6, 0.2)
		"soft":
			haptic(12, 0.3)
		"impact":
			haptic(70, 0.9)
		"record":
			haptic(20, 0.5)
			Motion.after(0.12, func() -> void: haptic(45, 0.85))
		"error":
			haptic(8, 0.3)
			Motion.after(0.07, func() -> void: haptic(8, 0.3))
