class_name PerkPanel
extends Control
## Between waves: three upgrade cards rise in over the empty field, one
## after another. Tap one: it lifts and flares, the others fall away, and
## the next wave may start. Blocks the field while open (a choice is due).

signal chosen(id: String)

const CARD := Vector2(200, 262)
const GAP := 14.0
const IN_TIME := 0.42
const STAGGER := 0.09
const OUT_TIME := 0.45

var hud: Hud
var _ids: Array[String] = []
var _levels: Dictionary = {}
var _t := 0.0
var _press := -1
var _picked := -1
var _out_t := -1.0
var _box: StyleBoxFlat
var _box_hi: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_box = StyleBoxFlat.new()
	_box.bg_color = Tok.SURFACE_HI
	_box.border_color = Tok.BORDER_HI
	_box.set_border_width_all(1)
	_box.set_corner_radius_all(Tok.RADIUS_M)
	_box.shadow_color = Color(0, 0, 0, 0.45)
	_box.shadow_size = 14
	_box.shadow_offset = Vector2(0, 6)
	_box.anti_aliasing = true
	_box_hi = _box.duplicate()
	_box_hi.border_color = Tok.PRIMARY
	_box_hi.set_border_width_all(2)
	_box_hi.bg_color = Tok.SURFACE_HI.lightened(0.04)


func is_open() -> bool:
	return visible and _out_t < 0.0


## Shows `ids` (levels owned so far in `levels`).
func open(ids: Array[String], levels: Dictionary) -> void:
	_ids = ids
	_levels = levels
	_t = 0.0
	_press = -1
	_picked = -1
	_out_t = -1.0
	visible = true
	Sfx.play("panel")


## Picks card `i` (also used by test harnesses).
func pick(i: int) -> void:
	if _picked >= 0 or i < 0 or i >= _ids.size():
		return
	_picked = i
	_out_t = 0.0
	Sfx.play("clear", 1.2, -4.0)
	Sfx.phrase([2, 4, 7], 0.06, -4.0)
	Sfx.haptic_pattern("light")
	chosen.emit(_ids[i])


func _card_rect(i: int) -> Rect2:
	var l := hud.l
	var n := _ids.size()
	var w := CARD.x * n + GAP * (n - 1)
	var x := l.center_x - w * 0.5 + i * (CARD.x + GAP)
	var y := l.rail_y + l.play_h * 0.5 - CARD.y * 0.5 + 20.0
	return Rect2(Vector2(x, y), CARD)


func _hit(p: Vector2) -> int:
	for i in _ids.size():
		if _card_rect(i).grow(6.0).has_point(p):
			return i
	return -1


func _gui_input(e: InputEvent) -> void:
	if _picked >= 0 or _t < IN_TIME * 0.6:
		accept_event()
		return
	var pos := Vector2.INF
	var down := false
	var up := false
	if e is InputEventScreenTouch:
		pos = e.position
		down = e.pressed
		up = not e.pressed
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
		down = e.pressed
		up = not e.pressed
	if pos == Vector2.INF:
		return
	accept_event()
	var i := _hit(pos)
	if down:
		_press = i
	elif up:
		if i >= 0 and i == _press:
			pick(i)
		_press = -1


func _process(delta: float) -> void:
	if not visible:
		return
	var rd := delta / maxf(Engine.time_scale, 0.001)
	_t += rd
	if _out_t >= 0.0:
		_out_t += rd
		if _out_t >= OUT_TIME:
			visible = false
	queue_redraw()


func _draw() -> void:
	if hud == null or hud.l == null:
		return
	var l := hud.l
	var caps := hud.caps_font()
	var disp := hud.display_font()
	var w := l.size.x
	var fade := 1.0 - (Motion.ease_value(Motion.Ease.EXIT, _out_t / OUT_TIME) if _out_t >= 0.0 else 0.0)
	# A soft dark band behind the cards so they read over the field.
	var mid := l.rail_y + l.play_h * 0.5 + 20.0
	var band := Motion.ease_value(Motion.Ease.ENTER, minf(1.0, _t / 0.3)) * fade
	for k in 14:
		var f := float(k) / 13.0
		var a := 0.55 * band * (1.0 - f * f)
		draw_rect(Rect2(0, mid - (k + 1) * 14.0, w, 14.0), Color(Tok.BACKGROUND, a * 0.55))
		draw_rect(Rect2(0, mid + k * 14.0, w, 14.0), Color(Tok.BACKGROUND, a * 0.55))
	var title_y := _card_rect(0).position.y - 30.0
	draw_string(caps, Vector2(0, title_y), Loc.t("perk.choose"), HORIZONTAL_ALIGNMENT_CENTER, w, Tok.TYPE_LABEL, Color(Tok.PRIMARY, band))
	for i in _ids.size():
		var k := Motion.ease_value(Motion.Ease.EMPHASIZED, clampf((_t - i * STAGGER) / IN_TIME, 0.0, 1.0))
		if k <= 0.0:
			continue
		var r := _card_rect(i)
		var a := k
		var off := Vector2(0, (1.0 - k) * 60.0)
		var sc := 1.0
		if _picked >= 0:
			var o := Motion.ease_value(Motion.Ease.STANDARD, minf(1.0, _out_t / OUT_TIME))
			if i == _picked:
				sc = 1.0 + 0.06 * sin(PI * minf(1.0, _out_t / 0.25))
				a = 1.0 - maxf(0.0, (_out_t - 0.2) / (OUT_TIME - 0.2))
				off.y -= 16.0 * o
			else:
				a = 1.0 - o
				off.y += 90.0 * o * o
		elif _press == i:
			sc = 0.97
		if a <= 0.0:
			continue
		var c := r.get_center() + off
		draw_set_transform(c, 0.0, Vector2(sc, sc))
		var local := Rect2(-r.size * 0.5, r.size)
		modulate_card(a)
		draw_style_box(_box_hi if (i == _picked or i == _press) else _box, local)
		_draw_card(i, local, a, caps, disp)
		draw_set_transform(Vector2.ZERO)
	modulate_card(1.0)


