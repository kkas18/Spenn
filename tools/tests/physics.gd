extends "res://tools/tests/harness.gd"
## The physics, as rules that must always hold:
##  1. the same flight at every frame rate (30 to 144 Hz, and uneven frames),
##     with no time gained or lost;
##  2. no ball passes through a body, whatever the kind, speed, angle or
##     where in a step the contact falls;
##  3. no fast ball steps over a string it should cut;
##  4. every ball leaves play, nothing is ever left stuck, and no number
##     goes bad (NaN), in a crowded field under steady fire;
##  5. a crowded field left alone settles: no body shakes on the spot.

const SUB := 1.0 / 120.0
var rng := RandomNumberGenerator.new()


func _test() -> void:
	rng.seed = 7
	if not await start_run():
		return
	game.lives = 99
	await _frame_rates()
	await _guide_is_the_flight()
	await _no_tunnelling()
	await _string_cut()
	await _steady_fire()
	await _settles()
	finish()


# ---------------------------------------------------------------- 1

## One shot, replayed under different frame times. The game is stepped by
## hand (`_process` with the frame time under test), and the ball's place
## is compared substep for substep with a run of even 1/120 s frames.
func _frame_rates() -> void:
	game.set_process(false)
	var l = game.layout
	var from: Vector2 = l.pouch_rest()
	var vel: Vector2 = Vector2(0.62, -0.78) * 2250.0 * l.scale   # off the right wall and on up
	var ref := {}
	var patterns := {
		"120 Hz": [SUB], "30 Hz": [1.0 / 30.0], "60 Hz": [1.0 / 60.0], "90 Hz": [1.0 / 90.0], "144 Hz": [1.0 / 144.0],
		"uneven": [0.004, 0.021, 0.009, 0.033, 0.0167, 0.006, 0.045, 0.011],
	}
	for name: String in patterns:
		clear_field()
		game._acc = 0.0
		var b = game.balls[0]
		b.fire(from, vel, false, 0)
		var steps: Array = patterns[name]
		var worst := 0.0
		var seen := 0
		var fed := 0.0
		var t_before: float = game._time
		var i := 0
		while b.active and b.age < 0.45:
			var d: float = steps[i % steps.size()]
			i += 1
			fed += d
			game._process(d)
			var key := roundi(b.age / SUB)
			if name == "120 Hz":
				ref[key] = b.pos
			elif ref.has(key):
				worst = maxf(worst, (b.pos as Vector2).distance_to(ref[key]))
				seen += 1
			# What is drawn is never more than one substep behind what is simulated.
			if b.active:
				check((b.position as Vector2).length() <= vel.length() * SUB * 1.05, "%s: the drawn ball lags under one substep" % name)
		if name != "120 Hz":
			check(seen >= 8 and worst < 0.01, "%s: the flight matches the 120 Hz one (off by %.4f px over %d samples)" % [name, worst, seen])
		check(absf((game._time - t_before) - fed) <= SUB * 1.01, "%s: no time gained or lost (%.4f s fed, %.4f s simulated)" % [name, fed, game._time - t_before])
		b.stop()
	check(ref.size() >= 50 and (ref[50] as Vector2).x < l.size.x - 20.0 and (ref[50] as Vector2).y < from.y - 300.0, "the reference flight banked off the wall and flew on")
	# A long hitch (a frame of a quarter second) slows the game down for
	# that frame instead of leaping ahead: at most 0.05 s is simulated.
	var t0: float = game._time
	game._process(0.25)
	check(game._time - t0 <= 0.05 + SUB, "a long hitch never simulates more than 0.05 s at once")
	game._acc = 0.0
	game.set_process(true)
	await frames(2)


## The dotted aim guide and what the enemies read of your aim come from
## one rule (Ball.trace). It must be the path the ball then flies: in still
## air, in a gust, and off a wall.
func _guide_is_the_flight() -> void:
	game.set_process(false)
	var l = game.layout
	var ball_script := load("res://scripts/ball.gd") as Script
	var from: Vector2 = l.pouch_rest()
	for case: Array in [["straight up", Vector2(0.05, -1.0), 0.0], ["in a gust", Vector2(-0.2, -1.0), 96.0], ["off the wall", Vector2(0.75, -0.66), 0.0], ["off the wall in a gust", Vector2(-0.8, -0.6), -96.0]]:
		clear_field()
		game._acc = 0.0
		var vel: Vector2 = (case[1] as Vector2).normalized() * 1900.0 * l.scale
		var wind: float = case[2]
		game.gust = wind / game.GUST_BALL
		var path: PackedVector2Array = ball_script.call("trace", from, vel, wind, l, 0.5, SUB, true, true)
		var b = game.balls[0]
		b.fire(from, vel, false, 0)
		var worst := 0.0
		var n := 0
		for i in path.size():
			game._process(SUB)
			if not b.active or b.hit_rail:
				break
			worst = maxf(worst, (b.pos as Vector2).distance_to(path[i]))
			n += 1
		check(n >= 30 and worst <= 0.05, "the guide is the flight, %s (off by %.2f px over %d steps)" % [case[0], worst, n])
		b.stop()
	game.gust = 0.0
	game._acc = 0.0
	game.set_process(true)
	await frames(2)


