class_name Target
extends Node2D
## A target hanging from the rail on an elastic string (pooled).
## Body: rigid disc on a one-sided spring with its own angular inertia, so
## off-centre hits make it wobble about the string. String: Verlet rope.
## Everything is drawn in world coordinates; the node itself stays at origin.

enum Kind { RING, HEAVY, SPLIT, ROD, DROP, SHIELD, BOSS, REEL, SHADE }
enum Phase { OFF, HANGING, FALLING }

const N := 10                  # rope points
const GRAVITY := 900.0
const STRING_K := 120.0        # spring stiffness per unit mass (1/s²)
const DAMPING := 1.1

const RADIUS := {Kind.RING: 30.0, Kind.HEAVY: 34.0, Kind.SPLIT: 32.0, Kind.ROD: 15.0, Kind.DROP: 20.0, Kind.SHIELD: 26.0, Kind.BOSS: 46.0, Kind.REEL: 24.0, Kind.SHADE: 26.0}
const HP := {Kind.RING: 1, Kind.HEAVY: 2, Kind.SPLIT: 1, Kind.ROD: 1, Kind.DROP: 1, Kind.SHIELD: 1, Kind.BOSS: 8, Kind.REEL: 1, Kind.SHADE: 1}
const POINTS := {Kind.RING: 10, Kind.HEAVY: 20, Kind.SPLIT: 10, Kind.ROD: 15, Kind.DROP: 5, Kind.SHIELD: 25, Kind.BOSS: 40, Kind.REEL: 20, Kind.SHADE: 25}
const ROD_HALF := 30.0
const HOOK_LEN := 11.5         # rail pivot -> bottom of the hook eyelet
const HOOK_TILT := 0.8
const MASS := {Kind.RING: 1.0, Kind.HEAVY: 1.6, Kind.SPLIT: 1.1, Kind.ROD: 1.25, Kind.DROP: 0.6, Kind.SHIELD: 1.3, Kind.BOSS: 3.5, Kind.REEL: 0.9, Kind.SHADE: 0.9}
const SHIELD_HALF := deg_to_rad(62.0)   # Vokter: half-width of the front plate
const BOSS_ARC_HALF := deg_to_rad(38.0) # Spinneren: half-width of each orbiting plate
const ANG_K := 55.0            # angular spring back to the string angle (1/s²)
const ANG_C := 2.6             # angular damping (1/s)
const SPEED_MUL := {Kind.RING: 1.0, Kind.HEAVY: 0.85, Kind.SPLIT: 1.0, Kind.ROD: 1.1, Kind.DROP: 1.7, Kind.SHIELD: 0.9, Kind.BOSS: 0.45, Kind.REEL: 1.0, Kind.SHADE: 1.0}

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

# Brain: every behaviour is telegraphed before it acts, so it can be read.
var aggression := 0.0          # 0..1 from the director
var aimed := false             # the player's aim line is on this target
var dodge_dir := 0.0           # side to dodge toward (set by the game)
var threat := Vector2.ZERO     # where the shots come from (shield faces it)
var enraged := false
var tele_t := 0.0              # telegraph (tremble + squint) before a lunge
var shield_ang := PI * 0.5     # world angle of the Vokter plate
var orbit := 0.0               # Spinneren plate orbit
var wants_minion := false      # Spinneren asks the game for a Dykker
var flash_t := 0.0
var alarm := false             # a ball is closing in (Snelle reels up)
var has_cover := false         # Vakt: an x where another target shields it
var cover_x := 0.0
var hidden_amt := 0.0          # Skygge: 0 solid .. 1 faded out
var intro_t := 0.0             # marker ring when first introduced
var fray_t := 0.0              # string frayed: a second precise hit cuts it
var _fray_at := Vector2.ZERO
var _reeled := 0.0
var _calm_t := 0.0
var _shade_t := 0.0
var _shade_hidden := false
var _aim_t := 0.0
var _dodge_cd := 0.0
var _brain_t := 3.0
var _minion_t := 4.0
var _lunge_left := 0.0
var _speed_bonus := 1.0
var _cut := false
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
	aimed = false
	enraged = false
	tele_t = 0.0
	flash_t = 0.0
	wants_minion = false
	orbit = randf() * TAU
	shield_ang = PI * 0.5
	_aim_t = 0.0
	_dodge_cd = 1.0
	_brain_t = randf_range(2.5, 5.0)
	_minion_t = 4.0
	_lunge_left = 0.0
	_speed_bonus = 1.0
	_cut = false
	alarm = false
	has_cover = false
	hidden_amt = 0.0
	intro_t = 0.0
	fray_t = 0.0
	_reeled = 0.0
	_calm_t = 0.0
	_shade_t = randf_range(1.5, 3.0)
	_shade_hidden = false
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
	if k == Kind.ROD:
		vel.x = 70.0 if randf() < 0.5 else -70.0


