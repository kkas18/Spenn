class_name Fx
extends Node2D
## Pooled hit sparks and score popups, screen shake and hit-stop.
## Popups, impact rings, shards and smoke are plain data drawn by this node,
## so they cost no nodes at all. Sparks, smoke and the soft pressure ring use
## textures from the Kenney Particle Pack (CC0), tinted and kept matte.

const SPARK_POOL := 8
const POPUP_POOL := 12
const POPUP_LIFE := 0.9
const POPUP_RISE := 38.0
const SHAKE_MAX := 3.0
const SHAKE_TIME := 0.15
const HITSTOP := 0.04
const RING_POOL := 8
const RING_LIFE := 0.22
const SHARD_POOL := 32
const SHARD_LIFE := 0.9
const FRAG_POOL := 64
const FRAG_LIFE := 0.75
const RAY_LIFE := 0.26
const PUFF_POOL := 24

const TEX_SMOKE: Array[Texture2D] = [preload("res://assets/particles/smoke_a.png"), preload("res://assets/particles/smoke_b.png")]
const TEX_RING := preload("res://assets/particles/ring.png")
const TEX_STREAK := preload("res://assets/particles/streak.png")

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
var _held := -1.0
var _frags: Array[Dictionary] = []
var _next_frag := 0
var _queued: Array[Dictionary] = []   # staged bursts (boss)
var _tokens: Array[Dictionary] = []
var _next_token := 0
const TOKEN_POOL := 40
const TOKEN_TIME := 0.5
var _slow_left := 0.0
var _base_scale := 1.0           # sustained slow time (overload), under everything else
var _punch := 0.0
# Focus: the camera leans in on a point for a big moment (a boss falling,
# the last kill of a wave), easing in and back out over real time.
var _focus_pt := Vector2.ZERO
var _focus_amt := 0.0
var _focus_t := -1.0
var _focus_dur := 1.0
var _focus_w := 0.0              # eased 0..1 weight, drives zoom and pan
var _focus_rot := 0.0            # a slight roll toward the moment (rad)
var _rings: Array[Dictionary] = []
var _next_ring := 0
var _shards: Array[Dictionary] = []
var _next_shard := 0
var _rng := RandomNumberGenerator.new()
var shock_rect: ColorRect          # screen-space refraction layer (set by the game)
var _waves: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _chroma := 0.0
var view := Vector2.ZERO          # tilt parallax offset of the world (px)
# Light that adds instead of covering: impact blooms and hot halos. A child
# layer with additive blending, drawn over the rest of the effects.
var _glow: Node2D
const TEX_SOFT := preload("res://assets/particles/soft.png")
var _links: Array[Dictionary] = []
var _later: Array[Dictionary] = []   # calls due after a delay (game time)
var _puffs: Array[Dictionary] = []
var _next_puff := 0


func _ready() -> void:
	_rng.randomize()
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.z_index = 1
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
	var tex := TEX_STREAK
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
		p.scale_amount_min = 0.3
		p.scale_amount_max = 0.55
		p.particle_flag_align_y = true
		p.scale_amount_curve = size_curve
		p.color_ramp = ramp
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
	for i in TOKEN_POOL:
		_tokens.append({"t": -1.0, "from": Vector2.ZERO, "to": Vector2.ZERO, "ctrl": Vector2.ZERO, "delay": 0.0})
	for i in POPUP_POOL:
		_popups.append({"t": -1.0, "text": "", "pos": Vector2.ZERO, "col": Pal.INK, "size": 20, "accent": false})
	for i in PUFF_POOL:
		_puffs.append({"t": -1.0, "life": 0.8, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "rot": 0.0,
			"spin": 0.0, "s0": 10.0, "s1": 30.0, "col": Pal.INK, "a": 0.3, "tex": 0})


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
	var n := Device.count(clampi(count, 6, 10))
	if p.amount != n:
		p.amount = n
	p.restart()


## Thin pressure ring at the contact: 180 ms, local, no glow.
func ring(at: Vector2, col: Color, size := 30.0) -> void:
	var r := _rings[_next_ring]
	_next_ring = (_next_ring + 1) % RING_POOL
	r.t = 0.0
	r.pos = at
	r.col = col
	r.r = size


