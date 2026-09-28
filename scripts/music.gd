extends Node
## Music system (autoload `Music`). Recorded tracks by Kevin MacLeod
## (incompetech.com, CC BY 4.0, see CREDITS.md), prepared as seamless loops
## by tools/import_assets.py:
##   menu  «Dreamy Flashback»    dreamy, harp and pads
##   play  «Mesmerizing Galaxy»  124 BPM, a mysterious groove (no drums)
##   lift  «Brain Dance»         124 BPM, the driving groove of later waves
##   boss  «Cephalopod»          124 BPM, hard and dark, while the Spinneren hangs
## The three play tracks share their tempo and sit around F, so the game
## picks one (`track`) and the change waits for the next bar line: the new
## one comes in on the downbeat, in step with the old, which fades under it.
## State changes never cut the music; they crossfade and move a low-pass on
## the Music bus:
##   MENU   menu track, slightly dark
##   PLAY   a play track, open
##   PAUSE  play track held, low-passed to ~700 Hz and quieter
##   DEATH  filtered down and faded out over ~1.2 s
## While playing, the music makes room for the game: it sits a little lower
## than in the menu and is carved where the effects have their body (a dip
## around 320 Hz and 1 kHz, deeper as the pressure rises), it gives way as
## the field gets busy (by how many effects are sounding), and it ducks
## under an enemy's laugh (a compressor keyed by the Voices bus). The
## pressure no longer turns it up: the lift is the change of track. A
## closing low-pass as a target nears the line (tunnel vision), muffled in
## overload, ducked under the big accents.
## A track that has faded out stops, and starts from the top when it is
## next wanted, so every run begins on the downbeat.

enum Mode { SILENT, MENU, PLAY, PAUSE, DEATH }

const LEVEL_DB := [-80.0, -30.0, -24.0, -18.0]
const SILENT_DB := -80.0
const BPM := 124.0
const PLAY_DB := -3.5          # the play tracks, under the effects
const TRACKS := ["menu", "play", "lift", "boss"]
# Per-track gain (dB): the lift's file is held 2.9 dB under its loudness
# match by its peaks (import_assets.py); the bus has the headroom.
const TRIM := {"lift": 2.9}
# The carve (AudioEffectEQ6 bands 32, 100, 320, 1000, 3200, 10000 Hz, dB)
# at full pressure; two thirds of it at rest.
const CARVE := [0.0, 0.0, -3.0, -2.5, -1.0, 0.0]
const BUSY_DB := 2.5           # the most the field's busyness takes off

var mode := Mode.SILENT
var track := "play"            # the play track wanted (set by the game)
var intensity := 0.0           # 0..1, set by the game while playing
var overload := false          # overload: the mix goes warm and close
var flow := false              # flow: the mix opens up and lifts
var danger := 0.0              # 0..1, the closest target to the line
var finale := false            # the wave's finale: the band opens and lifts
var dark := 0.0                # blackout, 0..1: the music moves into a big dark room
var _room: AudioEffectReverb
var _eq: AudioEffectEQ6
var _dark := 0.0
var _carve := 0.0
var _duck := 0.0               # dB taken off under an accent (eases back)
var _duck_hold := 0.0
var _duck_now := 0.0           # all the ducking, smoothed: applied to the play tracks

var _bus := 0
var _lp: AudioEffectLowPassFilter
var _players := {}             # name -> AudioStreamPlayer
var _db := {}                  # name -> its fade (dB)
var _cur := "play"             # the play track sounding (or last to sound)
var _cut := 800.0
var _spec: AudioEffectSpectrumAnalyzerInstance
var _level := 0.0
var _started := false
# Headless runs (CI smoke test) have no audio output; a stream left playing
# there is still held by the dummy driver at exit and reported as a leak.
var _headless := DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus = AudioServer.bus_count
	AudioServer.add_bus(_bus)
	AudioServer.set_bus_name(_bus, "Music")
	AudioServer.set_bus_send(_bus, &"Master")
	_lp = AudioEffectLowPassFilter.new()
	_lp.cutoff_hz = 800.0
	AudioServer.add_bus_effect(_bus, _lp)
	_eq = AudioEffectEQ6.new()
	AudioServer.add_bus_effect(_bus, _eq)
	# Under a laugh: keyed by the Voices bus (its players, before its fader,
	# so the depth does not follow the volume setting). About 4 dB on
	# average through a laugh, 6-7 at its loudest, easing back between
	# the "ha"s rather than pumping (measured on the takes).
	var duck := AudioEffectCompressor.new()
	duck.sidechain = &"Voices"
	duck.threshold = -30.0
	duck.ratio = 1.3
	duck.attack_us = 2000.0
	duck.release_ms = 300.0
	AudioServer.add_bus_effect(_bus, duck)
	# A room the music is sent into when the lights go out.
	_room = AudioEffectReverb.new()
	_room.room_size = 0.9
	_room.damping = 0.6
	_room.dry = 1.0
	_room.wet = 0.0
	AudioServer.add_bus_effect(_bus, _room)
	# Read by the menu, whose light breathes with the music.
	AudioServer.add_bus_effect(_bus, AudioEffectSpectrumAnalyzer.new())
	_spec = AudioServer.get_bus_effect_instance(_bus, AudioServer.get_bus_effect_count(_bus) - 1) as AudioEffectSpectrumAnalyzerInstance
	for name: String in TRACKS:
		_players[name] = _player("res://assets/music/%s.ogg" % name)
		_db[name] = SILENT_DB
	Prefs.changed.connect(_apply_volume)
	_apply_volume()


func _player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Music"
	p.volume_db = SILENT_DB
	var s: AudioStreamOggVorbis = load(path)
	s.loop = true
	p.stream = s
	add_child(p)
	return p


