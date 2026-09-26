extends "res://scripts/target_body.gd"
## Target, part 2 of 3: how an enemy looks. The lit body (mesh, shell,
## membrane), its string, chain and plates, its colour, and the per-frame
## transform. See target_body.gd for its state and behaviour and target.gd
## for its face.

# ---------------------------------------------------------------- rendering
# Each target draws through two child canvas items that follow the body's
# transform. `_body` carries the shared lit material (shaders/lit.gdshader)
# and holds the string, the contact shadow and the body as triangle meshes,
# one draw call each; the light is computed per pixel from a normal per
# vertex, so jelly and shells shade as real solids. `_face` holds the eye,
# mouth and small details, collected in one Ink: a single draw call (see
# target.gd).
# A body's mesh is built once per kind and health (shells never rebuild it);
# jelly only moves its vertices along the surface of its spring field.

var _m_pts := PackedVector2Array()  # body mesh (body space)
var _m_uv := PackedVector2Array()   # band-coded normals
var _m_sh := PackedVector2Array()   # the same, in the shadow band
var _m_idx := PackedInt32Array()
var _m_col := PackedColorArray()
var _one_col := PackedColorArray([Color.WHITE])
var _r_mid := PackedVector2Array()
var _c_pts := PackedVector2Array()  # chain links (world space)
var _c_uv := PackedVector2Array()
var _c_sh := PackedVector2Array()
var _c_links := -1                 # links the chain arrays are laid out for
var _lc := PackedVector2Array()     # link centres this frame
var _ld := PackedVector2Array()     # and directions
var _c_idx := PackedInt32Array()  # string strip (world space)
var _r_pts := PackedVector2Array()
var _r_uv := PackedVector2Array()
var _r_sh := PackedVector2Array()
var _r_idx := PackedInt32Array()
var _p_pts := PackedVector2Array()  # armour plates (world space)
var _p_uv := PackedVector2Array()
var _p_idx := PackedInt32Array()
var _p_col := PackedColorArray()

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
	var tilt_x := cos(tilt) if phase == Phase.FALLING or (kind == Kind.MIRROR and _dropping) else 1.0
	var wig := 0.0
	var bob := Vector2.ZERO
	if _taunt >= 0.0:
		var env := sin(PI * _taunt / TAUNT_TIME)
		wig = sin(_taunt * TAU * 3.2) * 0.28 * env
		bob = Vector2(0, -absf(sin(_taunt * TAU * 3.2)) * 5.0 * env)
	var body := Transform2D(body_rot + wig, Vector2.ZERO) * Transform2D(0.0, Vector2(maxf(absf(tilt_x), 0.08) * signf(tilt_x + 0.0001), 1.0), 0.0, Vector2.ZERO)
	var ds := depth_scale()
	return Transform2D(0.0, pos + render_off + _jit + bob) * squash * body * Transform2D(0.0, Vector2(ds, ds), 0.0, Vector2.ZERO)


## Steel chain along the string: links every 7 px, alternately seen flat
## (an open oval) and edge-on (a short bar), hidden where the body covers
## the end. Built as one tube mesh in the lit wire material (shaded and
## antialiased by the shader) plus its soft shadow: two draw calls for the
## whole chain. World space, drawn with the string.
const LINK_SEG := 8
static var _LINK_P := PackedVector2Array()
static var _LINK_M := PackedVector2Array()


