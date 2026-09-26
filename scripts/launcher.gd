extends Node2D
class_name SpennLauncher

signal fired(projectile)

const Projectile = preload("res://scripts/projectile.gd")
var dragging: bool = false
var pull: Vector2 = Vector2.ZERO
var max_pull: float = 125.0

func _ready() -> void:
	z_index = 20
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed and global_position.distance_to(event.position) < 115.0:
			dragging = true
			pull = Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif dragging and not event.pressed:
			_fire()
			dragging = false
			pull = Vector2.ZERO
			queue_redraw()
	elif dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		pull = (event.position - global_position).limit_length(max_pull)
		if pull.y < -15.0: pull.y = -15.0
		queue_redraw()

func _fire() -> void:
	if pull.length() < 18.0: return
	var ball: SpennProjectile = Projectile.new()
	ball.global_position = global_position + Vector2(0,-42)
	get_tree().current_scene.add_child(ball)
	ball.launch(-pull * 5.6)
	fired.emit(ball)

func _draw() -> void:
	var left: Vector2 = Vector2(-43,-52)
	var right: Vector2 = Vector2(43,-52)
	var pocket: Vector2 = Vector2(0,-42) + (pull if dragging else Vector2.ZERO)
	draw_line(left, pocket, Color("#6B4B35"), 7.0, true)
	draw_line(right, pocket, Color("#6B4B35"), 7.0, true)
	draw_line(Vector2(-48,5), left, Color("#D5B06A"), 18.0, true)
	draw_line(Vector2(48,5), right, Color("#D5B06A"), 18.0, true)
	draw_circle(Vector2(-48,5), 9, Color("#F3D59A"))
	draw_circle(Vector2(48,5), 9, Color("#F3D59A"))
	draw_circle(pocket, 15, Color("#E9B84E"))
