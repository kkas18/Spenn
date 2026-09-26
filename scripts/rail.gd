class_name Rail
extends Node2D
## The top beam: 6 px, two tones, shadow down/right, with a hook at every
## hanging string. Hooks tip as their string swings. A gold inlay along its
## face is the overload meter: it fills out from the middle as the tension
## builds, throbs when nearly full and blazes while overload lasts.

var l: Layout
var targets: Array[Target] = []
var _flex_x := 0.0
var _flex_amp := 0.0
var _flex_t := 10.0
var _line := PackedVector2Array()
var _inlay := PackedVector2Array()
var _under := PackedVector2Array()
# Fairy lights: a garland of small warm bulbs strung in scallops under the
# beam. They twinkle, breathe with the music's beat and flare when
# something breaks. Their glow is added as light on a child layer.
const BULB_GAP := 44.0
const SWAG := 3               # bulbs per scallop
var _bulbs := PackedVector2Array()
var _wire := PackedVector2Array()
var _bulb_ph := PackedFloat32Array()
var _flare := 0.0
var calm := 0.0                # between waves: the bulbs glow brighter and slower
var _glow: Node2D
const SOFT := preload("res://assets/particles/soft.png")
const BULB := Color("FFE3C2")
var charge := 0.0              # 0..1, set by the game
var hot := false               # overload running
var _shown := 0.0
var _clock := 0.0


func setup(layout: Layout, list: Array[Target]) -> void:
	l = layout
	targets = list
	if _glow == null:
		_glow = Node2D.new()
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = add
		add_child(_glow)
		_glow.draw.connect(_draw_glow)
	# Pins every SWAG bulbs, the wire sagging between them.
	_bulbs.clear()
	_wire.clear()
	_bulb_ph.clear()
	var y0 := l.rail_y + 9.0
	var n := int(l.size.x / BULB_GAP) + 2
	for i in n:
		var x := -BULB_GAP * 0.5 + i * BULB_GAP
		var k := float(i % SWAG) / SWAG
		_bulbs.append(Vector2(x, y0 + 4.0 + sin(PI * (k + 0.5 / SWAG)) * 9.0))
		_bulb_ph.append(randf() * TAU)
	for j in n * 4:
		var x := -BULB_GAP * 0.5 + j * BULB_GAP * 0.25
		var k := fposmod(x + BULB_GAP * 0.5, BULB_GAP * SWAG) / (BULB_GAP * SWAG)
		_wire.append(Vector2(x, y0 + sin(PI * k) * 12.0))


## Something broke: the bulbs flare for a moment.
func flare(amount := 1.0) -> void:
	_flare = maxf(_flare, amount)


## A breach yanks the beam: a local dip that rings out like a struck bar.
func flex(x: float, amp: float) -> void:
	_flex_x = x
	_flex_amp = amp
	_flex_t = 0.0


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.001)
	_flex_t += delta
	_clock += rd
	_shown = lerpf(_shown, charge, Pal.damp(0.12, rd)) if absf(charge - _shown) > 0.001 else charge
	_flare = maxf(0.0, _flare - rd * 2.5)
	queue_redraw()
	if _glow:
		_glow.queue_redraw()


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
	# edge (light from the upper left) and a row of rivets. At rest it is a
	# handful of plain rects, which the renderer batches into one call; only
	# while a breach flexes it does it follow the dip as polylines.
	var y := l.rail_y - 6.0
	var w := l.size.x
	# Drawn past both edges so tilt parallax never shows the beam's ends.
	var x0 := -32.0
	var ww := w + 64.0
	if _flex_amp > 0.0 and _flex_t < 1.2:
		_line.clear()
		for i in 33:
			var x := w * i / 32.0
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
	else:
		for k in 4:
			draw_rect(Rect2(x0, y + 9.5 + k * 4.0, ww, 5.0), Color(0, 0, 0, 0.16 - k * 0.035))
		draw_rect(Rect2(x0, y - 0.5, ww, 11.0), Pal.METAL_DARK)
		draw_rect(Rect2(x0, y, ww, 8.0), Pal.METAL)
		draw_rect(Rect2(x0, y, ww, 1.6), Pal.METAL_LIGHT)
		draw_rect(Rect2(x0, y + 8.6, ww, 1.2), Color(0, 0, 0, 0.35))
		# Seen from below: the beam's underside, a dark face that is deeper
		# toward the ends (perspective), as if it runs away into the walls.
		_under.clear()
		_under.append_array([Vector2(x0, y + 9.8), Vector2(x0 + ww, y + 9.8), Vector2(x0 + ww, y + 15.0), Vector2(w * 0.5, y + 12.2), Vector2(x0, y + 15.0)])
		draw_colored_polygon(_under, Color(Pal.METAL_DARK.darkened(0.3), 0.95))
		draw_line(Vector2(x0, y + 9.9), Vector2(x0 + ww, y + 9.9), Color(Pal.METAL_LIGHT, 0.18), 1.0)
	_draw_inlay(y + 3.4)
	_draw_garland()
	# Hooks in two passes (plates and stems, then eyelets) so each pass is a
	# single batch however many strings hang from the beam.
	for t in targets:
		if _shows(t):
			_hook_plate(t.anchor + Vector2(0, offset_at(t.anchor.x)), t.hook_angle(), t.rope_alpha)
	draw_set_transform(Vector2.ZERO)
	var x := 32.0
	while x < w:
		var p := Vector2(x, y + 4.5 + offset_at(x))
		Pal.disc(self, p + Vector2(0.8, 0.8), 2.0, Color(0, 0, 0, 0.45))
		Pal.disc(self, p, 1.8, Pal.METAL_LIGHT)
		Pal.disc(self, p - Vector2(0.5, 0.5), 0.8, Color(Pal.INK, 0.5))
		x += 64.0
	for t in targets:
		if _shows(t):
			_hook_eye(t.anchor + Vector2(0, offset_at(t.anchor.x)), t.hook_angle(), t.rope_alpha)
	draw_set_transform(Vector2.ZERO)