## A shock ring that bends the picture as it expands (kills, breaches,
## the end of a run). Off with reduced motion and on the lowest tier.
func shock(at: Vector2, strength: float, max_r: float, dur := 0.45) -> void:
	if shock_rect == null or Prefs.reduced_motion or Device.tier == Device.Tier.LOW:
		return
	if _waves.size() >= 4:
		_waves.pop_front()
	_waves.append({"at": at, "t": 0.0, "d": dur, "r": max_r, "s": strength})


## A white flash at the point of impact: a disc that collapses in 70 ms,
## with a soft bloom of light around it that lingers a little longer.
func flash(at: Vector2, r: float, col := Color.WHITE) -> void:
	if _flashes.size() >= 6:
		_flashes.pop_front()
	_flashes.append({"at": at, "r": r, "t": 0.0, "col": col})


## Red and blue split apart toward the edges for a moment (big impacts).
func aberrate(px: float) -> void:
	if shock_rect == null or Prefs.reduced_motion or Device.tier == Device.Tier.LOW:
		return
	_chroma = maxf(_chroma, px)


## A brief dashed tether between two targets working together (0.5 s).
## Re-issued while the pairing lasts; it only refreshes, never stacks.
func link(a: Vector2, b: Vector2, col: Color) -> void:
	for k in _links:
		if k.a.distance_to(a) < 30.0 and k.b.distance_to(b) < 30.0:
			k.a = a
			k.b = b
			k.t = minf(k.t, 0.1)
			return
	if _links.size() < 6:
		_links.append({"a": a, "b": b, "col": col, "t": 0.0})


## Runs `cb` after `delay` seconds of game time (slowed by hit-stop).
func after(delay: float, cb: Callable) -> void:
	_later.append({"t": delay, "cb": cb})


## Soft smoke that blooms and drifts up from a break, a breach or the end
## of a run: tinted toward the background so it stays matte, never glows.
func puff(at: Vector2, col: Color, count: int, size: float, alpha := 0.3) -> void:
	if Prefs.reduced_motion:
		count = maxi(1, count / 2)
	count = Device.count(count)
	var tint := col.lerp(Pal.BG, 0.35)
	for i in count:
		var d := _puffs[_next_puff]
		_next_puff = (_next_puff + 1) % PUFF_POOL
		var a := _rng.randf() * TAU
		d.t = 0.0
		d.life = _rng.randf_range(0.65, 1.0)
		d.pos = at + Vector2.from_angle(a) * size * _rng.randf_range(0.0, 0.25)
		d.vel = Vector2.from_angle(a) * size * _rng.randf_range(0.3, 0.8) + Vector2(0, -size * 0.35)
		d.rot = _rng.randf() * TAU
		d.spin = _rng.randf_range(-0.8, 0.8)
		d.s0 = size * _rng.randf_range(0.45, 0.65)
		d.s1 = size * _rng.randf_range(1.2, 1.6)
		d.col = tint.lightened(_rng.randf_range(0.0, 0.12))
		d.a = alpha * _rng.randf_range(0.7, 1.0)
		d.tex = _rng.randi() % TEX_SMOKE.size()


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
	if Target.is_soft_kind(kind):
		_splash(at, radius, col, inherit)
		return
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
		Target.Kind.SPLIT, Target.Kind.BOSS, Target.Kind.MIRROR:
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
	if Prefs.reduced_motion:
		rays /= 3
	rays = Device.count(rays)
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


## Jelly bursts into blobs: a ring of droplets of mixed size flung out and
## falling, a few slow heavy ones, and a soft wet splash ring. No rays.
func _splash(at: Vector2, radius: float, col: Color, inherit: Vector2) -> void:
	var n := Device.count(14 if not Prefs.reduced_motion else 7)
	for i in n:
		var a := i * TAU / n + _rng.randf_range(-0.2, 0.2)
		var sp := _rng.randf_range(110.0, 300.0)
		var f := _frag(Frag.DOT, at + Vector2.from_angle(a) * radius * 0.55, inherit + Vector2.from_angle(a) * sp + Vector2(0, -90), col.lightened(_rng.randf_range(0.0, 0.15)), _rng.randf_range(0.5, 0.8))
		f.r = _rng.randf_range(2.5, 6.0) * radius / 30.0
	for i in 3:
		var a := _rng.randf() * TAU
		var f := _frag(Frag.DOT, at + Vector2.from_angle(a) * radius * 0.2, inherit + Vector2.from_angle(a) * 70.0 + Vector2(0, -40), col.darkened(0.1), 0.9)
		f.r = _rng.randf_range(6.0, 9.0) * radius / 30.0
	ring(at, col.lightened(0.1), radius * 1.3)


