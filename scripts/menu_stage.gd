class_name MenuStage
extends Node2D
## The main menu's atmosphere, between the wall and the title:
## - rays of the lamp, swaying slowly, with gold motes glittering in them;
##   both breathe with the menu music;
## - the enemies waiting in the dark: pairs of eyes that open one by one,
##   blink on their own, watch the slingshot's pouch, widen while it is
##   drawn and squeeze shut when a ball flies past.
## Starting a run sends the eyes rushing at the camera and puts the light out.

const RAYS := 5
const MOTES := 22
const EYES := 9
const SOFT := preload("res://assets/particles/soft.png")

var l: Layout
var look := Vector2.ZERO        # what the eyes watch (the pouch)
var tense := 0.0                # 0..1, how far the band is drawn
var avoid := Rect2()            # keep the eyes out of the menu's text
var avoid_pts: Array[Vector2] = []  # ... and away from the title letters
var view := Vector2.ZERO        # tilt parallax
var _on := false
var _amount := 0.0              # the whole stage fades in and out
var _clock := 0.0
var _rush := -1.0               # time since the run started (<0: none)
var _rng := RandomNumberGenerator.new()
var _eyes: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _add: Node2D                # additive light
var _front: Node2D              # the eyes
var _ray_pts := PackedVector2Array()
var _ray_cols := PackedColorArray()


func _ready() -> void:
	_rng.randomize()
	_add = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = mat
	add_child(_add)
	_add.draw.connect(_draw_light)
	_front = Node2D.new()
	add_child(_front)
	_front.draw.connect(_draw_eyes)
	_ray_pts.resize(4)
	_ray_cols.resize(4)
	visible = false


func setup(layout: Layout) -> void:
	l = layout
	if _eyes.is_empty():
		_place()


## Lights the stage; the eyes open one after another from `delay` on.
func show_stage(delay := 0.6) -> void:
	if l == null:
		return
	_on = true
	_rush = -1.0
	_place()
	for i in _eyes.size():
		_eyes[i].wake = delay + i * 0.32 + _rng.randf_range(0.0, 0.2)
	visible = true


## A run starts: the eyes rush at the camera and the light goes out.
func rush() -> void:
	if _on:
		_on = false
		_rush = 0.0


## Hides at once (another screen took over).
func hide_stage() -> void:
	_on = false
	_rush = -1.0


## A ball flew by: eyes near its path squeeze shut for a moment.
func flinch(p: Vector2) -> void:
	for e in _eyes:
		if e.pos.distance_to(p) < 150.0 * e.depth:
			e.squeeze = 0.4


## Eyes spread over the dark middle of the field, away from each other and
## from the title letters' band; far ones smaller and dimmer.
func _place() -> void:
	if l == null:
		return
	_eyes.clear()
	var tries := 0
	while _eyes.size() < EYES and tries < 400:
		tries += 1
		var depth := _rng.randf_range(0.45, 1.0)
		var p := Vector2(_rng.randf_range(0.08, 0.92) * l.size.x,
			l.rail_y + l.play_h * _rng.randf_range(0.08, 0.95))
		var ok := not avoid.has_point(p)
		for q in avoid_pts:
			if q.distance_to(p) < 150.0:
				ok = false
		for e in _eyes:
			if e.pos.distance_to(p) < 120.0:
				ok = false
				break
		if not ok:
			continue
		var kind := _rng.randi() % 9
		_eyes.append({
			"pos": p, "depth": depth, "col": Pal.kind_color(kind), "wake": 99.0, "open": 0.0,
			"blink": 0.0, "next_blink": _rng.randf_range(2.0, 6.0), "gaze": Vector2.ZERO,
			"squeeze": 0.0, "sway": _rng.randf() * TAU, "wide": 0.0, "gap": _rng.randf_range(0.9, 1.2),
		})
	_motes.clear()
	for i in MOTES:
		_motes.append({"u": _rng.randf(), "v": _rng.randf(), "s": _rng.randf_range(0.5, 1.4),
			"ph": _rng.randf() * TAU, "sp": _rng.randf_range(0.01, 0.03)})


