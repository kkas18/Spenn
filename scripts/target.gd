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
# Evasion profile per kind: [reaction s (at aggression 0), slide px,
# slide speed px/s, hop px, aggression needed]. Reactions shorten and moves
# grow with aggression; every move is telegraphed by a narrowed, watching
# eye first, and followed by a cooldown, so it can be read and punished.
const EVADE := {
	Kind.RING: [0.7, 110.0, 330.0, 55.0, 0.0],
	Kind.HEAVY: [0.95, 60.0, 150.0, 0.0, 0.35],
	Kind.SPLIT: [0.55, 130.0, 390.0, 0.0, 0.2],
	Kind.ROD: [0.75, 90.0, 260.0, 0.0, 0.3],
	Kind.SHIELD: [0.9, 70.0, 210.0, 0.0, 0.5],
	Kind.REEL: [0.5, 85.0, 300.0, 0.0, 0.25],
}
# Material. Soft bodies are jelly: a ring of radial springs that dents
# where it is struck, bulges elsewhere (area is kept), ripples round and
# lags behind when the body is swung. Rigid bodies keep their shape; they
# ring briefly, rock and spin instead.
const SOFT_KINDS := [Kind.RING, Kind.SPLIT, Kind.DROP, Kind.SHADE]
const SOFT_N := 18
const SOFT_K := 340.0          # radial spring (1/s²)
const SOFT_C := 7.5            # damping (1/s)
const SOFT_COUPLE := 900.0     # neighbour coupling: dents spread as ripples
const SOFT_INERTIA := 0.0011   # how far the jelly sloshes per px/s² of swing
const POP_TIME := 0.08

# Temperament, rolled per target so no two behave quite alike.
enum Temper { CALM, TIMID, BOLD, ERRATIC }

const SPEED_MUL := {Kind.RING: 1.0, Kind.HEAVY: 0.85, Kind.SPLIT: 1.0, Kind.ROD: 1.1, Kind.DROP: 1.7, Kind.SHIELD: 0.9, Kind.BOSS: 0.45, Kind.REEL: 1.0, Kind.SHADE: 1.0}

var kind: Kind = Kind.RING
var soft := false
var temper: Temper = Temper.CALM
var _sd := PackedFloat32Array()  # soft: radial displacement per spoke (px)
var _sv := PackedFloat32Array()  # soft: radial velocity per spoke
var _last_vel := Vector2.ZERO
var _ring_t := 1.0             # rigid: time since the last knock (metal ring)
var _ring_dir := Vector2.RIGHT
var _wander_t := 3.0           # idle drift along the rail
var _hue_shift := 0.0          # each one a slightly different shade of its kind
var _dropping := false        # still paying out its string on the way in
var _gone := false             # burst jelly: the body is gone, the string recoils
var pop_t := 0.0               # soft: squashed for a moment before it bursts
# Teasing: close to the line they turn smug, dance and mock near misses.
var smug := 0.0                # 0..1: half-lidded eye and a raised brow
var _taunt := -1.0             # time into a taunt (<0: none)
var _taunt_in := 3.0           # until the next unprompted taunt
var _taunt_delay := -1.0       # a near miss is mocked a moment later
static var _last_tease_ms := 0
# Teamwork: a sturdy one steps into the line of fire to shield an ally.
var covered := false           # an ally is guarding this one: it holds still
var _guard_wait := -1.0        # reaction time before the guard moves
var _guard_x := 0.0
var guard_of: Target = null    # whom this one is shielding (eye follows it)
var _queued_x := NAN           # erratic: the real slide after the feint
var _queued_speed := 0.0
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
var scared := false            # overload: panics, stops sinking, climbs its string
# Chain reactions: a struck body can knock into others; a falling one lands
# on whatever hangs below. `chain_depth` counts the links back to the ball.
var struck_t := 0.0
var chain_depth := 0
var crushed: Array[int] = []    # targets this falling body has already hit

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
# Threat reading (set by the game each frame from the predicted shot).
var threat_lvl := 0.0          # 0..1, how squarely the shot path crosses it
var incoming := false          # a ball in flight will pass close, with time to react
var slide_lo := 0.0            # the anchor may slide within [lo, hi] on the rail
var slide_hi := 0.0
var _slide_to := NAN
var _slide_speed := 0.0
var _hop_left := 0.0
var _hopped := 0.0
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

var _body: Node2D                  # lit layer: string, shadow, body (see rendering)
var _face: Node2D                  # face layer: eye, mouth, details
var _xf := Transform2D.IDENTITY    # this frame's body transform
var _jit := Vector2.ZERO           # this frame's tremble, shared by every layer
var _m_pts := PackedVector2Array()  # body mesh (body space)
var _m_base := PackedVector2Array() # rest positions (jelly moves from these)
var _m_uv := PackedVector2Array()   # band-coded normals
var _m_sh := PackedVector2Array()   # the same, in the shadow band
var _m_idx := PackedInt32Array()
var _m_col := PackedColorArray()
var _m_dv := PackedInt32Array()     # vertices the jelly moves
var _m_dd := PackedVector2Array()   # ... along this direction
var _m_ds := PackedFloat32Array()   # ... by the surface at this spoke
var _m_mem := 0                     # leading vertices: the membrane
var _m_dim := Vector2i(-1, -1)      # vertex range at reduced alpha (cracked ring)
var _m_key := -1
var _one_col := PackedColorArray([Color.WHITE])
var _r_mid := PackedVector2Array()  # string strip (world space)
var _r_pts := PackedVector2Array()
var _r_uv := PackedVector2Array()
var _r_idx := PackedInt32Array()
var _p_pts := PackedVector2Array()  # armour plates (world space)
var _p_uv := PackedVector2Array()
var _p_idx := PackedInt32Array()
var _p_col := PackedColorArray()

var _pts := PackedVector2Array()
var _prev := PackedVector2Array()
var _rope_len := 0.0
var _attached := true
var _screen_h := 1280.0
var _pluck_cd := 0.0


func _ready() -> void:
	_pts.resize(N)
	_prev.resize(N)
	_sd.resize(SOFT_N)
	_sv.resize(SOFT_N)
	_setup_canvas()
	visible = false


func spawn(k: Kind, anchor_pos: Vector2, start_len: float, target_len: float, wait: float) -> void:
	kind = k
	soft = k in SOFT_KINDS
	_m_key = -1
	_sd.fill(0.0)
	_sv.fill(0.0)
	_last_vel = Vector2.ZERO
	_ring_t = 1.0
	_wander_t = randf_range(2.0, 5.0)
	_queued_x = NAN
	pop_t = 0.0
	_gone = false
	_dropping = false
	_hue_shift = randf_range(-0.035, 0.035)
	covered = false
	_guard_wait = -1.0
	guard_of = null
	smug = 0.0
	_taunt = -1.0
	_taunt_in = randf_range(2.0, 4.0)
	_taunt_delay = -1.0
	temper = _roll_temper()
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
	scared = false
	struck_t = 0.0
	chain_depth = 0
	crushed.clear()
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
	threat_lvl = 0.0
	incoming = false
	slide_lo = anchor_pos.x
	slide_hi = anchor_pos.x
	_slide_to = NAN
	_hop_left = 0.0
	_hopped = 0.0
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


## Most are calm early on; the mix grows livelier as aggression rises.
func _roll_temper() -> Temper:
	var r := randf()
	var a := aggression
	if kind == Kind.BOSS:
		return Temper.CALM
	if r < 0.22 + 0.1 * a:
		return Temper.TIMID
	if r < 0.4 + 0.15 * a:
		return Temper.BOLD
	if r < 0.52 + 0.2 * a:
		return Temper.ERRATIC
	return Temper.CALM