func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players.values():
		p.stop()
		p.stream = null


## Called by the intro's accent: the music may begin.
func start() -> void:
	_started = true
	if mode == Mode.SILENT:
		mode = Mode.MENU


## Pull the music down `db` for `hold` seconds under a big accent.
func duck(db: float, hold := 0.5) -> void:
	_duck = maxf(_duck, db)
	_duck_hold = maxf(_duck_hold, hold)


## How loud the music is right now, 0..1 (lows and mids, smoothed: quick
## to rise, slow to fall). Zero without audio output.
func level() -> float:
	return _level


## Beats played so far on the play track sounding (124 BPM), or -1 when it
## is silent: the background's drops of light fall on the beat.
func beat() -> float:
	var p: AudioStreamPlayer = _players[_cur]
	if not p.playing or float(_db[_cur]) <= -40.0:
		return -1.0
	return p.get_playback_position() * BPM / 60.0


func set_mode(m: Mode) -> void:
	mode = m


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(_bus, LEVEL_DB[clampi(Prefs.music_volume, 0, 3)])
	AudioServer.set_bus_mute(_bus, Prefs.music_volume == 0)


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.001)
	var menu_t := SILENT_DB
	var play_t := SILENT_DB
	var cut_t := 20000.0
	var carve_t := 0.0
	if _started:
		match mode:
			Mode.MENU:
				menu_t = 0.0
				cut_t = 6500.0
			Mode.PLAY:
				play_t = PLAY_DB
				carve_t = lerpf(0.65, 1.0, intensity)
				cut_t = lerpf(20000.0, 3200.0, smoothstep(0.55, 1.0, danger))
				if finale:
					play_t += 0.5
					cut_t = maxf(cut_t, 12000.0)
				if flow:
					play_t += 1.0
					cut_t = 20000.0
				if overload:
					# Slowed time: the band goes muffled, as if heard through
					# the rush of it, so the bright note ladder rides on top.
					play_t += 1.0
					cut_t = 1400.0
			Mode.PAUSE:
				play_t = PLAY_DB - 2.0
				cut_t = 700.0
			Mode.DEATH:
				cut_t = 350.0
	_switch()
	# Ducking: under the accents (held, then eased back) and as the field
	# gets busy; quick to take, slower to give back.
	_duck_hold -= rd
	if _duck_hold <= 0.0:
		_duck = maxf(0.0, _duck - rd * 10.0)
	var busy := BUSY_DB * Sfx.busy() if mode == Mode.PLAY else 0.0
	var duck_t := maxf(_duck, busy)
	_duck_now = lerpf(_duck_now, duck_t, 1.0 - exp(-rd / (0.06 if duck_t > _duck_now else 0.45)))
	# Fades move in dB with a time constant: in quickly, out gently.
	var out_tc := 1.2 if mode == Mode.DEATH else 0.6
	for name: String in TRACKS:
		var want := menu_t if name == "menu" else (play_t if name == _cur else SILENT_DB)
		var cur: float = _db[name]
		_db[name] = _approach(cur, want, rd, 0.25 if want > cur else out_tc)
		var gain := float(TRIM.get(name, 0.0)) - (_duck_now if name != "menu" else 0.0)
		_drive(_players[name], _db[name], want, gain)
	_cut = exp(lerpf(log(_cut), log(cut_t), 1.0 - exp(-rd / 0.25)))
	_lp.cutoff_hz = _cut
	_carve = lerpf(_carve, carve_t, 1.0 - exp(-rd / 0.5))
	for i in CARVE.size():
		_eq.set_band_gain_db(i, CARVE[i] * _carve)
	_dark = lerpf(_dark, dark if mode == Mode.PLAY else 0.0, 1.0 - exp(-rd / 0.5))
	_room.wet = 0.35 * _dark
	_room.dry = 1.0 - 0.3 * _dark
	if _spec:
		var m := _spec.get_magnitude_for_frequency_range(40.0, 2000.0).length()
		var want := clampf((linear_to_db(maxf(m, 0.00001)) + 42.0) / 30.0, 0.0, 1.0)
		_level = lerpf(_level, want, 1.0 - exp(-rd / (0.06 if want > _level else 0.5)))


## Moves to the wanted play track: at once when nothing is sounding to keep
## in step with, else on the first frame past a bar line of the one
## playing, the new one started as far into its first bar as the old is
## into its bar, so the two beats line up exactly.
func _switch() -> void:
	if track == _cur or not _players.has(track):
		return
	var old: AudioStreamPlayer = _players[_cur]
	if mode != Mode.PLAY or not old.playing or float(_db[_cur]) <= -40.0:
		_cur = track
		return
	var into := fposmod(old.get_playback_position() * BPM / 60.0, 4.0)
	if into > 0.5:
		return
	_cur = track
	var p: AudioStreamPlayer = _players[_cur]
	if not _headless:
		p.volume_db = SILENT_DB
		p.play(into * 60.0 / BPM)


func _approach(cur: float, target: float, rd: float, tc: float) -> float:
	# Fade in the linear domain so the tail of a fade-out isn't abrupt.
	var a := db_to_linear(cur)
	var b := db_to_linear(target) if target > SILENT_DB else 0.0
	a = lerpf(a, b, 1.0 - exp(-rd / tc))
	return maxf(linear_to_db(a), SILENT_DB) if a > 0.0001 else SILENT_DB


func _drive(p: AudioStreamPlayer, db: float, target: float, gain: float) -> void:
	p.volume_db = db + gain if db > SILENT_DB else SILENT_DB
	if _headless:
		return
	if target > SILENT_DB and not p.playing:
		p.volume_db = SILENT_DB
		p.play(0.0)
	elif target <= SILENT_DB and db <= SILENT_DB and p.playing:
		p.stop()
