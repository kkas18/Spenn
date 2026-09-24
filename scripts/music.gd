extends Node
## Music system (autoload `Music`). Two stems synthesised once on a worker
## thread and looped in lockstep: a slow pad (Dm–B♭–F–C) and a quiet pulse
## (plucked arpeggio, soft kick, faint tick). State changes never cut the
## music; they move stem volumes and a low-pass on the Music bus:
##   MENU   pad only, a little dark
##   PLAY   pad + pulse, open (pulse rises with intensity)
##   PAUSE  both, low-passed to ~700 Hz and quieter
##   DEATH  filtered down and faded out over ~1.2 s

enum Mode { SILENT, MENU, PLAY, PAUSE, DEATH }

const RATE := 16000
const BPM := 92.0
const BARS := 8
const LEVEL_DB := [-80.0, -24.0, -17.0, -12.0]

var mode := Mode.SILENT
var intensity := 0.0           # 0..1, set by the game while playing

var _bus := 0
var _lp: AudioEffectLowPassFilter
var _pad: AudioStreamPlayer
var _pulse: AudioStreamPlayer
var _ready_streams := false
var _want_start := false
var _pad_db := -80.0
var _pulse_db := -80.0
var _cut := 800.0
var _gain_db := -80.0
var _task := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus = AudioServer.bus_count
	AudioServer.add_bus(_bus)
	AudioServer.set_bus_name(_bus, "Music")
	AudioServer.set_bus_send(_bus, &"Master")
	_lp = AudioEffectLowPassFilter.new()
	_lp.cutoff_hz = 800.0
	AudioServer.add_bus_effect(_bus, _lp)
	_pad = AudioStreamPlayer.new()
	_pulse = AudioStreamPlayer.new()
	for p in [_pad, _pulse]:
		p.bus = &"Music"
		p.volume_db = -80.0
		add_child(p)
	Prefs.changed.connect(_apply_volume)
	_apply_volume()
	_task = WorkerThreadPool.add_task(_build, false, "music")


func _exit_tree() -> void:
	# Never leave the synthesis thread running past shutdown.
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for p in [_pad, _pulse]:
		p.stop()
		p.stream = null


## Called by the intro's accent: start the loop (once the stems are ready).
func start() -> void:
	_want_start = true
	if mode == Mode.SILENT:
		mode = Mode.MENU
	_try_start()


func set_mode(m: Mode) -> void:
	mode = m


func _try_start() -> void:
	if _want_start and _ready_streams and not _pad.playing:
		_pad.play()
		_pulse.play()


func _apply_volume() -> void:
	AudioServer.set_bus_mute(_bus, Prefs.music_volume == 0)


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.001)
	var pad_t := -80.0
	var pulse_t := -80.0
	var cut_t := 18000.0
	match mode:
		Mode.MENU:
			pad_t = 0.0
			cut_t = 5000.0
		Mode.PLAY:
			pad_t = -1.5
			pulse_t = lerpf(-9.0, -2.0, intensity)
			cut_t = 18000.0
		Mode.PAUSE:
			pad_t = -3.0
			pulse_t = -10.0
			cut_t = 700.0
		Mode.DEATH:
			cut_t = 350.0
	# Smooth, time-based moves: fades never click, filters sweep.
	var fade := 1.0 - exp(-rd / (1.2 if mode == Mode.DEATH else 0.35))
	_pad_db = lerpf(_pad_db, pad_t, fade)
	_pulse_db = lerpf(_pulse_db, pulse_t, fade)
	_cut = exp(lerpf(log(_cut), log(cut_t), 1.0 - exp(-rd / 0.25)))
	_lp.cutoff_hz = _cut
	_pad.volume_db = _pad_db
	_pulse.volume_db = _pulse_db
	var g: float = LEVEL_DB[clampi(Prefs.music_volume, 0, 3)]
	_gain_db = g
	AudioServer.set_bus_volume_db(_bus, g)