static func is_soft_kind(k: int) -> bool:
	return k in SOFT_KINDS


const TAUNT_TIME := 0.9


## Arrival: the string snaps taut and the body bounces on it; jelly dents
## from below, a shell rings.
func _land() -> void:
	vel.y += 50.0
	dent(pos + Vector2(0, radius), 320.0)
	if not soft:
		_ring_t = 0.0
		_ring_dir = Vector2.DOWN
	Sfx.play("knock", randf_range(0.9, 1.15), -12.0)


const GUARD_KINDS := [Kind.HEAVY, Kind.SHIELD]


## Asked to shield `ally`: after a short, readable beat (the eye turns to
## the ally) the hook slides so the body sits on the shot line at `x`.
func guard(x: float, ally: Target) -> bool:
	if not (kind in GUARD_KINDS) or aggression < 0.25 or enraged or _dodge_cd > 0.0 or _guard_wait >= 0.0:
		return false
	_guard_x = x
	guard_of = ally
	_guard_wait = lerpf(0.45, 0.2, aggression)
	return true


func _guard_step(dt: float) -> void:
	if _guard_wait < 0.0:
		return
	_guard_wait -= dt
	if _guard_wait < 0.0:
		var sc := _screen_h / 1280.0
		_slide(anchor.x + (_guard_x - pos.x), EVADE[kind][2] * 1.2 * sc)
		_dodge_cd = lerpf(2.4, 1.2, aggression)
		startle_t = 0.2



## The closer to the line, the smugger (bold ones sooner, timid ones never);
## smug ones break into a little dance now and then.
func _tease(dt: float) -> void:
	var start := 0.25 if temper == Temper.BOLD else 0.4
	var want := 0.0 if (temper == Temper.TIMID or scared) else smoothstep(start, start + 0.25, danger)
	smug = move_toward(smug, want, dt * 1.5)
	if _taunt_delay >= 0.0:
		_taunt_delay -= dt
		if _taunt_delay < 0.0:
			taunt()
	if _taunt >= 0.0:
		_taunt += dt
		if _taunt >= TAUNT_TIME:
			_taunt = -1.0
	elif smug > 0.5 and not aimed:
		_taunt_in -= dt
		if _taunt_in <= 0.0:
			_taunt_in = randf_range(1.5, 3.0) if temper == Temper.BOLD else randf_range(2.5, 4.5)
			taunt()


## A wiggle-and-bob, a wink and (rarely, quietly) a "na-na".
func taunt() -> void:
	if _taunt >= 0.0 or phase != Phase.HANGING or temper == Temper.TIMID or _closed_t > 0.0 or scared:
		return
	_taunt = 0.0
	_blink_t = 0.12
	if soft:
		for i in SOFT_N:
			_sv[i] += cos(3.0 * i * TAU / SOFT_N) * 90.0 * (radius / 30.0)
	var now := Time.get_ticks_msec()
	if now - _last_tease_ms > 1600:
		_last_tease_ms = now
		Sfx.play("tease", randf_range(1.12, 1.3))


## A strike on a soft body: the spokes near the contact are driven inward
## (the dent), the rest take up the displaced area on the next step.
func dent(at: Vector2, speed: float) -> void:
	if not soft:
		_ring_t = 0.0
		_ring_dir = (pos - at).normalized()
		return
	var la := (at - pos).angle() - body_rot
	var k := clampf(speed * 0.55, 60.0, 520.0) * (radius / 30.0)
	for i in SOFT_N:
		var d := angle_difference(la, i * TAU / SOFT_N)
		_sv[i] -= k * exp(-pow(d / 0.6, 2.0))


func _soft_step(dt: float) -> void:
	if not soft or dt <= 0.0:
		return
	var acc := (vel - _last_vel) / dt
	_last_vel = vel
	acc = acc.limit_length(9000.0)
	var mean := 0.0
	var lim := radius * 0.28
	for i in SOFT_N:
		var dir := Vector2.from_angle(i * TAU / SOFT_N + body_rot)
		var lap := _sd[(i + SOFT_N - 1) % SOFT_N] + _sd[(i + 1) % SOFT_N] - 2.0 * _sd[i]
		var f := -SOFT_K * _sd[i] - SOFT_C * _sv[i] + SOFT_COUPLE * lap * 0.25
		# Inertia: speeding up to the right, the jelly lags to the left.
		f += acc.dot(dir) * SOFT_INERTIA * radius
		_sv[i] += f * dt
	for i in SOFT_N:
		_sd[i] = clampf(_sd[i] + _sv[i] * dt, -lim, lim)
		mean += _sd[i]
	mean /= SOFT_N
	for i in SOFT_N:
		_sd[i] -= mean


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


## A falling body still solid and fast enough to knock off what it meets.
func is_crushing(min_speed: float) -> bool:
	return phase == Phase.FALLING and pop_t <= 0.0 and not _gone and modulate.a > 0.35 and vel.length() > min_speed


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
	struck_t = 0.45
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
	if soft:
		pop_t = POP_TIME
		vel = Vector2.ZERO
		spin = 0.0
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
	# Missed it: once the fright passes, it mocks you.
	if temper != Temper.TIMID and _taunt_delay < 0.0:
		_taunt_delay = 0.5
	var away := (pos - from).normalized()
	push(away * 45.0, pos - away * radius * 0.5 + Vector2(0, -radius * 0.3))


func step(dt: float, descent: float, danger_y: float, danger_band: float, screen_h: float) -> void:
	_screen_h = screen_h
	_pluck_cd = maxf(0.0, _pluck_cd - dt)
	struck_t = maxf(0.0, struck_t - dt)
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
				_dropping = true
			else:
				if _dropping:
					_dropping = false
					_land()
				if scared:
					# Overload: it scrambles back up its string, away from you.
					length = maxf(60.0 * (_screen_h / 1280.0), length - 35.0 * dt)
				else:
					length += descent * SPEED_MUL[kind] * _speed_bonus * dt
				goal_length = length
			if scared:
				tele_t = 0.0
				_lunge_left = 0.0
				_dodge_cd = maxf(_dodge_cd, 0.5)
			else:
				_brain(dt)
			_move_anchor(dt)
			if _lunge_left > 0.0:
				var step_len := minf(_lunge_left, 340.0 * dt)
				length += step_len
				goal_length = length
				_lunge_left -= step_len
			_body_step(dt)
			_tease(dt)
			_soft_step(dt)
			danger = clampf(1.0 - (danger_y - bottom_y()) / danger_band, 0.0, 1.0)
			_rope_step(dt)
		Phase.FALLING:
			if pop_t > 0.0:
				# Jelly holds still, squashed around the blow, then bursts.
				pop_t -= dt
				_soft_step(dt)
				_rope_step(dt)
				if pop_t <= 0.0:
					_gone = true
				return
			fall_t += dt
			vel.y += GRAVITY * dt
			pos += vel * dt
			body_rot += spin * dt
			tilt += 4.5 * dt
			_soft_step(dt)
			# Burst jelly is gone; only its recoiling string remains.
			if not soft:
				modulate.a = clampf(1.0 - (fall_t - 0.6) / 0.5, 0.0, 1.0)
			_rope_step(dt)
			if (pos.y - radius > screen_h + 40.0 or modulate.a <= 0.0 or _gone) and rope_alpha <= 0.0:
				phase = Phase.OFF
				visible = false