func _process(delta: float) -> void:
	if l == null:
		return
	var rd := delta / maxf(Engine.time_scale, 0.001)
	_clock += rd
	var want := 1.0 if _on else 0.0
	_amount = move_toward(_amount, want, rd / (1.4 if _on else 0.7))
	if _rush >= 0.0:
		_rush += rd
	if _amount <= 0.0 and not _on:
		visible = false
		return
	visible = true
	position = view * 0.55
	for e in _eyes:
		if e.wake > 0.0:
			e.wake -= rd
			continue
		e.open = move_toward(e.open, 1.0, rd / 0.35)
		e.next_blink -= rd
		if e.next_blink <= 0.0:
			e.blink = 0.16
			e.next_blink = _rng.randf_range(2.5, 7.0)
			# Now and then a double blink.
			if _rng.randf() < 0.25:
				e.next_blink = 0.3
		e.blink = maxf(0.0, e.blink - rd)
		e.squeeze = maxf(0.0, e.squeeze - rd)
		var to: Vector2 = (look - e.pos)
		e.gaze = e.gaze.lerp(to.normalized() * minf(1.0, to.length() / 300.0), Pal.damp(0.08, rd))
		e.wide = lerpf(e.wide, tense, Pal.damp(0.15, rd))
	_add.queue_redraw()
	_front.queue_redraw()


