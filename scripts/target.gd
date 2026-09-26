extends Area2D
class_name SpennTarget

signal destroyed(points: int)

@export var target_color := Color("#6557D9")
@export var points := 100
@export var radius := 34.0
var hp := 1
var phase := 0.0

func _ready() -> void:
	add_to_group("targets")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	phase = position.x * 0.017
	queue_redraw()

func _process(delta: float) -> void:
	rotation = sin(Time.get_ticks_msec() * 0.0015 + phase) * 0.025
	queue_redraw()

func hit() -> void:
	hp -= 1
	if hp <= 0:
		destroyed.emit(points)
		queue_free()

func _draw() -> void:
	for r in range(int(radius + 9), int(radius), -2):
		draw_circle(Vector2.ZERO, r, Color(0.15,0.22,0.35,0.035))
	draw_circle(Vector2.ZERO, radius, Color("#F4F0E8"))
	draw_circle(Vector2.ZERO, radius - 4.0, target_color.darkened(0.18))
	draw_circle(Vector2(-8,-9), radius * 0.46, target_color.lightened(0.18))
	draw_circle(Vector2(-10,-12), radius * 0.13, Color(1,1,1,0.42))
	draw_arc(Vector2.ZERO, radius - 2.0, 0, TAU, 40, Color(1,1,1,0.28), 2.0, true)
