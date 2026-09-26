class_name Backdrop
extends Node2D
## Static layer behind the play field: the lit, grained backdrop shader, a
## distant parallax layer of strings (40% scale, slower than the foreground),
## the danger line, slow dust and a few large out-of-focus motes drifting
## through the lamp light. Nothing here shakes.
##
## The far strings are fibres of light:
## - colour flows slowly down each one through the wave's enemy palette
##   (softened toward ink), each string a little behind its neighbour, so
##   the colours drift across the room like an aurora and follow the theme;
## - drops of light slide down them on the beat and light the bead below;
## - they answer the game: a hit sends a ripple of the target's colour
##   through the strings around it, overload turns them gold, and as a
##   target nears the line their lower ends warm to coral.
## They dim where a target hangs in front, so the field always reads first.
##
## They are also the game's energy net:
## - a kill sends a bead of its colour up the nearest fibre, along the rail
##   and into the tension string (which it tightens: `energy_arrived`);
## - where an enemy is about to drop in, a thread of its colour runs down
##   first (`foreshadow`);
## - a ball crossing a fibre plucks it: it quivers and sounds (`cross`);
## - the streak lights them one by one from the middle out;
## - they warn of a hazard just before it: they lean into a gust, go dark
##   from the top before a blackout, flicker gold before a golden one;
## - in the finale they pull straight and burn amber on the beat;
## - now and then a gold drop gathers on one; shoot it (`gold_pos`).

const FAR_SCALE := 0.4
const FAR_ALPHA := 0.08
const FAR_COUNT := 9
const SEG := 18                # vertices per fibre
const FLOW := 1.0 / 44.0       # palette cycles per second
const RIPPLE_SPEED := 700.0
const RIPPLE_LIFE := 1.1
const DROP_EVERY := 2          # beats between drops
# Kinds whose theme colours the fibres flow through.
const FIBRE_KINDS := [0, 2, 3, 4, 1]

var l: Layout
var danger := 0.0              # max target danger, 0..1
var descent := 0.0             # foreground descent speed (px/s)
var heat := 0.0                # overload (0/1): the room warms to gold
var flow := false              # flow: the fibres pulse on every beat
var gust := 0.0                # a gust (px/s², signed): streaks of wind, strings lean
var dark := 0.0                # blackout, 0..1: the wall and dust sink into the dark
var _rescue := 0.0             # a rescue: the danger wire flashes gold
var _flow := 0.0
var targets: Array[Target] = []  # their shadows fall on the wall
var view := Vector2.ZERO       # tilt parallax (world px); this layer moves less
var _heat := 0.0
signal energy_arrived(col: Color)
const ENERGY_UP := 0.3         # s up the fibre
const ENERGY_ALONG := 0.3      # s along the rail into the string
const T_WARM := Color("EC9A3C")
var progress := 0.0            # the wave's progress: where the string's tip is
var string_y := 0.0            # the tension string's height (set by the game)
var streak_lit := 0            # fibres lit by the streak (0..FAR_COUNT)
var finale := false
var warn := 0.0                # a hazard is coming, 0..1
var warn_kind := 0             # 1 gust, 2 blackout, 3 golden
var warn_dir := 1.0
var _energy: Array[Dictionary] = []
var _fore: Array[Dictionary] = []
var _lit: Array[float] = []
var _finale := 0.0
var _gold := {}                # the shootable drop: {i, t, st} (st 0 forming, 1 hanging, 2 falling)
const RANK := [4, 3, 5, 2, 6, 1, 7, 0, 8]
var _bokeh: Array[Dictionary] = []
const SOFT := preload("res://assets/particles/soft.png")

var _far: Array[Dictionary] = []
var _far_drop := 0.0
var _clock := 0.0
var _dust: CPUParticles2D
var _bg: ColorRect
var _layer: Node2D
var _rng := RandomNumberGenerator.new()
var _wire := PackedVector2Array()
var _far_lines := PackedVector2Array()
var _glow: Node2D              # additive: the fibres' halo and the drops
var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _halo := PackedColorArray()
var _pal: Array[Color] = []
var _ripples: Array[Dictionary] = []
var _drops: Array[Dictionary] = []
var _last_beat := -1
var _drop_t := 2.0
const MIST := preload("res://assets/particles/smoke_b.png")


