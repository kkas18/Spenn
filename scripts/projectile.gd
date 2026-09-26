extends Area2D
class_name SpennProjectile

var velocity: Vector2 = Vector2.ZERO
var active: bool = false
var radius: float = 13.0
var age: float = 0.0
var trail: Array[Vector2] = []

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	area_entered.connect(_on_area_entered)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	queue_redraw()

func launch(v: Vector2) -> void:
	velocity = v
	active = true

func _physics_process(delta: float) -> void:
	if not active: return
	age += delta
	trail.push_front(global_position)
	if trail.size() > 8: trail.pop_back()
	queue_redraw()
	velocity.y += 520.0 * delta
	position += velocity * delta
	if position.y > 1380 or position.x < -80 or position.x > 800:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("hit"):
		area.hit()
		queue_free()

func _draw() -> void:
	for i in range(trail.size()-1, -1, -1):
		var local_p: Vector2 = to_local(trail[i])
		var alpha: float = 0.04 + (1.0-float(i)/maxf(1.0,float(trail.size()))) * 0.12
		draw_circle(local_p, maxf(2.0,radius-float(i)*1.3), Color(1.0,0.78,0.28,alpha))
	draw_circle(Vector2(4,7), radius + 3, Color(0.14,0.25,0.40,0.16))
	draw_circle(Vector2.ZERO, radius, Color("#E9B84E"))
	draw_circle(Vector2(-4,-5), radius * 0.48, Color("#FFF0A9"))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 28, Color("#FFF7D0"), 2.0, true)
