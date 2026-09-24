class_name Target
extends Node2D
## A target hanging from the rail on an elastic string (pooled).
## Body: rigid disc on a one-sided spring with its own angular inertia, so
## off-centre hits make it wobble about the string. String: Verlet rope.
## Everything is drawn in world coordinates; the node itself stays at origin.

enum Kind { RING, HEAVY, SPLIT, ROD, DROP }
enum Phase { OFF, HANGING, FALLING }

const N := 10                  # rope points
const GRAVITY := 900.0
const STRING_K := 120.0        # spring stiffness per unit mass (1/s²)
const DAMPING := 1.1

const RADIUS := {Kind.RING: 30.0, Kind.HEAVY: 34.0, Kind.SPLIT: 32.0, Kind.ROD: 15.0, Kind.DROP: 20.0}
const HP := {Kind.RING: 1, Kind.HEAVY: 2, Kind.SPLIT: 1, Kind.ROD: 1, Kind.DROP: 1}
const POINTS := {Kind.RING: 10, Kind.HEAVY: 20, Kind.SPLIT: 10, Kind.ROD: 15, Kind.DROP: 5}
const ROD_HALF := 30.0
const HOOK_LEN := 11.5         # rail pivot -> bottom of the hook eyelet
const HOOK_TILT := 0.8
const MASS := {Kind.RING: 1.0, Kind.HEAVY: 1.6, Kind.SPLIT: 1.1, Kind.ROD: 1.25, Kind.DROP: 0.6}
const ANG_K := 55.0            # angular spring back to the string angle (1/s²)
const ANG_C := 2.6             # angular damping (1/s)
const SPEED_MUL := {Kind.RING: 1.0, Kind.HEAVY: 0.85, Kind.SPLIT: 1.0, Kind.ROD: 1.1, Kind.DROP: 1.7}

var kind: Kind = Kind.RING
var phase: Phase = Phase.OFF
var hp := 1
var radius := 30.0
var anchor := Vector2.ZERO
var length := 100.0            # rest length of the string
var goal_length := 100.0       # drop-in target length
var delay := 0.0
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var body_rot := 0.0
var danger := 0.0              # 0..1, how close to the danger line
var rope_alpha := 1.0
var squash_t := 1.0            # time since last hit (s)
var squash_dir := Vector2.UP
var spin := 0.0                # rad/s while falling
var tilt := 0.0                # perspective tilt phase while falling
var fall_t := 0.0
var ang_off := 0.0             # body angle relative to the string (rad)
var ang_vel := 0.0
var wind := 0.0                # horizontal breeze acceleration (px/s²)
var startle_t := 0.0           # wide eye + flinch after a near miss
var look_at := Vector2.ZERO    # world point the pupil follows
var has_look := false
var squint := false            # nearest target while the player aims
var _pupil := Vector2.ZERO
var _open := 1.0
var _closed_t := 0.0           # "–" eye after a hit
var _blink_in := 4.0
var _blink_t := 0.0
var _clock := 0.0

var _pts := PackedVector2Array()
var _prev := PackedVector2Array()
var _rope_len := 0.0
var _attached := true
var _screen_h := 1280.0
var _pluck_cd := 0.0


func _ready() -> void:
	_pts.resize(N)
	_prev.resize(N)
	visible = false


func spawn(k: Kind, anchor_pos: Vector2, start_len: float, target_len: float, wait: float) -> void:
	kind = k
	hp = HP[k]
	radius = RADIUS[k]
	anchor = anchor_pos
	length = start_len
	goal_length = target_len
	delay = wait
	pos = anchor + Vector2(0, start_len)
	vel = Vector2.ZERO
	body_rot = 0.0
	ang_off = 0.0
	ang_vel = 0.0
	startle_t = 0.0
	_pluck_cd = 0.0
	danger = 0.0
	rope_alpha = 1.0
	squash_t = 1.0
	spin = 0.0
	tilt = 0.0
	fall_t = 0.0
	modulate.a = 1.0
	_pupil = Vector2.ZERO
	_open = 1.0
	_closed_t = 0.0
	_blink_in = randf_range(3.0, 7.0)
	_blink_t = 0.0
	_clock = randf() * 10.0
	_attached = true
	_rope_len = start_len
	for i in N:
		_pts[i] = anchor.lerp(pos, float(i) / (N - 1))
		_prev[i] = _pts[i]
	phase = Phase.HANGING
	visible = true