## Per-type behaviour. Aggression (0..1) shortens reactions and cooldowns.
func _brain(dt: float) -> void:
	var a := aggression
	_dodge_cd = maxf(0.0, _dodge_cd - dt)
	_guard_step(dt)
	_wander(dt)
	match kind:
		Kind.RING:
			# Vakt: with cover available it slides its hook along the rail to
			# hang behind another target; otherwise it evades like the rest.
			if aimed and has_cover and a > 0.12 and _dodge_cd <= 0.0:
				_aim_t += dt
				if _aim_t > lerpf(0.6, 0.25, a):
					_slide(anchor.x + (cover_x - pos.x), EVADE[kind][2] * 0.8)
					_dodge_cd = lerpf(2.4, 1.2, a)
					_aim_t = 0.0
					startle_t = 0.3
			else:
				_evade(dt)
		Kind.HEAVY, Kind.SPLIT:
			if not enraged:
				_evade(dt)
		Kind.ROD:
			_evade(dt)
			# Pendel: pumps its own swing up to a cap, so it is never still.
			var swing := atan2(pos.x - anchor.x, pos.y - anchor.y)
			if absf(swing) < lerpf(0.28, 0.5, a):
				var dir := signf(vel.x) if absf(vel.x) > 4.0 else (1.0 if randf() < 0.5 else -1.0)
				vel.x += dir * lerpf(40.0, 95.0, a) * dt
		Kind.DROP:
			# Dykker: when it sees the shot coming it ducks under it early.
			if (aimed or incoming) and a > 0.3 and tele_t <= 0.0 and _lunge_left <= 0.0 and _dodge_cd <= 0.0:
				_aim_t += dt
				if _aim_t > lerpf(0.6, 0.25, a) or incoming:
					tele_t = 0.2
					_brain_t = lerpf(4.5, 2.2, a)
					_dodge_cd = lerpf(3.0, 1.6, a)
					_aim_t = 0.0
			_lunge_brain(dt, lerpf(4.5, 2.2, a), 50.0)
		Kind.SHIELD:
			# Vokter: the plate turns toward the slingshot with some lag.
			_evade(dt)
			var want := (threat - pos).angle()
			shield_ang = rotate_toward(shield_ang, want, lerpf(1.6, 3.6, a) * dt)
		Kind.REEL:
			_evade(dt)
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
			# Seen in the line of fire, it fades out early (once in a while).
			if aimed and not _shade_hidden and a > 0.3 and _dodge_cd <= 0.0:
				_aim_t += dt
				if _aim_t > lerpf(0.7, 0.3, a):
					_shade_t = 0.0
					_dodge_cd = lerpf(4.0, 2.2, a)
					_aim_t = 0.0
			if _shade_t <= 0.0:
				_shade_hidden = not _shade_hidden
				_shade_t = lerpf(1.3, 1.9, a) if _shade_hidden else lerpf(2.6, 1.7, a) * randf_range(0.85, 1.2)
				if _shade_hidden:
					Sfx.play("fade", randf_range(0.95, 1.05))
			hidden_amt = move_toward(hidden_amt, 1.0 if _shade_hidden else 0.0, dt / 0.35)
		Kind.BOSS:
			# Spinneren: aimed at, it spins its plates faster to close the gap.
			orbit += lerpf(1.0, 1.7, a) * (1.35 if enraged else 1.0) * (lerpf(1.4, 2.2, a) if aimed else 1.0) * dt
			_minion_t -= dt
			if _minion_t <= 0.0:
				_minion_t = lerpf(6.0, 3.5, a)
				wants_minion = true
			_lunge_brain(dt, lerpf(10.0, 6.0, a), 40.0)


## Common evasion: watch the shot (narrowed eye) for a reaction time, then
## slide the hook along the rail away from the path, or retreat up the
## string if there is no room. A ball already in flight is read faster but
## answered with a shorter move. Cooldown after every move.
func _evade(dt: float) -> void:
	var a := aggression
	var prof: Array = EVADE[kind]
	var threatened := aimed or incoming
	if guard_of != null:
		# On guard duty: standing in the line of fire is the point.
		return
	if not threatened:
		_aim_t = maxf(0.0, _aim_t - dt * 2.0)
		return
	if covered and not incoming:
		# Shielded by a teammate: trusts it and stays put.
		return
	if _dodge_cd > 0.0 or a < prof[4]:
		return
	_aim_t += dt
	var react: float = prof[0] * lerpf(1.0, 0.4, a) * [1.0, 0.7, 1.35, 0.9][temper]
	if incoming and not aimed:
		if a < 0.4:
			return
		react *= 0.35
	if _aim_t < react:
		return
	if temper == Temper.BOLD and randf() < 0.35:
		# Stands its ground: a defiant flinch, no move (a chance for you).
		ang_vel -= dodge_dir * 1.5
		_dodge_cd = lerpf(2.0, 1.0, a)
		_aim_t = 0.0
		return
	var sc := _screen_h / 1280.0
	var reach: float = prof[1] * lerpf(0.75, 1.2, a) * sc * (0.6 if incoming and not aimed else 1.0) * [1.0, 1.25, 0.8, 1.0][temper]
	var speed: float = prof[2] * lerpf(1.0, 1.4, a) * sc
	var room_fwd := (slide_hi - anchor.x) if dodge_dir > 0.0 else (anchor.x - slide_lo)
	var room_back := (anchor.x - slide_lo) if dodge_dir > 0.0 else (slide_hi - anchor.x)
	var moved := false
	if room_fwd > 28.0 * sc:
		_slide(anchor.x + dodge_dir * minf(reach, room_fwd), speed)
		moved = true
	elif room_back > reach * 0.8 and a > 0.45:
		# Boxed in on the far side: cut back across the shot instead.
		_slide(anchor.x - dodge_dir * minf(reach * 1.3, room_back), speed * 1.15)
		moved = true
	var hop: float = prof[3]
	if (not moved or (hop > 0.0 and a > 0.35) or temper == Temper.TIMID) and length > 90.0 * sc:
		_hop_left += maxf(hop, 45.0) * sc * lerpf(0.8, 1.3, a)
		Sfx.play("creak", randf_range(0.95, 1.1))
	ang_vel += dodge_dir * 2.5
	startle_t = 0.3
	_dodge_cd = lerpf(2.6, 1.1, a) * (1.3 if kind == Kind.HEAVY else 1.0)
	_aim_t = 0.0


func _slide(x: float, speed: float, quiet := false) -> void:
	x = clampf(x, minf(slide_lo, anchor.x), maxf(slide_hi, anchor.x))
	if absf(x - anchor.x) < 4.0:
		return
	if temper == Temper.ERRATIC and not quiet and randf() < 0.6:
		# Feint: a quick jink the wrong way, then the real move.
		var fake := clampf(anchor.x - signf(x - anchor.x) * 26.0 * (_screen_h / 1280.0), minf(slide_lo, anchor.x), maxf(slide_hi, anchor.x))
		_queued_x = x
		_queued_speed = speed
		x = fake
		speed *= 1.3
	_slide_to = x
	_slide_speed = speed
	if not quiet:
		Sfx.play("slide", randf_range(0.92, 1.08))


