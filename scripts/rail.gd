extends Node2D
class_name SpennRail

func _ready() -> void:
	z_index = 2
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(40,0),Vector2(680,0),Color(0.18,0.30,0.40,0.24),8,true)
	draw_line(Vector2(40,-3),Vector2(680,-3),Color(0.95,0.88,0.68,0.65),3,true)
	for x in range(80,681,120):
		draw_circle(Vector2(x,0),6,Color("#E9C67D"))