func _draw_chain(ci: RID) -> void:
	if _LINK_P.is_empty():
		for j in LINK_SEG + 1:
			var ang := TAU * j / LINK_SEG
			_LINK_P.append(Vector2(cos(ang) * 4.6, sin(ang) * 2.67))
			_LINK_M.append(Vector2(cos(ang) / 4.6, sin(ang) / 2.67).normalized())
	const STEP := 7.0
	const HW := 1.15
	var hide := radius * depth_scale() * 0.85
	# First the links' centres and directions along the string. Only the
	# last few (inside the body) are ever hidden, so the drawn links are
	# always the first K: their UVs and triangles depend on K alone and are
	# rebuilt only when it changes; each frame just moves the vertices.
	_lc.clear()
	_ld.clear()
	var dist := 0.0
	var next := STEP * 0.5
	for i in range(1, _r_mid.size()):
		var p0 := _r_mid[i - 1]
		var p1 := _r_mid[i]
		var seg := p0.distance_to(p1)
		while seg > 0.0 and next <= dist + seg:
			var c := p0.lerp(p1, (next - dist) / seg)
			next += STEP
			if _attached and c.distance_to(pos) < hide:
				continue
			_lc.append(c)
			_ld.append((p1 - p0) / seg)
		dist += seg
	var links := _lc.size()
	if links == 0:
		return
	if links != _c_links:
		_chain_layout(links)
	var v := 0
	for k in links:
		var c := _lc[k]
		var d := _ld[k]
		var n := d.orthogonal()
		if k % 2 == 1:
			# Flat link: a tube around an oval 4.6 along, 2.7 across
			# (its outline and normals from a table, in the link's frame).
			for j in LINK_SEG + 1:
				var lp := _LINK_P[j]
				var lm := _LINK_M[j]
				var p := c + d * lp.x + n * lp.y
				var m := (d * lm.x + n * lm.y) * HW
				_c_pts[v] = p - m
				_c_pts[v + 1] = p + m
				v += 2
		else:
			# Edge-on link: a short bar.
			var e := d * 4.6
			var w := n * HW * 1.2
			_c_pts[v] = c - e - w
			_c_pts[v + 1] = c - e + w
			_c_pts[v + 2] = c + e - w
			_c_pts[v + 3] = c + e + w
			v += 4
	var a := rope_alpha * modulate.a
	# Shadow: the same links, pushed down-right, in the soft shadow band.
	RenderingServer.canvas_item_add_set_transform(ci, _xf.affine_inverse() * Transform2D(0.0, Vector2(0.9, 0.9)))
	_one_col[0] = Color(0.0, 0.0, 0.0, 0.5 * a)
	RenderingServer.canvas_item_add_triangle_array(ci, _c_idx, _c_pts, _one_col, _c_sh)
	RenderingServer.canvas_item_add_set_transform(ci, _xf.affine_inverse())
	_one_col[0] = Color(Pal.METAL_LIGHT.lightened(0.35).lerp(_base_color(), 0.1).lerp(Pal.INK_DIM, danger * 0.5), a)
	RenderingServer.canvas_item_add_triangle_array(ci, _c_idx, _c_pts, _one_col, _c_uv)


## UVs, shadow UVs and triangles for a chain of `links` links (edge-on and
## flat in turn, starting edge-on); the vertices are filled per frame.
func _chain_layout(links: int) -> void:
	_c_links = links
	_c_pts.clear()
	_c_uv.clear()
	_c_idx.clear()
	for k in links:
		var base := _c_uv.size()
		if k % 2 == 1:
			for j in LINK_SEG + 1:
				_c_uv.append(Vector2(B_WIRE - 1.0, float(j)))
				_c_uv.append(Vector2(B_WIRE + 1.0, float(j)))
			for j in LINK_SEG:
				var q := base + j * 2
				_c_idx.append_array([q, q + 1, q + 3, q, q + 3, q + 2])
		else:
			_c_uv.append_array([Vector2(B_WIRE - 1.0, 0.0), Vector2(B_WIRE + 1.0, 0.0), Vector2(B_WIRE - 1.0, 1.0), Vector2(B_WIRE + 1.0, 1.0)])
			_c_idx.append_array([base, base + 1, base + 3, base, base + 3, base + 2])
	_c_pts.resize(_c_uv.size())
	_c_sh.resize(_c_uv.size())
	for j in _c_uv.size():
		_c_sh[j] = Vector2(B_SHADOW + (_c_uv[j].x - B_WIRE), 0.0)


func rope_style() -> Rope:
	match kind:
		Kind.DROP:
			return Rope.BUNGEE
		Kind.REEL:
			return Rope.MONO
		Kind.SHIELD, Kind.MIRROR:
			return Rope.CABLE
		Kind.HEAVY, Kind.BOSS:
			return Rope.CHAIN
	return Rope.CORD if soft else Rope.WIRE


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
	if trait_kind == Trait.JITTERY and phase == Phase.HANGING:
		j += Vector2(sin(_clock * 23.0 + _hue_shift * 50.0), cos(_clock * 19.0)) * 0.3
	if (panicked() or hurry) and phase == Phase.HANGING:
		j += Vector2(sin(_clock * 47.0), cos(_clock * 41.0)) * (1.1 if panicked() else 0.7)
	var ew := evolve_warning()
	if ew > 0.0 and phase == Phase.HANGING:
		j += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 1.8 * ew
	return j


