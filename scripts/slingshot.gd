class_name Slingshot
extends Node2D
## Fork, elastic band, pouch, power arc and the ammo stack.
##
## Band: two Line2D strips with a width_curve whose width follows
## rest × √(rest_len / len) (6 px at rest, 3 px at full stretch), each with a
## darker underside offset down/right. The band wraps round the fork tip and
## is tucked under a lashing, so no loose end shows.
## Release: damped spring (k 900, c 12) gives overshoot and 2–3 swings in
## ~350 ms; the ball leaves when the pouch crosses its rest point.

signal launched(pos: Vector2, vel: Vector2, ammo_kind: int)

enum Ammo { NORMAL, PIERCE, TRIPLE }

const MIN_POWER := 0.18
const SPRING_K := 900.0
const SPRING_C := 12.0
const BAND_REST_W := 6.0
const BAND_MIN_W := 3.0
const ARM_W := 13.0
const SHAFT_W := 16.0
const GRIP_W := 21.0
const POUCH_HALF := 15.0
const ARC_FADE := 0.12

enum Mode { IDLE, AIM, RELEASE }

var l: Layout
var mode := Mode.IDLE
var pouch := Vector2.ZERO
var pouch_vel := Vector2.ZERO
var pouch_rot := 0.0
var power := 0.0
var aim_dir := Vector2.UP

var _ammo: Array[int] = []
var _reload := 0.0
var _arc_alpha := 0.0
var _at_max := false
var _release_t := 0.0
var _release_dir := Vector2.UP
var _release_speed := 0.0
var _release_kind := 0
var _ball_in_pouch := true
var _load_anim := 1.0
var _was_empty := false

var _band_l: Line2D
var _band_r: Line2D
var _under_l: Line2D
var _under_r: Line2D
var _front: Node2D
var _fork: Node2D               # static: redrawn only on layout change
var _pts_l := PackedVector2Array()
var _pts_r := PackedVector2Array()
var _rest_len := 1.0


func _ready() -> void:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.9))
	curve.add_point(Vector2(0.18, 1.0))
	curve.add_point(Vector2(0.65, 0.84))
	curve.add_point(Vector2(1.0, 0.95))
	_fork = Node2D.new()
	add_child(_fork)
	_fork.draw.connect(_draw_fork)
	_under_l = _make_band(Pal.BAND_DARK, curve)
	_band_l = _make_band(Pal.BAND, curve)
	_under_r = _make_band(Pal.BAND_DARK, curve)
	_band_r = _make_band(Pal.BAND, curve)
	for u in [_under_l, _under_r]:
		u.position = Vector2(0.8, 1.6)
	_front = Node2D.new()
	add_child(_front)
	_front.draw.connect(_draw_front)


func _make_band(col: Color, curve: Curve) -> Line2D:
	var line := Line2D.new()
	line.default_color = col
	line.width_curve = curve
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	add_child(line)
	return line


func setup(layout: Layout) -> void:
	l = layout
	pouch = l.pouch_rest()
	pouch_vel = Vector2.ZERO
	_rest_len = _tip(-1).distance_to(pouch + Vector2(-POUCH_HALF, 0))
	_update_bands()
	_fork.queue_redraw()


func set_ammo(queue: Array[int], reload_frac: float) -> void:
	var empty := queue.is_empty()
	if _was_empty and not empty and mode != Mode.RELEASE:
		_load_anim = 0.0
		Sfx.play("reload", 1.0, -8.0)
	_was_empty = empty
	_ammo = queue
	_reload = reload_frac


func has_ball() -> bool:
	return not _ammo.is_empty()


func is_aiming() -> bool:
	return mode == Mode.AIM


func begin_aim() -> bool:
	if not has_ball() or mode == Mode.RELEASE:
		return false
	mode = Mode.AIM
	_at_max = false
	return true


## `offset` is the finger's travel since the drag began.
func drag(offset: Vector2) -> void:
	if mode != Mode.AIM:
		return
	var rest := l.pouch_rest()
	var v := offset
	v.y = maxf(v.y, 0.0)
	var ang := 0.0
	if v.length() > 0.01:
		ang = clampf(Vector2.DOWN.angle_to(v), -deg_to_rad(80), deg_to_rad(80))
	# Power comes from how far the finger travelled (a physical distance);
	# the pouch shows it by stretching the band in proportion.
	power = clampf(v.length() / l.drag_range, 0.0, 1.0)
	var dir := Vector2.DOWN.rotated(ang)
	var p := rest + dir * l.max_pull * power
	p.x = maxf(p.x, l.pouch_min_x())
	pouch = p
	if v.length() > 0.01:
		aim_dir = -dir
	if power >= 0.995 and not _at_max:
		_at_max = true
		Sfx.haptic(14, 0.35)
		Sfx.play("tick", 1.0, -10.0)
	elif power < 0.95:
		_at_max = false


