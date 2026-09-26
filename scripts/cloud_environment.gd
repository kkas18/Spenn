extends Node2D
## Lightweight procedural 2.5D cloud environment for Spenn.
## Keeps gameplay 2D while creating depth with layered motion and atmosphere.

@export var drift_speed := 7.0
var t := 0.0

const SKY_TOP := Color("#69BFE7")
const SKY_MID := Color("#A9DCF0")
const SKY_HORIZON := Color("#F6D5B4")
const SUN := Color("#FFF0BE")

var far_clouds := [
	[Vector2(90, 255), 0.70], [Vector2(420, 320), 0.90], [Vector2(680, 230), 0.62],
	[Vector2(250, 455), 0.78], [Vector2(590, 510), 0.72]
]
var mid_clouds := [
	[Vector2(30, 610), 1.05], [Vector2(355, 690), 1.18], [Vector2(700, 620), 1.0],
	[Vector2(160, 865), 1.12], [Vector2(560, 900), 1.25]
]
var front_clouds := [
	[Vector2(-40, 1080), 1.65], [Vector2(285, 1160), 1.85], [Vector2(700, 1090), 1.55]
]

func _ready() -> void:
	z_index = -100
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	_draw_sky()
	_draw_sun()
	_draw_layer(far_clouds, 0.18, Color(0.91, 0.96, 1.0, 0.52), 42.0)
	_draw_haze()
	_draw_islands()
	_draw_layer(mid_clouds, 0.45, Color(0.96, 0.98, 1.0, 0.76), 58.0)
	_draw_layer(front_clouds, 0.90, Color(1.0, 0.985, 0.97, 0.92), 76.0)

func _draw_sky() -> void:
	var bands := 20
	for i in range(bands):
		var k := float(i) / float(bands - 1)
		var c := SKY_TOP.lerp(SKY_MID, min(k * 1.45, 1.0))
		if k > 0.55:
			c = SKY_MID.lerp(SKY_HORIZON, (k - 0.55) / 0.45)
		draw_rect(Rect2(0, i * 64.0, 720, 66), c)

func _draw_sun() -> void:
	var p := Vector2(580, 270)
	for r in range(120, 35, -14):
		var a := 0.008 + (120.0 - r) / 120.0 * 0.018
		draw_circle(p, r, Color(SUN, a))
	draw_circle(p, 36, Color(SUN, 0.82))

func _draw_haze() -> void:
	draw_rect(Rect2(0, 520, 720, 360), Color(1.0, 0.83, 0.72, 0.075))

func _draw_cloud(center: Vector2, scale_v: float, color: Color) -> void:
	var shadow := Color(0.28, 0.48, 0.62, color.a * 0.12)
	draw_ellipse(center + Vector2(5, 15) * scale_v, Vector2(92, 31) * scale_v, shadow)
	var parts := [
		[Vector2(-65, 5), 43.0], [Vector2(-25, -15), 57.0],
		[Vector2(22, -22), 67.0], [Vector2(70, 2), 45.0]
	]
	for part in parts:
		draw_circle(center + part[0] * scale_v, part[1] * scale_v, color)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)

func _draw_layer(items: Array, parallax: float, color: Color, wrap_margin: float) -> void:
	for item in items:
		var p: Vector2 = item[0]
		var s: float = item[1]
		var x := fmod(p.x + t * drift_speed * parallax + wrap_margin, 820.0) - wrap_margin
		var bob := sin(t * (0.16 + parallax * 0.05) + p.x * 0.01) * (2.0 + parallax * 2.5)
		_draw_cloud(Vector2(x, p.y + bob), s, color)

func _draw_islands() -> void:
	_draw_island(Vector2(115, 505), 0.52)
	_draw_island(Vector2(605, 575), 0.42)

func _draw_island(p: Vector2, s: float) -> void:
	var rock := PackedVector2Array([
		p + Vector2(-72, 0) * s, p + Vector2(68, 0) * s,
		p + Vector2(35, 68) * s, p + Vector2(5, 112) * s,
		p + Vector2(-34, 63) * s
	])
	draw_colored_polygon(rock, Color("#71899A"))
	draw_circle(p + Vector2(0, -2) * s, 72 * s, Color("#91B77E"))
	draw_arc(p + Vector2(0, -1) * s, 70 * s, PI, TAU, 28, Color("#E4E7C4"), 5.0 * s, true)
