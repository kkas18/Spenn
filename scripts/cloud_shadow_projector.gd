extends Node2D
class_name CloudShadowProjector
## Projects soft stylised shadows from gameplay objects onto the cloud plane.
## Attach this node as a child of a target and update height_hint as needed.

@export var height_hint := 180.0
@export var base_radius := 34.0
@export var light_direction := Vector2(-0.42, 0.90)
@export_range(0.0, 1.0) var strength := 0.20

func _ready() -> void:
	z_index = -2
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var h := clamp(height_hint, 30.0, 520.0)
	var offset := light_direction.normalized() * lerp(16.0, 76.0, h / 520.0)
	var flatten := lerp(0.46, 0.25, h / 520.0)
	var radius := base_radius * lerp(0.82, 1.65, h / 520.0)
	for i in range(5, 0, -1):
		var k := float(i) / 5.0
		var alpha := strength * (1.0 - k * 0.72) * 0.38
		_draw_ellipse(offset, Vector2(radius * (1.0 + k * 0.34), radius * flatten * (1.0 + k * 0.22)), Color(0.16, 0.30, 0.43, alpha))

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(33):
		var a := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
