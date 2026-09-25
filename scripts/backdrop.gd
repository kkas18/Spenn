class_name Backdrop
extends Node2D
## Static layer behind the play field: the lit, grained backdrop shader, a
## distant parallax layer of bare strings (40% scale, 8% opacity, slower than
## the foreground), the danger line and slow dust. Nothing here shakes.

const FAR_SCALE := 0.4
const FAR_ALPHA := 0.08
const FAR_COUNT := 9

var l: Layout
var danger := 0.0              # max target danger, 0..1
var descent := 0.0             # foreground descent speed (px/s)

var _far: Array[Dictionary] = []
var _far_drop := 0.0
var _clock := 0.0
var _dust: CPUParticles2D
var _bg: ColorRect
var _layer: Node2D
var _rng := RandomNumberGenerator.new()
var _wire := PackedVector2Array()
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
	_far_drop = fmod(_far_drop + descent * FAR_SCALE * delta, l.play_h * 0.3) if l else 0.0
	_layer.queue_redraw()


func _draw_layer() -> void:
	if l == null:
		return
	_draw_far()
	_draw_danger()


## Bare distant strings with a few beads: depth without silhouettes that
## could be mistaken for targets.
func _draw_far() -> void:
	var col := Color(Pal.INK, FAR_ALPHA)
	for f in _far:
		var sway := sin(_clock * f.rate + f.phase) * 6.0
		var top := Vector2(f.x, l.rail_y + 10.0)
		var bottom := top + Vector2(sway, l.play_h * f.len * 0.8 + _far_drop * FAR_SCALE)
		_layer.draw_line(top, bottom, col, 1.0, true)
		for b in f.beads:
			var t := 1.0 - float(b) * 0.09
			_layer.draw_circle(top.lerp(bottom, t), 2.2, col, true, -1.0, true)


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