func _update_eye(delta: float) -> void:
	_closed_t = maxf(0.0, _closed_t - delta)
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_t = 0.26 if trait_kind == Trait.SLEEPY else 0.13
		match trait_kind:
			Trait.JITTERY:
				_blink_in = randf_range(1.0, 2.6)
			Trait.SLEEPY:
				_blink_in = randf_range(4.0, 8.0)
			_:
				_blink_in = randf_range(3.0, 7.0)
	if _blink_in > 2.0 and morale > 0.5:
		# Nervous: they blink more.
		_blink_in -= delta
	_blink_t = maxf(0.0, _blink_t - delta)
	startle_t = maxf(0.0, startle_t - delta)
	_watch_t = maxf(0.0, _watch_t - delta)
	if kind == Kind.MIRROR and phase == Phase.HANGING:
		_admire_t = maxf(0.0, _admire_t - delta)
		_vain_in -= delta
		if _vain_in <= 0.0:
			_vain_in = randf_range(6.0, 10.0)
			if not aimed and not incoming:
				_admire_t = 1.3
	var goal_open := 0.42 if (squint or tele_t > 0.0) else 1.0
	if startle_t > 0.0 or (panicked() and phase == Phase.HANGING):
		goal_open = 1.3
	elif _blink_t > 0.0:
		goal_open = 0.0
	_open = lerpf(_open, goal_open, Pal.damp(0.35, delta))
	# Pupil follows the ball: 0.15 per frame, clamped inside the eye ring.
	var goal := Vector2.ZERO
	var target := look_at
	var looking := has_look
	if _watch_t > 0.0 and is_instance_valid(_watch) and not incoming:
		target = _watch.pos
		looking = true
	if looking:
		var d := (target - pos).rotated(-body_rot)
		goal = d.normalized() * minf(1.0, d.length() / 160.0) if d.length() > 0.01 else Vector2.ZERO
	if _admire_t > 0.0:
		# Up and to the left, at the glint on its own face.
		goal = Vector2(-0.75, -0.65)
	var quick := 0.15
	if not is_nan(_queued_x):
		# Mid-feint: the eye darts to where it is really going (the tell).
		goal = Vector2(signf(_queued_x - anchor.x), -0.15).rotated(-body_rot)
		quick = 0.45
	_pupil = _pupil.lerp(goal, Pal.damp(quick, delta))


func color() -> Color:
	var base := _base_color()
	if danger > 0.0 and phase == Phase.HANGING and not scared:
		var pulse := 0.8 + 0.2 * sin(_clock * TAU * 0.8)
		base = base.lerp(Pal.CORAL, danger * pulse)
	if scared:
		# Blanched with fright.
		base = base.lerp(Pal.INK, 0.3)
	# Depth: back ones recede into the room's darkness, front ones catch
	# a little more of the lamp.
	# Back ones sink into the room (darker, cooler, flatter), so a crowd
	# separates into layers and the front row reads first.
	var sd := seen_depth()
	var back := maxf(0.0, -sd)
	base = base.darkened(0.4 * back).lerp(Color("2A3140"), 0.14 * back).lightened(0.08 * maxf(0.0, sd))
	var ew := evolve_warning()
	if ew > 0.0:
		# About to harden: a quickening pale pulse.
		base = base.lerp(Pal.EYE, 0.35 * ew * (0.5 + 0.5 * sin(_clock * lerpf(8.0, 22.0, ew))))
	if flash_t > 0.0:
		# One-frame-ish matte flash on impact (lighter, never glowing).
		base = base.lerp(Pal.EYE, 0.55 * flash_t / 0.07)
	return base


func _base_color() -> Color:
	if golden:
		return Pal.GOLD.lerp(Pal.GOLD_LIGHT, 0.5 + 0.5 * sin(_clock * 7.0))
	# The current colour theme (they change, harmoniously, wave by wave).
	var base := Pal.kind_color(kind)
	if variant != Var.STD:
		base = base.lerp(VARIANT_TINT[variant], 0.75)
	if _stance_k > 0.0 and stance != Stance.CALM:
		base = base.lerp(STANCE_TINT[stance], 0.4 * _stance_k)
	if kind != Kind.SHIELD and kind != Kind.BOSS and kind != Kind.MIRROR:
		# Each individual a shade of its own: hue, saturation and value drift
		# a little around the theme's colour, never far enough to blur kinds.
		base = Color.from_hsv(fposmod(base.h + _hue_shift, 1.0), clampf(base.s + _hue_shift, 0.3, 1.0), clampf(base.v + _val_shift, 0.2, 1.0))
	return base


const SHADOW_OFF := Vector2(5.0, 6.0)
const B_JELLY := 0.0
const B_SHADOW := 4.0
const B_CORD := 8.0
const B_WIRE := 12.0
const B_SHELL := 16.0
const B_MEMBRANE := 20.0
const B_METAL := 24.0
const B_CABLE := 28.0
# How each kind hangs: its string, by what it has to carry.
#   cord    jelly bodies: a dyed braided cord
#   bungee  the Dykker: thick elastic, thinning as it stretches
#   mono    the Snelle: fine fishing line off its reel
#   cable   armoured Vokter and Speilet: twisted steel
#   chain   Tungvekt and Spinneren: the heaviest, on steel chain
#   wire    the rest of the shells: plain wire
enum Rope { CORD, BUNGEE, MONO, CABLE, CHAIN, WIRE }
const ROPE_SUB := 2                 # smoothing steps per rope segment

static var _lit: ShaderMaterial


