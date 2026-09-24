class_name TitleLetters
extends Node2D
## The title: S P E N N hanging from the rail on strings, each letter a
## swinging body. Balls knock them about; starting a run snaps the strings
## one by one so the letters drop out of the way.

const WORD := "SPENN"
const GOLD_INDEX := 2
const K := 90.0
const GRAVITY := 900.0

var l: Layout
var font: Font
var active := false
var _letters: Array[Dictionary] = []
var _snap_t := -1.0
var _rng := RandomNumberGenerator.new()


func setup(layout: Layout, display_font: Font) -> void:
	l = layout
	font = display_font
	reset()


func reset() -> void:
	_rng.randomize()
	_letters.clear()
	var lens := [0.2, 0.33, 0.25, 0.36, 0.17]
	for i in WORD.length():
		var ax := l.size.x * (0.14 + 0.18 * i)
		var len: float = l.play_h * lens[i]
		_letters.append({
			"ch": WORD[i], "anchor": Vector2(ax, l.rail_y + 3.0), "len": len,
			"pos": Vector2(ax, l.rail_y + 3.0 + len * 0.3), "vel": Vector2(_rng.randf_range(-60, 60), 0),
			"rot": 0.0, "spin": 0.0, "attached": true, "alpha": 1.0,
		})
	_snap_t = -1.0
	active = true
	visible = true


## Starts the exit: strings snap left to right over ~0.5 s.
func release() -> void:
	if _snap_t < 0.0:
		_snap_t = 0.0


func is_gone() -> bool:
	return not active


## A ball passing through knocks a letter; returns true on contact.
func knock(p: Vector2, v: Vector2, r: float) -> bool:
	var any := false
	for d in _letters:
		if d.pos.distance_to(p) < r + 34.0:
			d.vel += v * 0.25
			d.spin += signf(v.x + 0.01) * 4.0
			any = true
	return any


func _process(delta: float) -> void:
	if not active or l == null:
		return
	var dt := minf(delta, 1.0 / 30.0)
	if _snap_t >= 0.0:
		_snap_t += dt
	var alive := false
	for i in _letters.size():
		var d: Dictionary = _letters[i]
		if d.attached and _snap_t >= 0.0 and _snap_t > i * 0.09:
			d.attached = false
			d.vel += Vector2(_rng.randf_range(-80, 80), -140)
			d.spin = _rng.randf_range(-5.0, 5.0)
			Sfx.play("snap", _rng.randf_range(0.9, 1.15), -10.0)
		d.vel.y += GRAVITY * dt
		if d.attached:
			var off: Vector2 = d.pos - d.anchor
			var dist := off.length()
			if dist > d.len:
				var dir := off / dist
				d.vel -= dir * K * (dist - d.len) * dt
				d.vel -= dir * d.vel.dot(dir) * 2.0 * dt
			d.vel *= exp(-0.8 * dt)
			d.rot = lerp_angle(d.rot, atan2(-off.x, off.y) * 0.8, Pal.damp(0.2, dt))
		else:
			d.rot += d.spin * dt
			d.alpha = maxf(0.0, d.alpha - dt * 1.2)
		d.pos += d.vel * dt
		if d.alpha > 0.0 and d.pos.y < l.size.y + 80.0:
			alive = true
	if not alive:
		active = false
		visible = false
	queue_redraw()


func _draw() -> void:
	if font == null:
		return
	var fs := 92
	for i in _letters.size():
		var d: Dictionary = _letters[i]
		var a: float = d.alpha
		if d.attached:
			draw_line(d.anchor, d.pos + Vector2(0, -fs * 0.62).rotated(d.rot), Color(Pal.STRING, a), 1.6, true)
		var w := font.get_string_size(d.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col := Pal.GOLD if i == GOLD_INDEX else Pal.INK
		draw_set_transform(d.pos + Pal.SHADOW_OFFSET * 1.5, d.rot)
		draw_string(font, Vector2(-w * 0.5, fs * 0.08), d.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35 * a))
		draw_set_transform(d.pos, d.rot)
		draw_string(font, Vector2(-w * 0.5, fs * 0.08), d.ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
	draw_set_transform(Vector2.ZERO)