# ---------------------------------------------------------------- 2

## Each kind in turn hangs alone; balls are driven at its middle at full
## speed from many angles, starting at random distances (so the contact
## falls anywhere within a step). Every one must touch it.
func _no_tunnelling() -> void:
	var kinds: Dictionary = (load("res://scripts/target_body.gd") as Script).get_script_constant_map()["Kind"]
	var speed: float = 2250.0 * game.layout.scale
	var through := 0
	var shots := 0
	for kname: String in kinds:
		if kname == "BOSS":
			continue
		for trial in 24:
			var t = await _hang_one(int(kinds[kname]))
			if t == null or not t.is_solid():
				continue
			var dir := Vector2.UP.rotated(rng.randf_range(-1.1, 1.1))
			var side: Vector2 = dir.orthogonal() * rng.randf_range(-0.45, 0.45) * t.radius
			var b = game.balls[0]
			b.fire(t.pos + side - dir * (t.radius + 60.0 + rng.randf_range(0.0, speed * SUB)), dir * speed, false, 0)
			var id: int = t.get_instance_id()
			var touched := false
			for s in 24:
				b.pos += b.vel * SUB
				game.contacts.collide(b)
				if not b.can_touch(id) or t.phase != 1:
					touched = true
					break
			shots += 1
			if not touched:
				through += 1
				note("a ball went through a %s (radius %.0f, angle %.0f°)" % [kname, t.radius, rad_to_deg(dir.angle_to(Vector2.UP))])
			b.stop()
	check(shots >= 300, "enough shots were tried (%d)" % shots)
	check(through == 0, "no ball passes through a body (%d of %d did)" % [through, shots])
	clear_field()
	await frames(2)


## One enemy of `kind`, hanging at rest in an otherwise empty field.
func _hang_one(kind: int) -> Node:
	clear_field()
	game.fx.reset_time()
	var t = game._spawn_one(kind, 0.35)
	if t == null:
		return null
	t.delay = 0.0
	for i in 150:
		game._step(SUB)
	return t if t.phase == 1 else null


# ---------------------------------------------------------------- 3

## Fast balls sent across the top of a string, upright and steeply
## slanted: each crossing must be seen (the string frays or is cut).
func _string_cut() -> void:
	var l = game.layout
	var missed := 0
	var shots := 0
	for deg: int in [0, 20, 40, 55, 65, 72]:
		for sgn: float in [-1.0, 1.0]:
			if deg == 0 and sgn > 0.0:
				continue
			for trial in 20:
				var t = await _hang_one(0)
				if t == null:
					continue
				var dir := Vector2.UP.rotated(deg_to_rad(deg) * sgn)
				var speed: float = rng.randf_range(1500.0, 2250.0) * l.scale
				var cross: Vector2 = (t._pts[0] as Vector2).lerp(t._pts[3], rng.randf_range(0.2, 0.8))
				var b = game.balls[0]
				b.fire(cross - dir * rng.randf_range(30.0, 30.0 + speed * SUB * 2.0), dir * speed, false, 0)
				var seen := false
				for s in 16:
					b.pos += b.vel * SUB
					if b.pos.y < l.rail_y + 16.0:
						break
					game.contacts.collide(b)
					if b.cut_any:
						seen = true
						break
				shots += 1
				if not seen:
					missed += 1
				b.stop()
	check(shots >= 200, "enough crossings were tried (%d)" % shots)
	check(missed == 0, "a fast ball crossing a string near its hook is always seen (%d of %d were not)" % [missed, shots])
	clear_field()
	await frames(2)


# ---------------------------------------------------------------- 4