## Idle life: now and then a target drifts along the rail on its own. Bold
## ones patrol wider and swing, erratic ones twitch, timid ones keep still.
func _wander(dt: float) -> void:
	if aimed or incoming or not is_nan(_slide_to) or kind == Kind.BOSS or kind == Kind.ROD:
		return
	_wander_t -= dt
	if _wander_t > 0.0:
		return
	var sc := _screen_h / 1280.0
	match temper:
		Temper.TIMID:
			_wander_t = randf_range(5.0, 9.0)
			return
		Temper.BOLD:
			_wander_t = randf_range(2.5, 4.5)
			vel.x += (1.0 if randf() < 0.5 else -1.0) * 70.0
			_slide(anchor.x + randf_range(-80.0, 80.0) * sc, 70.0 * sc, true)
		Temper.ERRATIC:
			_wander_t = randf_range(0.9, 2.0)
			_slide(anchor.x + randf_range(-35.0, 35.0) * sc, 160.0 * sc, true)
		_:
			_wander_t = randf_range(3.5, 6.5)
			if aggression > 0.2:
				_slide(anchor.x + randf_range(-45.0, 45.0) * sc, 55.0 * sc, true)


## The hook glides along the rail (eased in and out); the body follows on
## its string with a natural lag. Hops pull the string up, then it pays
## back out once things are calm.
func _move_anchor(dt: float) -> void:
	if not is_nan(_slide_to):
		var d := _slide_to - anchor.x
		var sp := _slide_speed * clampf(absf(d) / 40.0, 0.35, 1.0)
		var step_x := signf(d) * minf(absf(d), sp * dt)
		anchor.x += step_x
		if absf(_slide_to - anchor.x) < 0.5:
			_slide_to = NAN
			if not is_nan(_queued_x):
				_slide_to = _queued_x
				_slide_speed = _queued_speed
				_queued_x = NAN
	if _hop_left > 0.0:
		var u := minf(_hop_left, 320.0 * dt)
		u = minf(u, maxf(0.0, length - 60.0))
		length -= u
		goal_length = length
		_hopped += u
		_hop_left = 0.0 if u <= 0.0 else _hop_left - u
	elif _hopped > 0.0 and not aimed and not incoming and _dodge_cd < 0.6:
		var back := minf(_hopped, 110.0 * dt)
		length += back
		goal_length = length
		_hopped -= back


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
	# They are alive: when the hook has moved on, the body pulls itself back
	# under it instead of trailing for seconds on a long string.
	if kind != Kind.ROD:
		var off := anchor.x - pos.x
		if absf(off) > 10.0:
			vel.x += clampf(off * 6.0, -700.0, 700.0) * dt / MASS[kind]
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
	# Bending stiffness: a real cord resists sharp kinks, so a fast slide
	# along the rail sends a smooth wave down it instead of a zigzag.
	var bend := 0.35 if soft else 0.25
	for _it in 2:
		for i in range(1, last):
			var mid := (_pts[i - 1] + _pts[i + 1]) * 0.5
			_pts[i] = _pts[i].lerp(mid, bend)
	if not _attached:
		# The recoiling stub folds against the rail instead of passing it.
		for i in range(1, N):
			_pts[i].y = maxf(_pts[i].y, anchor.y + 1.0)


func _snap(impulse: Vector2) -> void:
	phase = Phase.FALLING
	crushed.clear()
	_attached = false
	vel = impulse * 0.5 / MASS[kind] + Vector2(0, -120)
	# Keep the wobble it already had; heavier bodies tumble slower.
	spin = ang_vel * 0.5 + randf_range(3.0, 6.0) * (1.0 if impulse.x >= 0.0 else -1.0) / MASS[kind]
	# Whip recoil: the freed rope springs upward for a few frames.
	for i in range(1, N):
		var k := float(i) / (N - 1)
		_prev[i] = _pts[i] + Vector2(randf_range(-2.0, 2.0), 9.0 + 12.0 * k)


## Squash (1.25 x 0.8 along the hit) for 60 ms, then an elastic return;
## while falling, a cosine on one axis reads as a perspective tilt. The
## tremble is computed once per frame (`_jit`) so every layer moves as one.
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
	# Jelly deforms through its spokes; a rigid shell does not squash.
	var amt := 0.35 if soft else 0.0
	sx = 1.0 + (sx - 1.0) * amt
	sy = 1.0 + (sy - 1.0) * amt
	# Idle breathing: jelly swells and settles, shells barely move.
	if phase == Phase.HANGING:
		var br := sin(_clock * 2.1 + _hue_shift * 90.0) * (0.03 if soft else 0.01)
		sx *= 1.0 + br
		sy *= 1.0 - br * 0.6
	var a := squash_dir.angle() + PI * 0.5
	var squash := Transform2D(a, Vector2.ZERO) * Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2.ZERO) * Transform2D(-a, Vector2.ZERO)
	var tilt_x := cos(tilt) if phase == Phase.FALLING else 1.0
	var wig := 0.0
	var bob := Vector2.ZERO
	if _taunt >= 0.0:
		var env := sin(PI * _taunt / TAUNT_TIME)
		wig = sin(_taunt * TAU * 3.2) * 0.28 * env
		bob = Vector2(0, -absf(sin(_taunt * TAU * 3.2)) * 5.0 * env)
	var body := Transform2D(body_rot + wig, Vector2.ZERO) * Transform2D(0.0, Vector2(maxf(absf(tilt_x), 0.08) * signf(tilt_x + 0.0001), 1.0), 0.0, Vector2.ZERO)
	return Transform2D(0.0, pos + _jit + bob) * squash * body


## This frame's tremble: the lunge telegraph, a struck shell ringing and a
## timid one's nerves.
func _tremble() -> Vector2:
	var j := Vector2.ZERO
	if tele_t > 0.0:
		j = Vector2(randf_range(-1.8, 1.8), randf_range(-1.0, 1.0))
	if not soft and _ring_t < 0.16:
		j += _ring_dir * sin(_ring_t * 110.0) * 2.2 * (1.0 - _ring_t / 0.16)
	if temper == Temper.TIMID and phase == Phase.HANGING and startle_t <= 0.0:
		j += Vector2(sin(_clock * 31.0), cos(_clock * 27.0)) * 0.35
	if scared and phase == Phase.HANGING:
		j += Vector2(sin(_clock * 47.0), cos(_clock * 41.0)) * 1.1
	return j


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
	if phase == Phase.OFF or delay > 0.0:
		return
	intro_t = maxf(0.0, intro_t - delta)
	_ring_t += delta
	squash_t += delta
	_clock += delta
	_update_eye(delta)
	_jit = _tremble()
	_xf = body_xform()
	_body.transform = _xf
	_face.transform = _xf
	_body.queue_redraw()
	_face.queue_redraw()


func _update_eye(delta: float) -> void:
	_closed_t = maxf(0.0, _closed_t - delta)
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_t = 0.13
		_blink_in = randf_range(3.0, 7.0)
	_blink_t = maxf(0.0, _blink_t - delta)
	startle_t = maxf(0.0, startle_t - delta)
	var goal_open := 0.42 if (squint or tele_t > 0.0) else 1.0
	if startle_t > 0.0 or (scared and phase == Phase.HANGING):
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
	var base := _base_color()
	if danger > 0.0 and phase == Phase.HANGING and not scared:
		var pulse := 0.8 + 0.2 * sin(_clock * TAU * 0.8)
		base = base.lerp(Pal.CORAL, danger * pulse)
	if scared:
		# Blanched with fright.
		base = base.lerp(Pal.INK, 0.3)
	if flash_t > 0.0:
		# One-frame-ish matte flash on impact (lighter, never glowing).
		base = base.lerp(Pal.EYE, 0.55 * flash_t / 0.07)
	return base


