extends Node2D
class_name HeavenlyAtmosphere
## Cheap mobile-friendly light shafts, motes and foreground glints.

var t := 0.0
var motes := [
	Vector2(82, 180), Vector2(174, 345), Vector2(286, 220), Vector2(398, 410),
	Vector2(520, 165), Vector2(635, 360), Vector2(120, 720), Vector2(470, 790),
	Vector2(650, 920), Vector2(255, 1010), Vector2(555, 1110)
]

func _ready() -> void:
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_IGNORE if self is Control else 0
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	_draw_light_shafts()
	_draw_motes()

func _draw_light_shafts() -> void:
	var shafts := [
		PackedVector2Array([Vector2(500,0),Vector2(610,0),Vector2(410,900),Vector2(285,900)]),
		PackedVector2Array([Vector2(625,0),Vector2(690,0),Vector2(610,760),Vector2(515,760)])
	]
	draw_colored_polygon(shafts[0], Color(1.0,0.90,0.70,0.025))
	draw_colored_polygon(shafts[1], Color(1.0,0.94,0.80,0.018))

func _draw_motes() -> void:
	for i in range(motes.size()):
		var p: Vector2 = motes[i]
		var y := fmod(p.y - t * (3.0 + float(i % 4)) + 1280.0, 1280.0)
		var x := p.x + sin(t * 0.35 + float(i)) * 7.0
		var pulse := 0.10 + 0.08 * (sin(t * 0.8 + i * 1.7) * 0.5 + 0.5)
		draw_circle(Vector2(x,y), 1.2 + float(i % 3) * 0.55, Color(1.0,0.92,0.72,pulse))
