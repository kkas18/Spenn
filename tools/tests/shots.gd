extends "res://tools/tests/harness.gd"
## A tour of the game in pictures: menu, aiming, a calm and a busy field,
## a hit, pause, settings, the countdown and the results. Needs a renderer
## and a window of the test screen's shape:
##
##   xvfb-run -s "-screen 0 720x1560x24" godot --path . --resolution 720x1560 \
##       --fixed-fps 60 -s res://tools/tests/shots.gd
##
## OUT: the folder the PNGs go to (default user://shots). LANG=no for the
## Norwegian texts.

var out := "user://shots"


func _configure() -> void:
	super()
	out = _env("OUT", out)
	DirAccess.make_dir_recursive_absolute(out)
	if _env("LANG_UI", "en") == "no":
		prefs.set_lang("no")
	prefs.runs = 5                 # past the first-run hints


func _test() -> void:
	await wait_until(func() -> bool: return in_state("MAIN_MENU"), 900)
	await frames(150)
	_snap("01_menu")
	var o := grip()
	touch(o, true)
	await frames(1)
	drag(o + pull(Vector2(0.25, -1.0), 0.85))
	await frames(12)
	_snap("02_aim_from_menu")
	touch(o + pull(Vector2(0.25, -1.0), 0.85), false)
	if not await wait_until(func() -> bool: return in_state("PLAYING"), 240):
		check(false, "the run starts")
		return
	await frames(170)
	_snap("03_first_wave")
	# A busy late field of every kind.
	seed(12345)
	game.director.elapsed = 170.0
	game.lives = 99
	for k: int in [1, 2, 3, 4, 5, 7, 8, 0, 0, 1, 2, 7, 9, 10, 12, 13]:
		game._spawn_one(k)
	for i in 200:
		game.lives = 99
		await process_frame
	_snap("04_busy_field")
	await wait_until(can_aim, 240)
	touch(o, true)
	await frames(1)
	drag(o + pull(Vector2(-0.3, -1.0), 1.0))
	await frames(14)
	_snap("05_aim_full_pull")
	touch(o + pull(Vector2(-0.3, -1.0), 1.0), false)
	for i in 14:
		game.lives = 99
		await process_frame
	_snap("06_shot_in_flight")
	for i in 40:
		game.lives = 99
		await process_frame
	_snap("07_after_the_hit")
	game._pause()
	await frames(50)
	_snap("08_pause")
	game.hud.open_settings("pause")
	await frames(50)
	_snap("09_settings")
	game.hud._close_settings()
	await frames(40)
	game._resume()
	await frames(18)
	_snap("10_countdown")
	await wait_until(func() -> bool: return in_state("PLAYING"), 200)
	game.lives = 1
	await wait_until(func() -> bool: return not hittable().is_empty(), 300)
	game._breach(hittable()[0])
	await wait_until(func() -> bool: return in_state("GAME_OVER"), 400)
	await frames(110)
	_snap("11_results")
	finish()


func _snap(name: String) -> void:
	var path := "%s/%s.png" % [out, name]
	root.get_texture().get_image().save_png(path)
	note("saved " + path)