func is_hittable() -> bool:
	return phase == Phase.HANGING and delay <= 0.0


## Balls collide with the body only while it is there (Skygge fades out).
func is_solid() -> bool:
	return is_hittable() and hidden_amt < 0.6


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


func was_cut() -> bool:
	return _cut


## True when a contact from direction `n` (centre → ball) lands on armour.
func blocks(n: Vector2) -> bool:
	match kind:
		Kind.SHIELD:
			return absf(angle_difference(n.angle(), shield_ang)) < SHIELD_HALF
		Kind.BOSS:
			for k in 2:
				if absf(angle_difference(n.angle(), orbit + PI * k)) < BOSS_ARC_HALF:
					return true
	return false


## Distance test against the top third of the string, just under the hook:
## cutting is a precision shot, not something a stray ball does by luck.
func rope_hit(p: Vector2, r: float) -> bool:
	if not _attached:
		return false
	for i in range(0, 3):
		if Geometry2D.get_closest_point_to_segment(p, _pts[i], _pts[i + 1]).distance_to(p) < r + 1.5:
			return true
	return false


## A precise hit on the string: the first frays it (visible for 4 s), a
## second one while frayed severs it. Returns true when it severed.
func strike_string(p: Vector2) -> bool:
	if fray_t > 0.0:
		cut()
		return true
	fray_t = 4.0
	_fray_at = p
	for i in range(1, 4):
		_prev[i] = _pts[i] - Vector2(randf_range(-2.0, 2.0), 3.0)
	return false


## The string is severed: the body falls whatever its armour or health.
func cut() -> void:
	_cut = true
	hp = 0
	_closed_t = 1.2
	flash_t = 0.07
	_snap(Vector2(0, 60))


## Returns true if the target died from this hit. `at` is the contact point:
## off-centre contacts add torque, so the body wobbles about its string.
func hit(impulse: Vector2, at: Vector2) -> bool:
	var m: float = MASS[kind]
	vel += impulse / m
	var arm := at - pos
	ang_vel += clampf(arm.cross(impulse) / (radius * radius * m) * 0.9, -14.0, 14.0)
	squash_t = 0.0
	squash_dir = impulse.normalized() if impulse.length() > 0.01 else Vector2.UP
	_closed_t = 1.2 if kind != Kind.BOSS else 0.35
	flash_t = 0.07
	hp -= 1
	if hp > 0:
		if kind == Kind.HEAVY and not enraged:
			# Bulwark rage: throws itself down and sinks faster from now on.
			enraged = true
			_lunge_left += 60.0
			_speed_bonus = 1.6
			Sfx.play("whoosh", 0.8, -6.0)
		elif kind == Kind.BOSS and hp == 4:
			enraged = true
			_speed_bonus = 1.4
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
	flash_t = maxf(0.0, flash_t - dt)
	fray_t = maxf(0.0, fray_t - dt)
	match phase:
		Phase.HANGING:
			if delay > 0.0:
				delay -= dt
				visible = delay <= 0.0
				return
			if length < goal_length:
				length = minf(goal_length, length + 900.0 * dt)
			else:
				length += descent * SPEED_MUL[kind] * _speed_bonus * dt
				goal_length = length
			_brain(dt)
			if _lunge_left > 0.0:
				var step_len := minf(_lunge_left, 340.0 * dt)
				length += step_len
				goal_length = length
				_lunge_left -= step_len
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


