extends SceneTree
## Soak test: a crowded late-game field (a dozen extra enemies of every
## kind, time pushed on, lives topped up) run for 20 s of game time. Fails
## (exit code 1) if the node count grows (something is created every frame
## and never freed) or an effect pool outgrows its size.
##
##   godot --headless --path . --fixed-fps 60 -s res://tools/tests/soak.gd

const RUN_FRAMES := 1200
var frame := 0
var game: Node
var nodes_at_start := 0
var nodes_max := 0


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
			game.director.elapsed = 170.0
			game.lives = 99
			for k in [1, 2, 3, 4, 5, 7, 8, 0, 0, 1, 2, 7]:
				game._spawn_one(k)
		360:
			nodes_at_start = get_node_count()
	if frame > 360:
		game.lives = 99
		nodes_max = maxi(nodes_max, get_node_count())
		# Keep shooting straight up so hits, bursts and popups happen.
		if frame % 20 == 0:
			_touch(o, true)
		elif frame % 20 == 8:
			_drag(o + Vector2(randf_range(-60.0, 60.0), 150))
		elif frame % 20 == 12:
			_touch(o + Vector2(0, 150), false)
	if frame == 360 + RUN_FRAMES:
		var alive := 0
		for t in game.targets:
			if t.phase != 0:
				alive += 1
		var grew := nodes_max - nodes_at_start
		print("SOAK frames=%d alive=%d nodes=%d..%d" % [RUN_FRAMES, alive, nodes_at_start, nodes_max])
		var fail := false
		if grew > 8:
			print("SOAK FAIL: the node count grew by %d" % grew)
			fail = true
		if game.fx._popups.size() != game.fx.POPUP_POOL or game.fx._frags.size() != game.fx.FRAG_POOL:
			print("SOAK FAIL: an effect pool changed size")
			fail = true
		print("SOAK " + ("FAIL" if fail else "OK"))
		quit(1 if fail else 0)
	return false