func release() -> void:
	if mode != Mode.AIM:
		return
	mode = Mode.RELEASE
	_release_t = 0.0
	pouch_vel = Vector2.ZERO
	_release_dir = aim_dir
	_ball_in_pouch = power >= MIN_POWER and has_ball()
	if _ball_in_pouch:
		_release_speed = launch_speed()
		_release_kind = _ammo[0]
		Sfx.play("release", lerpf(1.15, 0.9, power), -2.0)
		Sfx.haptic(10, 0.25)


func cancel() -> void:
	mode = Mode.IDLE
	pouch = l.pouch_rest()
	pouch_vel = Vector2.ZERO
	power = 0.0
	_ball_in_pouch = true


func step(dt: float) -> void:
	if mode != Mode.RELEASE:
		return
	_release_t += dt
	var rest := l.pouch_rest()
	var before := (pouch - rest).dot(_release_dir)
	pouch_vel += (-SPRING_K * (pouch - rest) - SPRING_C * pouch_vel) * dt
	pouch += pouch_vel * dt
	var after := (pouch - rest).dot(_release_dir)
	if _ball_in_pouch and before <= 0.0 and after > 0.0:
		_ball_in_pouch = false
		launched.emit(rest, _release_dir * _release_speed, _release_kind)
	if _release_t > 0.35 and pouch_vel.length() < 40.0 and pouch.distance_to(rest) < 1.5:
		mode = Mode.IDLE
		pouch = rest
		pouch_vel = Vector2.ZERO
		power = 0.0
		_ball_in_pouch = true
		_load_anim = 0.0


func _process(delta: float) -> void:
	if l == null:
		return
	var target_alpha := 1.0 if mode == Mode.AIM else 0.0
	_arc_alpha = move_toward(_arc_alpha, target_alpha, delta / ARC_FADE)
	_load_anim = minf(1.0, _load_anim + delta / 0.14)
	# The pouch lies across the pull; after release it tips with its velocity.
	var rest := l.pouch_rest()
	var goal := 0.0
	if mode == Mode.AIM and pouch.distance_to(rest) > 1.0:
		goal = Vector2.DOWN.angle_to(pouch - rest)
	elif mode == Mode.RELEASE:
		goal = clampf(pouch_vel.x * 0.0012, -0.7, 0.7)
	pouch_rot = lerp_angle(pouch_rot, goal, Pal.damp(0.35, delta))
	_update_bands()
	if _arc_alpha > 0.0 or target_alpha > 0.0:
		queue_redraw()
	_front.queue_redraw()


func _tip(side: int) -> Vector2:
	return Vector2(l.center_x + side * l.fork_half, l.fork_y)


## Unit direction of the arm at its tip (pointing out of the tip).
func _arm_dir(side: int) -> Vector2:
	var tip := _tip(side)
	var ctrl := Vector2(l.center_x + side * l.fork_half * 0.96, l.crotch_y - 12.0)
	return (tip - ctrl).normalized()


func _pouch_ends() -> Array[Vector2]:
	var axis := Vector2.RIGHT.rotated(pouch_rot) * POUCH_HALF
	return [pouch - axis, pouch + axis]


func _update_bands() -> void:
	var ends := _pouch_ends()
	_build_band(-1, ends[0], _pts_l)
	_build_band(1, ends[1], _pts_r)
	for pair in [[_band_l, _under_l, _pts_l, ends[0], -1], [_band_r, _under_r, _pts_r, ends[1], 1]]:
		var band: Line2D = pair[0]
		var under: Line2D = pair[1]
		var len := _tip(pair[4]).distance_to(pair[3])
		var w := clampf(BAND_REST_W * sqrt(_rest_len / maxf(len, 1.0)), BAND_MIN_W, BAND_REST_W)
		band.points = pair[2]
		under.points = pair[2]
		band.width = w
		under.width = w + 1.0


## Band path: tucked end on the inner side of the arm, wrap over the tip,
## then a tangent line to the pouch.
func _build_band(side: int, attach: Vector2, out: PackedVector2Array) -> void:
	var tip := _tip(side)
	var d := _arm_dir(side)
	var n_out := Vector2(-d.y, d.x)
	if n_out.x * side < 0.0:
		n_out = -n_out
	var r := ARM_W * 0.5 + 1.5
	var sigma := float(side)
	var a_in := (-n_out).angle()
	var to_a := attach - tip
	var dist := maxf(to_a.length(), r + 0.5)
	var a_t := to_a.angle() - sigma * acos(r / dist)
	var sweep := fposmod(sigma * (a_t - a_in), TAU)
	const K := 7
	out.resize(K + 3)
	out[0] = tip - d * 12.0 - n_out * r
	for k in K + 1:
		var a := a_in + sigma * sweep * float(k) / K
		out[k + 1] = tip + Vector2.from_angle(a) * r
	out[K + 2] = attach