func is_hittable() -> bool:
	return phase == Phase.HANGING and delay <= 0.0


func points() -> int:
	return POINTS[kind]


func speed_mul() -> float:
	return SPEED_MUL[kind]


func mass() -> float:
	return MASS[kind]


## Circle used for target-to-target contact (the rod uses its half span).
func contact_radius() -> float:
	return ROD_HALF + radius * 0.4 if kind == Kind.ROD else radius


## Closest point of the body's collision shape to `p`.
func closest_point(p: Vector2) -> Vector2:
	if kind != Kind.ROD:
		return pos
	var axis := Vector2.RIGHT.rotated(body_rot) * ROD_HALF
	var a := pos - axis
	var b := pos + axis
	return Geometry2D.get_closest_point_to_segment(p, a, b)


func bottom_y() -> float:
	return pos.y + radius


## Returns true if the target died from this hit. `at` is the contact point:
## off-centre contacts add torque, so the body wobbles about its string.
func hit(impulse: Vector2, at: Vector2) -> bool:
	var m: float = MASS[kind]
	vel += impulse / m
	var arm := at - pos
	ang_vel += clampf(arm.cross(impulse) / (radius * radius * m) * 0.9, -14.0, 14.0)
	squash_t = 0.0
	squash_dir = impulse.normalized() if impulse.length() > 0.01 else Vector2.UP
	_closed_t = 1.2
	hp -= 1
	if hp > 0:
		return false
	_snap(impulse)
	return true


## Knock from a neighbour or a near miss: no damage, only motion.
func push(impulse: Vector2, at: Vector2) -> void:
	var m: float = MASS[kind]
	vel += impulse / m
	ang_vel += clampf((at - pos).cross(impulse) / (radius * radius * m) * 0.6, -6.0, 6.0)


## A ball crossing the string plucks it. Returns true when it did.
func pluck(p: Vector2, v: Vector2, r: float) -> bool:
	if not _attached or _pluck_cd > 0.0:
		return false
	var hit_any := false
	for i in range(2, N - 2):
		if _pts[i].distance_to(p) < r + 5.0:
			hit_any = true
			break
	if not hit_any:
		return false
	_pluck_cd = 0.25
	var kick := Vector2(v.x, v.y * 0.3).limit_length(900.0) * (1.0 / 120.0) * 0.45
	for i in range(1, N - 1):
		var fall := exp(-pow(_pts[i].distance_to(p) / 60.0, 2.0))
		_prev[i] = _pts[i] - kick * fall
	vel += Vector2(v.x, 0).limit_length(600.0) * 0.04 / MASS[kind]
	return true


func startle(from: Vector2) -> void:
	if startle_t > 0.0 or _closed_t > 0.0:
		return
	startle_t = 0.45
	var away := (pos - from).normalized()
	push(away * 45.0, pos - away * radius * 0.5 + Vector2(0, -radius * 0.3))


func step(dt: float, descent: float, danger_y: float, danger_band: float, screen_h: float) -> void:
	_screen_h = screen_h
	_pluck_cd = maxf(0.0, _pluck_cd - dt)
	match phase:
		Phase.HANGING:
			if delay > 0.0:
				delay -= dt
				visible = delay <= 0.0
				return
			if length < goal_length:
				length = minf(goal_length, length + 900.0 * dt)
			else:
				length += descent * SPEED_MUL[kind] * dt
				goal_length = length
			_body_step(dt)
			danger = clampf(1.0 - (danger_y - bottom_y()) / danger_band, 0.0, 1.0)
			_rope_step(dt)
		Phase.FALLING:
			fall_t += dt
			vel.y += GRAVITY * dt
			pos += vel * dt
			body_rot += spin * dt
			tilt += 4.5 * dt
			modulate.a = clampf(1.0 - (fall_t - 0.45) / 0.5, 0.0, 1.0)
			_rope_step(dt)
			if (pos.y - radius > screen_h + 40.0 or modulate.a <= 0.0) and rope_alpha <= 0.0:
				phase = Phase.OFF
				visible = false


