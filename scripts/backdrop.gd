class_name Backdrop
extends Node2D
## Static layer behind the play field: the lit, grained backdrop shader, a
## distant parallax layer of bare strings (40% scale, 8% opacity, slower than
## the foreground), the danger line, slow dust and a few large out-of-focus
## motes drifting through the lamp light. Nothing here shakes.

const FAR_SCALE := 0.4
const FAR_ALPHA := 0.08
const FAR_COUNT := 9

var l: Layout
var danger := 0.0              # max target danger, 0..1
var descent := 0.0             # foreground descent speed (px/s)
var heat := 0.0                # overload (0/1): the room warms to gold
var targets: Array[Target] = []  # their shadows fall on the wall
var view := Vector2.ZERO       # tilt parallax (world px); this layer moves less
var _heat := 0.0
var _bokeh: Array[Dictionary] = []
const SOFT := preload("res://assets/particles/soft.png")

var _far: Array[Dictionary] = []
var _far_drop := 0.0
var _clock := 0.0
var _dust: CPUParticles2D
var _flies: CPUParticles2D
var _bg: ColorRect
var _layer: Node2D
var _rng := RandomNumberGenerator.new()
var _wire := PackedVector2Array()
var _far_lines := PackedVector2Array()
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
	for i in FAR_COUNT:
		_far.append({
			"x": 0.0,
			"len": _rng.randf_range(0.15, 0.75),
			"phase": _rng.randf() * TAU,
			"rate": _rng.randf_range(0.18, 0.32),
			"beads": 1 + _rng.randi() % 3,
		})
	for i in 9:
		_bokeh.append({"x": _rng.randf(), "y": _rng.randf(), "r": _rng.randf_range(40.0, 90.0),
			"vx": _rng.randf_range(-4.0, 4.0), "vy": _rng.randf_range(-6.0, -2.0), "ph": _rng.randf() * TAU})
	# Fireflies: a few warm-green glows drifting through the room, blinking
	# slowly (the colour ramp pulses), added as light.
	_flies = CPUParticles2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flies.material = add
	_flies.amount = Device.count(9)
	Device.tier_changed.connect(func() -> void: _flies.amount = Device.count(9))
	_flies.lifetime = 11.0
	_flies.preprocess = 11.0
	_flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_flies.direction = Vector2.UP
	_flies.spread = 180.0
	_flies.gravity = Vector2.ZERO
	_flies.initial_velocity_min = 4.0
	_flies.initial_velocity_max = 12.0
	_flies.orbit_velocity_min = -0.02
	_flies.orbit_velocity_max = 0.02
	_flies.texture = SOFT
	_flies.scale_amount_min = 0.12
	_flies.scale_amount_max = 0.22
	_flies.color = Color(0.86, 0.95, 0.6, 0.55)
	var blink := Gradient.new()
	blink.set_color(0, Color(1, 1, 1, 0))
	blink.set_color(1, Color(1, 1, 1, 0))
	for k in 5:
		var at := 0.1 + k * 0.18
		blink.add_point(at, Color(1, 1, 1, 0.9))
		blink.add_point(at + 0.07, Color(1, 1, 1, 0.15))
	_flies.color_ramp = blink
	add_child(_flies)
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
	_flies.position = Vector2(l.center_x, l.rail_y + l.play_h * 0.5)
	_flies.emission_rect_extents = Vector2(l.size.x * 0.5, l.play_h * 0.5)
	_dust.position = Vector2(l.center_x, l.size.y * 0.55)
	_dust.emission_rect_extents = Vector2(l.size.x * 0.5, l.size.y * 0.45)


func _process(delta: float) -> void:
	_clock += delta
	var mat := _bg.material as ShaderMaterial
	mat.set_shader_parameter("time", _clock)
	mat.set_shader_parameter("danger", clampf(danger, 0.0, 1.0))
	var rd := delta / maxf(Engine.time_scale, 0.001)
	_heat = move_toward(_heat, heat, rd / 0.6)
	mat.set_shader_parameter("heat", _heat)
	_dust.color = Color(Pal.INK.lerp(Pal.GOLD_LIGHT, _heat), 0.07 + 0.08 * _heat)
	if l:
		for b in _bokeh:
			b.x = fposmod(b.x + b.vx * delta / l.size.x, 1.0)
			b.y = fposmod(b.y + b.vy * delta / l.size.y, 1.0)
	_far_drop = fmod(_far_drop + descent * FAR_SCALE * delta, l.play_h * 0.3) if l else 0.0
	_layer.queue_redraw()


func _draw_layer() -> void:
	if l == null:
		return
	_layer.position = view * 0.4
	_draw_wall_shadows()
	_draw_bokeh()
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
		var a := (0.014 + 0.034 * lit) * (0.7 + 0.3 * sin(_clock * 0.4 + b.ph))
		var r: float = b.r * 1.25
		# Warm where the lamp reaches, moon-blue elsewhere.
		var c := Color("C9D4FF").lerp(Color("FFE1BF"), lit).lerp(Pal.GOLD_LIGHT, _heat)
		_layer.draw_texture_rect(SOFT, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c, a))


## Bare distant strings with a few beads: depth without silhouettes that
## could be mistaken for targets.
func _draw_far() -> void:
	var col := Color(Pal.INK, FAR_ALPHA)
	# All strings in one multiline, then all beads (batched discs).
	_far_lines.resize(_far.size() * 2)
	for i in _far.size():
		var f: Dictionary = _far[i]
		var sway := sin(_clock * f.rate + f.phase) * 6.0
		var top := Vector2(f.x, l.rail_y + 10.0)
		_far_lines[i * 2] = top
		_far_lines[i * 2 + 1] = top + Vector2(sway, l.play_h * f.len * 0.8 + _far_drop * FAR_SCALE)
	# Out of focus: a wide faint stroke under a fine one reads as blur.
	_layer.draw_multiline(_far_lines, Color(col, col.a * 0.35), 3.0, true)
	_layer.draw_multiline(_far_lines, Color(col, col.a * 0.6), 1.0, true)
	for i in _far.size():
		var f: Dictionary = _far[i]
		for b in f.beads:
			Pal.disc(_layer, _far_lines[i * 2].lerp(_far_lines[i * 2 + 1], 1.0 - float(b) * 0.09), 2.2, col)


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
	var col := Pal.METAL.lerp(Pal.CORAL, k)
	if k > 0.05:
		# Warm halo around the wire when it is under strain.
		_layer.draw_polyline(_wire, Color(Pal.CORAL, 0.12 * k), 9.0, true)
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