func _draw() -> void:
	if l == null:
		return


func _fork_paths() -> Array:
	var cx := l.center_x
	var crotch := Vector2(cx, l.crotch_y)
	var arms := PackedVector2Array()
	for side in [-1, 1]:
		var tip := _tip(side)
		var ctrl := Vector2(cx + side * l.fork_half * 0.96, l.crotch_y - 12.0)
		var seg := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			seg.append(crotch.lerp(ctrl, t).lerp(ctrl.lerp(tip, t), t))
		if side == -1:
			seg.reverse()
			arms.append_array(seg)
		else:
			arms.append_array(seg.slice(1))
	var grip_top := Vector2(cx, lerpf(l.crotch_y, l.handle_end_y, 0.45))
	var grip_end := Vector2(cx, l.handle_end_y - GRIP_W * 0.5)
	return [
		[arms, ARM_W],
		[PackedVector2Array([crotch, grip_top]), SHAFT_W],
		[PackedVector2Array([grip_top, grip_end]), GRIP_W],
	]


func _draw_fork() -> void:
	var paths := _fork_paths()
	var caps := [[_tip(-1), ARM_W], [_tip(1), ARM_W], [paths[2][0][1], GRIP_W]]
	# Layers: shadow, dark edge (down/right), light edge (up/left), body.
	var layers := [
		[Pal.SHADOW_OFFSET, Pal.SHADOW, 0.0],
		[Vector2(1.5, 1.5), Pal.METAL_DARK, 0.0],
		[Vector2(-1.5, -1.5), Pal.METAL_LIGHT, 0.0],
		[Vector2.ZERO, Pal.METAL, -3.0],
	]
	for layer in layers:
		var off: Vector2 = layer[0]
		var col: Color = layer[1]
		var shrink: float = layer[2]
		for p in paths:
			var pts: PackedVector2Array = p[0]
			var moved := PackedVector2Array()
			for q in pts:
				moved.append(q + off)
			_fork.draw_polyline(moved, col, p[1] + shrink, true)
		for c in caps:
			Pal.disc(_fork, c[0] + off, (c[1] + shrink) * 0.5, col)
	# Grip wrap: a few fine grooves to read as a handle.
	var g0: Vector2 = paths[2][0][0]
	var g1: Vector2 = paths[2][0][1]
	for i in 4:
		var y := lerpf(g0.y + 10.0, g1.y - 4.0, float(i) / 3.0)
		_fork.draw_line(Vector2(g0.x - GRIP_W * 0.5 + 3.0, y), Vector2(g0.x + GRIP_W * 0.5 - 3.0, y + 3.0), Color(Pal.METAL_DARK, 0.8), 1.2, true)


func _draw_front() -> void:
	if l == null:
		return
	_draw_lashing()
	_draw_aim_dots()
	_draw_pouch()
	_draw_ammo()


func _draw_lashing() -> void:
	for side in [-1, 1]:
		var tip := _tip(side)
		var d := _arm_dir(side)
		var n := Vector2(-d.y, d.x)
		for j in 4:
			var c := tip - d * (6.0 + j * 3.0)
			var h := n * (ARM_W * 0.5 + 1.2)
			_front.draw_line(c - h + Vector2(0.6, 0.9), c + h + Vector2(0.6, 0.9), Pal.BAND_DARK, 1.8, true)
			_front.draw_line(c - h, c + h, Pal.BAND, 1.2, true)


## Short predicted path: same gravity and wall bounce as the ball, about
## 0.35 s of flight, so it guides without solving the shot.
func _draw_aim_dots() -> void:
	if _arc_alpha <= 0.0 or power < MIN_POWER or not Prefs.aim_guide:
		return
	var p := l.pouch_rest()
	var v := aim_dir * launch_speed()
	var dt := 1.0 / 120.0
	var next_dot := 0.05
	var t := 0.0
	var i := 0
	const DOTS := 8
	while i < DOTS and t < 0.4:
		t += dt
		v.y += Ball.GRAVITY * dt
		p += v * dt
		if p.x < Ball.RADIUS:
			p.x = Ball.RADIUS
			v.x = absf(v.x) * Ball.WALL_BOUNCE
		elif p.x > l.size.x - Ball.RADIUS:
			p.x = l.size.x - Ball.RADIUS
			v.x = -absf(v.x) * Ball.WALL_BOUNCE
		if p.y < l.rail_y + Ball.RADIUS:
			break
		if t >= next_dot:
			next_dot += 0.045
			var k := 1.0 - float(i) / DOTS
			# The dots carry the power: brighter and fuller the harder you pull,
			# warming in the last 15 %.
			var col := Pal.GOLD.lerp(Pal.GOLD_WARM, clampf((power - 0.85) / 0.15, 0.0, 1.0))
			_front.draw_circle(p, lerpf(1.4, 2.8, k) * lerpf(0.8, 1.2, power), Color(col, (0.2 + 0.4 * power) * k * _arc_alpha), true, -1.0, true)
			i += 1