func _body_step(dt: float) -> void:
	vel.y += GRAVITY * dt
	vel.x += wind * dt / MASS[kind]
	var d := pos - anchor
	var dist := d.length()
	if dist > length and dist > 0.001:
		var dir := d / dist
		# Near the danger line the string pulls tighter (stiffer, less bounce).
		var k := STRING_K * (1.0 + danger * 0.9)
		vel -= dir * k * (dist - length) * dt
		# Extra damping along the string keeps the bounce elastic but calm.
		vel -= dir * vel.dot(dir) * (2.2 + danger * 2.0) * dt
	vel *= exp(-DAMPING * dt)
	pos += vel * dt
	# Swinging drives the wobble a little (the string pulls the top first).
	var swing := atan2(-(pos.x - anchor.x), pos.y - anchor.y)
	ang_vel += (-ANG_K * ang_off - ANG_C * ang_vel) * dt
	ang_off = clampf(ang_off + ang_vel * dt, -1.1, 1.1)
	body_rot = swing + ang_off


func _rope_step(dt: float) -> void:
	var g := Vector2(wind * 0.6, GRAVITY) * dt * dt
	var last := N - 1
	for i in range(1, N):
		if i == last and _attached:
			continue
		var cur := _pts[i]
		var v := (cur - _prev[i]) * 0.985
		_prev[i] = cur
		_pts[i] = cur + v + g
	_pts[0] = eyelet()
	if _attached:
		_pts[last] = pos
		_rope_len = maxf(length, pos.distance_to(anchor))
	else:
		_rope_len = move_toward(_rope_len, 0.0, 900.0 * dt)
		rope_alpha = maxf(0.0, rope_alpha - dt / 0.4)
	var seg := _rope_len / (N - 1)
	for _it in 4:
		for i in last:
			var d := _pts[i + 1] - _pts[i]
			var l := d.length()
			if l <= seg or l < 0.0001:
				continue
			var wa := 0.0 if i == 0 else 1.0
			var wb := 0.0 if (i + 1 == last and _attached) else 1.0
			var sum := wa + wb
			if sum == 0.0:
				continue
			var off := d * ((l - seg) / l)
			_pts[i] += off * (wa / sum)
			_pts[i + 1] -= off * (wb / sum)
	if not _attached:
		# The recoiling stub folds against the rail instead of passing it.
		for i in range(1, N):
			_pts[i].y = maxf(_pts[i].y, anchor.y + 1.0)


func _snap(impulse: Vector2) -> void:
	phase = Phase.FALLING
	_attached = false
	vel = impulse * 0.5 / MASS[kind] + Vector2(0, -120)
	# Keep the wobble it already had; heavier bodies tumble slower.
	spin = ang_vel * 0.5 + randf_range(3.0, 6.0) * (1.0 if impulse.x >= 0.0 else -1.0) / MASS[kind]
	# Whip recoil: the freed rope springs upward for a few frames.
	for i in range(1, N):
		var k := float(i) / (N - 1)
		_prev[i] = _pts[i] + Vector2(randf_range(-2.0, 2.0), 9.0 + 12.0 * k)


