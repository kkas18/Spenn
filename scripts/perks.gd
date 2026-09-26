class_name Perks
extends RefCounted
## Upgrades won between waves: after each cleared wave the run gains one at
## random (from those not yet at their cap), shown as it flies into the
## tray. The run's perks are kept by the game (`perks`: id -> level).

# id -> the most times it can be taken
const MAX := {
	"heavy": 1,    # hits on armoured (2+ HP) enemies count double
	"edge": 1,     # one strike severs a rope, and cuts come easier
	"flow": 2,     # +2.5 s of flow, the meter fills 20% faster
	"rack": 2,     # +1 ball in the rack
	"reload": 2,   # balls reload 15% faster
	"sight": 1,    # the aim guide reaches twice as far
	"magnet": 2,   # balls curve gently toward the nearest enemy
	"charge": 1,   # overload charges 25% faster
	"knot": 99,    # get a lost knot back (only offered when one is lost)
}
const OFFER := 3


## Up to three different perks that can still be taken, in random order.
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
	ci.draw_set_transform(Vector2.ZERO)
