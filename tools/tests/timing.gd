extends "res://tools/tests/harness.gd"
## Real time and game time. A hit freezes the game for a moment (hit-stop),
## kills slow it down, overload runs it at 70 %: none of that may stretch,
## shorten or swallow what is timed in real seconds. Before v8.0 every
## hit-stop made the real-time clocks leap 0.83 s ahead, which cut overload
## and flow short on each hit and swallowed the screen shake, the camera's
## lean and the slow motion that a hit had just asked for.

const FRAME := 1.0 / 60.0


func _test() -> void:
	if not await start_run():
		return
	game.lives = 99
	clear_field()
	await frames(30)

	# --- a shake asked for on the frame a hit-stop begins lasts its time
	game.fx.hitstop()
	game.fx.shake(3.0)
	var shaking := 0
	for f in 30:
		await process_frame
		if game.fx._shake_t > 0.0:
			shaking += 1
	var want: float = game.fx.SHAKE_TIME
	check(absf(shaking * FRAME - want) <= FRAME * 1.5, "a shake on a hit-stop frame lasts its %.2f s (%.2f s)" % [want, shaking * FRAME])

	# --- slow motion asked for with a hit-stop live lasts its real time
	await frames(20)
	game.fx.hitstop()
	game.fx.slowmo(0.2, 0.8)
	var slow := 0
	for f in 90:
		await process_frame
		if game.fx._slow_left > 0.0:
			slow += 1
	check(absf(slow * FRAME - 0.8) <= FRAME * 2.0, "0.8 s of slow motion lasts 0.8 s through a hit-stop (%.2f s)" % (slow * FRAME))
	check(is_equal_approx(Engine.time_scale, 1.0), "... and time is back to full speed after it")

	# --- the camera's lean on a kill plays out
	await frames(10)
	game.fx.hitstop()
	game.fx.focus(Vector2(200, 600), 0.06, 0.9)
	var leaning := 0
	for f in 90:
		await process_frame
		if game.fx._focus_t >= 0.0:
			leaning += 1
	check(absf(leaning * FRAME - 0.9) <= FRAME * 2.0, "a 0.9 s camera lean lasts 0.9 s through a hit-stop (%.2f s)" % (leaning * FRAME))

	# --- a real-time timer started on a hit-stop frame fires on time
	await frames(10)
	var fired := [false]
	var waited := 0
	game.fx.hitstop()
	var motion: Node = root.get_node("Motion")
	motion.after(0.5, func() -> void: fired[0] = true)
	for f in 60:
		await process_frame
		if fired[0]:
			break
		waited += 1
	check(fired[0] and absf(waited * FRAME - 0.5) <= FRAME * 2.0, "a 0.5 s real-time timer fires after 0.5 s through a hit-stop (%.2f s)" % (waited * FRAME))

	# --- the shot leaves when the finger lets go, whatever time is doing:
	# in the slow motion of a cleared wave it used to hang for a quarter
	# of a second
	await wait_until(can_aim, 300)
	var o := grip()
	touch(o, true)
	await frames(1)
	drag(o + pull(Vector2.UP, 0.9))
	await frames(2)
	game.fx.slowmo(0.2, 1.0)
	await frames(3)
	touch(o + pull(Vector2.UP, 0.9), false)
	var until_gone := 0
	for f in 40:
		await process_frame
		until_gone += 1
		if not active_balls().is_empty():
			break
	check(not active_balls().is_empty() and until_gone * FRAME <= 0.1, "a shot let go in slow motion leaves within a tenth of a second (%.2f s)" % (until_gone * FRAME))
	await wait_until(func() -> bool: return game.fx._slow_left <= 0.0, 120)
	clear_field()

	# --- overload lasts its real seconds however many hits land
	await frames(10)
	game._begin_overload()
	var over := 0
	for f in 600:
		if f % 6 == 0:
			game.fx.hitstop()       # a hit every tenth of a second
		await process_frame
		if game.overload_t > 0.0:
			over += 1
		else:
			break
	var want_over: float = game.OVERLOAD_TIME
	check(absf(over * FRAME - want_over) <= 0.1, "overload lasts its %.1f s under a rain of hits (%.2f s)" % [want_over, over * FRAME])

	# --- and so does flow
	await frames(30)
	game._begin_flow()
	var flowing := 0
	for f in 900:
		if f % 6 == 0:
			game.fx.hitstop()
		await process_frame
		if game.flow_t > 0.0:
			flowing += 1
		else:
			break
	var want_flow: float = game._flow_time()
	check(absf(flowing * FRAME - want_flow) <= 0.1, "flow lasts its %.1f s under a rain of hits (%.2f s)" % [want_flow, flowing * FRAME])

	# --- a hit-stop itself is short and always ends
	await frames(30)
	game.fx.hitstop()
	var stopped := 0
	for f in 30:
		await process_frame
		if Engine.time_scale < 0.5:
			stopped += 1
	check(stopped >= 1 and stopped * FRAME <= game.fx.HITSTOP + FRAME * 2.0, "a hit-stop lasts about %.0f ms (%d frames)" % [game.fx.HITSTOP * 1000.0, stopped])
	# --- a hit-stop lasts by the weight of the hit (v8.3): light for a hit
	# that does not kill, heavy for the boss
	await frames(20)
	var stops := {}
	for weight: float in [0.6, 1.0, 1.5]:
		game.fx.hitstop(weight)
		var held := 0
		for f in 20:
			await process_frame
			if game.fx._hitstop_live:
				held += 1
		stops[weight] = held
		await frames(6)
	check(stops[0.6] < stops[1.0] and stops[1.0] < stops[1.5], "a light hit stops the game for less time than a kill, and the boss for more (%s frames)" % str(stops.values()))
	check(stops[1.5] * FRAME <= 0.09, "... and the longest is under a tenth of a second (%.3f s)" % (stops[1.5] * FRAME))

	# --- a weaker vibration never cuts a stronger one short
	var sfx := root.get_node("Sfx")
	sfx._haptic_until = 0
	check(sfx._take_haptic(80, 0.9, 1000), "a strong vibration is made")
	check(not sfx._take_haptic(9, 0.4, 1020), "a weaker one is not made while it lasts")
	check(sfx._take_haptic(70, 0.9, 1040), "one as strong takes over")
	check(sfx._take_haptic(9, 0.4, 1120), "and when it has ended, the weak one is made again")

	# --- however keen, a creature watches before it moves (v8.3). The
	# narrowed eye is the warning that a dodge is coming, so it has to be
	# shown long enough to be seen. Every kind at its quickest: full
	# aggression, timid, leading, wary, sprung, and knowing your rhythm.
	var target: Script = load("res://scripts/target.gd")
	var consts: Dictionary = (load("res://scripts/target_body.gd") as Script).get_script_constant_map()
	var react_min: float = consts["REACT_MIN"]
	var react_flight: float = consts["REACT_MIN_FLIGHT"]
	var step: float = game.SUBSTEP
	var keep := [target.get("tactic"), target.get("rhythm"), target.get("hold_avg"), target.get("aim_hold")]
	var soonest := {}
	for case: String in ["aim", "flight", "beat"]:
		var least := INF
		for kind: int in consts["EVADE"]:
			var t: Node2D = target.new()
			t.kind = kind
			t.aggression = 1.0
			t.temper = consts["Temper"]["TIMID"]
			t.is_leader = true
			t.charm = consts["Charm"]["SPRING"]
			t.stance = consts["Stance"]["WARY"]
			target.set("tactic", 5)
			target.set("rhythm", case == "beat")
			target.set("hold_avg", 0.0)
			target.set("aim_hold", 1.0)
			t.aimed = case != "flight"
			t.incoming = case == "flight"
			var watched := 0.0
			while not t.mind_ask and watched < 3.0:
				t._evade(step)
				watched += step
			least = minf(least, watched)
			t.free()
		soonest[case] = least
	target.set("tactic", keep[0])
	target.set("rhythm", keep[1])
	target.set("hold_avg", keep[2])
	target.set("aim_hold", keep[3])
	check(soonest.aim >= react_min - 0.001, "no creature moves sooner than %.2f s after the aim lands on it (%.3f s)" % [react_min, soonest.aim])
	check(soonest.flight >= react_flight - 0.001, "... or sooner than %.2f s at a ball in flight (%.3f s)" % [react_flight, soonest.flight])
	check(soonest.beat >= react_flight - 0.001, "... or on your rhythm without having watched that long (%.3f s)" % soonest.beat)
	check(react_min >= 0.15 and react_flight >= 0.1, "the least reactions are what a player can see (%.2f s and %.2f s)" % [react_min, react_flight])
	finish()