func _base_color() -> Color:
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
	if kind != Kind.SHIELD and kind != Kind.BOSS:
		base = Color.from_hsv(fposmod(base.h + _hue_shift, 1.0), clampf(base.s + _hue_shift, 0.3, 1.0), base.v)
	return base


# ---------------------------------------------------------------- rendering
# Each target draws through two child canvas items that follow the body's
# transform. `_body` carries the shared lit material (shaders/lit.gdshader)
# and holds the string, the contact shadow and the body as triangle meshes,
# one draw call each; the light is computed per pixel from a normal per
# vertex, so jelly and shells shade as real solids. `_face` holds the eye,
# mouth and small details, mostly circle sprites that batch into one call.
# A body's mesh is built once per kind and health (shells never rebuild it);
# jelly only moves its vertices along the surface of its spring field.

const SHADOW_OFF := Vector2(5.0, 6.0)
const B_JELLY := 0.0
const B_SHADOW := 4.0
const B_CORD := 8.0
const B_WIRE := 12.0
const B_SHELL := 16.0
const B_MEMBRANE := 20.0
const B_METAL := 24.0
const ROPE_SUB := 2                 # smoothing steps per rope segment

static var _lit: ShaderMaterial
static var _dir_cache := {}


## Unit directions around a circle, cached per segment count.
static func _dirs(seg: int) -> PackedVector2Array:
	if not _dir_cache.has(seg):
		var a := PackedVector2Array()
		for i in seg:
			a.append(Vector2.from_angle(i * TAU / seg))
		_dir_cache[seg] = a
	return _dir_cache[seg]


func _setup_canvas() -> void:
	if _lit == null:
		_lit = ShaderMaterial.new()
		_lit.shader = preload("res://shaders/lit.gdshader")
	_body = Node2D.new()
	_body.material = _lit
	add_child(_body)
	_body.draw.connect(_draw_body)
	_face = Node2D.new()
	add_child(_face)
	_face.draw.connect(_draw_face)


func _draw_body() -> void:
	if phase == Phase.OFF or delay > 0.0:
		return
	var ci := _body.get_canvas_item()
	var inv := _xf.affine_inverse()
	if rope_alpha > 0.0:
		RenderingServer.canvas_item_add_set_transform(ci, inv)
		_draw_rope(ci)
		RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)
	if _gone:
		return
	_mesh_update()
	var keep := 1.0 - 0.9 * hidden_amt
	var col := color()
	col.a *= keep
	# Contact shadow: the same mesh, pushed down and right in world space.
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D(0.0, inv.basis_xform(SHADOW_OFF)))
	_one_col[0] = Color(0.0, 0.0, 0.0, Pal.SHADOW.a * keep)
	RenderingServer.canvas_item_add_triangle_array(ci, _m_idx, _m_pts, _one_col, _m_sh)
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)
	_mesh_colors(col)
	RenderingServer.canvas_item_add_triangle_array(ci, _m_idx, _m_pts, _m_col, _m_uv)
	if kind == Kind.SHIELD or kind == Kind.BOSS:
		RenderingServer.canvas_item_add_set_transform(ci, inv)
		_draw_plates(ci, keep)
		RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)


## The string: the Verlet points smoothed (Catmull-Rom) and extruded into a
## strip whose normal runs across it, lit as a cord (jelly) or a wire
## (shells). World space.
func _draw_rope(ci: RID) -> void:
	var m := (N - 1) * ROPE_SUB + 1
	_r_mid.resize(m)
	var k := 0
	for i in N - 1:
		var p0 := _pts[maxi(i - 1, 0)]
		var p1 := _pts[i]
		var p2 := _pts[i + 1]
		var p3 := _pts[mini(i + 2, N - 1)]
		for s in ROPE_SUB:
			var t := float(s) / ROPE_SUB
			var t2 := t * t
			_r_mid[k] = 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t2 * t)
			k += 1
	_r_mid[k] = _pts[N - 1]
	var hw := (1.6 if soft else 1.1) + danger * 0.3
	var band := B_CORD if soft else B_WIRE
	_r_pts.resize(m * 2)
	_r_uv.resize(m * 2)
	var run := 0.0
	for i in m:
		var t := _r_mid[mini(i + 1, m - 1)] - _r_mid[maxi(i - 1, 0)]
		var nn := t.orthogonal().normalized() if t.length_squared() > 1e-6 else Vector2.RIGHT
		if i > 0:
			run += _r_mid[i].distance_to(_r_mid[i - 1])
		_r_pts[i * 2] = _r_mid[i] - nn * hw
		_r_pts[i * 2 + 1] = _r_mid[i] + nn * hw
		_r_uv[i * 2] = Vector2(band - 1.0, run)
		_r_uv[i * 2 + 1] = Vector2(band + 1.0, run)
	if _r_idx.size() != (m - 1) * 6:
		_r_idx.resize((m - 1) * 6)
		for i in m - 1:
			var a := i * 2
			_r_idx[i * 6] = a
			_r_idx[i * 6 + 1] = a + 1
			_r_idx[i * 6 + 2] = a + 3
			_r_idx[i * 6 + 3] = a
			_r_idx[i * 6 + 4] = a + 3
			_r_idx[i * 6 + 5] = a + 2
	# Each string takes its target's colour: a dyed cord for jelly, a
	# darker tinted wire for shells; near the line it pales under strain.
	var tint := _base_color()
	var sc := (tint.darkened(0.2) if soft else tint.darkened(0.35).lerp(Pal.STRING, 0.3)).lerp(Pal.INK_DIM, danger * 0.5)
	_one_col[0] = Color(sc, rope_alpha)
	RenderingServer.canvas_item_add_triangle_array(ci, _r_idx, _r_pts, _one_col, _r_uv)


## Rebuilds the mesh when the kind or health changed; jelly then moves its
## surface vertices by the spring field every frame.
func _mesh_update() -> void:
	var key := int(kind) * 16 + hp
	if key != _m_key:
		_m_key = key
		_mesh_build()
	if soft:
		for k in _m_dv.size():
			var i := _m_dv[k]
			_m_pts[i] = _m_base[i] + _m_dd[k] * _soft_lin(_m_ds[k])


func _soft_lin(s: float) -> float:
	var i := int(s)
	var w := s - float(i)
	i = i % SOFT_N
	return lerpf(_sd[i], _sd[(i + 1) % SOFT_N], w * w * (3.0 - 2.0 * w))


func _mesh_colors(col: Color) -> void:
	var n := _m_pts.size()
	if _m_col.size() != n:
		_m_col.resize(n)
	_m_col.fill(col)
	if _m_mem > 0:
		var mem := col.darkened(0.55)
		mem.a = col.a * (0.88 if soft else 1.0)
		for i in _m_mem:
			_m_col[i] = mem
	if _m_dim.x >= 0:
		var dim := Color(col, col.a * 0.55)
		for i in range(_m_dim.x, _m_dim.y):
			_m_col[i] = dim