func _ready() -> void:
	_rng.seed = 7
	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/backdrop.gdshader")
	_bg.material = mat
	add_child(_bg)
	_layer = Node2D.new()
	add_child(_layer)
	_layer.draw.connect(_draw_layer)
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
	_pts.resize(SEG)
	_cols.resize(SEG)
	_halo.resize(SEG)
	for i in FAR_COUNT:
		_far.append({
			"x": 0.0,
			"len": _rng.randf_range(0.15, 0.75),
			"phase": _rng.randf() * TAU,
			"rate": _rng.randf_range(0.18, 0.32),
			"beads": 1 + _rng.randi() % 3,
			"flash": 0.0,
			"vib": 0.0,
			"cd": 0.0,
		})
		_lit.append(0.0)
	for i in 6:
		_bokeh.append({"x": _rng.randf(), "y": _rng.randf(), "r": _rng.randf_range(40.0, 90.0),
			"vx": _rng.randf_range(-4.0, 4.0), "vy": _rng.randf_range(-6.0, -2.0), "ph": _rng.randf() * TAU})
	_dust = CPUParticles2D.new()
	_dust.amount = Device.count(16)
	Device.tier_changed.connect(func() -> void: _dust.amount = Device.count(16))
	_dust.lifetime = 16.0
	_dust.preprocess = 16.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.direction = Vector2.UP
	_dust.spread = 25.0
	_dust.gravity = Vector2(0, -3)
	_dust.initial_velocity_min = 6.0
	_dust.initial_velocity_max = 14.0
	# Soft motes (Kenney Particle Pack, CC0) at a few depths: they drift in
	# and out of the light instead of popping.
	_dust.texture = preload("res://assets/particles/soft.png")
	_dust.scale_amount_min = 0.07
	_dust.scale_amount_max = 0.2
	_dust.color = Color(Pal.INK, 0.07)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	_dust.color_ramp = fade
	add_child(_dust)


func setup(layout: Layout) -> void:
	l = layout
	_bg.position = Vector2.ZERO
	_bg.size = l.size
	var mat := _bg.material as ShaderMaterial
	mat.set_shader_parameter("size", l.size)
	mat.set_shader_parameter("rail_y", l.rail_y)
	mat.set_shader_parameter("danger_y", l.danger_y)
	for i in FAR_COUNT:
		_far[i].x = (i + 0.5) / FAR_COUNT * l.size.x + _rng.randf_range(-20.0, 20.0)
	_dust.position = Vector2(l.center_x, l.size.y * 0.55)
	_dust.emission_rect_extents = Vector2(l.size.x * 0.5, l.size.y * 0.45)


func _process(delta: float) -> void:
	_clock += delta
	var mat := _bg.material as ShaderMaterial
	mat.set_shader_parameter("time", _clock)
	mat.set_shader_parameter("danger", clampf(danger, 0.0, 1.0))
	var rd := delta / maxf(Engine.time_scale, 0.001)
	_heat = move_toward(_heat, heat, rd / 0.6)
	_flow = move_toward(_flow, 1.0 if flow else 0.0, rd / 0.4)
	_rescue = maxf(0.0, _rescue - rd / 0.9)
	_bg.modulate = Color.WHITE.lerp(Color(0.3, 0.32, 0.4), dark)
	_dust.gravity = Vector2(gust * 0.35, -3.0)
	mat.set_shader_parameter("heat", _heat)
	_dust.color = Color(Pal.INK.lerp(Pal.GOLD_LIGHT, _heat), 0.07 + 0.08 * _heat)
	if l:
		for b in _bokeh:
			b.x = fposmod(b.x + b.vx * delta / l.size.x, 1.0)
			b.y = fposmod(b.y + b.vy * delta / l.size.y, 1.0)
	_far_drop = fmod(_far_drop + descent * FAR_SCALE * delta, l.play_h * 0.3) if l else 0.0
	_step_fibres(rd)
	_layer.queue_redraw()
	_glow.queue_redraw()


## A hit at `at`: a ring of the target's colour runs out through the strings.
func ripple(at: Vector2, col: Color, strength := 1.0) -> void:
	if _ripples.size() >= 6:
		_ripples.pop_front()
	_ripples.append({"at": at - view * 0.4, "col": col.lerp(Pal.INK, 0.15), "s": strength, "t": 0.0})


