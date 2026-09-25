class_name Rail
extends Node2D
## The top beam: 6 px, two tones, shadow down/right, with a hook at every
## hanging string. Hooks tip as their string swings. A gold inlay along its
## face is the overload meter: it fills out from the middle as the tension
## builds, throbs when nearly full and blazes while overload lasts.

var l: Layout
var targets: Array[Target] = []
var _flex_x := 0.0
var _flex_amp := 0.0
var _flex_t := 10.0
var _line := PackedVector2Array()
var _inlay := PackedVector2Array()
var charge := 0.0              # 0..1, set by the game
var hot := false               # overload running
var _shown := 0.0
var _clock := 0.0


func setup(layout: Layout, list: Array[Target]) -> void:
	l = layout
	targets = list


## A breach yanks the beam: a local dip that rings out like a struck bar.
func flex(x: float, amp: float) -> void:
	_flex_x = x
	_flex_amp = amp
	_flex_t = 0.0


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.001)
	_flex_t += delta
	_clock += rd
	_shown = lerpf(_shown, charge, Pal.damp(0.12, rd)) if absf(charge - _shown) > 0.001 else charge
	queue_redraw()


func offset_at(x: float) -> float:
	if _flex_amp <= 0.0:
		return 0.0
	var env := exp(-_flex_t * 5.0) * cos(_flex_t * 34.0)
	var spread := exp(-pow((x - _flex_x) / 150.0, 2.0))
	return _flex_amp * env * spread


func _draw() -> void:
	if l == null:
		return
	# A steel beam: soft cast shadow below, dark lower lip, body, lit top
	# edge (light from the upper left) and a row of rivets. At rest it is a
	# handful of plain rects, which the renderer batches into one call; only
	# while a breach flexes it does it follow the dip as polylines.
	var y := l.rail_y - 6.0
	var w := l.size.x
	# Drawn past both edges so tilt parallax never shows the beam's ends.
	var x0 := -32.0
	var ww := w + 64.0
	if _flex_amp > 0.0 and _flex_t < 1.2:
		_line.clear()
		for i in 33:
			var x := w * i / 32.0
			_line.append(Vector2(x, y + offset_at(x)))
		for k in 4:
			draw_set_transform(Vector2(0, 12.0 + k * 4.0))
			draw_polyline(_line, Color(0, 0, 0, 0.16 - k * 0.035), 5.0)
		draw_set_transform(Vector2(0, 5.0))
		draw_polyline(_line, Pal.METAL_DARK, 11.0)
		draw_set_transform(Vector2(0, 4.0))
		draw_polyline(_line, Pal.METAL, 8.0)
		draw_set_transform(Vector2(0, 0.8))
		draw_polyline(_line, Pal.METAL_LIGHT, 1.6)
		draw_set_transform(Vector2(0, 9.2))
		draw_polyline(_line, Color(0, 0, 0, 0.35), 1.2)
		draw_set_transform(Vector2.ZERO)
	else:
		for k in 4:
			draw_rect(Rect2(x0, y + 9.5 + k * 4.0, ww, 5.0), Color(0, 0, 0, 0.16 - k * 0.035))
		draw_rect(Rect2(x0, y - 0.5, ww, 11.0), Pal.METAL_DARK)
		draw_rect(Rect2(x0, y, ww, 8.0), Pal.METAL)
		draw_rect(Rect2(x0, y, ww, 1.6), Pal.METAL_LIGHT)
		draw_rect(Rect2(x0, y + 8.6, ww, 1.2), Color(0, 0, 0, 0.35))
	_draw_inlay(y + 3.4)
	# Hooks in two passes (plates and stems, then eyelets) so each pass is a
	# single batch however many strings hang from the beam.
	for t in targets:
		if _shows(t):
			_hook_plate(t.anchor + Vector2(0, offset_at(t.anchor.x)), t.hook_angle(), t.rope_alpha)
	draw_set_transform(Vector2.ZERO)
	var x := 32.0
	while x < w:
		var p := Vector2(x, y + 4.5 + offset_at(x))
		Pal.disc(self, p + Vector2(0.8, 0.8), 2.0, Color(0, 0, 0, 0.45))
		Pal.disc(self, p, 1.8, Pal.METAL_LIGHT)
		Pal.disc(self, p - Vector2(0.5, 0.5), 0.8, Color(Pal.INK, 0.5))
		x += 64.0
	for t in targets:
		if _shows(t):
			_hook_eye(t.anchor + Vector2(0, offset_at(t.anchor.x)), t.hook_angle(), t.rope_alpha)
	draw_set_transform(Vector2.ZERO)


func _draw_inlay(y: float) -> void:
	if _shown < 0.003:
		return
	var w := l.size.x
	var half := w * 0.5 * _shown
	var pulse := 0.0
	if hot:
		pulse = 0.6 + 0.4 * sin(_clock * 14.0)
	elif _shown > 0.85:
		pulse = 0.5 + 0.5 * sin(_clock * 9.0)
	_inlay.clear()
	for i in 17:
		var x := w * 0.5 + lerpf(-half, half, i / 16.0)
		_inlay.append(Vector2(x, y + offset_at(x)))
	if pulse > 0.0:
		draw_polyline(_inlay, Color(Pal.GOLD, 0.16 * pulse), 12.0)
	draw_polyline(_inlay, Pal.GOLD_DARK, 3.4)
	draw_polyline(_inlay, Color(Pal.GOLD_LIGHT, 0.55 + 0.45 * pulse), 1.4)
	for sx: float in [-1.0, 1.0]:
		var e := _inlay[0] if sx < 0.0 else _inlay[16]
		Pal.disc(self, e, 2.4 + 1.2 * pulse, Pal.GOLD_LIGHT)


func _shows(t: Target) -> bool:
	return t.phase != Target.Phase.OFF and t.rope_alpha > 0.0 and t.delay <= 0.0


## Mount plate and stem; the string ties into the eyelet below.
func _hook_plate(at: Vector2, angle: float, alpha: float) -> void:
	draw_set_transform(at, angle)
	draw_rect(Rect2(-4.0 + 2.0, -1.0 + 2.0, 8.0, 3.0), Color(Pal.SHADOW, Pal.SHADOW.a * alpha))
	draw_rect(Rect2(-4.0, -1.0, 8.0, 3.0), Color(Pal.METAL_LIGHT, alpha))
	draw_rect(Rect2(-1.0, 2.0, 2.0, 3.2), Color(Pal.METAL, alpha))


func _hook_eye(at: Vector2, angle: float, alpha: float) -> void:
	draw_set_transform(at, angle)
	Pal.hoop(self, Vector2(1.2, 9.2), 4.6, Color(Pal.METAL_DARK, alpha))
	Pal.hoop(self, Vector2(0, 8.0), 4.4, Color(Pal.METAL_LIGHT, alpha))
