class_name Perks
extends RefCounted
## Upgrades: after each cleared wave the run picks one of three (v8.9; until
## then one came at random). Most change how a run plays, not only its
## numbers, and some work best together (Splitt with Smell, Rikosjett with
## Vegg-mester). The run's perks are kept by the game (`perks`: id -> level).

# id -> the most times it can be taken
const MAX := {
	"heavy": 1,    # hits on armoured (2+ HP) enemies count double
	"edge": 1,     # one strike severs a rope, and cuts come easier
	"flow": 2,     # +1 s of flow, the meter fills 20% faster
	"rack": 2,     # +1 ball in the rack
	"reload": 2,   # balls reload 15% faster
	"sight": 1,    # the aim guide reaches twice as far
	"magnet": 2,   # balls curve gently toward the nearest enemy
	"charge": 1,   # overload charges 25% faster
	"knot": 99,    # get a lost knot back (only offered when one is lost)
	# v8.9: the ones that change a run
	"split": 2,    # a ball's first hit splits it in two (three)
	"ricochet": 2, # after a hit the ball jumps on to the nearest enemy (twice)
	"blast": 2,    # a hit knocks those around it away (and, at 2, hits the nearest)
	"slowmo": 2,   # time runs slower while you aim
	"big": 2,      # balls are bigger: they hit wider, and reload a little slower
	"freeze": 2,   # a hit freezes those around it: they stop sinking and dodging
	"glass": 1,    # +1 on the multiplier, one knot fewer
	"walls": 1,    # balls keep their speed off the walls; bank shots pay double
}
## The ones that change how a run plays: every offer has at least one while
## any is left.
const SHAPERS := ["split", "ricochet", "blast", "slowmo", "big", "freeze", "walls"]
const OFFER := 3
## Upgrades that work well together: a card says so when the run already
## has the other one.
const PAIRS := [["split", "blast"], ["split", "ricochet"], ["split", "big"], ["blast", "freeze"],
	["freeze", "edge"], ["walls", "sight"], ["walls", "magnet"], ["slowmo", "sight"], ["slowmo", "edge"],
	["glass", "flow"], ["glass", "charge"], ["ricochet", "magnet"], ["big", "heavy"]]


## The first perk the run already has that `id` goes well with ("" if none).
static func partner(id: String, owned: Dictionary) -> String:
	for pair: Array in PAIRS:
		var other := ""
		if pair[0] == id:
			other = pair[1]
		elif pair[1] == id:
			other = pair[0]
		if other != "" and int(owned.get(other, 0)) > 0:
			return other
	return ""


