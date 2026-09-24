class_name Slingshot
extends Node2D
## Fork, band, pouch and the ammo stack.

signal launched(pos: Vector2, vel: Vector2, special: bool)

const MIN_POWER := 0.18

var l: Layout
var aiming := false
var pouch := Vector2.ZERO
var power := 0.0
var aim_dir := Vector2.UP
var _ammo: Array[bool] = []
var _reload := 0.0


func setup(layout: Layout) -> void:
	l = layout
	pouch = l.pouch_rest()
	queue_redraw()


func set_ammo(queue: Array[bool], reload_frac: float) -> void:
	_ammo = queue
	_reload = reload_frac


func has_ball() -> bool:
	return not _ammo.is_empty()


func begin_aim() -> bool:
	if not has_ball():
		return false
	aiming = true
	return true


## `offset` is the finger's travel since the drag began.
func drag(offset: Vector2) -> void:
	if not aiming:
		return
	var rest := l.pouch_rest()
	var v := offset
	# Only pulls toward the player are meaningful; keep within ±80° of down.
	if v.y < 0.0:
		v.y = 0.0
	var ang := clampf(Vector2.DOWN.angle_to(v), -deg_to_rad(80), deg_to_rad(80)) if v.length() > 0.01 else 0.0
	v = Vector2.DOWN.rotated(ang) * minf(v.length(), l.max_pull)
	var p := rest + v
	p.x = maxf(p.x, l.pouch_min_x())
	pouch = p
	var pull := pouch - rest
	power = clampf(pull.length() / l.max_pull, 0.0, 1.0)
	if pull.length() > 0.01:
		aim_dir = -pull.normalized()


func release() -> void:
	if not aiming:
		return
	aiming = false
	if power >= MIN_POWER:
		var speed := lerpf(950.0, 2150.0, power) * l.scale
		launched.emit(pouch, aim_dir * speed, _ammo[0])
	pouch = l.pouch_rest()
	power = 0.0


func cancel() -> void:
	aiming = false
	pouch = l.pouch_rest()
	power = 0.0


func step(_dt: float) -> void:
	pass


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if l == null:
		return
	var cx := l.center_x
	var tl := Vector2(cx - l.fork_half, l.fork_y)
	var tr := Vector2(cx + l.fork_half, l.fork_y)
	var crotch := Vector2(cx, l.crotch_y)
	draw_polyline(PackedVector2Array([tl, crotch, tr]), Pal.METAL, 14.0, true)
	draw_line(crotch, Vector2(cx, l.handle_end_y), Pal.METAL, 18.0, true)
	draw_line(tl, pouch, Pal.BAND, 5.0, true)
	draw_line(tr, pouch, Pal.BAND, 5.0, true)
	if has_ball():
		Pal.disc(self, pouch, Ball.RADIUS, Pal.GOLD)
	_draw_ammo()


func _draw_ammo() -> void:
	for i in 5:
		var p := Vector2(l.ammo_x, l.ammo_top + i * l.ammo_step)
		if i < _ammo.size():
			var col := Pal.GOLD if i == 0 else Pal.GOLD_DARK
			if i == 0:
				Pal.disc(self, p, 8.0, col)
			else:
				Pal.ring(self, p, 7.0, col, 2.0)
		else:
			Pal.ring(self, p, 7.0, Color(Pal.INK_FAINT, 0.5), 1.0)
