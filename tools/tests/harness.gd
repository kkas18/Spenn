extends SceneTree
## Shared base of the headless tests (see run.sh). A test extends this,
## writes its steps as one coroutine in `_test()`, and ends by calling
## `finish()`:
##
##   extends "res://tools/tests/harness.gd"
##   func _test() -> void:
##       await start_run()
##       check(game.lives == 3, "a run starts with three lives")
##       finish()
##
## Every test runs on a save file of its own (never the player's), starts
## from the same seed, and fails on a broken check, a script error (run.sh
## reads the log) or a run that never finishes.
##
##   godot --headless --path . --fixed-fps 60 -s res://tools/tests/<name>.gd

const SAVE := "user://test_%s.cfg"
## The screen the tests play on: a common tall phone (Galaxy S23 class:
## 1080 x 2340 at 425 dpi, the camera cut-out at the top). A headless run
## has no window, and left alone the view would be a 1280 px square that
## no phone has (and every synthetic touch twenty times too far).
const SCREEN := Vector2i(720, 1560)
const SCREEN_DP := 1.77
const SCREEN_SAFE_TOP := 53.0

var game: Node                  # the Game scene (untyped: this compiles before the game's classes)
var prefs: Node
var label := "test"
var checks := 0
var fails := 0
var _finished := false


func _initialize() -> void:
	label = (get_script() as Script).resource_path.get_file().get_basename()
	set_screen(SCREEN, SCREEN_DP, SCREEN_SAFE_TOP)
	_run.call_deferred()


## Hook: runs before the game scene loads (seed, preferences).
func _configure() -> void:
	set_seed(int(_env("SEED", "1")))


func _run() -> void:
	# The autoloads are up from the first frame on (not yet in _initialize).
	await process_frame
	prefs = root.get_node("Prefs")
	# A save of this test's own, empty at the start (SPENN_TEST_TAG keeps
	# runs of one test in parallel apart).
	prefs.path = SAVE % (label + _env("SPENN_TEST_TAG", ""))
	wipe_save()
	prefs.load_from_disk()
	prefs.intro_seen = true      # straight to the menu
	prefs.set_lang("en")
	_configure()
	change_scene_to_file("res://scenes/main.tscn")
	await wait_until(func() -> bool: return current_scene != null and "layout" in current_scene, 600)
	game = current_scene
	if game == null:
		check(false, "the game scene loads")
		finish()
		return
	await _test()
	if not _finished:
		finish()


## The test's steps (override).
func _test() -> void:
	pass


static func _env(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else fallback


func wipe_save() -> void:
	for ext: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(prefs.path + ext):
			DirAccess.remove_absolute(prefs.path + ext)


## Gives the game a screen of this shape (in the game's own pixels: 720
## wide for a phone), with `dp` game pixels per density-independent pixel
## and the safe-area insets a phone would report. Input given to `touch`
## and `drag` is in the same pixels.
func set_screen(size: Vector2i, dp := 2.0, safe_top := 0.0, safe_bottom := 0.0) -> void:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = size
	var layout := load("res://scripts/layout.gd") as Script
	layout.set("emulate", {"dp": dp, "safe_top": safe_top, "safe_bottom": safe_bottom})


## Every run from here rolls the same (0: by chance, like a player's).
func set_seed(s: int) -> void:
	(load("res://scripts/game.gd") as Script).set("test_seed", s)


# ---------------------------------------------------------------- waiting

func frames(n: int) -> void:
	for i in n:
		await process_frame


## Waits until `cond` holds; false if it did not within `max_frames`.
func wait_until(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func state(n: String) -> int:
	return int((game.get_script() as Script).get_script_constant_map()["State"][n])


func in_state(n: String) -> bool:
	return game.state == state(n)


func state_name() -> String:
	var names: Dictionary = (game.get_script() as Script).get_script_constant_map()["State"]
	for k: String in names:
		if int(names[k]) == game.state:
			return k
	return "?"


# ---------------------------------------------------------------- input

func touch(p: Vector2, pressed: bool, index := 0, canceled := false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = root.get_final_transform() * p
	e.pressed = pressed
	e.canceled = canceled
	Input.parse_input_event(e)


func drag(p: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = root.get_final_transform() * p
	Input.parse_input_event(e)


## Where a pull begins: on the pouch, as the demo shows it.
func grip() -> Vector2:
	return game.layout.pouch_rest()


## The finger offset that aims along `dir` (up the field) at `power` (0..1).
func pull(dir: Vector2, power := 0.9) -> Vector2:
	return -dir.normalized() * game.layout.drag_range * power


## True when a new pull would be taken (a ball is loaded, and the last
## one has left the pouch).
func can_aim() -> bool:
	if not game.slingshot.has_method("is_launching"):
		# v7.57 and before: the pouch had to come to rest first.
		return game.slingshot.has_ball() and game.slingshot.mode != 2
	return game.slingshot.has_ball() and not game.slingshot.is_launching()


## One whole shot: press, pull over a few frames, hold, let go.
func shoot(dir := Vector2.UP, power := 0.9, hold_frames := 6) -> void:
	await wait_until(can_aim, 240)
	var o := grip()
	var off := pull(dir, power)
	touch(o, true)
	await frames(1)
	for i in 4:
		drag(o + off * (i + 1) / 4.0)
		await frames(1)
	await frames(hold_frames)
	touch(o + off, false)
	await frames(1)


## From the menu into a run (the first shot starts it).
func start_run() -> bool:
	if not await wait_until(func() -> bool: return in_state("MAIN_MENU"), 900):
		check(false, "the menu is reached (state %s)" % state_name())
		return false
	await frames(20)
	await shoot()
	var ok := await wait_until(func() -> bool: return in_state("PLAYING"), 240)
	check(ok, "a pull from the menu starts a run (state %s)" % state_name())
	return ok


func alive() -> int:
	var n := 0
	for t in game.targets:
		if t.phase != 0:
			n += 1
	return n


func hittable() -> Array:
	var out := []
	for t in game.targets:
		if t.is_hittable():
			out.append(t)
	return out


func active_balls() -> Array:
	var out := []
	for b in game.balls:
		if b.active:
			out.append(b)
	return out


## Empties the field (enemies and balls) without ending the run.
func clear_field() -> void:
	for t in game.targets:
		if t.phase != 0:
			t.phase = 0
			t.visible = false
	for b in game.balls:
		b.stop()


# ---------------------------------------------------------------- results

func check(cond: bool, what: String) -> bool:
	checks += 1
	if not cond:
		fails += 1
		print("TEST %s FAIL: %s" % [label, what])
	return cond


func note(what: String) -> void:
	print("TEST %s: %s" % [label, what])


func finish() -> void:
	if _finished:
		return
	_finished = true
	Engine.time_scale = 1.0
	paused = false
	prefs.flush()
	wipe_save()
	print("TEST %s %s (%d checks, %d failed)" % [label, "OK" if fails == 0 else "FAILED", checks, fails])
	quit(0 if fails == 0 else 1)
