extends "res://tools/tests/harness.gd"
## A tour of the game in pictures: menu, aiming, a calm and a busy field,
## a hit, pause, settings, the countdown, the results and a record. Needs
## a renderer and a window of the test screen's shape:
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
	# The balls (with enough points to have won some, and one on the way).
	prefs.skin_points = 420000
	game.hud._open_meta(game.hud._skins, game.hud._skins_box, game.hud._fill_skins)
	await frames(50)
	_snap("01a_balls")
	game.hud._close_meta(game.hud._skins)
	await frames(40)
	prefs.skin_points = 0
	# A record to play against, with its pace (the score as wave 2 began).
	prefs.record = 900
	prefs.pace = [150]
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
	# The moment of a kill, and what is left of it shortly after.
	var kills: int = game.run_kills
	var waited := 0
	while game.run_kills == kills and waited < 90:
		game.lives = 99
		await process_frame
		waited += 1
	for step: Array in [[3, "06a_kill"], [6, "06b_kill_after"], [12, "06c_kill_settling"]]:
		for i in int(step[0]):
			game.lives = 99
			await process_frame
		_snap(step[1])
	for i in maxi(1, 40 - waited - 21):
		game.lives = 99
		await process_frame
	_snap("07_after_the_hit")
	# A wave cleared (the celebration), a little way in and as it settles.
	game._last_kill = Vector2(game.layout.center_x - 60.0, game.layout.rail_y + game.layout.play_h * 0.4)
	game._clear_wave()
	for step: Array in [[16, "07a_wave_clear"], [50, "07b_wave_clear_later"], [45, "07c_wave_clear_settling"]]:
		for i in int(step[0]):
			game.lives = 99
			await process_frame
		_snap(step[1])
	# The next wave's card (with how the run stands against the record's).
	var w: int = game.director.wave
	var waited2 := 0
	while game.director.wave == w and waited2 < 400:
		game.lives = 99
		await process_frame
		waited2 += 1
	for i in 40:
		game.lives = 99
		await process_frame
	_snap("07d_next_wave")
	for i in 60:
		game.lives = 99
		await process_frame
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
	# Again, to a record: the stamp, and the paper thrown as it lands.
	game.hud.restart_pressed.emit()
	if not await wait_until(func() -> bool: return in_state("PLAYING"), 300):
		check(false, "a run starts again from the results")
		return
	await frames(60)
	game.score = maxi(prefs.record, 900) + 47350
	game.lives = 1
	await wait_until(func() -> bool: return not hittable().is_empty(), 300)
	game._breach(hittable()[0])
	await wait_until(func() -> bool: return in_state("GAME_OVER"), 400)
	await wait_until(func() -> bool: return game.hud._over._record_done, 400)
	for step: Array in [[8, "12_record_stamp"], [36, "12a_record_paper"], [70, "12b_record_settling"]]:
		await frames(int(step[0]))
		_snap(step[1])
	finish()


func _snap(name: String) -> void:
	var path := "%s/%s.png" % [out, name]
	root.get_texture().get_image().save_png(path)
	note("saved " + path)