func _step_fibres(rd: float) -> void:
	for r in _ripples:
		r.t += rd
	_ripples = _ripples.filter(func(r: Dictionary) -> bool: return r.t < RIPPLE_LIFE)
	for i in _far.size():
		var f: Dictionary = _far[i]
		f.flash = maxf(0.0, f.flash - rd * 2.2)
		f.vib = maxf(0.0, f.vib - rd * 1.4)
		f.cd = maxf(0.0, f.cd - rd)
		var rank: int = RANK.find(i)
		var want := 1.0 if rank < streak_lit else 0.0
		# Lit from the middle out; put out from the edges in.
		_lit[i] = move_toward(_lit[i], want, rd * (4.0 if want > _lit[i] else 1.2 + (8 - rank) * 0.5))
	_finale = move_toward(_finale, 1.0 if finale else 0.0, rd / 0.8)
	_step_energy(rd)
	for d in _drops:
		d.t += rd
		if d.t >= d.dur and not d.landed:
			d.landed = true
			_far[d.i].flash = 1.0
	_drops = _drops.filter(func(d: Dictionary) -> bool: return d.t < d.dur + 0.1)
	if Prefs.reduced_motion or l == null:
		return
	# Drops fall on the beat while the play track runs; in the menu, at an
	# unhurried random pace.
	var b := Music.beat()
	if b >= 0.0:
		var n := int(b) / (1 if flow else DROP_EVERY)
		if n != _last_beat:
			_last_beat = n
			if flow or _rng.randf() < 0.6:
				_spawn_drop()
	else:
		_drop_t -= rd
		if _drop_t <= 0.0:
			_drop_t = _rng.randf_range(1.6, 3.4)
			_spawn_drop()


# ---------------------------------------------------------------- energy net

## A kill at `at` (screen space): its energy runs up the nearest fibre.
func send_energy(at: Vector2, col: Color) -> void:
	if l == null or _far.is_empty() or not _far[0].has("pts"):
		energy_arrived.emit(col)
		return
	var lx := at.x - view.x * 0.4
	var best := 0
	for i in _far.size():
		if absf(_far[i].x - lx) < absf(_far[best].x - lx):
			best = i
	var f: Dictionary = _far[best]
	var len := maxf(1.0, f.pts[SEG - 1].y - f.pts[0].y)
	var s0 := clampf((at.y - view.y * 0.4 - f.pts[0].y) / len, 0.0, 1.0)
	if _energy.size() >= 8:
		# Too many at once: the oldest arrives now.
		var e: Dictionary = _energy.pop_front()
		energy_arrived.emit(e.col)
	_energy.append({"i": best, "s0": s0, "col": col.lerp(Pal.INK, 0.1), "t": 0.0, "up": ENERGY_UP * (0.4 + 0.6 * s0)})
	f.flash = maxf(f.flash, 0.6)


func _step_energy(rd: float) -> void:
	for e in _energy:
		e.t += rd
	var keep: Array[Dictionary] = []
	for e in _energy:
		if e.t >= e.up + ENERGY_ALONG:
			energy_arrived.emit(e.col)
		else:
			keep.append(e)
	_energy = keep
	for fo in _fore:
		fo.t += rd
	_fore = _fore.filter(func(fo: Dictionary) -> bool: return fo.t < fo.dur + 0.35)
	if not _gold.is_empty():
		_gold.t += rd
		match int(_gold.st):
			0:
				if _gold.t >= 0.8:
					_gold.st = 1
					_gold.t = 0.0
			1:
				if _gold.t >= 5.0:
					_gold.st = 2
					_gold.t = 0.0
			2:
				if _gold.t >= 1.0:
					_gold = {}


## Where an energy bead is now (layer space): up the fibre, then an arc
## along the rail into the string at its tip.
func _energy_pos(e: Dictionary) -> Vector2:
	var f: Dictionary = _far[e.i]
	if not f.has("pts"):
		return Vector2.INF
	if e.t < e.up:
		var k: float = e.t / e.up
		var s: float = lerpf(e.s0, 0.0, k * k)
		return _fibre_at(f, s)
	var a: Vector2 = f.pts[0]
	var tip := Vector2(24.0 + progress * (l.size.x - 48.0), string_y) - view * 0.4
	var ctrl := Vector2(lerpf(a.x, tip.x, 0.55), l.rail_y - 4.0)
	var u := Motion.ease_value(Motion.Ease.STANDARD, clampf((e.t - e.up) / ENERGY_ALONG, 0.0, 1.0))
	return a.lerp(ctrl, u).lerp(ctrl.lerp(tip, u), u)


