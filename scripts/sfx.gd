extends Node
## Procedurally synthesised sounds (no audio assets) and haptics.
## Streams are generated once at startup; playback uses a fixed player pool.

const RATE := 22050
const POOL := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_players.append(p)
	# name: [partials(freq, amp), duration, decay, noise, pitch glide]
	_streams["release"] = _synth([[98.0, 0.7], [196.0, 0.25]], 0.28, 11.0, 0.18, -0.35)
	_streams["hit"] = _synth([[587.0, 0.55], [1174.0, 0.2], [1760.0, 0.08]], 0.16, 26.0, 0.10, 0.0)
	_streams["thud"] = _synth([[196.0, 0.7], [392.0, 0.15]], 0.18, 20.0, 0.12, -0.2)
	_streams["snap"] = _synth([[1320.0, 0.25]], 0.09, 45.0, 0.65, 0.0)
	_streams["tick"] = _synth([[880.0, 0.4]], 0.04, 60.0, 0.0, 0.0)
	_streams["reload"] = _synth([[440.0, 0.25]], 0.05, 50.0, 0.05, 0.1)
	_streams["clear"] = _synth([[523.0, 0.4], [784.0, 0.35], [1046.0, 0.12]], 0.7, 4.5, 0.0, 0.0)
	_streams["lose"] = _synth([[220.0, 0.55], [330.0, 0.2]], 0.9, 3.2, 0.05, -0.45)


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Short vibration; amplitude 0..1 (ignored on devices without amplitude control).
func haptic(ms: int, amplitude := 0.5) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)


func _synth(partials: Array, dur: float, decay: float, noise: float, glide: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phases := PackedFloat32Array()
	phases.resize(partials.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(dur) ^ partials.size()
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-decay * t) * minf(1.0, t * 400.0)
		var f_mul := 1.0 + glide * (t / dur)
		var s := 0.0
		for k in partials.size():
			phases[k] += TAU * partials[k][0] * f_mul / RATE
			s += sin(phases[k]) * partials[k][1]
		# Low-passed noise gives a soft, matte transient rather than hiss.
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		s += lp * noise * exp(-decay * 2.5 * t)
		var v := clampi(int(s * env * 0.6 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
