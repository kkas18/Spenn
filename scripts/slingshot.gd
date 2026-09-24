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

signal launched(pos: Vector2, vel: Vector2, special: bool)

const MIN_POWER := 0.18
const SPRING_K := 900.0
const SPRING_C := 12.0
const BAND_REST_W := 6.0
const BAND_MIN_W := 3.0
const ARM_W := 13.0
const SHAFT_W := 16.0
const GRIP_W := 21.0
const POUCH_HALF := 15.0
const ARC_SPAN := deg_to_rad(84.0)
const ARC_FADE := 0.12

enum Mode { IDLE, AIM, RELEASE }

var l: Layout
var mode := Mode.IDLE
var pouch := Vector2.ZERO
var pouch_vel := Vector2.ZERO
var pouch_rot := 0.0
var power := 0.0
var aim_dir := Vector2.UP

var _ammo: Array[bool] = []
var _reload := 0.0
var _arc_alpha := 0.0
var _arc_ang := PI * 0.5
var _at_max := false
var _release_t := 0.0
var _release_dir := Vector2.UP
var _release_speed := 0.0
var _release_special := false
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


func set_ammo(queue: Array[bool], reload_frac: float) -> void:
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
	_arc_ang = PI * 0.5
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
	v = Vector2.DOWN.rotated(ang) * minf(v.length(), l.max_pull)
	var p := rest + v
	p.x = maxf(p.x, l.pouch_min_x())
	pouch = p
	var pull := pouch - rest
	power = clampf(pull.length() / l.max_pull, 0.0, 1.0)
	if pull.length() > 0.01:
		aim_dir = -pull.normalized()
		_arc_ang = pull.angle()
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
		_release_speed = lerpf(950.0, 2150.0, power) * l.scale
		_release_special = _ammo[0]
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
		launched.emit(rest, _release_dir * _release_speed, _release_special)
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
	_draw_arc()


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


func _draw_arc() -> void:
	if _arc_alpha <= 0.0:
		return
	# Gauge centred on the pull: fills outward both ways, warmer in the last 15 %.
	var rest := l.pouch_rest()
	var a := _arc_alpha
	var half := ARC_SPAN * 0.5
	var c := _arc_ang
	draw_arc(rest, l.arc_radius, c - half, c + half, 40, Color(Pal.GOLD, 0.14 * a), 3.0, true)
	var fill := half * power
	var warm := half * 0.85
	var cold := minf(fill, warm)
	if cold > 0.0:
		draw_arc(rest, l.arc_radius, c - cold, c + cold, 32, Color(Pal.GOLD, 0.9 * a), 3.0, true)
	if fill > warm:
		for sgn in [-1.0, 1.0]:
			draw_arc(rest, l.arc_radius, c + sgn * warm, c + sgn * fill, 6, Color(Pal.GOLD_WARM, 0.95 * a), 3.0, true)
	var end_col := Color(Pal.GOLD_WARM if power > 0.85 else Pal.GOLD, a)
	for sgn in [-1.0, 1.0]:
		Pal.disc(self, rest + Vector2.from_angle(c + sgn * fill) * l.arc_radius, 3.2, end_col)


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


func _draw_aim_dots() -> void:
	if _arc_alpha <= 0.0 or power < MIN_POWER:
		return
	var rest := l.pouch_rest()
	for i in 4:
		var p := rest + aim_dir * (70.0 + i * 36.0 + power * 30.0)
		_front.draw_circle(p, 2.6 - i * 0.35, Color(Pal.GOLD, (0.34 - i * 0.07) * _arc_alpha), true, -1.0, true)


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
		Ball.draw_ball(_front, pouch, Ball.RADIUS * lerpf(0.4, 1.0, s), _ammo[0], 0.0, Vector2.UP)


func _draw_ammo() -> void:
	for i in 5:
		var p := Vector2(l.ammo_x, l.ammo_top + i * l.ammo_step)
		if i < _ammo.size():
			_draw_ammo_icon(p, _ammo[i], i == 0)
		elif i == _ammo.size() and _reload > 0.0:
			_front.draw_arc(p, 7.0, -PI * 0.5, -PI * 0.5 + TAU * _reload, 24, Color(Pal.GOLD_DARK, 0.7), 1.5, true)
		else:
			_front.draw_arc(p, 7.0, 0.0, TAU, 24, Color(Pal.INK_FAINT, 0.35), 1.0, true)


func _draw_ammo_icon(p: Vector2, special: bool, current: bool) -> void:
	var col := Pal.GOLD if current else Pal.GOLD_DARK
	if special:
		var r := 9.0
		var diamond := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		if current:
			var sh := PackedVector2Array()
			for q in diamond:
				sh.append(q + Vector2(2, 2))
			_front.draw_colored_polygon(sh, Pal.SHADOW)
			_front.draw_colored_polygon(diamond, col)
		else:
			diamond.append(diamond[0])
			_front.draw_polyline(diamond, col, 2.0, true)
		return
	if current:
		_front.draw_circle(p + Vector2(2, 2), 8.0, Pal.SHADOW, true, -1.0, true)
		_front.draw_circle(p, 8.0, col, true, -1.0, true)
	else:
		_front.draw_arc(p, 7.0, 0.0, TAU, 24, col, 2.0, true)
