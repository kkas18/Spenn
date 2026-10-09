class_name Smarts
extends RefCounted
## The smart enemies' thinking, once a frame after the game has read your
## aim and the balls in flight (see Game._update_eyes). Each has one clear
## ability and one clear answer:
##  - Kommandøren (CAPTAIN) reads the line you are aiming along and orders
##    up to three neighbours standing in it to step out; brass threads show
##    each order. It keeps a body between itself and you (Game._find_cover).
##    When it falls, its squad stands leaderless for a moment.
##  - Leseren (SEER) reads a shot the instant it leaves the pouch: it runs
##    the ball's real flight (gravity, wall bounces) forward, finds where it
##    would be struck, and takes one exact step out of the path. Then it is
##    tired and cannot dodge; a quick second ball gets it.
##  - Luringen (SNEAK) creeps down only while unwatched; that part lives in
##    Target._smart_step, as it needs no view of the field.

const ORDER_REACH := 260.0      # px (scaled) a Kommandør's voice carries
const ORDER_MAX := 3
const READ_HORIZON := 1.2       # s of flight the Seer can read ahead
const READ_MIN_T := 0.14        # a ball closer than this cannot be dodged
const TIRED := 1.1
const LEADERLESS := 1.4         # s the squad stands stunned when it falls

var g: Game
var _read: Dictionary = {}      # ball instance id -> the serial of the flight already read


func _init(game: Game) -> void:
	g = game


func tick(path: PackedVector2Array) -> void:
	if g.state != Game.State.PLAYING and g.state != Game.State.STARTING:
		return
	for t: Target in g.targets:
		if not t.is_hittable():
			continue
		match t.kind:
			Target.Kind.CAPTAIN:
				if not path.is_empty() and t.orders_cd <= 0.0 and not t.panicked():
					_give_orders(t, path)
			Target.Kind.SEER:
				if t.tired_t <= 0.0 and t.read_cd <= 0.0 and not t.panicked():
					_read_shots(t)


## Orders the neighbours standing in the line of fire to step out of it,
## each to the side away from the path.
func _give_orders(c: Target, path: PackedVector2Array) -> void:
	var sc: float = g.layout.scale
	var squad: Array[Target] = []
	for o: Target in g.targets:
		if o == c or not o.is_hittable() or o.kind == Target.Kind.BOSS or o.panicked():
			continue
		if o.pos.distance_to(c.pos) > ORDER_REACH * sc or o.threat_lvl < 0.25:
			continue
		squad.append(o)
	if squad.is_empty():
		return
	squad.sort_custom(func(a: Target, b: Target) -> bool: return a.threat_lvl > b.threat_lvl)
	for o in squad.slice(0, ORDER_MAX):
		var q := _nearest_on(path, o.pos)
		var side := signf(o.pos.x - q.x) if absf(o.pos.x - q.x) > 2.0 else (1.0 if o.pos.x < g.layout.center_x else -1.0)
		var step: float = (o.radius + Ball.RADIUS + 26.0) * sc
		var x: float = o.anchor.x + side * step
		if x < o.slide_lo or x > o.slide_hi:
			x = o.anchor.x - side * step
		o.slide_now(x, 380.0 * sc)
		o.ordered_by = c
		o.ordered_life = c.life
		g.fx.order(c, o)
	c.order_flash = 0.7
	c.orders_cd = lerpf(3.6, 2.2, c.aggression)
	c.voice("up", -4.0)
	Sfx.play("tease", 1.2, -10.0)
	g._name_trick("smart.order", c.pos, Tok.PRIMARY_HI)


## Reads each ball just released and steps out of its path, if it can.
func _read_shots(s: Target) -> void:
	var sc: float = g.layout.scale
	for b: Ball in g.balls:
		if not b.active or b.age > 0.05:
			continue
		var id := b.get_instance_id()
		if int(_read.get(id, -1)) == b.serial:
			continue
		_read[id] = b.serial
		var hit := _first_contact(b, s)
		if hit.x < READ_MIN_T:
			continue
		# Out of the path: the side away from where the ball would pass, far
		# enough to clear it (or the other way, if the wall is in the way).
		var reach: float = s.radius + Ball.RADIUS + 14.0 * sc
		var dx := s.pos.x - hit.y
		var side := signf(dx) if absf(dx) > 1.0 else (1.0 if s.pos.x < g.layout.center_x else -1.0)
		var x: float = s.anchor.x + side * (reach - absf(dx) + 6.0)
		if x < s.slide_lo or x > s.slide_hi:
			x = s.anchor.x - side * (reach + absf(dx) + 6.0)
			if x < s.slide_lo or x > s.slide_hi:
				continue
		var from := s.pos
		s.slide_now(x, clampf(absf(x - s.anchor.x) / (hit.x * 0.6), 300.0 * sc, 1100.0 * sc))
		# The hook slides, but the body hangs on a string and would lag: it
		# also springs aside on its own, enough to clear the path in time.
		var need := absf(x - s.anchor.x)
		s.vel.x += signf(x - s.anchor.x) * minf(need / maxf(0.12, hit.x * 0.45), 900.0 * sc)
		s.tired_t = TIRED
		s.read_cd = lerpf(2.6, 1.8, s.aggression)
		s.read_flash = 0.45
		g.fx.afterimage(from, s.radius, s.color(), signf(x - s.anchor.x))
		g._name_trick("smart.read", s.pos, Pal.SHADE)
		return


## When (s) and where (x) ball `b` would first touch `s` on its current
## flight; x is INF when it would miss within the horizon.
func _first_contact(b: Ball, s: Target) -> Vector2:
	var p := b.pos
	var v := b.vel
	var dt := 1.0 / 120.0
	var w := g.layout.size.x
	var rr := s.radius + Ball.RADIUS + 4.0
	var t := 0.0
	var wind: float = g.gust * Game.GUST_BALL
	while t < READ_HORIZON:
		t += dt
		v.y += Ball.GRAVITY * dt
		v.x += wind * dt
		p += v * dt
		if p.x < Ball.RADIUS:
			p.x = Ball.RADIUS
			v.x = absf(v.x) * Ball.WALL_BOUNCE
		elif p.x > w - Ball.RADIUS:
			p.x = w - Ball.RADIUS
			v.x = -absf(v.x) * Ball.WALL_BOUNCE
		if p.distance_squared_to(s.pos) < rr * rr:
			return Vector2(t, p.x)
		if p.y < g.layout.rail_y:
			break
	return Vector2(-1.0, INF)


## A Kommandør fell: its squad (those it ordered, and any close by) stands
## leaderless for a moment, and the order threads snap.
func captain_down(c: Target) -> void:
	var sc: float = g.layout.scale
	var any := false
	for o: Target in g.targets:
		if o == c or not o.is_hittable():
			continue
		if o.ordered_by == c or o.pos.distance_to(c.pos) < ORDER_REACH * sc:
			o.stun_t = maxf(o.stun_t, LEADERLESS)
			o.startle_t = 0.4
			o.ordered_by = null
			g.fx.snap_thread(c.pos, o.pos)
			any = true
	if any:
		g._name_trick("smart.leaderless", c.pos, Tok.PRIMARY_HI)


func _nearest_on(path: PackedVector2Array, p: Vector2) -> Vector2:
	var best := path[0]
	var bd := INF
	for q in path:
		var d := q.distance_squared_to(p)
		if d < bd:
			bd = d
			best = q
	return best
