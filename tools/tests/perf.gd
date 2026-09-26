extends SceneTree
## Performance probe: a crowded late-game field (about 25 enemies), then
## draw calls, primitives and process time sampled over 10 s. Needs a real
## renderer for the draw counts (not --headless); script times on a busy
## desktop are noisy, so compare medians across runs.
##
##   godot --path . --resolution 720x1600 -s res://tools/tests/perf.gd
##
## Budget (see PLAN.md, v7.50): under 400 draw calls in this scene.

var frame := 0
var game: Node
var samples := {"draw": [], "prims": [], "proc": []}


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")


func _touch(p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = p
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = p
	Input.parse_input_event(e)


func _process(_d: float) -> bool:
	frame += 1
	game = current_scene
	if game == null or not ("layout" in game):
		return false
	var l = game.layout
	var o := Vector2(l.center_x, l.fork_y + 40)
	match frame:
		230:
			_touch(o, true)
		232:
			_drag(o + Vector2(0, 150))
		240:
			_touch(o + Vector2(0, 150), false)
		300:
			seed(12345)
			game.director.elapsed = 170.0
			game.lives = 99
			for k in [1, 2, 3, 4, 5, 7, 8, 0, 0, 1, 2, 7]:
				game._spawn_one(k)
	if frame > 500 and frame <= 1100:
		game.lives = 99
		samples.draw.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		samples.proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	if frame == 1101:
		var alive := 0
		for t in game.targets:
			if t.phase != 0:
				alive += 1
		for k in samples:
			var a: Array = samples[k]
			a.sort()
			print("PERF %-5s median=%.1f max=%.1f" % [k, a[a.size() / 2], a[a.size() - 1]])
		print("PERF enemies=%d" % alive)
		quit()
	return false
