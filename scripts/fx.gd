class_name Fx
extends Node2D
## Pooled hit sparks and score popups, screen shake and hit-stop.
## Popups, impact rings and shards are plain data drawn by this node, so
## they cost no nodes at all.

const SPARK_POOL := 8
const POPUP_POOL := 8
const POPUP_LIFE := 0.9
const POPUP_RISE := 38.0
const SHAKE_MAX := 3.0
const SHAKE_TIME := 0.15
const HITSTOP := 0.04
const RING_POOL := 8
const RING_LIFE := 0.18
const SHARD_POOL := 32
const SHARD_LIFE := 0.9

var l: Layout
var shake_target: Node2D
var font: Font

var _sparks: Array[CPUParticles2D] = []
var _next_spark := 0
var _popups: Array[Dictionary] = []
var _next_popup := 0
var _shake_t := 0.0
var _shake_amp := 0.0
var _hitstop_live := false
var _drawn_last := false
var _rings: Array[Dictionary] = []
var _next_ring := 0
var _shards: Array[Dictionary] = []
var _next_shard := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var tex := _dot_texture()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.55, Color(1, 1, 1, 0.8))
	var size_curve := Curve.new()
	size_curve.add_point(Vector2(0, 1))
	size_curve.add_point(Vector2(1, 0.45))
	for i in SPARK_POOL:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 8
		p.lifetime = 0.6
		p.explosiveness = 0.95
		p.texture = tex
		p.gravity = Vector2(0, 720)
		p.initial_velocity_min = 140.0
		p.initial_velocity_max = 290.0
		p.damping_min = 40.0
		p.damping_max = 80.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.0
		p.scale_amount_curve = size_curve
		p.color_ramp = ramp
		p.angular_velocity_min = -200.0
		p.angular_velocity_max = 200.0
		p.local_coords = false
		add_child(p)
		_sparks.append(p)
	for i in RING_POOL:
		_rings.append({"t": -1.0, "pos": Vector2.ZERO, "col": Pal.INK, "r": 30.0})
	for i in SHARD_POOL:
		_shards.append({"t": -1.0, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "rot": 0.0, "spin": 0.0,
			"col": Pal.INK, "pts": PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])})
	for i in POPUP_POOL:
		_popups.append({"t": -1.0, "text": "", "pos": Vector2.ZERO, "col": Pal.INK, "size": 20})


