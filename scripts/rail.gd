class_name Rail
extends Node2D
## The top beam every string hangs from.

var l: Layout
var targets: Array[Target] = []


func setup(layout: Layout, list: Array[Target]) -> void:
	l = layout
	targets = list


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if l == null:
		return
	draw_rect(Rect2(0, l.rail_y - 3.0, l.size.x, 6.0), Pal.METAL)