## Style boxes take no alpha when drawn, so fade their colours instead.
func modulate_card(a: float) -> void:
	for b: StyleBoxFlat in [_box, _box_hi]:
		b.bg_color.a = a
		b.border_color.a = a
		b.shadow_color.a = 0.45 * a


func _draw_card(i: int, r: Rect2, a: float, caps: Font, disp: Font) -> void:
	var id := _ids[i]
	var top := r.position
	var cx := r.get_center().x
	# Icon on a dark disc.
	var ic := Vector2(cx, top.y + 58.0)
	draw_circle(ic, 34.0, Color(Tok.SURFACE_LO, a), true, -1.0, true)
	draw_arc(ic, 34.0, 0.0, TAU, 48, Color(Tok.PRIMARY_LO, 0.8 * a), 1.2, true)
	_icon(id, ic, a)
	# Title and description.
	var title := Loc.t("perk." + id)
	var fs := 25
	while fs > 16 and disp.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 20.0:
		fs -= 1
	draw_string(disp, Vector2(top.x, top.y + 134.0), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(Tok.TEXT_PRIMARY, a))
	draw_multiline_string(caps, Vector2(top.x + 12.0, top.y + 162.0), Loc.t("perk." + id + ".d"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 24.0, 13, 4, Color(Tok.TEXT_SECONDARY, a))
	# Level pips: owned (gold), this one (bright), the rest (faint).
	var mx: int = Perks.MAX[id]
	if mx > 1 and mx < 10:
		var have := int(_levels.get(id, 0))
		var pw := 14.0
		var px := cx - (mx - 1) * pw * 0.5
		for k in mx:
			var p := Vector2(px + k * pw, r.end.y - 20.0)
			var col := Tok.PRIMARY if k < have else (Tok.PRIMARY_HI if k == have else Tok.BORDER_HI)
			draw_circle(p, 3.6 if k == have else 3.0, Color(col, a), true, -1.0, true)


## Simple line icons, gold on the dark disc.
func _icon(id: String, c: Vector2, a: float) -> void:
	var g := Color(Tok.PRIMARY, a)
	var gl := Color(Tok.PRIMARY_HI, a)
	match id:
		"heavy":
			draw_circle(c + Vector2(0, 3), 14.0, g, true, -1.0, true)
			draw_circle(c + Vector2(-4, -1), 4.0, Color(gl, 0.6 * a), true, -1.0, true)
			for k in 3:
				draw_line(c + Vector2(-20 + k * 5, 22), c + Vector2(-26 + k * 5, 30), g, 2.0, true)
		"edge":
			draw_line(c + Vector2(-16, 16), c + Vector2(16, -16), gl, 3.0, true)
			draw_line(c + Vector2(-16, 16), c + Vector2(-9, 18), g, 2.0, true)
			draw_line(c + Vector2(-6, -18), c + Vector2(-6, 18), Color(g, 0.5 * a), 1.5, true)
		"flow":
			var pts := PackedVector2Array()
			for k in 25:
				var x := -20.0 + k * 40.0 / 24.0
				pts.append(c + Vector2(x, sin(x * 0.28) * 8.0))
			draw_polyline(pts, gl, 2.5, true)
		"rack":
			for k in 3:
				draw_circle(c + Vector2(0, -14 + k * 14), 5.5, g, true, -1.0, true)
			draw_line(c + Vector2(14, -8), c + Vector2(14, 8), gl, 2.0, true)
			draw_line(c + Vector2(6, 0), c + Vector2(22, 0), gl, 2.0, true)
		"reload":
			draw_arc(c, 15.0, -PI * 0.3, PI * 1.4, 32, g, 2.5, true)
			var tip := c + Vector2(cos(-PI * 0.3), sin(-PI * 0.3)) * 15.0
			draw_line(tip, tip + Vector2(-8, -1), g, 2.5, true)
			draw_line(tip, tip + Vector2(1, 8), g, 2.5, true)
		"sight":
			for k in 7:
				var t := k / 6.0
				draw_circle(c + Vector2(-20 + 40 * t, 14 - 34 * t + 22 * t * t), 2.4 - t, g, true, -1.0, true)
		"magnet":
			draw_arc(c + Vector2(0, -2), 12.0, 0.0, PI, 24, g, 6.0, true)
			draw_line(c + Vector2(-12, -2), c + Vector2(-12, -14), g, 6.0, true)
			draw_line(c + Vector2(12, -2), c + Vector2(12, -14), g, 6.0, true)
			draw_line(c + Vector2(-15, -14), c + Vector2(-9, -14), gl, 3.0, true)
			draw_line(c + Vector2(9, -14), c + Vector2(15, -14), gl, 3.0, true)
		"charge":
			draw_colored_polygon(PackedVector2Array([c + Vector2(3, -20), c + Vector2(-10, 3), c + Vector2(-1, 3), c + Vector2(-4, 20), c + Vector2(10, -4), c + Vector2(1, -4)]), g)
		"knot":
			draw_arc(c + Vector2(-5, 0), 9.0, 0.0, TAU, 28, g, 3.0, true)
			draw_arc(c + Vector2(5, 0), 9.0, 0.0, TAU, 28, gl, 3.0, true)
			draw_line(c + Vector2(-20, 12), c + Vector2(-9, 5), g, 3.0, true)
			draw_line(c + Vector2(20, 12), c + Vector2(9, 5), gl, 3.0, true)