func _dot_texture() -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var d := Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(5.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Sparks in the target's colour; aimed inward near screen edges so no
## spark is ever cut off.
func sparks(at: Vector2, col: Color, count := 8) -> void:
	var p := _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % SPARK_POOL
	var reach := 110.0
	var dir := Vector2.UP
	var spread := 150.0
	if at.x < reach + l.margin:
		dir = Vector2(1, -0.6).normalized()
		spread = 55.0
	elif at.x > l.size.x - reach - l.margin:
		dir = Vector2(-1, -0.6).normalized()
		spread = 55.0
	if at.y < l.top_bar_h + reach:
		dir = Vector2(dir.x, 0.4).normalized()
	p.global_position = at
	p.direction = dir
	p.spread = spread
	p.color = col
	p.amount = clampi(count, 6, 10)
	p.restart()


## Thin pressure ring at the contact: 180 ms, local, no glow.
func ring(at: Vector2, col: Color, size := 30.0) -> void:
	var r := _rings[_next_ring]
	_next_ring = (_next_ring + 1) % RING_POOL
	r.t = 0.0
	r.pos = at
	r.col = col
	r.r = size


## A broken target sheds a few chips of its own colour that tumble away.
func shards(at: Vector2, col: Color, count: int, base_vel: Vector2) -> void:
	for i in count:
		var d := _shards[_next_shard]
		_next_shard = (_next_shard + 1) % SHARD_POOL
		var a := _rng.randf() * TAU
		var size := _rng.randf_range(4.0, 7.5)
		d.t = 0.0
		d.pos = at + Vector2.from_angle(a) * _rng.randf_range(4.0, 16.0)
		d.vel = base_vel * 0.4 + Vector2.from_angle(a) * _rng.randf_range(90.0, 230.0) + Vector2(0, -160)
		d.rot = _rng.randf() * TAU
		d.spin = _rng.randf_range(-14.0, 14.0)
		d.col = col.darkened(_rng.randf_range(0.0, 0.25))
		var pts: PackedVector2Array = d.pts
		pts[0] = Vector2(-size, -size * 0.4)
		pts[1] = Vector2(size * _rng.randf_range(0.6, 1.0), -size * 0.6)
		pts[2] = Vector2(size * _rng.randf_range(-0.2, 0.4), size * 0.8)
		d.pts = pts


func popup(text: String, at: Vector2, col := Pal.INK, size := 20) -> void:
	var p := _popups[_next_popup]
	_next_popup = (_next_popup + 1) % POPUP_POOL
	p.t = 0.0
	p.text = text
	p.col = col
	p.size = size
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if font else 80.0
	var half := w * 0.5
	var x := clampf(at.x, l.margin + half, l.size.x - l.margin - half)
	var y := clampf(at.y, l.top_bar_h + l.margin + POPUP_RISE + size, l.size.y - l.margin)
	# Stack above young popups nearby instead of overprinting them.
	for q in _popups:
		if q != p and q.t >= 0.0 and q.t < 0.5 and absf(q.pos.x - x) < 140.0 and absf(q.pos.y - y) < size + 6.0:
			y = q.pos.y - (size + 8.0)
	y = maxf(y, l.top_bar_h + l.margin + POPUP_RISE + size)
	p.pos = Vector2(x, y)


func shake(amount := SHAKE_MAX) -> void:
	_shake_amp = minf(SHAKE_MAX, maxf(_shake_amp, amount))
	_shake_t = SHAKE_TIME


func hitstop() -> void:
	if _hitstop_live or get_tree().paused:
		return
	_hitstop_live = true
	Engine.time_scale = 0.02
	await get_tree().create_timer(HITSTOP, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_live = false


func clear() -> void:
	for p in _popups:
		p.t = -1.0
	for r in _rings:
		r.t = -1.0
	for d in _shards:
		d.t = -1.0
	for s in _sparks:
		s.emitting = false
	_shake_t = 0.0
	if shake_target:
		shake_target.position = Vector2.ZERO


func _process(delta: float) -> void:
	# Real time, so hit-stop freezes the game but not the settle of effects.
	var rd := delta / maxf(Engine.time_scale, 0.001) if _hitstop_live else delta
	if _shake_t > 0.0 and shake_target:
		_shake_t -= rd
		var k := maxf(_shake_t, 0.0) / SHAKE_TIME
		var a := _shake_amp * k * k
		shake_target.position = Vector2(_rng.randf_range(-a, a), _rng.randf_range(-a, a)).round()
		if _shake_t <= 0.0:
			shake_target.position = Vector2.ZERO
			_shake_amp = 0.0
	var any := false
	for r in _rings:
		if r.t >= 0.0:
			r.t += delta
			if r.t > RING_LIFE:
				r.t = -1.0
			else:
				any = true
	for d in _shards:
		if d.t >= 0.0:
			d.t += delta
			d.vel.y += 1100.0 * delta
			d.pos += d.vel * delta
			d.rot += d.spin * delta
			if d.t > SHARD_LIFE or d.pos.y > l.size.y + 20.0:
				d.t = -1.0
			else:
				any = true
	for p in _popups:
		if p.t >= 0.0:
			p.t += delta
			if p.t > POPUP_LIFE:
				p.t = -1.0
			else:
				any = true
	if any or _drawn_last:
		queue_redraw()
	_drawn_last = any



func _draw() -> void:
	for r in _rings:
		if r.t < 0.0:
			continue
		var k: float = r.t / RING_LIFE
		var e := 1.0 - pow(1.0 - k, 3.0)
		draw_arc(r.pos, lerpf(r.r * 0.35, r.r * 1.25, e), 0.0, TAU, 32, Color(r.col, 0.55 * (1.0 - k)), lerpf(3.0, 0.6, k), true)
	for d in _shards:
		if d.t < 0.0:
			continue
		var alpha := clampf((SHARD_LIFE - d.t) / 0.3, 0.0, 1.0)
		draw_set_transform(d.pos + Vector2(2.5, 2.5), d.rot)
		draw_colored_polygon(d.pts, Color(0, 0, 0, 0.3 * alpha))
		draw_set_transform(d.pos, d.rot)
		draw_colored_polygon(d.pts, Color(d.col, alpha))
	draw_set_transform(Vector2.ZERO)
	if font == null:
		return
	for p in _popups:
		if p.t < 0.0:
			continue
		var k: float = p.t / POPUP_LIFE
		var rise := ease(k, 0.35) * POPUP_RISE
		var alpha := 1.0 if k < 0.55 else 1.0 - (k - 0.55) / 0.45
		var s := 1.0 + 0.12 * maxf(0.0, 1.0 - k * 8.0)
		var pos: Vector2 = p.pos - Vector2(0, rise)
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, p.size).x
		draw_set_transform(pos, 0.0, Vector2(s, s))
		draw_string(font, Vector2(-w * 0.5, 0) + Vector2(2, 2), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, p.size, Color(0, 0, 0, 0.35 * alpha))
		draw_string(font, Vector2(-w * 0.5, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, p.size, Color(p.col, alpha))
	draw_set_transform(Vector2.ZERO)
