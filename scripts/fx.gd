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
const FRAG_POOL := 64
const FRAG_LIFE := 0.75
const RAY_LIFE := 0.26

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
var _slow_scale := 1.0
var _frags: Array[Dictionary] = []
var _next_frag := 0
var _queued: Array[Dictionary] = []   # staged bursts (boss)
var _slow_left := 0.0
var _punch := 0.0
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
	for i in FRAG_POOL:
		_frags.append({"t": -1.0, "type": 0, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "rot": 0.0,
			"spin": 0.0, "a0": 0.0, "a1": 0.0, "r": 0.0, "w": 0.0, "col": Pal.INK, "life": FRAG_LIFE})
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


enum Frag { ARC, SEG, DOT, RAY, CAPSULE }


func _frag(type: int, pos: Vector2, vel: Vector2, col: Color, life := FRAG_LIFE) -> Dictionary:
	var f := _frags[_next_frag]
	_next_frag = (_next_frag + 1) % FRAG_POOL
	f.t = 0.0
	f.type = type
	f.pos = pos
	f.vel = vel
	f.col = col
	f.life = life
	f.rot = 0.0
	f.spin = _rng.randf_range(-6.0, 6.0)
	return f


## Shape-true break-up: a ring parts into arcs, a hexagon into its edges,
## a rod into two halves, a drop into droplets; plus a quick fan of fine
## rays. Matte, local and short; all pooled data.
func burst(kind: int, at: Vector2, rot: float, radius: float, col: Color, base_vel: Vector2) -> void:
	var inherit := base_vel * 0.35
	match kind:
		Target.Kind.RING, Target.Kind.HEAVY, Target.Kind.SHIELD, Target.Kind.REEL:
			var pieces := 6 if kind != Target.Kind.HEAVY else 8
			var rr := radius - 5.0
			for i in pieces:
				var mid := rot + (i + 0.5) * TAU / pieces
				var f := _frag(Frag.ARC, at, inherit + Vector2.from_angle(mid) * _rng.randf_range(120.0, 200.0), col)
				f.a0 = mid - TAU / pieces * 0.42
				f.a1 = mid + TAU / pieces * 0.42
				f.r = rr
				f.w = 7.0 if kind != Target.Kind.HEAVY else 5.0
				f.spin = _rng.randf_range(-3.0, 3.0)
		Target.Kind.SPLIT, Target.Kind.BOSS:
			var rr := radius - (4.0 if kind == Target.Kind.SPLIT else 0.0)
			for i in 6:
				var a := rot + i * TAU / 6.0 + PI / 6.0
				var b := a + TAU / 6.0
				var p0 := Vector2.from_angle(a) * rr
				var p1 := Vector2.from_angle(b) * rr
				var mid := (p0 + p1) * 0.5
				var f := _frag(Frag.SEG, at + mid, inherit + mid.normalized() * _rng.randf_range(130.0, 230.0), col)
				f.rot = (p1 - p0).angle()
				f.r = p0.distance_to(p1) * 0.5
				f.w = 7.0 if kind == Target.Kind.SPLIT else 10.0
		Target.Kind.ROD:
			for side: float in [-1.0, 1.0]:
				var dir := Vector2.RIGHT.rotated(rot) * side
				var f := _frag(Frag.CAPSULE, at + dir * 15.0, inherit + dir * 150.0 + Vector2(0, -60), col)
				f.rot = rot
				f.r = radius
				f.w = 15.0
		Target.Kind.DROP, Target.Kind.SHADE:
			for i in 9:
				var a := _rng.randf() * TAU
				var f := _frag(Frag.DOT, at + Vector2.from_angle(a) * radius * 0.5, inherit + Vector2.from_angle(a) * _rng.randf_range(90.0, 240.0) + Vector2(0, -80), col, 0.6)
				f.r = _rng.randf_range(2.0, 4.5)
	# Fine rays: a quick, thin fan that reads as the burst's energy.
	var rays := 12 if kind != Target.Kind.BOSS else 20
	for i in rays:
		var a := rot + i * TAU / rays + _rng.randf_range(-0.08, 0.08)
		var f := _frag(Frag.RAY, at, Vector2.ZERO, col.lightened(0.25), RAY_LIFE)
		f.rot = a
		f.r = radius * 0.9
		f.w = radius * _rng.randf_range(1.6, 2.2)
	if kind == Target.Kind.BOSS:
		# Staged: two more rings of rays follow the first.
		_queued.append({"t": 0.14, "at": at, "r": radius * 1.5, "col": col})
		_queued.append({"t": 0.3, "at": at, "r": radius * 2.1, "col": col})


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
	_apply_time()
	await get_tree().create_timer(HITSTOP, true, false, true).timeout
	_hitstop_live = false
	_apply_time()


## Slow motion for `real_dur` seconds of real time (last kill, boss, loss).
func slowmo(scale: float, real_dur: float) -> void:
	_slow_scale = scale
	_slow_left = real_dur
	_apply_time()


