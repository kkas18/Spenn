extends Node
## Music system (autoload `Music`). Two recorded tracks by Kevin MacLeod
## (incompetech.com, CC BY 4.0, see CREDITS.md), prepared as seamless loops
## by tools/import_assets.py:
##   menu  «Envision»            calm, mysterious
##   play  «Mesmerizing Galaxy»  124 BPM, driving
## State changes never cut the music; they crossfade the tracks and move a
## low-pass on the Music bus:
##   MENU   menu track, slightly dark
##   PLAY   play track, open (a touch louder as the pressure rises)
##   PAUSE  play track held, low-passed to ~700 Hz and quieter
##   DEATH  filtered down and faded out over ~1.2 s
## While playing, the mix follows the game (there are no stems, so this is
## done with level and filter): louder as the pressure rises, a closing
## low-pass as a target nears the line (tunnel vision, the heartbeat comes
## through), muffled in overload, and ducked under the big accents.
## A track that has faded out stops, and starts from the top when it is
## next wanted, so every run begins on the downbeat.

enum Mode { SILENT, MENU, PLAY, PAUSE, DEATH }

const LEVEL_DB := [-80.0, -33.0, -27.0, -21.0]
const SILENT_DB := -80.0

var mode := Mode.SILENT
var intensity := 0.0           # 0..1, set by the game while playing
var overload := false          # overload: the mix goes warm and close
var danger := 0.0              # 0..1, the closest target to the line
var _duck := 0.0               # dB taken off (eases back)
var _duck_hold := 0.0

var _bus := 0
var _lp: AudioEffectLowPassFilter
var _menu: AudioStreamPlayer
var _play: AudioStreamPlayer
var _menu_db := SILENT_DB
var _play_db := SILENT_DB
var _cut := 800.0
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
	_menu = _player("res://assets/music/menu.ogg")
	_play = _player("res://assets/music/play.ogg")
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
	for p in [_menu, _play]:
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


## 1 on the beat of the play track (124 BPM), falling off before the next;
## 0 when it is not playing. For lights that breathe with the music.
func beat_pulse() -> float:
	if mode != Mode.PLAY or _play == null or not _play.playing:
		return 0.0
	var ph := fposmod(_play.get_playback_position() * 124.0 / 60.0, 1.0)
	return exp(-ph * 5.0) * db_to_linear(_play_db)


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
	if _started:
		match mode:
			Mode.MENU:
				menu_t = 0.0
				cut_t = 6500.0
			Mode.PLAY:
				play_t = lerpf(-3.0, 0.0, intensity)
				cut_t = lerpf(20000.0, 3200.0, smoothstep(0.55, 1.0, danger))
				if overload:
					# Slowed time: the band goes muffled, as if heard through
					# the rush of it, so the bright note ladder rides on top.
					play_t += 1.0
					cut_t = 1400.0
			Mode.PAUSE:
				play_t = -5.0
				cut_t = 700.0
			Mode.DEATH:
				cut_t = 350.0
	_duck_hold -= rd
	if _duck_hold <= 0.0:
		_duck = maxf(0.0, _duck - rd * 10.0)
	if play_t > SILENT_DB:
		play_t -= _duck
	# Fades move in dB with a time constant: in quickly, out gently.
	var out_tc := 1.2 if mode == Mode.DEATH else 0.6
	_menu_db = _approach(_menu_db, menu_t, rd, 0.35 if menu_t > _menu_db else out_tc)
	_play_db = _approach(_play_db, play_t, rd, 0.25 if play_t > _play_db else out_tc)
	_cut = exp(lerpf(log(_cut), log(cut_t), 1.0 - exp(-rd / 0.25)))
	_lp.cutoff_hz = _cut
	_drive(_menu, _menu_db, menu_t)
	_drive(_play, _play_db, play_t)


func _approach(cur: float, target: float, rd: float, tc: float) -> float:
	# Fade in the linear domain so the tail of a fade-out isn't abrupt.
	var a := db_to_linear(cur)
	var b := db_to_linear(target) if target > SILENT_DB else 0.0
	a = lerpf(a, b, 1.0 - exp(-rd / tc))
	return maxf(linear_to_db(a), SILENT_DB) if a > 0.0001 else SILENT_DB


func _drive(p: AudioStreamPlayer, db: float, target: float) -> void:
	p.volume_db = db
	if _headless:
		return
	if target > SILENT_DB and not p.playing:
		p.volume_db = SILENT_DB
		p.play(0.0)
	elif target <= SILENT_DB and db <= SILENT_DB and p.playing:
		p.stop()