func _fibre_at(f: Dictionary, s: float) -> Vector2:
	var x := clampf(s, 0.0, 1.0) * (SEG - 1)
	var i := mini(int(x), SEG - 2)
	return (f.pts[i] as Vector2).lerp(f.pts[i + 1], x - i)


## An enemy will drop in at `at` (screen space, where it will hang) in
## `dur` s: a thread of its colour runs down from the rail to there.
func foreshadow(at: Vector2, col: Color, dur: float) -> void:
	if _fore.size() >= 8:
		_fore.pop_front()
	_fore.append({"at": at, "col": col.lerp(Pal.INK, 0.1), "t": 0.0, "dur": maxf(0.25, dur)})


## A ball moved from `p0` to `p1` (screen space): the first fibre it
## crossed is plucked (it quivers and flashes) and returned, else -1.
func cross(p0: Vector2, p1: Vector2) -> int:
	if l == null or _far.is_empty() or not _far[0].has("pts"):
		return -1
	var o := view * 0.4
	var a := p0 - o
	var b := p1 - o
	for i in _far.size():
		var f: Dictionary = _far[i]
		var x: float = f.pts[SEG / 2].x
		if (a.x - x) * (b.x - x) > 0.0 or a.x == b.x or f.cd > 0.0:
			continue
		var y := lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
		if y < f.pts[0].y or y > f.pts[SEG - 1].y + 8.0:
			continue
		f.vib = 1.0
		f.cd = 0.15
		f.flash = maxf(f.flash, 0.5)
		return i
	return -1


## A gold drop gathers on a fibre (one at a time).
func spawn_gold() -> void:
	if not _gold.is_empty() or _far.is_empty():
		return
	_gold = {"i": _rng.randi() % _far.size(), "t": 0.0, "st": 0}


## The gold drop's position (screen space) while it can be shot, else INF.
func gold_pos() -> Vector2:
	if _gold.is_empty() or int(_gold.st) == 0 or not _far[_gold.i].has("bead"):
		return Vector2.INF
	return _gold_local() + view * 0.4


func catch_gold() -> Vector2:
	var p := gold_pos()
	_gold = {}
	return p


func _gold_local() -> Vector2:
	var f: Dictionary = _far[_gold.i]
	var p: Vector2 = f.bead + Vector2(0, 16.0)
	match int(_gold.st):
		1:
			p.y += sin(_clock * 2.2) * 2.0
		2:
			var k: float = _gold.t
			p.y += 60.0 * k * k * 3.0
	return p


func _spawn_drop() -> void:
	if _drops.size() >= (7 if flow else 4):
		return
	var i := _rng.randi() % _far.size()
	_drops.append({"i": i, "t": 0.0, "dur": 0.55 + float(_far[i].len) * 0.9, "landed": false})


func _draw_layer() -> void:
	if l == null:
		return
	_layer.position = view * 0.4
	_draw_wall_shadows()
	_draw_bokeh()
	_draw_gust()
	_draw_far()
	_draw_danger()


## Every hanging target throws a soft shadow onto the wall behind it, away
## from the lamp. The further from the wall (the higher its depth), the
## further the shadow falls and the softer and fainter it is; the string's
## shadow runs from the hook (on the wall) to the body's.
func _draw_wall_shadows() -> void:
	var lamp := Vector2(l.size.x * 0.32, l.rail_y - 60.0)
	var sc := Color(0.0, 0.0, 0.0)
	for t in targets:
		var a := t.shadow_alpha()
		if a <= 0.0:
			continue
		var far := (t.seen_depth() + 1.0) * 0.5
		var dir := (t.pos - lamp).normalized()
		var p := t.pos + dir * lerpf(14.0, 34.0, far) + Vector2(0, lerpf(6.0, 14.0, far))
		var r := t.radius * t.depth_scale() * lerpf(1.45, 2.0, far)
		var al := a * lerpf(0.6, 0.38, far)
		if t.phase == Target.Phase.HANGING and t.rope_alpha > 0.0:
			# World space: the body shadow below leaves its own transform set.
			_layer.draw_set_transform(Vector2.ZERO)
			_layer.draw_line(t.anchor + Vector2(0, 8), p, Color(sc, 0.1 * a), 2.0, true)
		var stretch := 1.0
		if t.kind == Target.Kind.ROD:
			stretch = (Target.ROD_HALF + t.radius) / t.radius
		_layer.draw_set_transform(p, t.body_rot, Vector2(stretch, 1.0))
		_layer.draw_texture_rect(SOFT, Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(sc, al))
	_layer.draw_set_transform(Vector2.ZERO)