func _mesh_build() -> void:
	_m_base.clear()
	_m_uv.clear()
	_m_sh.clear()
	_m_idx.clear()
	_m_dv.clear()
	_m_dd.clear()
	_m_ds.clear()
	_m_mem = 0
	_m_dim = Vector2i(-1, -1)
	var b := B_JELLY if soft else B_SHELL
	var r := radius
	match kind:
		Kind.RING:
			_membrane(r - 8.0, 24)
			_ring_tube(r - 5.0, 4.5, 32, b)
		Kind.HEAVY:
			_membrane(r - 14.5, 20)
			if hp > 1:
				_ring_tube(r - 3.0, 2.5, 36, b)
			else:
				# Cracked outer ring after the first hit.
				_m_dim.x = _m_base.size()
				for i in 6:
					var a := i * TAU / 6.0 + 0.2
					_arc_tube(r - 3.0, a, a + 0.62, 2.0, 5, b)
				_m_dim.y = _m_base.size()
			_ring_tube(r - 13.0, 3.0, 32, b)
		Kind.SHIELD:
			_membrane(r - 7.5, 22)
			_ring_tube(r - 5.0, 4.0, 32, b)
		Kind.REEL:
			_membrane(r - 6.0, 20)
			_ring_tube(r - 4.0, 3.5, 32, b)
			for i in 4:
				var d := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0)
				_bar(d * 11.0, d * (r - 7.0), 1.5, b)
		Kind.SPLIT:
			_membrane_poly(_hex(r - 7.0, 4))
			_poly_tube(_hex(r - 4.0, 4), 4.0, b)
			_bar(Vector2(0, -r + 8.0), Vector2(0, -r * 0.55), 1.0, b)
			_bar(Vector2(0, r - 8.0), Vector2(0, r * 0.55), 1.0, b)
		Kind.ROD:
			_capsule(ROD_HALF, r, b)
		Kind.DROP:
			_fan(_drop_outline(r), Vector2(0.0, -r * 0.1), b)
		Kind.SHADE:
			_fan(_crescent(r), Vector2(-r * 0.55, 0.0), b)
		Kind.BOSS:
			_fan(_hex(r, 3), Vector2.ZERO, b)
	_m_pts = _m_base.duplicate()


## Adds a vertex: position, surface normal (length 1 on a silhouette, 0
## facing the viewer), material band, whether it lies on the outer
## silhouette (where the contact shadow fades out), and the direction the
## jelly surface moves it (none for shells).
func _v(p: Vector2, n: Vector2, band: float, sil: bool, dd := Vector2.ZERO) -> int:
	var i := _m_base.size()
	_m_base.append(p)
	_m_uv.append(Vector2(band + n.x, n.y))
	_m_sh.append(Vector2(B_SHADOW + n.x, n.y) if sil else Vector2(B_SHADOW, 0.0))
	if soft and dd != Vector2.ZERO:
		_m_dv.append(i)
		_m_dd.append(dd)
		_m_ds.append(fposmod(p.angle(), TAU) / TAU * SOFT_N)
	return i


## How the jelly surface moves a point of a polygonal body: outward, less
## toward the middle.
func _poly_dd(p: Vector2) -> Vector2:
	var l := p.length()
	return p / l * minf(1.0, l / radius) if l > 0.001 else Vector2.ZERO


func _quads(base: int, n: int, closed: bool) -> void:
	for i in (n if closed else n - 1):
		var a := base + i * 2
		var b := base + ((i + 1) % n) * 2
		_m_idx.append_array([a, a + 1, b + 1, a, b + 1, b])


## The recessed inside of a ring: a flat disc under the face.
func _membrane(rr: float, seg: int) -> void:
	var c := _v(Vector2.ZERO, Vector2.ZERO, B_MEMBRANE, false)
	var dirs := _dirs(seg)
	for i in seg:
		_v(dirs[i] * rr, dirs[i], B_MEMBRANE, false, dirs[i])
	for i in seg:
		_m_idx.append_array([c, c + 1 + i, c + 1 + (i + 1) % seg])
	_m_mem = _m_base.size()


func _membrane_poly(rim: PackedVector2Array) -> void:
	var c := _v(Vector2.ZERO, Vector2.ZERO, B_MEMBRANE, false)
	var n := rim.size()
	for p in rim:
		_v(p, p.normalized(), B_MEMBRANE, false, _poly_dd(p))
	for i in n:
		_m_idx.append_array([c, c + 1 + i, c + 1 + (i + 1) % n])
	_m_mem = _m_base.size()


## A round tube: the ring bodies. Inner edge normal points in, outer out.
func _ring_tube(rm: float, hw: float, seg: int, band: float) -> void:
	var dirs := _dirs(seg)
	var base := _m_base.size()
	for d in dirs:
		_v(d * (rm - hw), -d, band, false, d)
		_v(d * (rm + hw), d, band, true, d)
	_quads(base, seg, true)


func _arc_tube(rm: float, a0: float, a1: float, hw: float, steps: int, band: float) -> void:
	var base := _m_base.size()
	for k in steps + 1:
		var d := Vector2.from_angle(lerpf(a0, a1, float(k) / steps))
		_v(d * (rm - hw), -d, band, false, d)
		_v(d * (rm + hw), d, band, true, d)
	_quads(base, steps + 1, false)


## A straight rod (spokes, the splitter's marks).
func _bar(a: Vector2, b: Vector2, hw: float, band: float) -> void:
	var n := (b - a).normalized().orthogonal()
	var base := _m_base.size()
	_v(a - n * hw, -n, band, false)
	_v(a + n * hw, n, band, false)
	_v(b - n * hw, -n, band, false)
	_v(b + n * hw, n, band, false)
	_quads(base, 2, false)


## A tube along a closed polygon (the splitter's hexagon).
func _poly_tube(path: PackedVector2Array, hw: float, band: float) -> void:
	var n := path.size()
	var base := _m_base.size()
	for i in n:
		var p := path[i]
		var nn := (path[(i + 1) % n] - path[(i - 1 + n) % n]).normalized().orthogonal()
		if nn.dot(p) < 0.0:
			nn = -nn
		var dd := _poly_dd(p)
		_v(p - nn * hw, -nn, band, false, dd)
		_v(p + nn * hw, nn, band, true, dd)
	_quads(base, n, true)


## A filled body, domed: normals face the viewer at `c` and turn out to
## the silhouette at the rim.
func _fan(rim: PackedVector2Array, c: Vector2, band: float) -> void:
	var n := rim.size()
	var ci := _v(c, Vector2.ZERO, band, false, _poly_dd(c))
	for i in n:
		var p := rim[i]
		var nn := (rim[(i + 1) % n] - rim[(i - 1 + n) % n]).normalized().orthogonal()
		if nn.dot(p - c) < 0.0:
			nn = -nn
		_v(p, nn, band, true, _poly_dd(p))
	for i in n:
		_m_idx.append_array([ci, ci + 1 + i, ci + 1 + (i + 1) % n])


## The pendulum's capsule: a spine along its axis faces the viewer, the
## outline turns away, so it shades as a rounded bar.
func _capsule(h: float, r: float, band: float) -> void:
	var rim := PackedVector2Array()
	for k in 5:
		rim.append(Vector2(lerpf(-h, h, k / 4.0), -r))
	for k in range(1, 8):
		rim.append(Vector2(h, 0.0) + Vector2.from_angle(-PI * 0.5 + PI * k / 8.0) * r)
	for k in 5:
		rim.append(Vector2(lerpf(h, -h, k / 4.0), r))
	for k in range(1, 8):
		rim.append(Vector2(-h, 0.0) + Vector2.from_angle(PI * 0.5 + PI * k / 8.0) * r)
	var base := _m_base.size()
	for p in rim:
		var s := Vector2(clampf(p.x, -h, h), 0.0)
		_v(s, Vector2.ZERO, band, false)
		_v(p, (p - s).normalized(), band, true)
	_quads(base, rim.size(), true)


