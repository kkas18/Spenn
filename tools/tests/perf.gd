extends "res://tools/tests/harness.gd"
## Performance probe: a busy late game (about twenty enemies, kept topped
## up, under steady fire) for ten seconds. Prints the time each frame took
## and, with a real renderer, draw calls and primitives.
##
##   godot --headless --path . --fixed-fps 60 -s res://tools/tests/perf.gd
##       script time per frame: everything a frame runs except the GPU
##   xvfb-run godot --path . --resolution 720x1560 -s res://tools/tests/perf.gd
##       also draw calls and primitives (frame times then include a
##       software renderer and say little)
##
## Timings are noisy on a busy machine: compare medians of a few runs, on
## the same machine. Budgets (see OPPGRADERING.md): under 250 draw calls,
## and a median script time that leaves a mid-range phone room for 60 Hz.

const FRAMES := 600
const CROWD := 20


func _test() -> void:
	if not await start_run():
		return
	game.lives = 99
	await frames(30)
	seed(12345)
	game.director.elapsed = 170.0
	for k: int in [1, 2, 3, 4, 5, 7, 8, 0, 0, 1, 2, 7]:
		game._spawn_one(k)
	for i in 200:
		game.lives = 99
		await process_frame
	var ms: Array[float] = []
	var crowd: Array[float] = []
	var draws: Array[float] = []
	var prims: Array[float] = []
	var o := grip()
	var last := Time.get_ticks_usec()
	for f in FRAMES:
		game.lives = 99
		# Keep the field full: top up what was shot down.
		if f % 30 == 0 and alive() < CROWD:
			game._spawn_one([0, 1, 2, 7, 4, 5][f / 30 % 6])
		if f % 20 == 0:
			touch(o, true)
		elif f % 20 == 8:
			drag(o + pull(Vector2.UP.rotated(randf_range(-0.5, 0.5)), 0.8))
		elif f % 20 == 12:
			touch(o + pull(Vector2.UP, 0.8), false)
		await process_frame
		var now := Time.get_ticks_usec()
		ms.append((now - last) / 1000.0)
		last = now
		crowd.append(float(alive()))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_stat("frame ms", ms)
	_stat("enemies", crowd)
	if DisplayServer.get_name() != "headless":
		_stat("draw calls", draws)
		_stat("primitives", prims)
	finish()


func _stat(what: String, a: Array[float]) -> void:
	a.sort()
	var n := a.size()
	var sum := 0.0
	for v in a:
		sum += v
	print("PERF %-10s mean=%.2f median=%.2f p95=%.2f p99=%.2f max=%.2f" % [what, sum / n, a[n / 2], a[int(n * 0.95)], a[int(n * 0.99)], a[n - 1]])