## A crowded late game under steady fire for 40 s: every number stays
## real, every body stays inside the walls, and every ball leaves play in
## its time (none is left lying in the field).
func _steady_fire() -> void:
	var l = game.layout
	game.director.elapsed = 170.0
	for k: int in [1, 2, 3, 4, 5, 7, 8, 0, 0, 1, 2, 7, 9, 10, 11]:
		game._spawn_one(k)
	var bad := 0
	var outside := 0
	var oldest := 0.0
	var fired := 0
	for f in 60 * 40:
		game.lives = 99
		if f % 22 == 0 and can_aim():
			var dir := Vector2.UP.rotated(rng.randf_range(-0.9, 0.9))
			var o := grip()
			touch(o, true)
			drag(o + pull(dir, rng.randf_range(0.3, 1.0)))
			fired += 1
		elif f % 22 == 6:
			touch(grip(), false)
		await process_frame
		for b in game.balls:
			if not b.active:
				continue
			oldest = maxf(oldest, b.age)
			if not (is_finite(b.pos.x) and is_finite(b.pos.y) and is_finite(b.vel.x) and is_finite(b.vel.y) and is_finite(b.w)):
				bad += 1
			if b.pos.x < 0.0 or b.pos.x > l.size.x:
				if outside == 0:
					note("outside the walls: a ball at %s (speed %s)" % [b.pos, b.vel])
				outside += 1
		for t in game.targets:
			if t.phase == 0:
				continue
			if not (is_finite(t.pos.x) and is_finite(t.pos.y) and is_finite(t.vel.x) and is_finite(t.vel.y) and is_finite(t.body_rot)):
				bad += 1
			if t.is_hittable() and (t.pos.x < -4.0 or t.pos.x > l.size.x + 4.0 or t.pos.y < l.rail_y - 40.0):
				if outside == 0:
					note("outside the walls: kind %d at %s (speed %s, hook %s, string %.0f, acro %d)" % [t.kind, t.pos, t.vel, t.anchor, t.length, t.acro])
				outside += 1
	check(fired >= 30, "the field was under fire (%d shots)" % fired)
	check(bad == 0, "no position, speed or spin goes bad (%d samples did)" % bad)
	check(outside == 0, "nothing leaves the walls (%d samples did)" % outside)
	check(oldest <= 4.0 + 0.05, "every ball leaves play within its 4 s (oldest %.2f s)" % oldest)
	check(is_equal_approx(Engine.time_scale, 1.0) or Engine.time_scale > 0.0, "time is running")
	clear_field()
	game.fx.reset_time()
	game._end_overload(true)
	game._end_flow(true)
	await frames(2)


# ---------------------------------------------------------------- 5

## Twenty-eight bodies packed into the field and left alone for 6 s. A
## body "shakes" when it is thrown back and forth from one substep to the
## next by more than the eye forgives: its change of place reverses, at a
## size (over 0.6 px of difference between two steps) no swing or breeze
## explains.
func _settles() -> void:
	game.set_process(false)
	game.director.elapsed = 170.0
	for k: int in [1, 2, 3, 4, 5, 7, 8, 0, 0, 1, 2, 7, 0, 0, 1, 1, 0, 2, 4, 0, 1, 7, 0, 0, 2, 0, 1, 0]:
		var t = game._spawn_one(k)
		if t != null:
			t.delay = 0.0
	for i in 360:
		game._step(SUB)
	var p1 := {}
	var p2 := {}
	var d_last := {}
	var shakes := 0
	var samples := 0
	var worst := 0.0
	for s in 720:
		game._step(SUB)
		for t in game.targets:
			var id: int = t.get_instance_id()
			if not t.is_hittable():
				p1.erase(id)
				p2.erase(id)
				d_last.erase(id)
				continue
			if p1.has(id) and p2.has(id):
				var d2: Vector2 = t.pos - 2.0 * (p1[id] as Vector2) + (p2[id] as Vector2)
				if d_last.has(id) and d2.dot(d_last[id]) < 0.0 and d2.length() > 0.6 and (d_last[id] as Vector2).length() > 0.6:
					shakes += 1
					worst = maxf(worst, d2.length())
				d_last[id] = d2
				samples += 1
			if p1.has(id):
				p2[id] = p1[id]
			p1[id] = t.pos
	var per_s := shakes / maxf(1.0, samples * SUB)
	note("crowded field at rest: %.2f shakes per body-second (worst %.2f px) over %d samples" % [per_s, worst, samples])
	check(samples > 5000, "a crowded field was watched (%d samples)" % samples)
	check(per_s < 0.5, "bodies at rest do not shake (%.2f shakes per body-second, worst %.2f px)" % [per_s, worst])
	game.set_process(true)
	clear_field()
	await frames(2)
