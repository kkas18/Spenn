class_name Rail
extends Node2D
## The top beam: 6 px, two tones, shadow down/right, with a hook at every
## hanging string. Hooks tip as their string swings.

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
	var y := l.rail_y - 3.0
	draw_rect(Rect2(Pal.SHADOW_OFFSET + Vector2(0, y), Vector2(l.size.x, 6.0)), Pal.SHADOW)
	draw_rect(Rect2(0, y, l.size.x, 3.0), Pal.METAL_LIGHT)
	draw_rect(Rect2(0, y + 3.0, l.size.x, 3.0), Pal.METAL)
	draw_line(Vector2(0, y + 6.0), Vector2(l.size.x, y + 6.0), Pal.METAL_DARK, 1.0)
	for t in targets:
		if t.phase == Target.Phase.OFF or t.rope_alpha <= 0.0 or t.delay > 0.0:
			continue
		_hook(t.anchor, t.hook_angle(), t.rope_alpha)


func _hook(at: Vector2, angle: float, alpha: float) -> void:
	draw_set_transform(at, angle)
	# Mount plate, stem and eyelet; the string ties into the eyelet.
	draw_rect(Rect2(-4.0 + 2.0, -1.0 + 2.0, 8.0, 3.0), Color(Pal.SHADOW, Pal.SHADOW.a * alpha))
	draw_rect(Rect2(-4.0, -1.0, 8.0, 3.0), Color(Pal.METAL_LIGHT, alpha))
	draw_line(Vector2(0, 2.0), Vector2(0, 5.0), Color(Pal.METAL, alpha), 2.0, true)
	draw_arc(Vector2(1.2, 9.2), 3.6, 0.0, TAU, 16, Color(Pal.METAL_DARK, alpha), 2.0, true)
	draw_arc(Vector2(0, 8.0), 3.6, 0.0, TAU, 16, Color(Pal.METAL_LIGHT, alpha), 1.6, true)
	draw_set_transform(Vector2.ZERO)