## Squash (1.25 x 0.8 along the hit) for 60 ms, then an elastic return;
## while falling, a cosine on one axis reads as a perspective tilt.
func body_xform(offset := Vector2.ZERO) -> Transform2D:
	var sx := 1.0
	var sy := 1.0
	var t := squash_t
	if t < 0.06:
		var k := t / 0.06
		sx = 1.0 + 0.25 * k
		sy = 1.0 - 0.2 * k
	elif t < 0.6:
		var e := exp(-(t - 0.06) * 12.0) * cos((t - 0.06) * 36.0)
		sx = 1.0 + 0.25 * e
		sy = 1.0 - 0.2 * e
	var a := squash_dir.angle() + PI * 0.5
	var squash := Transform2D(a, Vector2.ZERO) * Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2.ZERO) * Transform2D(-a, Vector2.ZERO)
	var tilt_x := cos(tilt) if phase == Phase.FALLING else 1.0
	var body := Transform2D(body_rot, Vector2.ZERO) * Transform2D(0.0, Vector2(maxf(absf(tilt_x), 0.08) * signf(tilt_x + 0.0001), 1.0), 0.0, Vector2.ZERO)
	return Transform2D(0.0, pos + offset) * squash * body

## Hook tilt, following the top rope segment's angle from vertical.
func hook_angle() -> float:
	var d := _pts[1] - _pts[0]
	return clampf(atan2(-d.x, d.y) * HOOK_TILT, -0.7, 0.7)


## Where the string leaves the hook; `anchor` is the hook's pivot on the rail.
func eyelet() -> Vector2:
	var d := _pts[1] - _pts[0]
	var a := clampf(atan2(-d.x, d.y) * HOOK_TILT, -0.7, 0.7) if d.length() > 0.01 else 0.0
	return anchor + Vector2(0, HOOK_LEN).rotated(a)


func _process(delta: float) -> void:
	if phase == Phase.OFF:
		return
	squash_t += delta
	_clock += delta
	_update_eye(delta)
	queue_redraw()


func _update_eye(delta: float) -> void:
	_closed_t = maxf(0.0, _closed_t - delta)
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_t = 0.13
		_blink_in = randf_range(3.0, 7.0)
	_blink_t = maxf(0.0, _blink_t - delta)
	startle_t = maxf(0.0, startle_t - delta)
	var goal_open := 0.42 if squint else 1.0
	if startle_t > 0.0:
		goal_open = 1.3
	elif _blink_t > 0.0:
		goal_open = 0.0
	_open = lerpf(_open, goal_open, Pal.damp(0.35, delta))
	# Pupil follows the ball: 0.15 per frame, clamped inside the eye ring.
	var goal := Vector2.ZERO
	if has_look:
		var d := (look_at - pos).rotated(-body_rot)
		goal = d.normalized() * minf(1.0, d.length() / 160.0) if d.length() > 0.01 else Vector2.ZERO
	_pupil = _pupil.lerp(goal, Pal.damp(0.15, delta))


func color() -> Color:
	var base := Pal.BLUE
	match kind:
		Kind.HEAVY: base = Pal.GREEN
		Kind.SPLIT: base = Pal.TEAL
		Kind.ROD: base = Pal.PURPLE
		Kind.DROP: base = Pal.DROP
	if danger > 0.0 and phase == Phase.HANGING:
		var pulse := 0.8 + 0.2 * sin(_clock * TAU * 0.8)
		base = base.lerp(Pal.CORAL, danger * pulse)
	return base


