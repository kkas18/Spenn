class_name Rail
extends Node2D
## The top beam: 6 px, two tones, shadow down/right, with a hook at every
## hanging string. Hooks tip as their string swings.

var l: Layout
var targets: Array[Target] = []
var _flex_x := 0.0
var _flex_amp := 0.0
var _flex_t := 10.0
var _line := PackedVector2Array()


func setup(layout: Layout, list: Array[Target]) -> void:
	l = layout
	targets = list


## A breach yanks the beam: a local dip that rings out like a struck bar.
func flex(x: float, amp: float) -> void:
	_flex_x = x
	_flex_amp = amp
	_flex_t = 0.0


func _process(delta: float) -> void:
	_flex_t += delta
	queue_redraw()


func offset_at(x: float) -> float:
	if _flex_amp <= 0.0:
		return 0.0
	var env := exp(-_flex_t * 5.0) * cos(_flex_t * 34.0)
	var spread := exp(-pow((x - _flex_x) / 150.0, 2.0))
	return _flex_amp * env * spread


func _draw() -> void:
	if l == null:
		return
	# A steel beam: soft cast shadow below, dark lower lip, body, lit top
	# edge (light from the upper left) and a row of rivets. It follows the
	# flex when a breach yanks it.
	var y := l.rail_y - 6.0
	_line.clear()
	for i in 33:
		var x := l.size.x * i / 32.0
		_line.append(Vector2(x, y + offset_at(x)))
	for k in 4:
		draw_set_transform(Vector2(0, 12.0 + k * 4.0))
		draw_polyline(_line, Color(0, 0, 0, 0.16 - k * 0.035), 5.0)
	draw_set_transform(Vector2(0, 5.0))
	draw_polyline(_line, Pal.METAL_DARK, 11.0)
	draw_set_transform(Vector2(0, 4.0))
	draw_polyline(_line, Pal.METAL, 8.0)
	draw_set_transform(Vector2(0, 0.8))
	draw_polyline(_line, Pal.METAL_LIGHT, 1.6)
	draw_set_transform(Vector2(0, 9.2))
	draw_polyline(_line, Color(0, 0, 0, 0.35), 1.2)
	draw_set_transform(Vector2.ZERO)
	var x := 32.0
	while x < l.size.x:
		var p := Vector2(x, y + 4.5 + offset_at(x))
		Pal.disc(self, p + Vector2(0.8, 0.8), 2.0, Color(0, 0, 0, 0.45))
		Pal.disc(self, p, 1.8, Pal.METAL_LIGHT)
		Pal.disc(self, p - Vector2(0.5, 0.5), 0.8, Color(Pal.INK, 0.5))
		x += 64.0
	for t in targets:
		if t.phase == Target.Phase.OFF or t.rope_alpha <= 0.0 or t.delay > 0.0:
			continue
		_hook(t.anchor + Vector2(0, offset_at(t.anchor.x)), t.hook_angle(), t.rope_alpha)


func _hook(at: Vector2, angle: float, alpha: float) -> void:
	draw_set_transform(at, angle)
	# Mount plate, stem and eyelet; the string ties into the eyelet.
	draw_rect(Rect2(-4.0 + 2.0, -1.0 + 2.0, 8.0, 3.0), Color(Pal.SHADOW, Pal.SHADOW.a * alpha))
	draw_rect(Rect2(-4.0, -1.0, 8.0, 3.0), Color(Pal.METAL_LIGHT, alpha))
	draw_line(Vector2(0, 2.0), Vector2(0, 5.0), Color(Pal.METAL, alpha), 2.0, true)
	draw_arc(Vector2(1.2, 9.2), 3.6, 0.0, TAU, 16, Color(Pal.METAL_DARK, alpha), 2.0, true)
	draw_arc(Vector2(0, 8.0), 3.6, 0.0, TAU, 16, Color(Pal.METAL_LIGHT, alpha), 1.6, true)
	draw_set_transform(Vector2.ZERO)