## Gold grains arc from a kill to the score counter (gold = points/power).
func tokens(from: Vector2, to: Vector2, count: int) -> void:
	for i in count:
		var k := _tokens[_next_token]
		_next_token = (_next_token + 1) % TOKEN_POOL
		k.t = 0.0
		k.delay = i * 0.03
		k.from = from + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10))
		k.to = to
		var side := _rng.randf_range(-1.0, 1.0)
		k.ctrl = from.lerp(to, 0.35) + Vector2(side * 140.0, 60.0)


func _step_waves(rd: float) -> void:
	if shock_rect == null:
		return
	var list: Array[Vector4] = []
	for w in _waves.duplicate():
		w.t += rd
		if w.t >= w.d:
			_waves.erase(w)
	for i in 4:
		if i < _waves.size():
			var w: Dictionary = _waves[i]
			var k: float = w.t / w.d
			var e := 1.0 - pow(1.0 - k, 3.0)
			list.append(Vector4(w.at.x, w.at.y, lerpf(8.0, w.r, e), w.s * (1.0 - k) * (1.0 - k)))
		else:
			list.append(Vector4.ZERO)
	_chroma = maxf(0.0, _chroma - rd * 22.0)
	shock_rect.visible = not _waves.is_empty() or _chroma > 0.0
	var sm := shock_rect.material as ShaderMaterial
	sm.set_shader_parameter("waves", list)
	sm.set_shader_parameter("chroma", _chroma)


## A score or label that rises and fades. `accent` (skill shots) pops in
## larger and underlines itself with a gold rule drawn out from the centre.
func popup(text: String, at: Vector2, col := Pal.INK, size := 20, accent := false) -> void:
	var p := _popups[_next_popup]
	_next_popup = (_next_popup + 1) % POPUP_POOL
	p.t = 0.0
	p.text = text
	p.col = col
	p.size = size
	p.accent = accent
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if font else 80.0
	var half := w * 0.5
	var x := clampf(at.x, l.margin + half, l.size.x - l.margin - half)
	var top := l.top_bar_h + l.margin + POPUP_RISE + size
	var y := clampf(at.y, top, l.size.y - l.margin)
	# Stack above young popups nearby instead of overprinting them; under
	# them when there is no room above (targets hanging near the rail).
	var going_up := true
	for pass_i in 6:
		var hit: Dictionary = {}
		for q in _popups:
			if q != p and q.t >= 0.0 and q.t < 0.6 and absf(q.pos.x - x) < 170.0 and absf(q.pos.y - y) < maxf(size, q.size) + 6.0:
				hit = q
				break
		if hit.is_empty():
			break
		if going_up:
			y = hit.pos.y - (size + 8.0)
			if y < top:
				going_up = false
				y = hit.pos.y + (hit.size + 8.0)
		else:
			y = hit.pos.y + (hit.size + 8.0)
	p.pos = Vector2(x, y)


func shake(amount := SHAKE_MAX) -> void:
	if Prefs.reduced_motion:
		return
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
	if Prefs.reduced_motion:
		return
	_punch = maxf(_punch, amount)


## Leans the camera in on `at` by `amount` (0.06 ≈ 6 %) for `dur` real
## seconds: a quick ease in, a hold, a slow ease out.
func focus(at: Vector2, amount: float, dur := 0.9) -> void:
	if Prefs.reduced_motion:
		return
	if _focus_t >= 0.0 and amount < _focus_amt * _focus_w:
		return
	_focus_pt = at
	_focus_amt = amount
	_focus_dur = dur
	_focus_t = 0.0
	# Roll toward the side it happened on, more for bigger moments (≤1.5°).
	if l:
		var side := clampf((at.x - l.center_x) / (l.size.x * 0.5), -1.0, 1.0)
		_focus_rot = deg_to_rad(-side * clampf(amount * 18.0, 0.3, 1.5))