## Per-type behaviour. Aggression (0..1) shortens reactions and cooldowns.
func _brain(dt: float) -> void:
	var a := aggression
	_dodge_cd = maxf(0.0, _dodge_cd - dt)
	match kind:
		Kind.RING:
			# Vakt: with cover available it slides in behind another target;
			# otherwise it sidesteps a held aim after a readable reaction time.
			if aimed and has_cover and a > 0.12:
				_aim_t += dt
				if _aim_t > lerpf(0.6, 0.25, a):
					var pull := clampf((cover_x - pos.x) / 60.0, -1.0, 1.0)
					vel.x += pull * lerpf(260.0, 520.0, a) * dt
			elif aimed and a > 0.12 and _dodge_cd <= 0.0:
				_aim_t += dt
				if _aim_t > lerpf(0.75, 0.3, a):
					vel.x += dodge_dir * lerpf(150.0, 300.0, a) / MASS[kind]
					ang_vel += dodge_dir * 3.0
					_dodge_cd = lerpf(2.6, 1.2, a)
					_aim_t = 0.0
					startle_t = 0.35
			elif not aimed:
				_aim_t = maxf(0.0, _aim_t - dt * 2.0)
		Kind.ROD:
			# Pendel: pumps its own swing up to a cap, so it is never still.
			var swing := atan2(pos.x - anchor.x, pos.y - anchor.y)
			if absf(swing) < lerpf(0.28, 0.5, a):
				var dir := signf(vel.x) if absf(vel.x) > 4.0 else (1.0 if randf() < 0.5 else -1.0)
				vel.x += dir * lerpf(40.0, 95.0, a) * dt
		Kind.DROP:
			_lunge_brain(dt, lerpf(4.5, 2.2, a), 50.0)
		Kind.SHIELD:
			# Vokter: the plate turns toward the slingshot with some lag.
			var want := (threat - pos).angle()
			shield_ang = rotate_toward(shield_ang, want, lerpf(1.6, 3.6, a) * dt)
		Kind.REEL:
			# Snelle: winches up toward the rail when threatened, lets itself
			# back down once it has been calm for a moment.
			if alarm or aimed:
				_calm_t = 0.0
				var d := minf(lerpf(240.0, 380.0, a) * dt, maxf(0.0, length - 40.0))
				if d > 0.0 and _reeled == 0.0:
					Sfx.play("reel", randf_range(0.95, 1.1))
				length -= d
				_reeled += d
			else:
				_calm_t += dt
				if _calm_t > lerpf(0.5, 1.0, a) and _reeled > 0.0:
					var u := minf(_reeled, 120.0 * dt)
					length += u
					_reeled -= u
			goal_length = length
		Kind.SHADE:
			# Skygge: visible for a while, then fades out (shots pass through),
			# then back. Only its eye and its string stay readable.
			_shade_t -= dt
			if _shade_t <= 0.0:
				_shade_hidden = not _shade_hidden
				_shade_t = lerpf(1.3, 1.9, a) if _shade_hidden else lerpf(2.6, 1.7, a) * randf_range(0.85, 1.2)
				if _shade_hidden:
					Sfx.play("fade", randf_range(0.95, 1.05))
			hidden_amt = move_toward(hidden_amt, 1.0 if _shade_hidden else 0.0, dt / 0.35)
		Kind.BOSS:
			orbit += lerpf(1.0, 1.7, a) * (1.35 if enraged else 1.0) * dt
			_minion_t -= dt
			if _minion_t <= 0.0:
				_minion_t = lerpf(6.0, 3.5, a)
				wants_minion = true
			_lunge_brain(dt, lerpf(10.0, 6.0, a), 40.0)


## Tremble and squint for 0.45 s, then drop by `drop` px (scaled).
func _lunge_brain(dt: float, every: float, drop: float) -> void:
	if tele_t > 0.0:
		tele_t -= dt
		if tele_t <= 0.0:
			_lunge_left += drop * (_screen_h / 1280.0)
			Sfx.play("whoosh", randf_range(0.95, 1.15), -8.0)
		return
	_brain_t -= dt
	if _brain_t <= 0.0:
		_brain_t = every * randf_range(0.8, 1.25)
		tele_t = 0.45


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
	var jitter := Vector2.ZERO
	if tele_t > 0.0:
		jitter = Vector2(randf_range(-1.8, 1.8), randf_range(-1.0, 1.0))
	return Transform2D(0.0, pos + offset + jitter) * squash * body

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
	intro_t = maxf(0.0, intro_t - delta)
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
	var goal_open := 0.42 if (squint or tele_t > 0.0) else 1.0
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
		Kind.SHIELD: base = Pal.ARMOR
		Kind.BOSS: base = Pal.BOSS
		Kind.REEL: base = Pal.REEL
		Kind.SHADE: base = Pal.SHADE
	if danger > 0.0 and phase == Phase.HANGING:
		var pulse := 0.8 + 0.2 * sin(_clock * TAU * 0.8)
		base = base.lerp(Pal.CORAL, danger * pulse)
	if flash_t > 0.0:
		# One-frame-ish matte flash on impact (lighter, never glowing).
		base = base.lerp(Pal.EYE, 0.55 * flash_t / 0.07)
	return base