## A hexagon (corner up), each edge split into `sub` pieces.
func _hex(r: float, sub: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 6:
		var a := Vector2.from_angle(i * TAU / 6.0 + PI / 6.0) * r
		var b := Vector2.from_angle((i + 1) * TAU / 6.0 + PI / 6.0) * r
		for k in sub:
			out.append(a.lerp(b, float(k) / sub))
	return out


func _drop_outline(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, -r * 1.75)])
	for i in 17:
		var a := -PI * 0.5 + 0.62 + (TAU - 1.24) * i / 16.0
		pts.append(Vector2.from_angle(a) * r)
	return pts


## Crescent: outer half-circle and an inner half-ellipse sharing the tips,
## thick on the left, tapering to points top and bottom. Never self-crosses.
func _crescent(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := -PI * 0.5 + PI * i / 16.0
		pts.append(Vector2(-cos(a) * r, sin(a) * r))
	for i in range(1, 16):
		var a := PI * 0.5 - PI * i / 16.0
		pts.append(Vector2(-cos(a) * r * 0.22, sin(a) * r * 0.96))
	return pts


## Plates that do not turn with the body (the Vokter's front plate, the
## Spinneren's two orbiting plates): polished metal arcs with their own
## shadow, in world space, one draw call.
func _draw_plates(ci: RID, keep: float) -> void:
	_p_pts.clear()
	_p_uv.clear()
	_p_idx.clear()
	_p_col.clear()
	var metal := Color(Pal.METAL_LIGHT, keep)
	var sh := Color(0.0, 0.0, 0.0, Pal.SHADOW.a * keep)
	match kind:
		Kind.SHIELD:
			_plate(radius + 5.0, shield_ang, SHIELD_HALF, 4.0, metal, sh)
		Kind.BOSS:
			for k in 2:
				_plate(radius + 11.0, orbit + PI * k, BOSS_ARC_HALF, 3.5, metal, sh)
	RenderingServer.canvas_item_add_triangle_array(ci, _p_idx, _p_pts, _p_col, _p_uv)


func _plate(r: float, center: float, half: float, hw: float, metal: Color, sh: Color) -> void:
	for pass_i in 2:
		var shadow := pass_i == 0
		var c := pos + (SHADOW_OFF if shadow else Vector2.ZERO)
		var band := B_SHADOW if shadow else B_METAL
		var base := _p_pts.size()
		var steps := 12
		for k in steps + 1:
			var d := Vector2.from_angle(lerpf(center - half, center + half, float(k) / steps))
			_p_pts.append(c + d * (r - hw))
			_p_uv.append(Vector2(band - d.x, -d.y))
			_p_pts.append(c + d * (r + hw))
			_p_uv.append(Vector2(band + d.x, d.y))
			_p_col.append(sh if shadow else metal)
			_p_col.append(sh if shadow else metal)
		for k in steps:
			var a := base + k * 2
			_p_idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])


# ---------------------------------------------------------------- face

## Face layer, in body space: the jelly's bubbles and the shells' rivets,
## then eye and mouth. World-space extras (the frayed string, the first-
## sighting ring, the boss's health) are drawn through the inverse.
func _draw_face() -> void:
	if phase == Phase.OFF or delay > 0.0:
		return
	var f := _face
	var inv := _xf.affine_inverse()
	f.draw_set_transform_matrix(inv)
	if fray_t > 0.0 and _attached and rope_alpha > 0.0:
		# Frayed: a few loose fibres at the nearest point, blinking faster
		# as the fray is about to mend.
		var q := _pts[1]
		for i in range(1, 4):
			if _pts[i].distance_to(_fray_at) < q.distance_to(_fray_at):
				q = _pts[i]
		var blink := 0.6 + 0.4 * sin(_clock * lerpf(6.0, 18.0, 1.0 - fray_t / 4.0))
		for k in 3:
			var a := -0.9 + k * 0.9
			f.draw_line(q, q + Vector2.from_angle(a) * 6.0, Color(Pal.INK, 0.7 * blink * rope_alpha), 1.2, true)
			f.draw_line(q, q + Vector2.from_angle(PI - a) * 6.0, Color(Pal.INK, 0.7 * blink * rope_alpha), 1.2, true)
	if _gone:
		f.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if intro_t > 0.0:
		# First sighting: a slow dashed ring marks the new enemy.
		var k := minf(1.0, intro_t / 0.5)
		for i in 12:
			var a0 := _clock * 0.8 + i * TAU / 12.0
			f.draw_arc(pos, radius + 16.0, a0, a0 + 0.3, 6, Color(Pal.INK, 0.5 * k), 1.5, true)
	if kind == Kind.BOSS and phase == Phase.HANGING:
		var hp_max: int = HP[kind]
		for i in hp_max:
			var x := (i - (hp_max - 1) * 0.5) * 10.0
			Pal.disc(f, pos + Vector2(x, radius + 26.0), 2.6, Color(Pal.INK, 0.85) if i < hp else Color(Pal.INK_FAINT, 0.6))
	f.draw_set_transform_matrix(Transform2D.IDENTITY)
	var col := color()
	col.a *= 1.0 - 0.9 * hidden_amt
	_details(col)
	_eye()


## Radius of the open centre of ring-shaped bodies (where the face sits).
func _hole() -> float:
	match kind:
		Kind.RING: return radius - 9.5
		Kind.HEAVY: return radius - 16.0
		Kind.SHIELD: return radius - 9.0
		Kind.REEL: return radius - 7.5
		Kind.SPLIT: return radius - 9.0
	return 0.0


## Bubbles rising slowly through jelly; rivets on the heavy's ring (gone
## once it cracks), bolts on the sentry, a hub on the reel.
func _details(col: Color) -> void:
	var f := _face
	if soft:
		var h := _hole()
		if h > 0.0:
			for i in 3:
				var ph := _clock * (7.0 + i * 2.5) + i * 17.0 + _hue_shift * 300.0
				var y := h * 0.7 - fposmod(ph, h * 1.4)
				var x := sin(_clock * 0.9 + i * 2.1) * h * 0.45
				var fade := 1.0 - absf(y) / (h * 0.75)
				if fade > 0.0:
					Pal.disc(f, Vector2(x, y), 1.4 + i * 0.5, Color(col.lightened(0.35), 0.3 * fade * col.a))
		return
	var rv := Color(col.lightened(0.45), col.a)
	var sh := Color(0, 0, 0, 0.4 * col.a)
	match kind:
		Kind.HEAVY:
			if hp > 1:
				for i in 8:
					var p := Vector2.from_angle(i * TAU / 8.0 + 0.2) * (radius - 3.0)
					Pal.disc(f, p + Vector2(0.7, 0.7), 1.5, sh)
					Pal.disc(f, p, 1.3, rv)
		Kind.SHIELD:
			for i in 4:
				var p := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * (radius - 5.0)
				Pal.disc(f, p + Vector2(0.7, 0.7), 2.0, sh)
				Pal.disc(f, p, 1.8, rv)
		Kind.REEL:
			Pal.disc(f, Vector2.ZERO, 11.5, Color(col.darkened(0.35), col.a))
			Pal.disc(f, Vector2.ZERO, 9.5, Color(col.darkened(0.6), col.a))