## Hands the balls' light (up to three, see shaders/lit.gdshader) to every
## lit body.
static func set_lights(lights: Array[Vector4], col: Color) -> void:
	if _lit:
		_lit.set_shader_parameter("lights", lights)
		_lit.set_shader_parameter("light_col", Vector3(col.r, col.g, col.b))
## Unit directions around a circle, cached per segment count.
static func _dirs(seg: int) -> PackedVector2Array:
	if not _dir_cache.has(seg):
		var a := PackedVector2Array()
		for i in seg:
			a.append(Vector2.from_angle(i * TAU / seg))
		_dir_cache[seg] = a
	return _dir_cache[seg]


static func set_view(v: Vector2) -> void:
	view_dir = v
	if _lit:
		_lit.set_shader_parameter("view", v * 0.35)


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
	var style := rope_style()
	var hw := (1.6 if soft else 1.1) + danger * 0.3
	var band := B_CORD if soft else B_WIRE
	match style:
		Rope.BUNGEE:
			# Elastic: thick, thinner the more it is stretched.
			hw = clampf(2.6 * sqrt(maxf(length, 40.0) / maxf(_rope_len_now(), 1.0)), 1.4, 2.8)
		Rope.MONO:
			hw = 0.75
			band = B_WIRE
		Rope.CABLE:
			hw = 1.7
			band = B_CABLE
		Rope.CHAIN:
			# Only a dark core here; the links are drawn on the face layer.
			hw = 0.7
			band = B_WIRE
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
	# The strings are materials, not light: undyed hemp for jelly, dark
	# steel wire for shells, each only faintly tinted by what hangs from it,
	# so they never read as the glowing fibres behind. Near the line they
	# pale under strain.
	var tint := _base_color()
	var sc := (Pal.HEMP.lerp(tint, 0.15) if soft else Pal.METAL_LIGHT.darkened(0.1).lerp(tint, 0.1)).lerp(Pal.INK_DIM, danger * 0.5)
	match style:
		Rope.CHAIN:
			sc = Color(0.0, 0.0, 0.0, 0.6)
		Rope.CABLE:
			# Bare steel, only faintly tinted by what hangs from it.
			sc = Pal.METAL_LIGHT.lerp(tint, 0.12).lerp(Pal.INK_DIM, danger * 0.5)
		Rope.MONO:
			sc = Pal.INK.lerp(tint, 0.15)
		Rope.BUNGEE:
			# Latex: the slingshot's amber, darkened.
			sc = Pal.BAND.darkened(0.15).lerp(tint, 0.15)
	if style != Rope.CHAIN and style != Rope.MONO:
		# A soft shadow on the wall behind, so the string stands off it.
		_r_sh.resize(_r_uv.size())
		for j in _r_uv.size():
			_r_sh[j] = Vector2(B_SHADOW + (_r_uv[j].x - band), 0.0)
		RenderingServer.canvas_item_add_set_transform(ci, _xf.affine_inverse() * Transform2D(0.0, Vector2(2.5, 3.5)))
		_one_col[0] = Color(0.0, 0.0, 0.0, 0.45 * rope_alpha)
		RenderingServer.canvas_item_add_triangle_array(ci, _r_idx, _r_pts, _one_col, _r_sh)
		RenderingServer.canvas_item_add_set_transform(ci, _xf.affine_inverse())
	_one_col[0] = Color(sc, rope_alpha)
	RenderingServer.canvas_item_add_triangle_array(ci, _r_idx, _r_pts, _one_col, _r_uv)
	if style == Rope.CHAIN:
		_draw_chain(ci)


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
		Kind.PIPP:
			_fan(_round(r, 20), Vector2.ZERO, b)
		Kind.PAKKIS:
			_fan(_round(r, 24), Vector2.ZERO, b)
		Kind.SHADE:
			_fan(_crescent(r), Vector2(-r * 0.55, 0.0), b)
		Kind.BOSS:
			_fan(_hex(r, 3), Vector2.ZERO, b)
		Kind.MEDIC:
			_membrane(r - 7.5, 22)
			_ring_tube(r - 4.5, 4.0, 32, b)
		Kind.MIRROR:
			# A polished hexagon: all metal, so it throws the light back.
			_fan(_hex(r, 2), Vector2.ZERO, B_METAL)
			_poly_tube(_hex(r - 2.0, 2), 2.0, b)
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


## A plain disc outline (Pipp, Pakkis): round, soft bodies.
func _round(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.from_angle(TAU * i / n) * r)
	return pts


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
			# Its orbiting plates are brass: the Spinneren is the one enemy
			# built from the same metal as your instrument.
			var brass := Color(Tok.PRIMARY, keep)
			var st: Array = BOSS_STAGES[boss_stage]
			for k in int(st[0]):
				_plate(radius + 11.0, orbit + TAU * k / st[0], deg_to_rad(st[1]), 4.5, brass, sh)
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