## Sustained slow time (overload): the floor the other effects work under.
func set_base_time(scale: float) -> void:
	_base_scale = scale
	_apply_time()


## Direct control of game time (death sequence); overrides slow motion.
func hold_time(scale: float) -> void:
	_held = scale
	_apply_time()


func release_time() -> void:
	_held = -1.0
	_apply_time()


func reset_time() -> void:
	_held = -1.0
	_slow_left = 0.0
	_slow_scale = 1.0
	_base_scale = 1.0
	_hitstop_live = false
	_punch = 0.0
	_focus_t = -1.0
	_focus_w = 0.0
	Engine.time_scale = 1.0


func _apply_time() -> void:
	if get_tree().paused:
		return
	if _held >= 0.0:
		Engine.time_scale = _held
		return
	Engine.time_scale = 0.02 if _hitstop_live else minf(_base_scale, _slow_scale if _slow_left > 0.0 else 1.0)


func clear() -> void:
	for p in _popups:
		p.t = -1.0
	for r in _rings:
		r.t = -1.0
	for d in _shards:
		d.t = -1.0
	for f in _frags:
		f.t = -1.0
	for k in _tokens:
		k.t = -1.0
	_queued.clear()
	_later.clear()
	_links.clear()
	_flashes.clear()
	_waves.clear()
	_step_waves(0.0)
	for d in _puffs:
		d.t = -1.0
	for s in _sparks:
		s.emitting = false
	_shake_t = 0.0
	_punch = 0.0
	_focus_t = -1.0
	_focus_w = 0.0
	if shake_target:
		shake_target.position = Vector2.ZERO
		shake_target.scale = Vector2.ONE
		shake_target.rotation = 0.0


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
	_focus_w = 0.0
	if _focus_t >= 0.0:
		_focus_t += rd
		var k := _focus_t / _focus_dur
		if k >= 1.0:
			_focus_t = -1.0
		else:
			# In over the first 15 %, hold, out over the last 45 %.
			_focus_w = smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.55, 1.0, k))
	if shake_target and l:
		var sc := 1.0 + _punch + _focus_amt * _focus_w
		var c := Vector2(l.center_x, l.rail_y + l.play_h * 0.5).lerp(_focus_pt, _focus_w * 0.85)
		var rot := _focus_rot * _focus_w
		shake_target.scale = Vector2(sc, sc)
		shake_target.rotation = rot
		shake_target.position = c - Transform2D(rot, Vector2(sc, sc), 0.0, Vector2.ZERO).basis_xform(c) + off + view
	var any := false
	for k in _tokens:
		if k.t < 0.0:
			continue
		if k.delay > 0.0:
			k.delay -= rd
			any = true
			continue
		k.t += rd
		if k.t >= TOKEN_TIME:
			k.t = -1.0
			Sfx.play("token", _rng.randf_range(0.95, 1.2))
		else:
			any = true
	_step_waves(rd)
	for f in _flashes.duplicate():
		f.t += delta
		if f.t > 0.22:
			_flashes.erase(f)
		else:
			any = true
	for k in _links.duplicate():
		k.t += delta
		if k.t > 0.5:
			_links.erase(k)
		else:
			any = true
	for q in _later.duplicate():
		q.t -= delta
		if q.t <= 0.0:
			_later.erase(q)
			q.cb.call()
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
	for d in _puffs:
		if d.t >= 0.0:
			d.t += delta
			if d.t > d.life:
				d.t = -1.0
				continue
			any = true
			d.vel *= exp(-2.4 * delta)
			d.pos += d.vel * delta
			d.rot += d.spin * delta
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
		_glow.queue_redraw()
	_drawn_last = any