## The mouth carries the mood: a small smile at rest, a worried line when
## you aim at it, an "o" when startled, a smirk when smug, a tongue when it
## taunts, a frown in rage and a grimace when struck. Drawn in eye space.
func _mouth(er: float) -> void:
	var f := _face
	var y := er * 1.25
	var w := er * 0.85
	var ink := Color(Pal.EYE, 0.9 * modulate.a * (1.0 - 0.8 * hidden_amt))
	var dark := Color(Pal.PUPIL, 0.95 * modulate.a)
	var pts := PackedVector2Array()
	if _closed_t > 0.0 or phase == Phase.FALLING:
		# Grimace: a tight zigzag.
		for i in 7:
			pts.append(Vector2(lerpf(-w * 0.6, w * 0.6, i / 6.0), y + (1.2 if i % 2 == 0 else -1.2)))
		f.draw_polyline(pts, ink, 1.6, true)
	elif startle_t > 0.0 or scared:
		Pal.disc(f, Vector2(0, y + 1.0), er * 0.26, dark)
		f.draw_arc(Vector2(0, y + 1.0), er * 0.26, 0.0, TAU, 14, ink, 1.4, true)
	elif _taunt >= 0.0:
		# Open grin with the tongue out.
		var grin := PackedVector2Array()
		for i in 9:
			var a := PI * i / 8.0
			grin.append(Vector2(cos(a) * w * 0.55, y - 1.0 + sin(a) * w * 0.45))
		f.draw_colored_polygon(grin, dark)
		Pal.disc(f, Vector2(w * 0.12, y + w * 0.32), w * 0.24, Color("E86A8A", modulate.a))
		f.draw_line(Vector2(-w * 0.55, y - 1.0), Vector2(w * 0.55, y - 1.0), ink, 1.5, true)
	elif enraged:
		for i in 7:
			var t := lerpf(-1.0, 1.0, i / 6.0)
			pts.append(Vector2(t * w * 0.5, y + 2.0 - (1.0 - t * t) * 3.0))
		f.draw_polyline(pts, ink, 1.8, true)
	elif squint or aimed or tele_t > 0.0:
		# Worried: a flat, wobbling line with the corners pulled down.
		for i in 7:
			var t := lerpf(-1.0, 1.0, i / 6.0)
			pts.append(Vector2(t * w * 0.45, y + sin(t * 5.0 + _clock * 14.0) * 0.6 + absf(t) * absf(t) * 1.8))
		f.draw_polyline(pts, ink, 1.5, true)
	elif smug > 0.35:
		# Smirk: flat on one side, curled up on the other.
		for i in 7:
			var t := i / 6.0
			pts.append(Vector2(lerpf(-w * 0.45, w * 0.55, t), y + 0.5 - pow(t, 3.0) * 3.2 * smug))
		f.draw_polyline(pts, ink, 1.7, true)
	else:
		for i in 7:
			var t := lerpf(-1.0, 1.0, i / 6.0)
			pts.append(Vector2(t * w * 0.4, y + (1.0 - t * t) * 2.0))
		f.draw_polyline(pts, ink, 1.5, true)


func _eye() -> void:
	var f := _face
	_eye_parts()
	if kind != Kind.ROD:
		var er := 7.0 if kind == Kind.DROP else (15.0 if kind == Kind.BOSS else 9.5)
		var eo := Vector2(-radius * 0.6, 0.0) if kind == Kind.SHADE else Vector2.ZERO
		eo.y -= er * (0.35 if kind != Kind.DROP else 0.1)
		f.draw_set_transform_matrix(Transform2D(0.0, eo))
		_mouth(er)
	f.draw_set_transform_matrix(Transform2D.IDENTITY)


## Eye (socket, white, pupil, glint, lids and brows) and, after it, the
## mouth, in the eye's own space. Discs first so they batch.
func _eye_parts() -> void:
	var f := _face
	# The Skygge's eye sits in the thick part of the crescent.
	var eo := Vector2(-radius * 0.6, 0.0) if kind == Kind.SHADE else Vector2.ZERO
	var er := 9.5
	if kind == Kind.DROP:
		er = 7.0
	elif kind == Kind.BOSS:
		er = 15.0
	var mouthed := kind != Kind.ROD
	if mouthed:
		# Eye sits a little high so there is room for a mouth below.
		eo.y -= er * (0.35 if kind != Kind.DROP else 0.1)
	var bx := Transform2D(0.0, eo)
	f.draw_set_transform_matrix(bx)
	var wide := maxf(1.0, _open)
	var pr := er * 0.48 / wide
	er *= lerpf(1.0, wide, 0.5)
	if kind == Kind.ROD or kind == Kind.DROP or kind == Kind.BOSS or kind == Kind.SHADE:
		# Filled bodies: a dark socket keeps the eye readable.
		Pal.disc(f, Vector2.ZERO, er + 2.0, Color(0, 0, 0, 0.22))
	if _closed_t > 0.0 or phase == Phase.FALLING:
		f.draw_line(Vector2(-er * 0.85, 0), Vector2(er * 0.85, 0), Pal.EYE, 2.4, true)
		return
	var open := clampf(_open, 0.0, 1.0)
	if open < 0.12:
		f.draw_line(Vector2(-er * 0.85, 0), Vector2(er * 0.85, 0), Pal.EYE, 2.2, true)
		return
	f.draw_set_transform_matrix(bx * Transform2D(0.0, Vector2(1.0, open), 0.0, Vector2.ZERO))
	Pal.disc(f, Vector2.ZERO, er, Pal.EYE)
	var pupil := _pupil * (er - pr - 1.2)
	Pal.disc(f, pupil, pr, Pal.PUPIL)
	Pal.disc(f, pupil - Vector2(pr, pr) * 0.35, pr * 0.28, Color(Pal.EYE, 0.7))
	f.draw_set_transform_matrix(bx)
	if enraged:
		# Brows pulled in: rage reads at a glance.
		for sx: float in [-1.0, 1.0]:
			f.draw_line(Vector2(sx * er * 1.15, -er * 1.25), Vector2(sx * er * 0.25, -er * 0.8), Pal.EYE if kind != Kind.BOSS else Pal.PUPIL, 2.2, true)
	if smug > 0.05 and open >= 0.9 and not enraged:
		# Smug: a heavy upper lid slides down and one brow goes up.
		var yc := lerpf(-er, -er * 0.05, smug)
		var hw := sqrt(maxf(0.0, er * er - yc * yc))
		var a0 := atan2(yc, -hw)
		var a1 := atan2(yc, hw)
		var lid := PackedVector2Array()
		for i in 11:
			lid.append(Vector2.from_angle(lerpf(a0, a1, i / 10.0)) * (er + 0.6))
		var lid_col := color().darkened(0.25)
		if lid.size() >= 3 and a1 > a0:
			f.draw_colored_polygon(lid, lid_col)
		f.draw_line(Vector2(-hw, yc + 1.5 * smug), Vector2(hw, yc - 1.5 * smug), Pal.PUPIL, 1.8, true)
		var bc := Color(Pal.EYE, smug)
		f.draw_line(Vector2(-er * 0.95, -er * 1.3), Vector2(er * 0.15, -er * 1.6 - 3.0 * smug), bc, 2.6, true)
		f.draw_line(Vector2(er * 0.15, -er * 1.6 - 3.0 * smug), Vector2(er * 1.0, -er * 1.35), bc, 2.6, true)
	if open < 0.9:
		# Lid lines make the squint read as intent, not just a squash.
		var y := er * open
		f.draw_line(Vector2(-er, -y), Vector2(er, -y * 0.7), Pal.PUPIL, 1.6, true)