func _draw() -> void:
	if phase == Phase.OFF or delay > 0.0:
		return
	if rope_alpha > 0.0:
		# Two-tone string: dark underside down/right, body, and a fine lit edge
		# up/left. Near the danger line it pulls tighter and lighter.
		var sc := Pal.STRING.lerp(Pal.INK_DIM, danger * 0.7)
		var w := 2.0 + danger * 0.6
		draw_set_transform(Vector2(0.9, 1.1))
		draw_polyline(_pts, Color(Pal.METAL_DARK, 0.8 * rope_alpha), w, true)
		draw_set_transform(Vector2.ZERO)
		draw_polyline(_pts, Color(sc, rope_alpha), w, true)
		draw_set_transform(Vector2(-0.45, -0.45))
		draw_polyline(_pts, Color(Pal.INK_DIM, 0.35 * rope_alpha), 0.7, true)
		draw_set_transform(Vector2.ZERO)
		if fray_t > 0.0 and _attached:
			# Frayed: a few loose fibres at the nearest point, blinking faster
			# as the fray is about to mend.
			var q := _pts[1]
			for i in range(1, 4):
				if _pts[i].distance_to(_fray_at) < q.distance_to(_fray_at):
					q = _pts[i]
			var blink := 0.6 + 0.4 * sin(_clock * lerpf(6.0, 18.0, 1.0 - fray_t / 4.0))
			for k in 3:
				var a := -0.9 + k * 0.9
				draw_line(q, q + Vector2.from_angle(a) * 6.0, Color(Pal.INK, 0.7 * blink * rope_alpha), 1.2, true)
				draw_line(q, q + Vector2.from_angle(PI - a) * 6.0, Color(Pal.INK, 0.7 * blink * rope_alpha), 1.2, true)
	var col := color()
	var dark := col.darkened(0.45)
	var light := col.lightened(0.22)
	if hidden_amt > 0.0:
		# Skygge fades as a whole; only a faint outline and the eye remain.
		var keep := 1.0 - 0.9 * hidden_amt
		col.a *= keep
		dark.a *= keep
		light.a *= keep
	if intro_t > 0.0:
		# First sighting: a slow dashed ring marks the new enemy.
		var k := minf(1.0, intro_t / 0.5)
		for i in 12:
			var a0 := _clock * 0.8 + i * TAU / 12.0
			draw_arc(pos, radius + 16.0, a0, a0 + 0.3, 6, Color(Pal.INK, 0.5 * k), 1.5, true)
	# Soft contact shadow, sharp shadow, dark rim (down/right), light rim
	# (up/left), body: one light source for everything.
	draw_set_transform_matrix(body_xform(Pal.SHADOW_OFFSET * 2.0))
	var half := Vector2(ROD_HALF + radius, radius) if kind == Kind.ROD else Vector2(radius, radius)
	Pal.soft_shadow(self, Vector2.ZERO, half)
	_shape(Pal.SHADOW_OFFSET, Color(Pal.SHADOW, Pal.SHADOW.a * (1.0 - hidden_amt)), 0.0)
	_shape(Vector2(1.2, 1.2), dark, 0.0)
	_shape(Vector2(-1.0, -1.0), light, 0.0)
	_shape(Vector2.ZERO, col, -2.0)
	_armor()
	draw_set_transform_matrix(body_xform())
	_eye()
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Plates that do not turn with the body: the Vokter's front plate and the
## Spinneren's two orbiting plates, plus the boss's remaining-health pips.
func _armor() -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var alpha := modulate.a
	match kind:
		Kind.SHIELD:
			_plate(radius + 5.0, shield_ang, SHIELD_HALF, 8.0)
		Kind.BOSS:
			for k in 2:
				_plate(radius + 11.0, orbit + PI * k, BOSS_ARC_HALF, 7.0)
			if phase == Phase.HANGING:
				var hp_max: int = HP[kind]
				for i in hp_max:
					var x := (i - (hp_max - 1) * 0.5) * 10.0
					var c := Color(Pal.INK, 0.85 * alpha) if i < hp else Color(Pal.INK_FAINT, 0.6 * alpha)
					draw_circle(pos + Vector2(x, radius + 26.0), 2.6, c, true, -1.0, true)


