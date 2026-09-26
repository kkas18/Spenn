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
const LEVEL_DB := [-80.0, -24.0, -18.0, -13.0]  # off, low, medium, high
const STRINGS_DB := -4.0        # the strings sit under the effects
# The mix keeps the music in front of the busy middle of the field:
# - each sound may retrigger only so often (GAP, else MIN_GAP);
# - the small field sounds (LOW) give way when many are already sounding:
#   past DENSE of them in the last DENSITY_WIN s each new one is quieter,
#   and past DENSE * 2 it is dropped. Accents always play.
const GAP := {
	"token": 0.14, "tick": 0.08, "deny": 0.4, "slide": 0.3, "creak": 0.3,
	"knock": 0.07, "snap": 0.08, "wood": 0.07, "metal": 0.07, "squish": 0.07,
	"splat": 0.09, "clank": 0.08, "whoosh": 0.12, "twang": 0.1, "reel": 0.2,
	"fade": 0.15, "tease": 0.6, "count": 0.06,
}
const LOW := ["token", "tick", "knock", "snap", "wood", "metal", "squish", "splat", "clank",
	"whoosh", "twang", "slide", "creak", "reel", "fade", "reload", "release", "tease", "deny"]
const DENSITY_WIN := 0.4
const DENSE := 5
const VOICE_MIN_GAP := 0.25
const HARP_GAP := 0.11
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
	"slide": [-26.0, 0.06, 3],
	"creak": [-24.0, 0.05, 3],
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
	# creature voices (made by the import tool), pitched onto the key
	"voice_up": [-17.0, 0.0, 1],
	"voice_taunt": [-18.0, 0.0, 1],
	"voice_down": [-16.0, 0.0, 1],
}

# Voices sing on the notes of the key (C minor: C D Eb G, and the octave).
const VOICE_STEPS := [1.0, 1.1225, 1.1892, 1.4983, 2.0]

# Tuned tines, one per step of the ladder the kills climb (C D Eb G over
# the octaves, the play track's key). Played at their own pitch, no drift.
const NOTE_COUNT := 9
const NOTE_DB := -17.0

# Strings: the background fibres are a harp and the top bar's tension
# string a low steel string (plucked-string samples, tools/import_assets.py),
# on their own bus with a longer room so they sit behind the action.
const HARP_COUNT := 11          # C minor pentatonic, C4..C6
const HARP_POOL := 6
const HARP_DB := -13.0
const TAUT_STEPS := [0, 3, 5, 7, 10, 12]   # the string's tuning as it tightens
const BPM := 124.0
var _harp: Array[AudioStream] = []
var _taut: Array[AudioStream] = []
var _hplayers: Array[AudioStreamPlayer] = []
var _hnext := 0
var _hbus := 0
var _recent: Array[float] = []   # when the last sounds started (the density window)
var _harp_last := -1.0
var _note_last := -1.0
var _takes := {}
var _notes: Array[AudioStream] = []
var _voice_last := -1.0
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
	# Room for the music: cut the lows (the track's bass and kick live
	# there), soften the grating top, then glue the bursts together so a
	# busy moment gets denser, not louder; a small dark room.
	var low := AudioEffectHighPassFilter.new()
	low.cutoff_hz = 140.0
	AudioServer.add_bus_effect(_bus, low)
	var shelf := AudioEffectHighShelfFilter.new()
	shelf.cutoff_hz = 5000.0
	shelf.gain = 0.45
	AudioServer.add_bus_effect(_bus, shelf)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -30.0
	comp.ratio = 4.0
	comp.attack_us = 2000.0
	comp.release_ms = 150.0
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
	_hbus = AudioServer.bus_count
	AudioServer.add_bus(_hbus)
	AudioServer.set_bus_name(_hbus, "Strings")
	AudioServer.set_bus_send(_hbus, &"Master")
	var hall := AudioEffectReverb.new()
	hall.room_size = 0.78
	hall.damping = 0.45
	hall.spread = 0.9
	hall.hipass = 0.2
	hall.dry = 0.85
	hall.wet = 0.32
	AudioServer.add_bus_effect(_hbus, hall)
	for i in HARP_COUNT:
		_harp.append(load("%sharp_%d.ogg" % [DIR, i]))
	for i in 2:
		_taut.append(load("%staut_%d.ogg" % [DIR, i]))
	for i in HARP_POOL:
		var hp := AudioStreamPlayer.new()
		hp.bus = &"Strings"
		add_child(hp)
		_hplayers.append(hp)
	apply_volume()
	Prefs.changed.connect(apply_volume)


