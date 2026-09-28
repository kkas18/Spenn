extends SceneTree
## A simple bot player, for balance checks and as a gameplay test: it aims
## at the lowest solid enemy with a little lead and a little human error,
## then prints one RESULT line when the run ends (or after 12 minutes).
##
##   godot --headless --path . --fixed-fps 60 -s res://tools/tests/bot.gd
##
## Environment: SEED (default 1), NOISE (aim error in radians, 0.05),
## AIM_MIN / AIM_MAX (frames the pull is held, 8..24), CAD (frames between
## shots, 20).

var game: Node
var frame := 0
var started := false
var last_shot := -100
var rng := RandomNumberGenerator.new()
var aim_frames := 0
var aim_off := Vector2.ZERO
var aim_noise := 0.0
var target_ref: Node2D = null   # a Target (untyped: this script compiles before the game's)
var noise := _env_f("NOISE", 0.05)
var aim_min := int(_env_f("AIM_MIN", 8))
var aim_max := int(_env_f("AIM_MAX", 24))
var cadence := int(_env_f("CAD", 20))


static func _env_f(key: String, fallback: float) -> float:
	var v := OS.get_environment(key)
	return float(v) if v != "" else fallback


func _initialize() -> void:
	rng.seed = int(_env_f("SEED", 1))
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
	if aim_frames > 0:
		aim_frames -= 1
		# Track the chosen target while holding, like a person would.
		if target_ref != null and is_instance_valid(target_ref) and target_ref.is_hittable():
			var ap: Vector2 = target_ref.pos + target_ref.vel * 0.18
			var d2: Vector2 = (ap - l.pouch_rest()).normalized().rotated(aim_noise)
			if d2.y > -0.2:
				d2 = Vector2(signf(d2.x) * 0.98, -0.2).normalized()
			aim_off = -d2 * l.drag_range * 0.9
		_drag(o + aim_off)
		if aim_frames == 0:
			_touch(o + aim_off, false)
		return false
	if game.state == game.get_script().get_script_constant_map()["State"]["GAME_OVER"]:
		var d = game.director
		print("RESULT seed=%d time=%.0fs score=%d acc=%d%% over=%d wave=%d" % [rng.seed, d.elapsed, game.score, int(100.0 * d.hits / maxf(1, d.shots)), game.overloads, d.wave])
		quit()
		return false
	if frame > 60 * 60 * 12:
		print("RESULT seed=%d time=%.0fs (capped) score=%d wave=%d" % [rng.seed, game.director.elapsed, game.score, game.director.wave])
		quit()
		return false
	if game.ammo.is_empty() or frame - last_shot < cadence:
		return false
	# The most dangerous solid target (the lowest), led a little.
	var best: Node2D = null
	var best_y := -INF
	for t in game.targets:
		if t.is_solid() and t.pos.y > best_y:
			best_y = t.pos.y
			best = t
	if best == null and started:
		return false
	var aim_pt: Vector2 = best.pos + best.vel * 0.18 if best else Vector2(l.center_x, l.rail_y + 200)
	aim_noise = rng.randf_range(-noise, noise)
	target_ref = best
	var dir: Vector2 = (aim_pt - l.pouch_rest()).normalized().rotated(aim_noise)
	if dir.y > -0.2:
		dir = Vector2(signf(dir.x) * 0.98, -0.2).normalized()
	aim_off = -dir * l.drag_range * 0.9
	_touch(o, true)
	aim_frames = rng.randi_range(aim_min, aim_max)
	last_shot = frame
	started = true
	return false