## Large soft motes, out of focus, brighter where the lamp's cone falls.
func _draw_bokeh() -> void:
	var lamp := Vector2(l.size.x * 0.32, l.rail_y)
	for b in _bokeh:
		var p := Vector2(b.x * l.size.x, l.rail_y + b.y * l.play_h)
		var lit := clampf(1.0 - p.distance_to(lamp) / (l.size.y * 0.7), 0.0, 1.0)
		var a := (0.012 + 0.03 * lit) * (0.7 + 0.3 * sin(_clock * 0.4 + b.ph)) * (1.0 - 0.8 * dark)
		var r: float = b.r
		var c := Pal.INK.lerp(Pal.GOLD_LIGHT, _heat)
		_layer.draw_texture_rect(SOFT, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c, a))


## The fibres: each string a polyline with a colour per vertex, drawn thin
## on the normal layer (with its beads) and again wide and faint on the
## additive layer as its halo.
func _draw_far() -> void:
	var calm := Prefs.reduced_motion
	var flow := _clock * FLOW * (0.5 if calm else 1.0)
	_pal.clear()
	# Cooled toward slate and kept faint: the fibres are the room's light,
	# and must never be mistaken for the creatures' strings in front.
	for k in FIBRE_KINDS:
		_pal.append(Pal.kind_color(k).lerp(Color("5E7896"), 0.45).lerp(Pal.INK, 0.08))
	var hittable: Array[Target] = []
	for t in targets:
		if t.is_hittable():
			hittable.append(t)
	var dk := clampf(danger, 0.0, 1.0)
	# Flow: every fibre flashes on the beat, tinted electric.
	var pulse := 0.0
	if _flow > 0.0:
		var b := Music.beat()
		pulse = _flow * (pow(1.0 - fposmod(b, 1.0), 4.0) if b >= 0.0 else 0.5 + 0.5 * sin(_clock * 13.0))
	for i in _far.size():
		var f: Dictionary = _far[i]
		var sway := (sin(_clock * f.rate + f.phase) * 6.0) * (1.0 - 0.85 * _finale) + gust * 0.12
		if warn_kind == 1:
			# A gust is coming: they lean into it first.
			sway += warn_dir * warn * 16.0
		var vib: float = f.vib * f.vib * 5.0
		var lit: float = _lit[i]
		var top := Vector2(f.x, l.rail_y + 10.0)
		var length: float = l.play_h * f.len * 0.8 + _far_drop * FAR_SCALE
		# Only the targets hanging near this string can dim it.
		var near_t: Array[Target] = []
		for t in hittable:
			if absf(t.pos.x - view.x * 0.4 - f.x) < t.radius * 3.0 + 16.0:
				near_t.append(t)
		var drop_s := -1.0
		for d in _drops:
			if d.i == i and not d.landed:
				var k: float = d.t / d.dur
				drop_s = k * k * _bead_s(f)
		for v in SEG:
			var s := float(v) / (SEG - 1)
			var p := top + Vector2(sway * pow(s, 1.5) + vib * sin(PI * s) * sin(_clock * 42.0 + i), length * s)
			_pts[v] = p
			# Colour flowing down the string through the palette.
			var col := _palette(flow + i * 0.11 - s * 0.35)
			# A slow swell of light travelling down.
			var bright := 0.13 + 0.07 * sin(_clock * 0.45 + i * 1.9 - s * 5.0)
			if _flow > 0.0:
				col = col.lerp(Pal.FLOW, 0.55 * _flow)
				bright += 0.1 * _flow + 0.35 * pulse
			if _heat > 0.0:
				col = col.lerp(Pal.GOLD_LIGHT, _heat * 0.85)
				bright += 0.1 * _heat
			if lit > 0.0:
				col = col.lerp(Pal.GOLD_LIGHT, 0.55 * lit)
				bright += 0.45 * lit
			if f.vib > 0.0:
				bright += 0.5 * f.vib * sin(PI * s)
			if _finale > 0.0:
				col = col.lerp(T_WARM, 0.6 * _finale)
				bright += _finale * (0.1 + 0.2 * _beat())
			if warn_kind == 2 and warn > 0.0 and s < warn:
				# A blackout is coming: the light drains from the top down.
				bright *= 0.25
			elif warn_kind == 3 and warn > 0.0:
				col = col.lerp(Pal.GOLD_LIGHT, 0.6 * warn * (0.5 + 0.5 * sin(_clock * 20.0 + i)))
			if dark > 0.0:
				bright *= 1.0 - 0.7 * dark * smoothstep(0.0, 0.6, 1.0 - s + dark * 0.6)
			if dk > 0.0:
				var low := pow(s, 1.3) * smoothstep(0.35, 1.0, dk)
				col = col.lerp(Pal.CORAL, low)
				bright += 0.2 * low
			for r in _ripples:
				var front: float = r.t * RIPPLE_SPEED
				var e: float = (p.distance_to(r.at) - front) / 110.0
				var w: float = exp(-e * e) * r.s * pow(1.0 - r.t / RIPPLE_LIFE, 2.0)
				if w > 0.01:
					col = col.lerp(r.col, minf(1.0, w * 1.3))
					bright += 0.7 * w
			if drop_s >= 0.0 and s <= drop_s + 0.02:
				# The drop's short tail of light.
				bright += 0.45 * clampf(1.0 - (drop_s - s) / 0.14, 0.0, 1.0)
			# Dim behind targets so the play field stays clear.
			for t in near_t:
				var near := p.distance_to(t.pos - view * 0.4) / (t.radius * 3.0)
				if near < 1.0:
					bright *= lerpf(0.3, 1.0, near * near)
			_cols[v] = Color(col, minf(bright, 0.8))
			_halo[v] = Color(col, minf(bright, 0.8) * 0.32)
		_layer.draw_polyline_colors(_pts, _cols, 1.0, true)
		for b in f.beads:
			var bs := 1.0 - float(b) * 0.09
			var bp := top + Vector2(sway * pow(bs, 1.5), length * bs)
			var bc: Color = _cols[SEG - 1]
			Pal.disc(_layer, bp, 2.4, Color(bc, minf(1.0, bc.a * 1.6 + 0.5 * f.flash)))
		f.pts = _pts.duplicate()
		f.halo = _halo.duplicate()
		f.bead = top + Vector2(sway, length * _bead_s(f))
		f.drop = top + Vector2(sway * pow(drop_s, 1.5), length * drop_s) if drop_s >= 0.0 else Vector2.INF
		f.col = _cols[SEG - 1]