func _exit_tree() -> void:
	for p in _players:
		p.stop()
		p.stream = null
	for p in _hplayers:
		p.stop()
		p.stream = null
	_takes.clear()
	_notes.clear()
	_harp.clear()
	_taut.clear()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(_bus, LEVEL_DB[clampi(Prefs.sfx_volume, 0, 3)])
	AudioServer.set_bus_mute(_bus, Prefs.sfx_volume == 0)
	if _hbus > 0:
		AudioServer.set_bus_volume_db(_hbus, LEVEL_DB[clampi(Prefs.sfx_volume, 0, 3)] + STRINGS_DB)
		AudioServer.set_bus_mute(_hbus, Prefs.sfx_volume == 0)


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if _headless or not _takes.has(name) or Prefs.sfx_volume == 0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -1.0)) < float(GAP.get(name, MIN_GAP)):
		return
	# Density: the small field sounds make way when the field is busy.
	while not _recent.is_empty() and now - _recent[0] > DENSITY_WIN:
		_recent.pop_front()
	var over := _recent.size() - DENSE
	var low := LOW.has(name)
	if low and over >= DENSE:
		return
	if low and over > 0:
		volume_db -= 1.5 * over
	_recent.append(now)
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
func note(i: int, volume_db := 0.0, pitch := 1.0) -> void:
	if _headless or Prefs.sfx_volume == 0 or _notes.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _note_last < 0.06:
		return
	_note_last = now
	if i >= NOTE_COUNT:
		i = NOTE_COUNT - 4 + (i - NOTE_COUNT) % 4
	var p := _players[_voice()]
	p.stream = _notes[maxi(i, 0)]
	p.pitch_scale = pitch
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


## How long until the next sixteenth of the play track (s), or 0 when it
## is not playing: string notes land on the music's grid.
func to_grid() -> float:
	var b := Music.beat()
	if b < 0.0:
		return 0.0
	var next := (floorf(b * 4.0) + 1.0) / 4.0
	var wait := (next - b) * 60.0 / BPM
	return wait if wait > 0.025 else 0.0


func _string(stream: AudioStream, pitch: float, volume_db: float) -> void:
	if _headless or Prefs.sfx_volume == 0 or stream == null:
		return
	var p := _hplayers[_hnext]
	_hnext = (_hnext + 1) % HARP_POOL
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## A harp string: step `i` of the pentatonic (clamped), on the grid.
func harp(i: int, volume_db := 0.0, on_grid := true) -> void:
	if _harp.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if on_grid and now - _harp_last < HARP_GAP:
		return
	_harp_last = now
	var st := _harp[clampi(i, 0, HARP_COUNT - 1)]
	var db := HARP_DB + minf(volume_db, 0.0)
	var wait := to_grid() if on_grid else 0.0
	if wait <= 0.0:
		_string(st, 1.0, db)
	else:
		get_tree().create_timer(wait, true, false, true).timeout.connect(func() -> void: _string(st, 1.0, db))


## Several harp strings swept in turn: a strum (or a run), starting on
## the grid.
func strum(steps: Array, gap := 0.045, volume_db := 0.0) -> void:
	var wait := to_grid()
	for k in steps.size():
		var i: int = steps[k]
		var d := wait + gap * k
		var db := volume_db - 1.0 * k
		if d <= 0.0:
			harp(i, db, false)
		else:
			get_tree().create_timer(d, true, false, true).timeout.connect(func() -> void: harp(i, db, false))


## The tension string, plucked: tuned up the scale as it tightens (`tight`
## 0..1 is the wave's progress), so a wave climbs an octave as it fills.
func taut(tight: float, volume_db := 0.0) -> void:
	if _taut.is_empty():
		return
	var step: int = TAUT_STEPS[clampi(int(round(clampf(tight, 0.0, 1.0) * (TAUT_STEPS.size() - 1))), 0, TAUT_STEPS.size() - 1)]
	_string(_taut[_rng.randi() % _taut.size()], pow(2.0, step / 12.0), -11.0 + minf(volume_db, 0.0))


## A creature's syllable: `shape` is up (startle), taunt or down (death);
## `register` sets the octave by size (0.5 big and low .. 2 small and high),
## and the note is a step of the key, so a crowd of them stays in tune.
func voice(shape: String, register: float, step: int, volume_db := 0.0) -> void:
	var name := "voice_" + shape
	if _headless or not _takes.has(name) or Prefs.sfx_volume == 0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _voice_last < VOICE_MIN_GAP:
		return
	_voice_last = now
	var p := _players[_voice()]
	p.stream = _takes[name][0]
	p.pitch_scale = clampf(register * VOICE_STEPS[posmod(step, VOICE_STEPS.size())], 0.3, 3.0)
	p.volume_db = float(MIX[name][0]) + minf(volume_db, 0.0)
	p.play()
	_started[_players.find(p)] = now


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