func _bulb_level(i: int) -> float:
	var tw := 0.72 + 0.28 * sin(_clock * (1.1 + 0.37 * (i % 5)) * (1.0 - 0.5 * calm) + _bulb_ph[i])
	return clampf(tw + 0.25 * Music.beat_pulse() + 0.6 * _flare + 0.35 * calm, 0.0, 1.6)


func _draw_garland() -> void:
	if _bulbs.is_empty():
		return
	draw_polyline(_wire, Color(0.0, 0.0, 0.0, 0.55), 1.2, true)
	# Caps in one pass, bulbs in the next, so each pass batches.
	for i in _bulbs.size():
		var p := _bulbs[i]
		draw_line(p + Vector2(0, -4.0), p + Vector2(0, -1.5), Pal.METAL_DARK, 2.0)
	for i in _bulbs.size():
		var k := _bulb_level(i)
		Pal.disc(self, _bulbs[i] + Vector2(0, 1.0), 2.6, Color(BULB.darkened(0.35).lerp(BULB, clampf(k, 0.0, 1.0)), 1.0))


func _draw_glow() -> void:
	for i in _bulbs.size():
		var p := _bulbs[i] + Vector2(0, 1.0)
		var k := _bulb_level(i)
		var r := 14.0 + 8.0 * k
		_glow.draw_texture_rect(SOFT, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(BULB, 0.22 * k))


func _draw_inlay(y: float) -> void:
	if _shown < 0.003:
		return
	var w := l.size.x
	var half := w * 0.5 * _shown
	var pulse := 0.0
	if hot:
		pulse = 0.6 + 0.4 * sin(_clock * 14.0)
	elif _shown > 0.85:
		pulse = 0.5 + 0.5 * sin(_clock * 9.0)
	_inlay.clear()
	for i in 17:
		var x := w * 0.5 + lerpf(-half, half, i / 16.0)
		_inlay.append(Vector2(x, y + offset_at(x)))
	if pulse > 0.0:
		draw_polyline(_inlay, Color(Pal.GOLD, 0.16 * pulse), 12.0)
	draw_polyline(_inlay, Pal.GOLD_DARK, 3.4)
	draw_polyline(_inlay, Color(Pal.GOLD_LIGHT, 0.55 + 0.45 * pulse), 1.4)
	for sx: float in [-1.0, 1.0]:
		var e := _inlay[0] if sx < 0.0 else _inlay[16]
		Pal.disc(self, e, 2.4 + 1.2 * pulse, Pal.GOLD_LIGHT)


func _shows(t: Target) -> bool:
	return t.phase != Target.Phase.OFF and t.rope_alpha > 0.0 and t.delay <= 0.0


## Mount plate and stem; the string ties into the eyelet below.
func _hook_plate(at: Vector2, angle: float, alpha: float) -> void:
	draw_set_transform(at, angle)
	draw_rect(Rect2(-4.0 + 2.0, -1.0 + 2.0, 8.0, 3.0), Color(Pal.SHADOW, Pal.SHADOW.a * alpha))
	draw_rect(Rect2(-4.0, -1.0, 8.0, 3.0), Color(Pal.METAL_LIGHT, alpha))
	draw_rect(Rect2(-1.0, 2.0, 2.0, 3.2), Color(Pal.METAL, alpha))


func _hook_eye(at: Vector2, angle: float, alpha: float) -> void:
	draw_set_transform(at, angle)
	Pal.hoop(self, Vector2(1.2, 9.2), 4.6, Color(Pal.METAL_DARK, alpha))
	Pal.hoop(self, Vector2(0, 8.0), 4.4, Color(Pal.METAL_LIGHT, alpha))