## The shot the current aim would fire: a point every 1/60 s, with the
## ball's gravity and wall bounce, until it reaches the rail. Targets read
## this to see whether they are in the line of fire.
func predict(max_t := 1.2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p := l.pouch_rest()
	var v := aim_dir * launch_speed()
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < max_t:
		t += dt
		v.y += Ball.GRAVITY * dt
		p += v * dt
		if p.x < Ball.RADIUS:
			p.x = Ball.RADIUS
			v.x = absf(v.x) * Ball.WALL_BOUNCE
		elif p.x > l.size.x - Ball.RADIUS:
			p.x = l.size.x - Ball.RADIUS
			v.x = -absf(v.x) * Ball.WALL_BOUNCE
		out.append(p)
		if p.y < l.rail_y + Ball.RADIUS:
			break
	return out


## Soft pulls lob, full pulls fly: a wide range with a slight curve so the
## difference is felt across the whole pull.
func launch_speed() -> float:
	return lerpf(620.0, 2250.0, pow(power, 1.15)) * l.scale


func _draw_pouch() -> void:
	var ends := _pouch_ends()
	var back := Vector2.DOWN.rotated(pouch_rot) * 7.0
	var pts := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		var mid := pouch + back
		pts.append(ends[0].lerp(mid, t).lerp(mid.lerp(ends[1], t), t))
	var shadow := PackedVector2Array()
	for q in pts:
		shadow.append(q + Vector2(1.0, 2.0))
	_front.draw_polyline(shadow, Pal.BAND_DARK, 9.0, true)
	_front.draw_polyline(pts, Pal.POUCH, 8.0, true)
	if _ball_in_pouch and has_ball():
		var s := ease(_load_anim, -2.0)
		Ball.draw_ball(_front, pouch, Ball.RADIUS * lerpf(0.4, 1.0, s), _ammo[0] == Ammo.PIERCE, 0.0, Vector2.UP)
		if _ammo[0] == Ammo.TRIPLE:
			for k in 3:
				_front.draw_circle(pouch + Vector2.from_angle(-PI * 0.5 + k * TAU / 3.0) * 5.0, 2.2, Pal.GOLD_DARK, true, -1.0, true)


## The spare balls, as real balls resting in a small rack beside the
## handle (the one in the pouch is the next shot). The slot being refilled
## shows a ball growing in as it reloads; empty slots are faint dimples.
func _draw_ammo() -> void:
	var slots := 4
	var top := Vector2(l.ammo_x, l.ammo_top)
	var bottom := top + Vector2(0, (slots - 1) * l.ammo_step)
	# The rack: a short dark channel, lit from the upper left.
	_front.draw_line(top + Vector2(2, -12), bottom + Vector2(2, 14), Pal.SHADOW, 22.0, true)
	_front.draw_line(top + Vector2(0, -12), bottom + Vector2(0, 12), Color(Pal.METAL_DARK, 0.9), 20.0, true)
	_front.draw_line(top + Vector2(-9, -10), bottom + Vector2(-9, 10), Color(Pal.METAL_LIGHT, 0.25), 1.2, true)
	for i in slots:
		var p := top + Vector2(0, i * l.ammo_step)
		var idx := i + 1
		if idx < _ammo.size():
			_draw_ammo_icon(p, _ammo[idx], true)
		elif idx == _ammo.size() and _reload > 0.0:
			var r := 7.5 * ease(_reload, 0.6)
			Pal.disc(_front, p, 7.5, Color(0, 0, 0, 0.25))
			if r > 0.5:
				_front.draw_circle(p, r, Color(Pal.GOLD_DARK, 0.85), true, -1.0, true)
			_front.draw_arc(p, 8.5, -PI * 0.5, -PI * 0.5 + TAU * _reload, 24, Color(Pal.GOLD, 0.55), 1.2, true)
		else:
			Pal.disc(_front, p, 7.5, Color(0, 0, 0, 0.28))


func _draw_ammo_icon(p: Vector2, kind: int, _current: bool) -> void:
	# A real ball, drawn exactly like the one in flight; power-ups carry
	# their mark (pierce: the steel band; triple: three seeds).
	Ball.draw_ball(_front, p, 8.0, kind == Ammo.PIERCE, 0.6, Vector2.UP, true)
	if kind == Ammo.TRIPLE:
		for k in 3:
			_front.draw_circle(p + Vector2.from_angle(-PI * 0.5 + k * TAU / 3.0) * 3.4, 1.6, Pal.GOLD_DARK, true, -1.0, true)


