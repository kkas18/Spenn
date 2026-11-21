class_name NearLayer
extends Node2D
## The nearest layer (v8.8): a few large, soft, out-of-focus motes between
## you and the field, drifting slowly, a little brighter in the lamp's
## cone. They move further than the field when the phone leans and as you
## aim, which sets the field back into the room. Very faint, so they never
## hide a creature; off on the lowest effect level.

const SOFT := preload("res://assets/particles/soft.png")
const COUNT := 6

var l: Layout
var _motes: Array[Dictionary] = []
var _clock := 0.0


func setup(layout: Layout) -> void:
	l = layout
	# Their own fixed dice: where they drift is the same in every run and
	# draws nothing from the game's.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4E3A1
	_motes.clear()
	for i in COUNT:
		_motes.append({
			"x": rng.randf(), "y": rng.randf_range(0.04, 0.7), "r": rng.randf_range(80.0, 150.0),
			"ph": rng.randf() * TAU, "sp": rng.randf_range(0.006, 0.014) * (1.0 if i % 2 == 0 else -1.0),
		})


func _process(_delta: float) -> void:
	visible = l != null and Device.tier != Device.Tier.LOW
	if not visible:
		return
	_clock += Motion.rd * (0.35 if Prefs.reduced_motion else 1.0)
	queue_redraw()


func _draw() -> void:
	if l == null:
		return
	var lamp := Vector2(l.size.x * 0.32, l.rail_y)
	var col := Pal.INK.lerp(Pal.world("lamp"), 0.4)
	for m in _motes:
		var x := (fposmod(float(m.x) + _clock * float(m.sp), 1.3) - 0.15) * l.size.x
		var y := l.rail_y + float(m.y) * l.play_h + sin(_clock * 0.25 + float(m.ph)) * 14.0
		var p := Vector2(x, y)
		var lit := clampf(1.0 - p.distance_to(lamp) / (l.size.y * 0.8), 0.0, 1.0)
		var a := (0.02 + 0.036 * lit) * (0.75 + 0.25 * sin(_clock * 0.35 + float(m.ph)))
		var r: float = m.r
		draw_texture_rect(SOFT, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col, a))