func _draw() -> void:
	if phase == Phase.OFF or delay > 0.0:
		return
	if rope_alpha > 0.0:
		# A string near the danger line pulls tighter and lighter.
		var sc := Pal.STRING.lerp(Pal.INK_DIM, danger * 0.7)
		draw_polyline(_pts, Color(sc, rope_alpha), 2.0 + danger * 0.6, true)
	var col := color()
	var dark := col.darkened(0.45)
	var light := col.lightened(0.22)
	# Shadow, dark rim (down/right), light rim (up/left), body: one light source.
	_shape(Pal.SHADOW_OFFSET, Pal.SHADOW, 0.0)
	_shape(Vector2(1.2, 1.2), dark, 0.0)
	_shape(Vector2(-1.0, -1.0), light, 0.0)
	_shape(Vector2.ZERO, col, -2.0)
	draw_set_transform_matrix(body_xform())
	_eye()
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Draws the silhouette in body space, offset in world space. `grow` thins
## strokes (negative) for the top layer so the two-tone rims show.
func _shape(offset: Vector2, col: Color, grow: float) -> void:
	draw_set_transform_matrix(body_xform(offset))
	match kind:
		Kind.RING:
			Pal.ring(self, Vector2.ZERO, radius - 5.0, col, 9.0 + grow)
		Kind.HEAVY:
			var outer_col := col if hp > 1 else Color(col, col.a * 0.0)
			if hp > 1:
				Pal.ring(self, Vector2.ZERO, radius - 3.0, outer_col, 5.0 + grow)
			else:
				# Cracked outer ring after the first hit.
				for i in 6:
					var a := i * TAU / 6.0 + 0.2
					draw_arc(Vector2.ZERO, radius - 3.0, a, a + 0.62, 6, Color(col, col.a * 0.55), 4.0 + grow, true)
			Pal.ring(self, Vector2.ZERO, radius - 13.0, col, 6.0 + grow)
		Kind.SPLIT:
			var hex := PackedVector2Array()
			for i in 7:
				var a := i * TAU / 6.0 + PI / 6.0
				hex.append(Vector2.from_angle(a) * (radius - 4.0))
			draw_polyline(hex, col, 8.0 + grow, true)
			draw_line(Vector2(0, -radius + 8.0), Vector2(0, -radius * 0.55), col, 2.0 + grow * 0.5, true)
			draw_line(Vector2(0, radius - 8.0), Vector2(0, radius * 0.55), col, 2.0 + grow * 0.5, true)
		Kind.ROD:
			var r := radius + grow * 0.5
			var h := ROD_HALF
			draw_rect(Rect2(-h, -r, h * 2.0, r * 2.0), col)
			Pal.disc(self, Vector2(-h, 0), r, col)
			Pal.disc(self, Vector2(h, 0), r, col)
		Kind.DROP:
			var r := radius + grow * 0.5
			var pts := PackedVector2Array()
			pts.append(Vector2(0, -r * 1.75))
			for i in 17:
				var a := -PI * 0.5 + 0.62 + (TAU - 1.24) * i / 16.0
				pts.append(Vector2.from_angle(a) * r)
			draw_colored_polygon(pts, col)
			pts.append(pts[0])
			draw_polyline(pts, col, 1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _eye() -> void:
	var er := 9.5 if kind != Kind.DROP else 7.0
	var wide := maxf(1.0, _open)
	var pr := er * 0.48 / wide
	er *= lerpf(1.0, wide, 0.5)
	if kind == Kind.ROD or kind == Kind.DROP:
		# Filled bodies: a dark socket keeps the eye readable.
		Pal.disc(self, Vector2.ZERO, er + 2.0, Color(0, 0, 0, 0.22))
	if _closed_t > 0.0 or phase == Phase.FALLING:
		draw_line(Vector2(-er * 0.85, 0), Vector2(er * 0.85, 0), Pal.EYE, 2.4, true)
		return
	var open := clampf(_open, 0.0, 1.0)
	if open < 0.12:
		draw_line(Vector2(-er * 0.85, 0), Vector2(er * 0.85, 0), Pal.EYE, 2.2, true)
		return
	draw_set_transform_matrix(body_xform() * Transform2D(0.0, Vector2(1.0, open), 0.0, Vector2.ZERO))
	Pal.disc(self, Vector2.ZERO, er, Pal.EYE)
	var pupil := _pupil * (er - pr - 1.2)
	Pal.disc(self, pupil, pr, Pal.PUPIL)
	Pal.disc(self, pupil - Vector2(pr, pr) * 0.35, pr * 0.28, Color(Pal.EYE, 0.7))
	draw_set_transform_matrix(body_xform())
	if open < 0.9:
		# Lid lines make the squint read as intent, not just a squash.
		var y := er * open
		draw_line(Vector2(-er, -y), Vector2(er, -y * 0.7), Pal.PUPIL, 1.6, true)
