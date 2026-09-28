extends Node
## Central motion system (autoload `Motion`). One set of durations and
## easing profiles for the whole game, and a small animation driver that
## runs in real time: UI keeps moving at its own pace during hit-stop, slow
## motion and pause. Honours the reduced-motion preference.

const FAST := 0.12
const NORMAL := 0.22
const SLOW := 0.4
const CINEMATIC := 0.7
const STAGGER := 0.08

enum Ease { STANDARD, ENTER, EXIT, EMPHASIZED, LINEAR }

var _tracks: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Duration adjusted for reduced motion.
static func dur(d: float) -> float:
	return d * (0.6 if Prefs.reduced_motion else 1.0)


static func ease_value(e: Ease, t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	match e:
		Ease.ENTER:
			return 1.0 - pow(1.0 - t, 3.0)
		Ease.EXIT:
			return t * t * t
		Ease.EMPHASIZED:
			# Back-out with a small overshoot (~4%).
			var s := 1.2
			var u := t - 1.0
			return 1.0 + (s + 1.0) * u * u * u + s * u * u
		Ease.LINEAR:
			return t
	# STANDARD: cubic in-out
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5


## Animates `obj.path` (supports sub-paths like "modulate:a") to `to`.
## Returns the track; set `track.done` to a Callable for a callback.
func to(obj: Object, path: String, value: Variant, d: float, e := Ease.STANDARD, delay := 0.0) -> Dictionary:
	cancel(obj, path)
	var tr := {"obj": obj, "path": path, "from": _read(obj, path), "to": value,
		"t": 0.0, "d": maxf(dur(d), 0.001), "delay": delay, "ease": e, "done": Callable()}
	_tracks.append(tr)
	return tr


## Calls `cb` after `delay` seconds of real time.
func after(delay: float, cb: Callable) -> void:
	_tracks.append({"obj": self, "path": "", "from": 0, "to": 0, "t": 0.0, "d": 0.001,
		"delay": delay, "ease": Ease.LINEAR, "done": cb})


func cancel(obj: Object, path := "") -> void:
	for i in range(_tracks.size() - 1, -1, -1):
		var tr: Dictionary = _tracks[i]
		if tr.obj == obj and (path == "" or tr.path == path):
			_tracks.remove_at(i)


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.001)
	var i := 0
	while i < _tracks.size():
		var tr: Dictionary = _tracks[i]
		if not is_instance_valid(tr.obj):
			_tracks.remove_at(i)
			continue
		if tr.delay > 0.0:
			tr.delay -= rd
			if tr.delay <= 0.0 and tr.path != "":
				tr.from = _read(tr.obj, tr.path)
			i += 1
			continue
		tr.t += rd
		var k := ease_value(tr.ease, tr.t / tr.d)
		if tr.path != "":
			_write(tr.obj, tr.path, _mix(tr.from, tr.to, k))
		if tr.t >= tr.d:
			_tracks.remove_at(i)
			if tr.done.is_valid():
				tr.done.call()
			continue
		i += 1


## "modulate:a" style paths use indexed access; plain (and slash-named
## resource) properties like "shader_parameter/amount" use get/set.
static func _read(obj: Object, path: String) -> Variant:
	return obj.get_indexed(NodePath(path)) if path.contains(":") else obj.get(path)


static func _write(obj: Object, path: String, v: Variant) -> void:
	if path.contains(":"):
		obj.set_indexed(NodePath(path), v)
	else:
		obj.set(path, v)


static func _mix(a: Variant, b: Variant, k: float) -> Variant:
	if a is float or a is int:
		return lerpf(float(a), float(b), k)
	return a.lerp(b, k)