## Up to three different perks that can still be taken, in random order,
## at least one of them a shaper (while any is left).
static func offer(owned: Dictionary, knot_lost: bool, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = []
	for id: String in MAX:
		if id == "knot" and not knot_lost:
			continue
		if int(owned.get(id, 0)) < int(MAX[id]):
			pool.append(id)
	var out: Array[String] = []
	while out.size() < OFFER and not pool.is_empty():
		var i := rng.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	var has_shaper := false
	for id in out:
		if id in SHAPERS:
			has_shaper = true
	if not has_shaper and out.size() == OFFER:
		var left: Array[String] = []
		for id in pool:
			if id in SHAPERS:
				left.append(id)
		if not left.is_empty():
			# The last card (never the knot, which is offered first if at all)
			# makes way for one.
			var at := OFFER - 1
			if out[at] == "knot":
				at -= 1
			out[at] = left[rng.randi() % left.size()]
	return out


## A perk's line icon, gold, centred on `c` and scaled by `s` (drawn on `ci`).
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, a: float, s := 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(s, s))
	c = Vector2.ZERO
	var g := Color(Tok.PRIMARY, a)
	var gl := Color(Tok.PRIMARY_HI, a)
	match id:
		"heavy":
			ci.draw_circle(c + Vector2(0, 3), 14.0, g, true, -1.0, true)
			ci.draw_circle(c + Vector2(-4, -1), 4.0, Color(gl, 0.6 * a), true, -1.0, true)
			for k in 3:
				ci.draw_line(c + Vector2(-20 + k * 5, 22), c + Vector2(-26 + k * 5, 30), g, 2.0, true)
		"edge":
			ci.draw_line(c + Vector2(-16, 16), c + Vector2(16, -16), gl, 3.0, true)
			ci.draw_line(c + Vector2(-16, 16), c + Vector2(-9, 18), g, 2.0, true)
			ci.draw_line(c + Vector2(-6, -18), c + Vector2(-6, 18), Color(g, 0.5 * a), 1.5, true)
		"flow":
			var pts := PackedVector2Array()
			for k in 25:
				var x := -20.0 + k * 40.0 / 24.0
				pts.append(c + Vector2(x, sin(x * 0.28) * 8.0))
			ci.draw_polyline(pts, gl, 2.5, true)
		"rack":
			for k in 3:
				ci.draw_circle(c + Vector2(0, -14 + k * 14), 5.5, g, true, -1.0, true)
			ci.draw_line(c + Vector2(14, -8), c + Vector2(14, 8), gl, 2.0, true)
			ci.draw_line(c + Vector2(6, 0), c + Vector2(22, 0), gl, 2.0, true)
		"reload":
			ci.draw_arc(c, 15.0, -PI * 0.3, PI * 1.4, 32, g, 2.5, true)
			var tip := c + Vector2(cos(-PI * 0.3), sin(-PI * 0.3)) * 15.0
			ci.draw_line(tip, tip + Vector2(-8, -1), g, 2.5, true)
			ci.draw_line(tip, tip + Vector2(1, 8), g, 2.5, true)
		"sight":
			for k in 7:
				var t := k / 6.0
				ci.draw_circle(c + Vector2(-20 + 40 * t, 14 - 34 * t + 22 * t * t), 2.4 - t, g, true, -1.0, true)
		"magnet":
			ci.draw_arc(c + Vector2(0, -2), 12.0, 0.0, PI, 24, g, 6.0, true)
			ci.draw_line(c + Vector2(-12, -2), c + Vector2(-12, -14), g, 6.0, true)
			ci.draw_line(c + Vector2(12, -2), c + Vector2(12, -14), g, 6.0, true)
			ci.draw_line(c + Vector2(-15, -14), c + Vector2(-9, -14), gl, 3.0, true)
			ci.draw_line(c + Vector2(9, -14), c + Vector2(15, -14), gl, 3.0, true)
		"charge":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(3, -20), c + Vector2(-10, 3), c + Vector2(-1, 3), c + Vector2(-4, 20), c + Vector2(10, -4), c + Vector2(1, -4)]), g)
		"knot":
			ci.draw_arc(c + Vector2(-5, 0), 9.0, 0.0, TAU, 28, g, 3.0, true)
			ci.draw_arc(c + Vector2(5, 0), 9.0, 0.0, TAU, 28, gl, 3.0, true)
			ci.draw_line(c + Vector2(-20, 12), c + Vector2(-9, 5), g, 3.0, true)
			ci.draw_line(c + Vector2(20, 12), c + Vector2(9, 5), gl, 3.0, true)
		"split":
			# One ball comes in, two fly on.
			ci.draw_line(c + Vector2(0, 20), c + Vector2(0, 4), Color(g, 0.6 * a), 2.0, true)
			ci.draw_circle(c + Vector2(0, 4), 6.0, g, true, -1.0, true)
			for sx: float in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(sx * 3.0, 0), c + Vector2(sx * 13.0, -12), Color(gl, 0.7 * a), 2.0, true)
				ci.draw_circle(c + Vector2(sx * 15.0, -15), 4.5, gl, true, -1.0, true)
		"ricochet":
			# A path that strikes one and turns to the next.
			var pts := PackedVector2Array([c + Vector2(-20, 18), c + Vector2(-4, -8), c + Vector2(18, 2)])
			ci.draw_polyline(pts, g, 2.5, true)
			ci.draw_circle(c + Vector2(-4, -14), 5.0, gl, false, 2.0, true)
			ci.draw_circle(c + Vector2(18, 2), 4.0, gl, true, -1.0, true)
		"blast":
			# A burst: a ring and rays out of it.
			ci.draw_arc(c, 7.0, 0.0, TAU, 20, gl, 2.5, true)
			for k in 8:
				var d := Vector2.from_angle(k * TAU / 8.0)
				ci.draw_line(c + d * 11.0, c + d * (20.0 if k % 2 == 0 else 16.0), g, 2.0, true)
		"slowmo":
			# An hourglass.
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -17), c + Vector2(11, -17), c + Vector2(0, 0)]), g)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, 17), c + Vector2(11, 17), c + Vector2(0, 0)]), Color(gl, 0.75 * a))
			ci.draw_line(c + Vector2(-14, -18), c + Vector2(14, -18), gl, 2.0, true)
			ci.draw_line(c + Vector2(-14, 18), c + Vector2(14, 18), gl, 2.0, true)
		"big":
			# A big ball over a small one.
			ci.draw_circle(c + Vector2(4, -2), 14.0, g, true, -1.0, true)
			ci.draw_circle(c + Vector2(-1, -7), 5.0, Color(gl, 0.6 * a), true, -1.0, true)
			ci.draw_circle(c + Vector2(-15, 14), 4.0, gl, true, -1.0, true)
		"freeze":
			# A snowflake.
			for k in 3:
				var d := Vector2.from_angle(k * PI / 3.0)
				ci.draw_line(c - d * 18.0, c + d * 18.0, gl, 2.5, true)
				for e: float in [-1.0, 1.0]:
					var tip := c + d * 12.0 * e
					ci.draw_line(tip, tip + d.rotated(0.7 * e) * -6.0 * e, g, 2.0, true)
					ci.draw_line(tip, tip + d.rotated(-0.7 * e) * -6.0 * e, g, 2.0, true)
		"glass":
			# A cracked pane.
			ci.draw_rect(Rect2(c + Vector2(-14, -18), Vector2(28, 36)), g, false, 2.5, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-3, -18), c + Vector2(2, -6), c + Vector2(-4, 4), c + Vector2(3, 18)]), gl, 2.0, true)
			ci.draw_line(c + Vector2(2, -6), c + Vector2(14, -2), gl, 1.5, true)
		"walls":
			# A wall and a ball bouncing off it at full speed.
			ci.draw_line(c + Vector2(-18, -20), c + Vector2(-18, 20), g, 4.0, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(12, -18), c + Vector2(-15, 0), c + Vector2(12, 18)]), gl, 2.5, true)
			ci.draw_circle(c + Vector2(14, 18), 4.0, gl, true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO)
