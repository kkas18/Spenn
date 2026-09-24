class_name Target
extends Node2D
## A target hanging from the rail on an elastic string (pooled).
## Body: point mass on a one-sided spring. String: Verlet rope for visuals.
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

var _pts := PackedVector2Array()
var _prev := PackedVector2Array()
var _rope_len := 0.0
var _attached := true
var _screen_h := 1280.0


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
	danger = 0.0
	rope_alpha = 1.0
	squash_t = 1.0
	spin = 0.0
	tilt = 0.0
	fall_t = 0.0
	modulate.a = 1.0
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


## Returns true if the target died from this hit.
func hit(impulse: Vector2) -> bool:
	vel += impulse
	squash_t = 0.0
	squash_dir = impulse.normalized() if impulse.length() > 0.01 else Vector2.UP
	hp -= 1
	if hp > 0:
		return false
	_snap(impulse)
	return true


func step(dt: float, descent: float, danger_y: float, danger_band: float, screen_h: float) -> void:
	_screen_h = screen_h
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
	var d := pos - anchor
	var dist := d.length()
	if dist > length and dist > 0.001:
		var dir := d / dist
		vel -= dir * STRING_K * (dist - length) * dt
		# Extra damping along the string keeps the bounce elastic but calm.
		vel -= dir * vel.dot(dir) * 2.2 * dt
	vel *= exp(-DAMPING * dt)
	pos += vel * dt
	body_rot = atan2(-(pos.x - anchor.x), pos.y - anchor.y)


func _rope_step(dt: float) -> void:
	var g := Vector2(0, GRAVITY) * dt * dt
	var last := N - 1
	for i in range(1, N):
		if i == last and _attached:
			continue
		var cur := _pts[i]
		var v := (cur - _prev[i]) * 0.985
		_prev[i] = cur
		_pts[i] = cur + v + g
	_pts[0] = anchor
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
	vel = impulse * 0.5 + Vector2(0, -120)
	spin = randf_range(3.0, 6.0) * (1.0 if impulse.x >= 0.0 else -1.0)
	# Whip recoil: the freed rope springs upward for a few frames.
	for i in range(1, N):
		var k := float(i) / (N - 1)
		_prev[i] = _pts[i] + Vector2(randf_range(-2.0, 2.0), 9.0 + 12.0 * k)


## Squash (1.25 x 0.8 along the hit) for 60 ms, then an elastic return;
## while falling, a cosine on one axis reads as a perspective tilt.
func body_xform() -> Transform2D:
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
	return Transform2D(0.0, pos) * squash * body

## Angle of the top rope segment relative to vertical (for the rail hooks).
func hook_angle() -> float:
	var d := _pts[1] - _pts[0]
	return atan2(-d.x, d.y)


func _process(delta: float) -> void:
	if phase != Phase.OFF:
		squash_t += delta
		queue_redraw()


func _draw() -> void:
	if phase == Phase.OFF or delay > 0.0:
		return
	if rope_alpha > 0.0:
		draw_polyline(_pts, Color(Pal.STRING, rope_alpha), 2.0, true)
	var col := color()
	Pal.shadow_disc(self, pos, radius)
	draw_set_transform_matrix(body_xform())
	Pal.ring(self, Vector2.ZERO, radius - 4.0, col, 8.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func color() -> Color:
	match kind:
		Kind.HEAVY: return Pal.GREEN
		Kind.SPLIT: return Pal.TEAL
		Kind.ROD: return Pal.PURPLE
		Kind.DROP: return Pal.DROP
	return Pal.BLUE
