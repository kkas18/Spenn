class_name Ball
extends Node2D
## A fired ball (pooled). Integrated by the game in fixed sub-steps.

const RADIUS := 13.0
const GRAVITY := 320.0
const WALL_BOUNCE := 0.85
const MAX_AGE := 4.0

var active := false
var special := false           # pierce ball: passes through targets
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var age := 0.0
var hits := 0                  # targets hit during this shot
var spin := 0.0                # visual rotation (rad)
var _touched := {}             # target instance id -> cooldown (s)
var _trail := PackedVector2Array()
var _trail_t := 0.0

const TRAIL := 6


func _ready() -> void:
	visible = false


func fire(p: Vector2, v: Vector2, is_special: bool) -> void:
	active = true
	special = is_special
	pos = p
	vel = v
	age = 0.0
	hits = 0
	spin = 0.0
	_touched.clear()
	_trail.resize(TRAIL + 1)
	_trail.fill(p)
	_trail_t = 0.0
	visible = true


func stop() -> void:
	active = false
	visible = false


func can_touch(id: int) -> bool:
	return not _touched.has(id)


func touch(id: int) -> void:
	_touched[id] = 0.15


## Advances the ball; returns false when it has left play.
func step(dt: float, l: Layout) -> bool:
	age += dt
	vel.y += GRAVITY * dt
	pos += vel * dt
	spin += vel.length() / RADIUS * dt * (1.0 if vel.x >= 0.0 else -1.0) * 0.35
	_trail_t += dt
	if _trail_t >= 1.0 / 60.0:
		_trail_t = 0.0
		for i in range(TRAIL, 0, -1):
			_trail[i] = _trail[i - 1]
	_trail[0] = pos
	for id in _touched.keys():
		_touched[id] -= dt
		if _touched[id] <= 0.0:
			_touched.erase(id)
	if pos.x < RADIUS:
		pos.x = RADIUS
		vel.x = absf(vel.x) * WALL_BOUNCE
	elif pos.x > l.size.x - RADIUS:
		pos.x = l.size.x - RADIUS
		vel.x = -absf(vel.x) * WALL_BOUNCE
	if pos.y < l.rail_y + RADIUS + 3.0 and vel.y < 0.0:
		pos.y = l.rail_y + RADIUS + 3.0
		vel.y = -vel.y * 0.55
	return age < MAX_AGE and pos.y < l.size.y + RADIUS * 2.0


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	# Six fading segments, matte gold, no glow.
	for i in TRAIL:
		var k := 1.0 - float(i) / TRAIL
		draw_line(_trail[i], _trail[i + 1], Color(Pal.GOLD_DARK, 0.4 * k), RADIUS * 1.5 * k, true)
	draw_ball(self, pos, RADIUS, special, spin, vel.normalized())


## Matte gold ball lit from the upper left. `rot` turns the seam so spin
## reads; a pierce ball carries a dark slit along its flight direction.
static func draw_ball(ci: CanvasItem, p: Vector2, r: float, is_special: bool, rot: float, dir: Vector2) -> void:
	Pal.disc(ci, p + Pal.SHADOW_OFFSET * 0.8, r, Pal.SHADOW)
	Pal.disc(ci, p, r, Pal.GOLD_DARK)
	Pal.disc(ci, p - Vector2(1.3, 1.3), r - 1.6, Pal.GOLD)
	Pal.disc(ci, p - Vector2(r, r) * 0.34, r * 0.32, Color(Pal.GOLD_LIGHT, 0.55))
	ci.draw_arc(p, r * 0.58, rot, rot + PI * 0.75, 12, Color(Pal.GOLD_DARK, 0.55), 1.4, true)
	if is_special:
		var d := dir.normalized() if dir.length() > 0.01 else Vector2.UP
		ci.draw_line(p - d * r * 0.72, p + d * r * 0.72, Pal.METAL_DARK, 3.0, true)
		Pal.ring(ci, p, r - 0.8, Pal.METAL_DARK, 1.6)
