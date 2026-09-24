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
var _touched := {}             # target instance id -> cooldown (s)


func _ready() -> void:
	visible = false


func fire(p: Vector2, v: Vector2, is_special: bool) -> void:
	active = true
	special = is_special
	pos = p
	vel = v
	age = 0.0
	hits = 0
	_touched.clear()
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
	Pal.shadow_disc(self, pos, RADIUS)
	Pal.disc(self, pos, RADIUS, Pal.GOLD)