func _beat() -> float:
	var b := Music.beat()
	return pow(1.0 - fposmod(b, 1.0), 3.0) if b >= 0.0 else 0.5 + 0.5 * sin(_clock * 6.0)


## A saved target: the wire it nearly crossed flashes gold.
func rescue() -> void:
	_rescue = 1.0


## Wind: fine streaks racing across the room with the gust.
func _draw_gust() -> void:
	var g := absf(gust) / (160.0 * l.scale)
	if g <= 0.02:
		return
	var w := l.size.x
	var dir := signf(gust)
	for i in 18:
		var u := fposmod(i * 0.618, 1.0)
		var y := l.rail_y + 30.0 + u * (l.play_h - 60.0)
		var len := 50.0 + 90.0 * fposmod(i * 0.37, 1.0)
		var sp := 700.0 + 500.0 * fposmod(i * 0.71, 1.0)
		var x := fposmod(i * 131.0 + _clock * sp * dir, w + len * 2.0) - len
		var a := 0.07 * g * (0.5 + 0.5 * fposmod(i * 0.43, 1.0))
		_layer.draw_line(Vector2(x, y), Vector2(x - dir * len, y + len * 0.04), Color(Pal.INK, a), 1.2, true)


## Where a string's lowest bead sits (0..1 down it).
func _bead_s(f: Dictionary) -> float:
	return 1.0 - float(f.beads) * 0.09


## A soft, looping blend through the fibre palette.
func _palette(u: float) -> Color:
	var n := _pal.size()
	var x := fposmod(u, 1.0) * n
	var i := int(x)
	return _pal[i % n].lerp(_pal[(i + 1) % n], smoothstep(0.0, 1.0, x - i))