## Additive layer: a bloom where each flash went off, growing and fading
## over 0.22 s.
func _draw_glow() -> void:
	for f in _flashes:
		var k: float = f.t / 0.22
		var r: float = f.r * lerpf(1.6, 3.2, 1.0 - pow(1.0 - k, 2.0))
		_glow.draw_texture_rect(TEX_SOFT, Rect2(f.at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(f.col, 0.35 * (1.0 - k) * (1.0 - k)))


func _draw() -> void:
	# Smoke sits behind everything else.
	for d in _puffs:
		if d.t < 0.0:
			continue
		var k: float = d.t / d.life
		var e := 1.0 - pow(1.0 - k, 2.5)
		var sz: float = lerpf(d.s0, d.s1, e)
		var alpha: float = d.a * minf(1.0, k * 8.0) * (1.0 - k) * (1.0 - k)
		draw_set_transform(d.pos, d.rot)
		draw_texture_rect(TEX_SMOKE[d.tex], Rect2(-sz, -sz, sz * 2.0, sz * 2.0), false, Color(d.col, alpha))
	draw_set_transform(Vector2.ZERO)
	for f in _flashes:
		if f.t < 0.07:
			var k: float = f.t / 0.07
			draw_circle(f.at, f.r * (1.0 - k * 0.6), Color(1, 1, 1, 0.55 * (1.0 - k)), true, -1.0, true)
	for k in _links:
		var a := 1.0 - float(k.t) / 0.5
		draw_dashed_line(k.a, k.b, Color(k.col, 0.5 * a), 2.0, 7.0, true)
	for r in _rings:
		if r.t < 0.0:
			continue
		var k: float = r.t / RING_LIFE
		var e := 1.0 - pow(1.0 - k, 3.0)
		# Soft pressure wave under the crisp line.
		var rr: float = lerpf(r.r * 0.5, r.r * 1.6, e)
		draw_texture_rect(TEX_RING, Rect2(r.pos - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(r.col, 0.3 * (1.0 - k)))
		draw_arc(r.pos, lerpf(r.r * 0.35, r.r * 1.25, e), 0.0, TAU, 32, Color(r.col, 0.55 * (1.0 - k)), lerpf(3.0, 0.6, k), true)
	for tk in _tokens:
		if tk.t < 0.0 or tk.delay > 0.0:
			continue
		var u: float = ease(tk.t / TOKEN_TIME, 2.2)
		var a: Vector2 = tk.from.lerp(tk.ctrl, u)
		var b: Vector2 = tk.ctrl.lerp(tk.to, u)
		var p := a.lerp(b, u)
		var r := lerpf(3.2, 2.0, u)
		draw_circle(p + Vector2(1.5, 1.5), r, Color(0, 0, 0, 0.3), true, -1.0, true)
		draw_circle(p, r, Pal.GOLD, true, -1.0, true)
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
				# Droplets stretch along their flight, like liquid does.
				var v: Vector2 = f.vel
				var st := 1.0 + minf(v.length() / 500.0, 0.9)
				draw_set_transform(f.pos + Pal.SHADOW_OFFSET * 0.5, v.angle(), Vector2(st, 1.0 / sqrt(st)))
				draw_circle(Vector2.ZERO, f.r, Color(0, 0, 0, 0.25 * alpha), true, -1.0, true)
				draw_set_transform(f.pos, v.angle(), Vector2(st, 1.0 / sqrt(st)))
				draw_circle(Vector2.ZERO, f.r, Color(c, alpha), true, -1.0, true)
				draw_circle(Vector2(-f.r * 0.3, -f.r * 0.3).rotated(-v.angle()), f.r * 0.35, Color(c.lightened(0.35), alpha * 0.6), true, -1.0, true)
				draw_set_transform(Vector2.ZERO)
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
		var s := 1.0 + (0.3 if p.accent else 0.12) * maxf(0.0, 1.0 - k * 8.0)
		var pos: Vector2 = p.pos - Vector2(0, rise)
		var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, p.size).x
		draw_set_transform(pos, 0.0, Vector2(s, s))
		draw_string(font, Vector2(-w * 0.5, 0) + Vector2(2, 2), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, p.size, Color(0, 0, 0, 0.35 * alpha))
		draw_string(font, Vector2(-w * 0.5, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, p.size, Color(p.col, alpha))
		if p.accent:
			var half := (w * 0.5 + 6.0) * ease(minf(1.0, k * 5.0), 0.4)
			draw_line(Vector2(-half, 7.0) + Vector2(1.5, 1.5), Vector2(half, 7.0) + Vector2(1.5, 1.5), Color(0, 0, 0, 0.3 * alpha), 2.0)
			draw_line(Vector2(-half, 7.0), Vector2(half, 7.0), Color(Pal.GOLD, alpha), 2.0)
	draw_set_transform(Vector2.ZERO)