# ---------------------------------------------------------------- synthesis
# Runs on a worker thread: pure computation, results handed back deferred.

func _build() -> void:
	var beat := 60.0 / BPM
	var n := int(beat * 4.0 * BARS * RATE)
	var pad := PackedFloat32Array()
	pad.resize(n)
	var pulse := PackedFloat32Array()
	pulse.resize(n)
	var chords := [[146.83, 174.61, 220.0], [116.54, 146.83, 174.61], [174.61, 220.0, 261.63], [130.81, 164.81, 196.0]]
	var seg := n / chords.size()
	# Pad: detuned sine pairs per chord tone, soft attack and release, a slow
	# breathing tremolo and a one-pole low-pass.
	var lp := 0.0
	for ci in chords.size():
		var notes: Array = chords[ci]
		var ph := PackedFloat32Array()
		ph.resize(6)
		var inc := PackedFloat32Array()
		inc.resize(6)
		for k in 3:
			inc[k * 2] = TAU * notes[k] * 0.997 / RATE
			inc[k * 2 + 1] = TAU * notes[k] * 1.003 / RATE
		var start := ci * seg
		for i in seg:
			var t := float(i) / RATE
			var env := minf(1.0, t / 0.9) * minf(1.0, (float(seg - i) / RATE) / 0.7)
			var s := 0.0
			for k in 6:
				ph[k] += inc[k]
				s += sin(ph[k])
			var trem := 0.85 + 0.15 * sin(TAU * 0.2 * float(start + i) / RATE)
			lp += (s * env * trem - lp) * 0.08
			pad[start + i] = lp * 0.06
	# Pulse: eighth-note plucks up the chord, a soft kick on 1 and 3 and a
	# faint off-beat tick. Written as events, wrapped for a seamless loop.
	var eighth := beat * 0.5
	var steps := int(4.0 * BARS * 2.0)
	var arp := [0, 1, 2, 1, 0, 2, 1, 2]
	for sidx in steps:
		var at := int(sidx * eighth * RATE)
		var ci2: int = mini(at / seg, chords.size() - 1)
		var f: float = chords[ci2][arp[sidx % 8]] * 2.0
		_note(pulse, at, f, 0.28, 11.0, 0.05)
		if sidx % 4 == 0:
			_kick(pulse, at)
		elif sidx % 2 == 1:
			_tick(pulse, at, sidx)
	call_deferred("_on_built", _to_wav(pad), _to_wav(pulse))


func _note(buf: PackedFloat32Array, at: int, f: float, dur: float, decay: float, amp: float) -> void:
	var n := buf.size()
	var len := int(dur * RATE)
	var ph := 0.0
	var inc := TAU * f / RATE
	for i in len:
		var t := float(i) / RATE
		ph += inc
		var env := exp(-decay * t) * minf(1.0, t * 300.0)
		buf[(at + i) % n] += (sin(ph) + 0.25 * sin(ph * 2.0)) * env * amp


func _kick(buf: PackedFloat32Array, at: int) -> void:
	var n := buf.size()
	var ph := 0.0
	for i in int(0.25 * RATE):
		var t := float(i) / RATE
		ph += TAU * lerpf(90.0, 48.0, minf(1.0, t / 0.08)) / RATE
		buf[(at + i) % n] += sin(ph) * exp(-t * 14.0) * minf(1.0, t * 400.0) * 0.12


func _tick(buf: PackedFloat32Array, at: int, seed: int) -> void:
	var n := buf.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lp := 0.0
	var prev := 0.0
	for i in int(0.04 * RATE):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.5
		var hp := lp - prev
		prev = lp
		buf[(at + i) % n] += hp * exp(-t * 90.0) * 0.02


func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, clampi(int(tanh(buf[i]) * 32000.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w


func _on_built(pad: AudioStreamWAV, pulse: AudioStreamWAV) -> void:
	_pad.stream = pad
	_pulse.stream = pulse
	_ready_streams = true
	_try_start()