## Additive: the fibres' halo, the drops and a bead's flash as a drop lands.
func _draw_glow() -> void:
	if l == null or _far.is_empty() or not _far[0].has("pts"):
		return
	_glow.position = view * 0.4
	var hi := Device.tier != Device.Tier.LOW
	for f in _far:
		if hi:
			_glow.draw_polyline_colors(f.pts, f.halo, 7.0, true)
		if f.drop != Vector2.INF:
			_glow.draw_texture_rect(SOFT, Rect2(f.drop - Vector2(9, 9), Vector2(18, 18)), false, Color(Pal.INK.lerp(f.col, 0.5), 0.55))
		if f.flash > 0.0:
			var r: float = 10.0 + 16.0 * (1.0 - f.flash)
			_glow.draw_texture_rect(SOFT, Rect2(f.bead - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(f.col, 0.5 * f.flash))
	# Energy beads, each with a tail, and the stretch of fibre it has
	# climbed still glowing behind it.
	for e in _energy:
		var f: Dictionary = _far[e.i]
		if f.has("pts") and e.t < e.up + 0.15:
			var k0: float = clampf(e.t / e.up, 0.0, 1.0)
			var s_now: float = lerpf(e.s0, 0.0, k0 * k0)
			var fade: float = 1.0 - clampf((e.t - e.up) / 0.15, 0.0, 1.0)
			var trail := PackedVector2Array()
			for k in 9:
				trail.append(_fibre_at(f, lerpf(s_now, e.s0, k / 8.0)))
			_glow.draw_polyline(trail, Color(e.col, 0.55 * fade), 3.0, true)
		for k in 6:
			var ek := e.duplicate()
			ek.t = maxf(0.0, e.t - k * 0.02)
			var p := _energy_pos(ek)
			if p == Vector2.INF:
				continue
			var r := 22.0 - k * 3.0
			_glow.draw_texture_rect(SOFT, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(e.col, 0.9 - k * 0.13))
		var hp := _energy_pos(e)
		if hp != Vector2.INF:
			_glow.draw_circle(hp, 3.6, Color(1, 1, 1, 0.9), true, -1.0, true)
	# Foreshadows: a thread running down to where an enemy will hang.
	var o := view * 0.4
	for fo in _fore:
		var k: float = clampf(fo.t / (fo.dur * 0.85), 0.0, 1.0)
		var top := Vector2(fo.at.x, l.rail_y + 4.0) - o
		var end := Vector2(fo.at.x, lerpf(l.rail_y + 4.0, fo.at.y, Motion.ease_value(Motion.Ease.STANDARD, k))) - o
		var fade: float = 1.0 - clampf((fo.t - fo.dur) / 0.35, 0.0, 1.0)
		_glow.draw_line(top, end, Color(fo.col, 0.6 * fade), 3.0, true)
		_glow.draw_texture_rect(SOFT, Rect2(end - Vector2(16, 16), Vector2(32, 32)), false, Color(fo.col, 0.9 * fade))
		# Where it will hang: a dashed ring the size of a body, turning.
		var ring_at := Vector2(fo.at.x, fo.at.y) - o
		var rk: float = Motion.ease_value(Motion.Ease.EMPHASIZED, clampf((fo.t - fo.dur * 0.5) / (fo.dur * 0.5), 0.0, 1.0))
		if rk > 0.0:
			for d in 10:
				var a0: float = _clock * 1.5 + d * TAU / 10.0
				_glow.draw_arc(ring_at, 26.0 * rk, a0, a0 + 0.35, 5, Color(fo.col, 0.7 * fade), 2.0, true)
		if fo.t >= fo.dur:
			var fr: float = 14.0 + 30.0 * (fo.t - fo.dur) / 0.35
			_glow.draw_texture_rect(SOFT, Rect2(end - Vector2(fr, fr), Vector2(fr, fr) * 2.0), false, Color(fo.col, 0.5 * fade))
	# Gust warning: glints running along the fibre tops the way it will blow.
	if warn_kind == 1 and warn > 0.0:
		for f in _far:
			var gx: float = f.pts[0].x + fposmod(_clock * 260.0 * warn_dir + f.phase * 40.0, 60.0) * warn_dir
			_glow.draw_circle(Vector2(gx, f.pts[0].y + 20.0), 2.0, Color(Pal.INK, 0.5 * warn), true, -1.0, true)
	# The gold drop.
	if not _gold.is_empty():
		var gp := _gold_local()
		var ga := 1.0
		var gr := 11.0
		match int(_gold.st):
			0:
				gr = 11.0 * Motion.ease_value(Motion.Ease.EMPHASIZED, _gold.t / 0.8)
			2:
				ga = 1.0 - clampf(_gold.t, 0.0, 1.0)
		var pulse := 0.7 + 0.3 * sin(_clock * 5.0)
		_glow.draw_texture_rect(SOFT, Rect2(gp - Vector2(44, 44), Vector2(88, 88)), false, Color(Pal.GOLD_LIGHT, 0.5 * ga * pulse))
		# Glints turning round it, so it reads as a prize, not a bead.
		for k in 4:
			var d := Vector2.from_angle(_clock * 1.8 + k * TAU / 4.0)
			_glow.draw_line(gp + d * (gr + 5.0), gp + d * (gr + 12.0), Color(Pal.GOLD_LIGHT, 0.7 * ga), 1.6, true)
		_glow.draw_circle(gp, gr, Color(Pal.GOLD, 0.95 * ga), true, -1.0, true)
		_glow.draw_circle(gp + Vector2(-3.0, -3.5), gr * 0.35, Color(1, 1, 1, 0.75 * ga), true, -1.0, true)


## The danger line is a real wire, strung taut from wall to wall between
## two bolted plates. At rest it is a quiet steel thread; as a target nears
## it tightens, hums (a standing wave) and warms to coral. A slow mist of
## smoke drifts along it, giving the space between field and ground depth.
func _draw_danger() -> void:
	var k := clampf(danger, 0.0, 1.0)
	var y := l.danger_y
	var w := l.size.x
	# Mist along the line (Kenney smoke, CC0), drifting slowly sideways.
	for i in 4:
		var x := fposmod(_clock * (9.0 + i * 3.0) + i * w * 0.31, w + 260.0) - 130.0
		var s := 150.0 + i * 30.0
		_layer.draw_texture_rect(MIST, Rect2(x - s, y - s * 0.32, s * 2.0, s * 0.64), false, Color(Pal.INK, 0.035 + 0.02 * k))
	# The wire: a standing wave whose size and pitch grow with the danger.
	_wire.clear()
	var amp := k * k * 3.2
	var hz := lerpf(9.0, 26.0, k)
	for i in 41:
		var x := w * i / 40.0
		var env := sin(PI * i / 40.0)
		_wire.append(Vector2(x, y + sin(_clock * hz + i * 0.9) * amp * env))
	var col := Pal.METAL.lerp(Pal.CORAL, k).lerp(Pal.GOLD_LIGHT, _rescue)
	if k > 0.05:
		# Warm halo around the wire when it is under strain.
		_layer.draw_polyline(_wire, Color(Pal.CORAL, 0.12 * k), 9.0, true)
	if _rescue > 0.0:
		_layer.draw_polyline(_wire, Color(Pal.GOLD_LIGHT, 0.3 * _rescue), 12.0, true)
	_layer.draw_set_transform(Vector2(0, 2))
	_layer.draw_polyline(_wire, Color(Pal.SHADOW, 0.6), 2.0, true)
	_layer.draw_set_transform(Vector2.ZERO)
	_layer.draw_polyline(_wire, Color(col, lerpf(0.45, 0.95, k)), 1.6 + k * 0.8, true)
	_layer.draw_set_transform(Vector2(0, -0.7))
	_layer.draw_polyline(_wire, Color(Pal.INK, 0.12 + 0.2 * k), 0.6, true)
	_layer.draw_set_transform(Vector2.ZERO)
	# Wall plates the wire is bolted to.
	for side in [0.0, 1.0]:
		var px: float = side * w
		var r := Rect2(px - 7.0, y - 11.0, 14.0, 22.0)
		_layer.draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Pal.SHADOW)
		_layer.draw_rect(r, Pal.METAL_DARK)
		_layer.draw_rect(Rect2(r.position, Vector2(14.0, 2.0)), Color(Pal.METAL_LIGHT, 0.5))
		Pal.disc(_layer, Vector2(px + (4.0 if side == 0.0 else -4.0), y - 6.0), 1.6, Pal.METAL_LIGHT)
		Pal.disc(_layer, Vector2(px + (4.0 if side == 0.0 else -4.0), y + 6.0), 1.6, Pal.METAL_LIGHT)
