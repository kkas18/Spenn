extends Node
## Music system (autoload `Music`). One recorded track by Kevin MacLeod
## (incompetech.com, CC BY 4.0, see CREDITS.md), prepared as a seamless
## loop by tools/import_assets.py:
##   menu  «Dreamy Flashback»    dreamy, harp and pads
## The menu has music; the game itself has none. The field speaks through
## its effects alone, and the waves are set apart by their own sounds (a
## cadence when one is cleared, a swell into the next, see Game._clear_wave).
## State changes never cut the music; they fade it and move a low-pass on
## the Music bus:
##   MENU   menu track, slightly dark
##   PLAY   silent: the menu track closes down and fades out as a run begins
##   PAUSE  silent
##   DEATH  silent
## A track that has faded out stops, and starts from the top when it is
## next wanted.

enum Mode { SILENT, MENU, PLAY, PAUSE, DEATH }

const LEVEL_DB := [-80.0, -30.0, -24.0, -18.0]
const SILENT_DB := -80.0
const FADE_IN := 0.35           # s (time constant) as the menu comes up
const FADE_OUT := 0.9           # ... and as it gives way to a run

var mode := Mode.SILENT

var _bus := 0
var _lp: AudioEffectLowPassFilter
var _menu: AudioStreamPlayer
var _menu_db := SILENT_DB
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
	# Read by the menu, whose light breathes with the music.
	AudioServer.add_bus_effect(_bus, AudioEffectSpectrumAnalyzer.new())
	_spec = AudioServer.get_bus_effect_instance(_bus, 1) as AudioEffectSpectrumAnalyzerInstance
	_menu = AudioStreamPlayer.new()
	_menu.bus = &"Music"
	_menu.volume_db = SILENT_DB
	var s: AudioStreamOggVorbis = load("res://assets/music/menu.ogg")
	s.loop = true
	_menu.stream = s
	add_child(_menu)
	Prefs.changed.connect(_apply_volume)
	_apply_volume()


func _exit_tree() -> void:
	_menu.stop()
	_menu.stream = null


## Called by the intro's accent: the music may begin.
func start() -> void:
	_started = true
	if mode == Mode.SILENT:
		mode = Mode.MENU


## How loud the music is right now, 0..1 (lows and mids, smoothed: quick
## to rise, slow to fall). Zero without audio output.
func level() -> float:
	return _level


## Beats of a playing track to keep time with, or -1. No music plays under
## the game, so there is none: what used to fall on its beat (the drops of
## light, the pulses) keeps its own unhurried pace.
func beat() -> float:
	return -1.0


func set_mode(m: Mode) -> void:
	mode = m


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(_bus, LEVEL_DB[clampi(Prefs.music_volume, 0, 3)])
	AudioServer.set_bus_mute(_bus, Prefs.music_volume == 0)


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.001)
	var want := SILENT_DB
	if _started and mode == Mode.MENU:
		want = 0.0
	# Fades move in dB with a time constant, in the linear domain so the
	# tail of a fade-out isn't abrupt.
	var a := db_to_linear(_menu_db)
	var b := db_to_linear(want) if want > SILENT_DB else 0.0
	a = lerpf(a, b, 1.0 - exp(-rd / (FADE_IN if b > a else FADE_OUT)))
	_menu_db = maxf(linear_to_db(a), SILENT_DB) if a > 0.0001 else SILENT_DB
	# The menu sits slightly dark; leaving it, the music closes down as it
	# fades, so it recedes rather than just getting quieter.
	var cut_t := 6500.0 if want > SILENT_DB else 900.0
	_cut = exp(lerpf(log(_cut), log(cut_t), 1.0 - exp(-rd / 0.4)))
	_lp.cutoff_hz = _cut
	_menu.volume_db = _menu_db
	if not _headless:
		if want > SILENT_DB and not _menu.playing:
			_menu.volume_db = SILENT_DB
			_menu.play(0.0)
		elif want <= SILENT_DB and _menu_db <= SILENT_DB and _menu.playing:
			_menu.stop()
	if _spec:
		var m := _spec.get_magnitude_for_frequency_range(40.0, 2000.0).length()
		var lv := clampf((linear_to_db(maxf(m, 0.00001)) + 42.0) / 30.0, 0.0, 1.0)
		_level = lerpf(_level, lv, 1.0 - exp(-rd / (0.06 if lv > _level else 0.5)))
