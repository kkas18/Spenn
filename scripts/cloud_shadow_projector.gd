extends Node2D
class_name CloudShadowProjector
## Projects soft stylised shadows from gameplay objects onto the cloud plane.
## Attach this node as a child of a target and update height_hint as needed.

@export var height_hint: float = 180.0
@export var base_radius: float = 34.0
@export var light_direction: Vector2 = Vector2(-0.42, 0.90)
@export_range(0.0, 1.0) var strength: float = 0.20

func _ready() -> void:
	z_index = -2
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var h: float = clampf(height_hint, 30.0, 520.0)
	var offset: Vector2 = light_direction.normalized() * lerpf(16.0, 76.0, h / 520.0)
	var flatten: float = lerpf(0.46, 0.25, h / 520.0)
	var radius: float = base_radius * lerpf(0.82, 1.65, h / 520.0)
	for i in range(5, 0, -1):
		var k: float = float(i) / 5.0
		var alpha: float = strength * (1.0 - k * 0.72) * 0.38
		_draw_ellipse(offset, Vector2(radius * (1.0 + k * 0.34), radius * flatten * (1.0 + k * 0.22)), Color(0.16, 0.30, 0.43, alpha))

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(33):
		var a: float = TAU * float(i) / 32.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
