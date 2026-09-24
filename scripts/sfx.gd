extends Node
## Procedurally synthesised sounds (no audio assets) and haptics.
## Mixed to sit under the game, not on top of it: soft attacks, low-passed
## noise, per-sound gain, a gentle low-pass + compressor + small room on the
## Sfx bus, per-sound rate limits and a small voice pool.

const RATE := 22050
const POOL := 6
const MIN_GAP := 0.06           # same sound can't retrigger faster than this
const LEVEL_DB := [-80.0, -17.0, -10.0, -5.0]   # off, low, medium, high

# name: [partials [freq, amp], duration, decay, noise, glide, gain dB]
const RECIPES := {
	"release": [[[98.0, 0.6], [147.0, 0.15]], 0.24, 12.0, 0.08, -0.3, -9.0],
	"hit": [[[440.0, 0.55], [660.0, 0.12]], 0.14, 30.0, 0.04, -0.05, -9.0],
	"thud": [[[196.0, 0.6], [294.0, 0.1]], 0.16, 24.0, 0.05, -0.15, -12.0],
	"snap": [[[880.0, 0.2]], 0.07, 55.0, 0.25, -0.1, -20.0],
	"knock": [[[262.0, 0.4]], 0.08, 45.0, 0.08, -0.1, -24.0],
	"twang": [[[196.0, 0.4], [392.0, 0.12]], 0.35, 9.0, 0.0, -0.02, -27.0],
	"clank": [[[988.0, 0.25], [1480.0, 0.12], [2217.0, 0.05]], 0.18, 26.0, 0.05, 0.0, -15.0],
	"whoosh": [[[110.0, 0.1]], 0.26, 9.0, 0.45, -0.4, -24.0],
	"cut": [[[1175.0, 0.18], [587.0, 0.25]], 0.22, 18.0, 0.12, -0.2, -13.0],
	"burst": [[[523.0, 0.25], [784.0, 0.12]], 0.3, 12.0, 0.1, 0.1, -17.0],
	"breach": [[[62.0, 0.7], [93.0, 0.2]], 0.55, 6.5, 0.15, -0.25, -8.0],
	"boss": [[[98.0, 0.4], [147.0, 0.25], [185.0, 0.12]], 1.0, 3.0, 0.02, 0.0, -12.0],
	"streak": [[[659.0, 0.3], [988.0, 0.15]], 0.3, 10.0, 0.0, 0.0, -15.0],
	"reel": [[[330.0, 0.2], [495.0, 0.08]], 0.2, 14.0, 0.2, 0.35, -22.0],
	"fade": [[[740.0, 0.15], [1110.0, 0.06]], 0.35, 8.0, 0.0, -0.3, -24.0],
	"intro": [[[392.0, 0.3], [587.0, 0.18]], 0.5, 6.0, 0.0, 0.0, -15.0],
	"tick": [[[880.0, 0.3]], 0.03, 70.0, 0.0, 0.0, -22.0],
	"reload": [[[523.0, 0.18]], 0.04, 60.0, 0.0, 0.1, -26.0],
	"clear": [[[523.0, 0.35], [784.0, 0.22], [1046.0, 0.08]], 0.6, 5.0, 0.0, 0.0, -11.0],
	"lose": [[[220.0, 0.5], [330.0, 0.15]], 0.8, 3.6, 0.02, -0.4, -9.0],
}

var _streams := {}
var _gain := {}
var _last := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bus := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus = AudioServer.bus_count
	AudioServer.add_bus(_bus)
	AudioServer.set_bus_name(_bus, "Sfx")
	AudioServer.set_bus_send(_bus, &"Master")
	# Take the edge off: roll off highs, hold peaks down, a small dark room.
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 4200.0
	AudioServer.add_bus_effect(_bus, lp)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -20.0
	comp.ratio = 4.0
	comp.attack_us = 2000.0
	comp.release_ms = 180.0
	AudioServer.add_bus_effect(_bus, comp)
	var room := AudioEffectReverb.new()
	room.room_size = 0.28
	room.damping = 0.8
	room.spread = 0.5
	room.hipass = 0.2
	room.dry = 1.0
	room.wet = 0.07
	AudioServer.add_bus_effect(_bus, room)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"Sfx"
		add_child(p)
		_players.append(p)
	for name in RECIPES:
		var r: Array = RECIPES[name]
		_streams[name] = _synth(r[0], r[1], r[2], r[3], r[4])
		_gain[name] = r[5]
	apply_volume()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(_bus, LEVEL_DB[clampi(Loc.volume, 0, 3)])
	AudioServer.set_bus_mute(_bus, Loc.volume == 0)


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(name) or Loc.volume == 0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -1.0)) < MIN_GAP:
		return
	_last[name] = now
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.pitch_scale = clampf(pitch, 0.8, 1.25)
	p.volume_db = _gain[name] + minf(volume_db, 0.0)
	p.play()


## Short vibration; amplitude 0..1 (ignored on devices without amplitude control).
func haptic(ms: int, amplitude := 0.5) -> void:
	if OS.has_feature("mobile") and Loc.haptics:
		Input.vibrate_handheld(ms, amplitude * 0.8)


func _synth(partials: Array, dur: float, decay: float, noise: float, glide: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phases := PackedFloat32Array()
	phases.resize(partials.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(dur) ^ partials.size()
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		# 5 ms attack, exponential decay, 20 ms fade at the tail: no clicks.
		var env := exp(-decay * t) * minf(1.0, t * 200.0) * minf(1.0, (dur - t) * 50.0)
		var f_mul := 1.0 + glide * (t / dur)
		var s := 0.0
		for k in partials.size():
			phases[k] += TAU * partials[k][0] * f_mul / RATE
			s += sin(phases[k]) * partials[k][1]
		# Doubly low-passed noise: a soft breath, never hiss.
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.2
		lp2 += (lp - lp2) * 0.2
		s += lp2 * noise * 2.0 * exp(-decay * 2.0 * t)
		var v := clampi(int(tanh(s * env * 0.9) * 0.5 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
