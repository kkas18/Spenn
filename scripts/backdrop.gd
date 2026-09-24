class_name Backdrop
extends Node2D
## Static layer behind the play field: a distant parallax layer of strings
## (40% scale, 8% opacity, slower than the foreground), the danger line and
## slow dust. Nothing here shakes.

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
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	for i in FAR_COUNT:
		_far.append({
			"x": 0.0,
			"len": _rng.randf_range(0.15, 0.75),
			"phase": _rng.randf() * TAU,
			"rate": _rng.randf_range(0.18, 0.32),
			"kind": _rng.randi() % 3,
		})
	_dust = CPUParticles2D.new()
	_dust.amount = 10
	_dust.lifetime = 16.0
	_dust.preprocess = 16.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.direction = Vector2.UP
	_dust.spread = 25.0
	_dust.gravity = Vector2(0, -3)
	_dust.initial_velocity_min = 6.0
	_dust.initial_velocity_max = 14.0
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.0
	_dust.color = Color(Pal.INK, 0.03)
	_dust.texture = _soft_dot()
	add_child(_dust)


func _soft_dot() -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var d := Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0).length() / 6.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d * d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func setup(layout: Layout) -> void:
	l = layout
	for i in FAR_COUNT:
		_far[i].x = (i + 0.5) / FAR_COUNT * l.size.x + _rng.randf_range(-20.0, 20.0)
	_dust.position = Vector2(l.center_x, l.size.y * 0.55)
	_dust.emission_rect_extents = Vector2(l.size.x * 0.5, l.size.y * 0.45)


func _process(delta: float) -> void:
	_clock += delta
	_far_drop = fmod(_far_drop + descent * FAR_SCALE * delta, l.play_h * 0.3) if l else 0.0
	queue_redraw()


func _draw() -> void:
	if l == null:
		return
	_draw_far()
	_draw_danger()


func _draw_far() -> void:
	var col := Color(Pal.INK, FAR_ALPHA)
	for f in _far:
		var sway := sin(_clock * f.rate + f.phase) * 6.0
		var top := Vector2(f.x, l.rail_y + 10.0)
		var bottom := top + Vector2(sway, l.play_h * f.len * 0.8 + _far_drop * FAR_SCALE)
		draw_line(top, bottom, col, 1.0, true)
		var r := 30.0 * FAR_SCALE
		match f.kind:
			0: draw_arc(bottom + Vector2(0, r), r, 0.0, TAU, 16, col, 3.0, true)
			1: draw_arc(bottom + Vector2(0, r), r, 0.0, TAU, 6, col, 3.0, true)
			_: draw_circle(bottom + Vector2(0, r), r * 0.8, col, true, -1.0, true)


## Nearly invisible at rest; coral and more tightly stippled as a target nears.
func _draw_danger() -> void:
	var k := clampf(danger, 0.0, 1.0)
	var pulse := 0.85 + 0.15 * sin(_clock * TAU * 0.8)
	var col := Pal.INK_FAINT.lerp(Pal.CORAL, k)
	col.a = lerpf(0.10, 0.75 * pulse, k)
	var gap := lerpf(18.0, 7.0, k)
	var dash := 3.0
	var x := fmod(_clock * 6.0, gap)
	while x < l.size.x:
		draw_line(Vector2(x, l.danger_y), Vector2(x + dash, l.danger_y), col, 2.0)
		x += gap