## Brief zoom toward the centre of the field (camera punch).
func punch(amount: float) -> void:
	_punch = maxf(_punch, amount)


func reset_time() -> void:
	_slow_left = 0.0
	_slow_scale = 1.0
	_hitstop_live = false
	_punch = 0.0
	Engine.time_scale = 1.0


func _apply_time() -> void:
	if get_tree().paused:
		return
	Engine.time_scale = 0.02 if _hitstop_live else (_slow_scale if _slow_left > 0.0 else 1.0)


func clear() -> void:
	for p in _popups:
		p.t = -1.0
	for r in _rings:
		r.t = -1.0
	for d in _shards:
		d.t = -1.0
	for f in _frags:
		f.t = -1.0
	_queued.clear()
	for s in _sparks:
		s.emitting = false
	_shake_t = 0.0
	_punch = 0.0
	if shake_target:
		shake_target.position = Vector2.ZERO
		shake_target.scale = Vector2.ONE


func _process(delta: float) -> void:
	# Real time, so hit-stop and slow motion freeze the game, not the camera.
	var rd := delta / maxf(Engine.time_scale, 0.001)
	if _slow_left > 0.0:
		_slow_left -= rd
		if _slow_left <= 0.0:
			_apply_time()
	var off := Vector2.ZERO
	if _shake_t > 0.0:
		_shake_t -= rd
		var k := maxf(_shake_t, 0.0) / SHAKE_TIME
		var a := _shake_amp * k * k
		off = Vector2(_rng.randf_range(-a, a), _rng.randf_range(-a, a)).round()
		if _shake_t <= 0.0:
			_shake_amp = 0.0
	_punch = maxf(0.0, _punch - rd * 0.12)
	if shake_target and l:
		var sc := 1.0 + _punch
		var c := Vector2(l.center_x, l.rail_y + l.play_h * 0.5)
		shake_target.scale = Vector2(sc, sc)
		shake_target.position = c * (1.0 - sc) + off
	var any := false
	for q in _queued.duplicate():
		q.t -= delta
		if q.t <= 0.0:
			_queued.erase(q)
			ring(q.at, q.col, q.r)
			for i in 14:
				var f := _frag(Frag.RAY, q.at, Vector2.ZERO, q.col.lightened(0.25), RAY_LIFE)
				f.rot = i * TAU / 14.0 + _rng.randf() * 0.2
				f.r = q.r * 0.6
				f.w = q.r * 1.3
		any = true
	for f in _frags:
		if f.t >= 0.0:
			f.t += delta
			if f.t > f.life:
				f.t = -1.0
				continue
			any = true
			if f.type != Frag.RAY:
				f.vel.y += 900.0 * delta
				f.vel *= exp(-0.8 * delta)
				f.pos += f.vel * delta
				f.rot += f.spin * delta
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
	for f in _frags:
		if f.t < 0.0:
			continue
		var k: float = f.t / f.life
		var alpha := 1.0 - k * k
		var c: Color = f.col
		match f.type:
			Frag.ARC:
				draw_arc(f.pos + Pal.SHADOW_OFFSET * 0.6, f.r, f.a0 + f.rot, f.a1 + f.rot, 10, Color(0, 0, 0, 0.3 * alpha), f.w, true)
				draw_arc(f.pos, f.r, f.a0 + f.rot, f.a1 + f.rot, 10, Color(c, alpha), f.w, true)
			Frag.SEG:
				var d: Vector2 = Vector2.from_angle(f.rot) * f.r
				draw_line(f.pos - d + Pal.SHADOW_OFFSET * 0.6, f.pos + d + Pal.SHADOW_OFFSET * 0.6, Color(0, 0, 0, 0.3 * alpha), f.w, true)
				draw_line(f.pos - d, f.pos + d, Color(c, alpha), f.w, true)
			Frag.CAPSULE:
				var d2 := Vector2.from_angle(f.rot) * 13.0
				for layer in 2:
					var o := Pal.SHADOW_OFFSET * 0.6 if layer == 0 else Vector2.ZERO
					var lc := Color(0, 0, 0, 0.3 * alpha) if layer == 0 else Color(c, alpha)
					draw_line(f.pos - d2 + o, f.pos + d2 + o, lc, f.w * 2.0, true)
					draw_circle(f.pos - d2 + o, f.w, lc, true, -1.0, true)
					draw_circle(f.pos + d2 + o, f.w, lc, true, -1.0, true)
			Frag.DOT:
				draw_circle(f.pos, f.r, Color(c, alpha), true, -1.0, true)
			Frag.RAY:
				# Rays run outward: inner end chases the outer end.
				var e := 1.0 - pow(1.0 - k, 3.0)
				var dir := Vector2.from_angle(f.rot)
				var r0: float = f.r + f.w * maxf(0.0, e - 0.35) * 1.4
				var r1: float = f.r + f.w * e
				draw_line(f.pos + dir * r0, f.pos + dir * r1, Color(c, 0.7 * (1.0 - k)), 1.6, true)
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