## Rays of the lamp and the motes in them.
func _draw_light() -> void:
	var amt := _amount
	if amt <= 0.0:
		return
	var lvl := Music.level()
	# Light from a high window up and to the left, above the screen: long,
	# near-parallel shafts, each feathered to nothing at both edges.
	var lamp := Vector2(l.size.x * 0.18, -l.size.y * 0.28)
	var reach := l.size.y * 1.5
	var n := RAYS if Device.tier != Device.Tier.LOW else 3
	var col := Pal.GOLD_LIGHT.lerp(Pal.INK, 0.35)
	for i in n:
		var base := lerpf(-0.16, 0.3, (i + 0.5) / n)
		var ang := base + sin(_clock * (0.05 + i * 0.011) + i * 1.7) * 0.035
		var half := 0.022 + 0.012 * sin(_clock * 0.09 + i * 2.3) + (0.01 if i % 2 == 0 else 0.0)
		var a := (0.075 + 0.04 * sin(_clock * 0.17 + i * 1.3) + 0.06 * lvl) * amt
		var dc := Vector2(sin(ang), cos(ang))
		for side in [-1.0, 1.0]:
			var de := Vector2(sin(ang + side * half), cos(ang + side * half))
			_ray_pts[0] = lamp + dc * 40.0
			_ray_pts[1] = lamp + de * 40.0
			_ray_pts[2] = lamp + de * reach
			_ray_pts[3] = lamp + dc * reach
			_ray_cols[0] = Color(col, a)
			_ray_cols[1] = Color(col, 0.0)
			_ray_cols[2] = Color(col, 0.0)
			_ray_cols[3] = Color(col, 0.0)
			_add.draw_polygon(_ray_pts, _ray_cols)
	# The lamp's own glow at the top.
	var gp := Vector2(l.size.x * 0.3, l.rail_y)
	var g := 260.0 + 40.0 * lvl
	_add.draw_texture_rect(SOFT, Rect2(gp - Vector2(g, g), Vector2(g, g) * 2.0), false, Color(Pal.GOLD_LIGHT, (0.04 + 0.04 * lvl) * amt))
	# Motes drifting down through the light, twinkling.
	for m in _motes:
		var v := fposmod(m.v + _clock * m.sp, 1.0)
		var u := fposmod(m.u + sin(_clock * 0.2 + m.ph) * 0.02, 1.0)
		var p := Vector2(u * l.size.x, l.rail_y + v * l.play_h)
		var in_beam := clampf(1.0 - absf(atan2(p.x - lamp.x, p.y - lamp.y) - 0.07) / 0.3, 0.0, 1.0)
		var tw := pow(0.5 + 0.5 * sin(_clock * (1.3 + m.s) + m.ph), 3.0)
		var a := (0.05 + 0.45 * tw * in_beam) * (0.6 + 0.6 * lvl) * amt * minf(1.0, v * 6.0) * minf(1.0, (1.0 - v) * 6.0)
		var r: float = 5.0 * m.s * (1.0 + tw * 0.6)
		_add.draw_texture_rect(SOFT, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(Pal.GOLD_LIGHT, a))
	# Each pair of eyes lights the dark around it faintly in its colour.
	for e in _eyes:
		var k := _eye_alpha(e)
		if k <= 0.0:
			continue
		var s := _eye_scale(e)
		var r: float = 60.0 * s
		_add.draw_texture_rect(SOFT, Rect2(_eye_pos(e) - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(e.col, 0.09 * k * e.open))


func _eye_alpha(e: Dictionary) -> float:
	if e.wake > 0.0:
		return 0.0
	var k: float = _amount * lerpf(0.45, 0.95, e.depth)
	if _rush >= 0.0:
		k *= clampf(1.0 - (_rush - 0.12) / 0.35, 0.0, 1.0)
	return k


func _eye_scale(e: Dictionary) -> float:
	var s: float = lerpf(0.55, 1.0, e.depth) * l.scale
	if _rush >= 0.0:
		s *= 1.0 + pow(_rush * 2.2, 2.0) * 1.6
	return s


func _eye_pos(e: Dictionary) -> Vector2:
	var p: Vector2 = e.pos + Vector2(sin(_clock * 0.3 + e.sway) * 6.0, sin(_clock * 0.47 + e.sway) * 4.0) * e.depth
	if _rush >= 0.0:
		# Toward the camera: out from the centre of the screen.
		p += (p - l.size * 0.5) * pow(_rush * 2.2, 2.0) * 0.5
	return p


## Eyes only: two whites, pupils looking at the pouch, lids for blinks.
func _draw_eyes() -> void:
	for e in _eyes:
		var k := _eye_alpha(e)
		if k <= 0.0:
			continue
		var s := _eye_scale(e)
		var c := _eye_pos(e)
		var shut: float = 1.0 - sin(PI * clampf(e.blink / 0.16, 0.0, 1.0))
		if e.squeeze > 0.0:
			# Shut fast, held, then opened warily.
			shut = minf(shut, maxf(clampf((e.squeeze - 0.35) / 0.05, 0.0, 1.0), clampf(1.0 - e.squeeze / 0.12, 0.0, 1.0)))
		var open: float = e.open * shut * (1.0 + 0.25 * e.wide)
		if open <= 0.02:
			# Closed: a fine lid line.
			for side in [-1.0, 1.0]:
				var q := c + Vector2(side * 11.0 * e.gap * s, 0)
				_front.draw_line(q - Vector2(6.0 * s, 0), q + Vector2(6.0 * s, 0), Color(e.col.lerp(Pal.INK, 0.4), 0.5 * k), 1.5, true)
			continue
		var white := Pal.EYE.lerp(e.col, 0.25)
		var rx := 7.5 * s
		var ry := 8.5 * s * open
		for side in [-1.0, 1.0]:
			var q := c + Vector2(side * 11.0 * e.gap * s, 0)
			_front.draw_set_transform(q, 0.0, Vector2(1.0, ry / rx))
			_front.draw_circle(Vector2.ZERO, rx, Color(white, 0.85 * k), true, -1.0, true)
			_front.draw_set_transform(Vector2.ZERO)
			var pr := rx * lerpf(0.52, 0.4, e.wide)
			var pp: Vector2 = q + e.gaze * Vector2(rx - pr - 0.5, ry - pr * minf(1.0, open)) * 0.9
			_front.draw_circle(pp, pr * minf(1.0, open + 0.2), Color(Pal.PUPIL, k), true, -1.0, true)
			_front.draw_circle(pp + Vector2(-pr * 0.35, -pr * 0.4), pr * 0.28, Color(1, 1, 1, 0.8 * k), true, -1.0, true)