func _plate(r: float, center: float, half: float, w: float) -> void:
	var a0 := center - half
	var a1 := center + half
	draw_arc(pos + Pal.SHADOW_OFFSET, r, a0, a1, 20, Pal.SHADOW, w, true)
	draw_arc(pos + Vector2(1.2, 1.2), r, a0, a1, 20, Pal.METAL_DARK, w, true)
	draw_arc(pos, r, a0, a1, 20, Pal.METAL_LIGHT, w - 1.5, true)
	draw_arc(pos - Vector2(0.8, 0.8), r + w * 0.3, a0 + 0.05, a1 - 0.05, 20, Color(Pal.INK, 0.25), 1.0, true)


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
		Kind.SHIELD:
			Pal.ring(self, Vector2.ZERO, radius - 5.0, col, 8.0 + grow)
		Kind.REEL:
			Pal.ring(self, Vector2.ZERO, radius - 4.0, col, 7.0 + grow)
			for i in 4:
				var d := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0)
				draw_line(d * 11.0, d * (radius - 7.0), col, 3.0 + grow * 0.5, true)
		Kind.SHADE:
			draw_colored_polygon(_crescent(radius + grow * 0.5), col)
		Kind.BOSS:
			var hexf := PackedVector2Array()
			for i in 6:
				hexf.append(Vector2.from_angle(i * TAU / 6.0 + PI / 6.0) * (radius + grow * 0.5))
			draw_colored_polygon(hexf, col)
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


## Crescent: outer half-circle and an inner half-ellipse sharing the tips,
## thick on the left, tapering to points top and bottom. Never self-crosses.
func _crescent(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := -PI * 0.5 + PI * i / 16.0
		pts.append(Vector2(-cos(a) * r, sin(a) * r))
	for i in 17:
		var a := PI * 0.5 - PI * i / 16.0
		pts.append(Vector2(-cos(a) * r * 0.22, sin(a) * r * 0.96))
	return pts


func _eye() -> void:
	# The Skygge's eye sits in the thick part of the crescent.
	var eo := Vector2(-radius * 0.6, 0.0) if kind == Kind.SHADE else Vector2.ZERO
	var bx := body_xform() * Transform2D(0.0, eo)
	draw_set_transform_matrix(bx)
	var er := 9.5
	if kind == Kind.DROP:
		er = 7.0
	elif kind == Kind.BOSS:
		er = 15.0
	var wide := maxf(1.0, _open)
	var pr := er * 0.48 / wide
	er *= lerpf(1.0, wide, 0.5)
	if kind == Kind.ROD or kind == Kind.DROP or kind == Kind.BOSS or kind == Kind.SHADE:
		# Filled bodies: a dark socket keeps the eye readable.
		Pal.disc(self, Vector2.ZERO, er + 2.0, Color(0, 0, 0, 0.22))
	if _closed_t > 0.0 or phase == Phase.FALLING:
		draw_line(Vector2(-er * 0.85, 0), Vector2(er * 0.85, 0), Pal.EYE, 2.4, true)
		return
	var open := clampf(_open, 0.0, 1.0)
	if open < 0.12:
		draw_line(Vector2(-er * 0.85, 0), Vector2(er * 0.85, 0), Pal.EYE, 2.2, true)
		return
	draw_set_transform_matrix(bx * Transform2D(0.0, Vector2(1.0, open), 0.0, Vector2.ZERO))
	Pal.disc(self, Vector2.ZERO, er, Pal.EYE)
	var pupil := _pupil * (er - pr - 1.2)
	Pal.disc(self, pupil, pr, Pal.PUPIL)
	Pal.disc(self, pupil - Vector2(pr, pr) * 0.35, pr * 0.28, Color(Pal.EYE, 0.7))
	draw_set_transform_matrix(bx)
	if enraged:
		# Brows pulled in: rage reads at a glance.
		for sx: float in [-1.0, 1.0]:
			draw_line(Vector2(sx * er * 1.15, -er * 1.25), Vector2(sx * er * 0.25, -er * 0.8), Pal.EYE if kind != Kind.BOSS else Pal.PUPIL, 2.2, true)
	if open < 0.9:
		# Lid lines make the squint read as intent, not just a squash.
		var y := er * open
		draw_line(Vector2(-er, -y), Vector2(er, -y * 0.7), Pal.PUPIL, 1.6, true)
