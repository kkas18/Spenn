extends "res://tools/tests/harness.gd"
## A whole session, the way a player moves through it: menu, a run, aiming
## with one and two fingers, a touch the system takes away, pause (double
## tap, the back button, the app sent to the background, also in the middle
## of the countdown), resume, restart, losing, the results, again, and back
## to the menu. After every step the game must be in the state it claims,
## with time running, input free and nothing left behind.

var _nodes := 0


func _test() -> void:
	if not await start_run():
		return
	var l = game.layout
	check(game.lives == 3 and game.score == 0 and game.director.wave == 1, "a run starts with 3 lives, no score, wave 1")
	_nodes = get_node_count()

	# --- one shot: the ball leaves, the rack gives one up and reloads
	clear_field()
	await wait_until(func() -> bool: return game.ammo.size() == game._ammo_cap(), 400)
	var before: int = game.ammo.size()
	await shoot(Vector2.UP, 0.9)
	check(await wait_until(func() -> bool: return active_balls().size() == 1, 30), "a full pull fires one ball")
	check(game.ammo.size() == before - 1, "the shot takes one ball from the rack")
	check(await wait_until(func() -> bool: return game.ammo.size() == before, 240), "the rack reloads")
	check(await wait_until(func() -> bool: return active_balls().is_empty(), 400), "the ball leaves play on its own")

	# --- the pouch can be taken again the moment the ball has left it:
	# three shots in well under a second, straight off the rack
	await wait_until(func() -> bool: return game.ammo.size() == before and can_aim(), 400)
	var shots_before: int = game.director.shots + game._shots.size()
	var o3 := grip()
	for k in 3:
		touch(o3, true)
		await frames(1)
		drag(o3 + pull(Vector2.UP.rotated(0.15 * (k - 1)), 0.9))
		await frames(2)
		touch(o3 + pull(Vector2.UP, 0.9), false)
		await frames(9)   # the ball leaves about 50 ms after the finger
	check(active_balls().size() == 3, "three quick pulls fire three balls (%d in flight)" % active_balls().size())
	check(game.ammo.size() == before - 3, "... and take three from the rack")
	await wait_until(func() -> bool: return active_balls().is_empty(), 400)

	# --- a press that comes while the ball is still leaving is kept, and
	# takes the next ball as soon as the pouch is free
	await wait_until(func() -> bool: return game.ammo.size() == before and can_aim(), 400)
	touch(o3, true)
	await frames(1)
	drag(o3 + pull(Vector2.UP, 0.9))
	await frames(2)
	touch(o3 + pull(Vector2.UP, 0.9), false)
	await frames(1)
	check(game.slingshot.is_launching(), "the ball is on its way out of the pouch")
	touch(o3, true)                      # too early by a few frames
	drag(o3 + pull(Vector2.UP.rotated(0.3), 0.7))
	await frames(8)
	check(game.slingshot.is_aiming() and absf(game.slingshot.power - 0.7) < 0.02, "an early press takes the next ball when the pouch is free (power %.2f)" % game.slingshot.power)
	touch(o3 + pull(Vector2.UP.rotated(0.3), 0.7), false)
	check(await wait_until(func() -> bool: return active_balls().size() == 2, 30), "... and fires it")
	await wait_until(func() -> bool: return active_balls().is_empty(), 400)

	# --- full power is within reach: a finger that takes the pouch and
	# pulls straight down gets there before it meets the gesture strip
	var strip: float = l.size.y - maxf(l.safe_bottom, l.MIN_GESTURE_DP * l.dp)
	check(grip().y + l.drag_range <= strip, "a full pull from the pouch fits above the gesture strip (%.0f px of %.0f)" % [l.drag_range, strip - grip().y])
	await wait_until(func() -> bool: return game.ammo.size() == before and can_aim(), 400)
	touch(grip(), true)
	await frames(1)
	drag(Vector2(grip().x, strip - 1.0))
	await frames(2)
	check(game.slingshot.power >= 0.999, "... and reaches full power there (%.2f)" % game.slingshot.power)
	# --- sliding up first makes room: the pull counts from the highest
	# point the finger reached, not from where it first touched
	drag(Vector2(grip().x, grip().y - 90.0))
	await frames(2)
	check(game.slingshot.power < 0.01, "a finger above where it began pulls nothing (%.2f)" % game.slingshot.power)
	drag(Vector2(grip().x, grip().y - 90.0 + l.drag_range * 0.5))
	await frames(2)
	check(absf(game.slingshot.power - 0.5) < 0.02, "... and from up there half a pull is half power (%.2f)" % game.slingshot.power)
	touch(Vector2(grip().x, grip().y - 90.0 + l.drag_range * 0.5), false)
	check(await wait_until(func() -> bool: return active_balls().size() == 1, 30), "... and letting go fires")
	await wait_until(func() -> bool: return active_balls().is_empty(), 400)

	# --- a weak pull is a way to back out: nothing is fired
	await wait_until(func() -> bool: return game.ammo.size() == before and can_aim(), 400)
	await shoot(Vector2.UP, 0.1)
	await frames(30)
	check(active_balls().is_empty() and game.ammo.size() == before, "a pull under the minimum fires nothing (%d balls, rack %d of %d, power %.2f)" % [active_balls().size(), game.ammo.size(), before, game.slingshot.power])

	# --- a second finger does not disturb the aim
	var o := grip()
	await wait_until(can_aim, 240)
	touch(o, true, 0)
	await frames(2)
	drag(o + pull(Vector2.UP, 0.8), 0)
	await frames(2)
	touch(Vector2(l.center_x + 200.0, o.y), true, 1)
	drag(Vector2(l.center_x + 260.0, o.y + 90.0), 1)
	await frames(2)
	check(game.slingshot.is_aiming() and absf(game.slingshot.power - 0.8) < 0.02, "a second finger leaves the aim alone (aiming %s, power %.2f)" % [game.slingshot.is_aiming(), game.slingshot.power])
	touch(Vector2(l.center_x + 260.0, o.y + 90.0), false, 1)
	await frames(2)
	check(game.slingshot.is_aiming(), "lifting the second finger does not fire")
	touch(o + pull(Vector2.UP, 0.8), false, 0)
	check(await wait_until(func() -> bool: return active_balls().size() == 1, 30), "lifting the aiming finger fires")
	await wait_until(func() -> bool: return active_balls().is_empty(), 400)

	# --- a touch the system cancels (a gesture from the edge, a call) is
	# not a release: the aim is dropped, nothing is fired
	await wait_until(func() -> bool: return game.ammo.size() == before and can_aim(), 300)
	touch(o, true)
	await frames(2)
	drag(o + pull(Vector2.UP, 0.9))
	await frames(3)
	touch(o + pull(Vector2.UP, 0.9), false, 0, true)
	await frames(30)
	check(active_balls().is_empty() and game.ammo.size() == before, "a cancelled touch fires nothing")
	check(not game.slingshot.is_aiming() and game._touch == -1, "a cancelled touch frees the aim")
	await shoot(Vector2.UP, 0.9)
	check(await wait_until(func() -> bool: return active_balls().size() == 1, 30), "the next pull works after a cancelled touch")
	await wait_until(func() -> bool: return active_balls().is_empty(), 400)

	# --- pause by double tap on the open field; nothing moves while paused
	var field := Vector2(l.center_x, l.rail_y + l.play_h * 0.5)
	touch(field, true)
	await frames(1)
	touch(field, false)
	await frames(4)
	touch(field, true)
	await frames(1)
	touch(field, false)
	check(await wait_until(func() -> bool: return in_state("PAUSED"), 30), "a double tap on the field pauses")
	check(paused, "the tree is paused")
	var t0: float = game.director.elapsed
	touch(o, true)
	await frames(2)
	drag(o + pull(Vector2.UP, 0.9))
	await frames(2)
	touch(o + pull(Vector2.UP, 0.9), false)
	await frames(30)
	check(game.director.elapsed == t0 and active_balls().is_empty(), "no time passes and nothing fires while paused")

	# --- resume: a countdown, then play
	game._resume()
	check(in_state("RESUMING"), "resume starts the countdown")
	check(await wait_until(func() -> bool: return in_state("PLAYING"), 200), "the countdown ends in play")
	check(not paused and is_equal_approx(Engine.time_scale, 1.0), "time runs again after the countdown")
	check(not game.hud.locked, "the interface is free after the countdown")

	# --- the app goes to the background mid-aim: paused, and no shot
	# waiting when it comes back
	await wait_until(func() -> bool: return game.ammo.size() == before and can_aim(), 300)
	touch(o, true)
	await frames(2)
	drag(o + pull(Vector2.UP, 0.9))
	await frames(2)
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	check(in_state("PAUSED") and not game.slingshot.is_aiming(), "losing focus mid-aim pauses and drops the aim")
	touch(o + pull(Vector2.UP, 0.9), false)
	await frames(5)

	# --- ... and again in the middle of the countdown: back in the pause
	# menu, which must still answer
	game._resume()
	await frames(20)
	check(in_state("RESUMING"), "counting down")
	game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	check(in_state("PAUSED"), "losing focus mid-countdown returns to the pause menu")
	await frames(120)
	check(in_state("PAUSED") and paused, "the old countdown does not start the game behind the menu")
	check(not game.hud.locked, "the pause menu answers after an interrupted countdown")
	check(game.hud.overlay.count_n == 0, "no countdown digit is left on the pause menu")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(await wait_until(func() -> bool: return in_state("PLAYING"), 200), "the back button resumes from the pause menu")
	check(active_balls().is_empty(), "no shot was waiting behind the pause")

	# --- the back button pauses; restart from the pause menu
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(await wait_until(func() -> bool: return in_state("PAUSED"), 10), "the back button pauses a run")
	game.score = 777
	await frames(20)
	game.hud.restart_pressed.emit()
	check(await wait_until(func() -> bool: return in_state("PLAYING"), 200), "restart from pause leads back into play")
	check(game.score == 0 and game.lives == 3 and game.director.wave == 1 and not paused, "a restart is a fresh run")
	check(is_equal_approx(Engine.time_scale, 1.0), "time runs at full speed after a restart")

	# --- losing: the last life goes, results show, the run is recorded
	var runs_before := int(prefs.stats.get("runs", 0))
	await _lose()
	check(await wait_until(func() -> bool: return in_state("GAME_OVER"), 400), "the last breach ends in the results")
	check(not paused, "the results are not a pause (the field behind is held in slow motion)")
	check(int(prefs.stats.get("runs", 0)) == runs_before + 1, "the run is counted in the statistics")
	check(prefs.best_runs.size() >= 1, "the run is entered in the best runs")
	await wait_until(func() -> bool: return not game.hud.locked, 120)
	touch(o, true)
	await frames(2)
	drag(o + pull(Vector2.UP, 0.9))
	await frames(2)
	touch(o + pull(Vector2.UP, 0.9), false)
	await frames(20)
	check(active_balls().is_empty() and in_state("GAME_OVER"), "the slingshot is dead on the results screen")

	# --- again, lose again, then to the menu and into a third run
	game.hud.restart_pressed.emit()
	check(await wait_until(func() -> bool: return in_state("PLAYING"), 200), "\"try again\" starts a new run")
	check(game.score == 0 and game.lives == 3, "the new run starts clean")
	await _lose()
	await wait_until(func() -> bool: return in_state("GAME_OVER"), 400)
	await wait_until(func() -> bool: return not game.hud.locked, 120)
	game.hud.menu_pressed.emit()
	check(await wait_until(func() -> bool: return in_state("MAIN_MENU"), 120), "the results lead back to the menu")
	check(alive() == 0 and active_balls().is_empty(), "the field is empty on the menu")
	await wait_until(func() -> bool: return not game.hud.locked, 120)
	await frames(30)
	await shoot()
	check(await wait_until(func() -> bool: return in_state("PLAYING"), 240), "a third run starts from the menu")
	await frames(120)
	var grown := get_node_count() - _nodes
	check(grown <= 8, "three runs leave no nodes behind (grew by %d)" % grown)

	# --- the settings added in v8.3 take hold at once and are stored
	var normal: float = game.layout.drag_range
	prefs.set_pull(0)
	await frames(2)
	check(game.layout.drag_range < normal * 0.85, "a short pull length shortens the pull at once (%.0f of %.0f px)" % [game.layout.drag_range, normal])
	prefs.set_pull(2)
	await frames(2)
	check(game.layout.drag_range > normal * 1.15, "a long pull length lengthens it (%.0f px)" % game.layout.drag_range)
	prefs.set_pull(1)
	await frames(2)
	check(is_equal_approx(game.layout.drag_range, normal), "normal is what it was")
	prefs.toggle_camera()
	game.fx.shake(3.0)
	game.fx.punch(0.03)
	check(game.fx._shake_t <= 0.0 and game.fx._punch <= 0.0, "with camera movement off, a shake and a punch are not made")
	prefs.toggle_camera()
	game.fx.shake(3.0)
	check(game.fx._shake_t > 0.0, "... and with it on, they are")

	# --- the progress written so far is on disk, whole
	prefs.set_pull(2)
	prefs.flush()
	var f := ConfigFile.new()
	check(f.load(prefs.path) == OK and f.has_section("seal"), "the save on disk is complete")
	check(int(f.get_value("settings", "pull", -1)) == 2 and f.get_value("settings", "camera", false) == true, "the pull length and camera settings are in it")
	prefs.set_pull(1)
	finish()


## Lets one through with a single life left.
func _lose() -> void:
	game.lives = 1
	await wait_until(func() -> bool: return not hittable().is_empty(), 600)
	var h := hittable()
	if check(not h.is_empty(), "there is an enemy to let through"):
		game._breach(h[0])
	await frames(2)
