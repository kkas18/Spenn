extends "res://tools/tests/harness.gd"
## Short sessions (v8.10):
##  1. a run is saved as each wave begins (its wave and clock, the score,
##     the knots and the upgrades), and a knot lost is lost in the save too;
##  2. closed and opened again, the menu offers «Fortsett runden», and the
##     run picks up as that wave began, its enemies anew;
##  3. the run's end drops the save, and so does a new run; the daily
##     challenge neither saves nor drops it; a save that is damaged or of
##     another layout is not offered;
##  4. Hurtigstart: locked until wave 6 has been reached; on, a run begins
##     at wave 3 once two upgrades are picked, and the daily challenge
##     ignores it.


func _test() -> void:
	if not await start_run():
		return
	await frames(30)
	game.lives = 3
	game.hud.bar.lives = 3
	# --- 1
	check(prefs.saved_run().is_empty(), "a run in its first wave has nothing saved")
	await _win_wave()
	var s: Dictionary = prefs.saved_run()
	check(not s.is_empty() and int(s.get("wave", 0)) == 2, "the run is saved as wave 2 begins")
	check(not s.is_empty() and int(s.score) == game.score and int(s.lives) == game.lives and (s.perks as Dictionary).size() == 1,
		"... with its score, knots and upgrade")
	check(await wait_until(func() -> bool: return not hittable().is_empty(), 600), "wave 2's enemies come")
	game._breach(hittable()[0])
	check(int(prefs.run_save.get("lives", 0)) == 2, "a knot lost is lost in the saved run too")
	var score_then: int = int(s.score)
	var perks_then: Dictionary = (s.perks as Dictionary).duplicate()
	var elapsed_then: float = float(s.elapsed)
	var saved: Dictionary = prefs.run_save.duplicate(true)

	# --- 2: the app is closed and opened again
	if not await _reopen():
		return
	check(await wait_until(func() -> bool: return in_state("MAIN_MENU"), 900), "the menu comes up")
	await frames(60)
	check(game.hud._m_continue.visible, "the menu offers «Fortsett runden»")
	game.hud._m_continue.pressed.emit()
	check(await wait_until(func() -> bool: return in_state("PLAYING"), 240), "«Fortsett runden» picks the run up")
	check(game.director.wave == 2 and game.resumed_at == 2, "at wave 2")
	check(game.score == score_then and game.hud.bar.score == score_then, "with its score (%d)" % game.score)
	check(game.lives == 2, "with the knots it had left (%d)" % game.lives)
	check(game.perks == perks_then and game.hud.perk_order.size() == perks_then.size(), "with its upgrades")
	check(absf(game.director.elapsed - elapsed_then) < 1.0, "and the clock where the wave began")
	check(alive() == 0, "nothing hangs in while the wave's title shows")
	check(await wait_until(func() -> bool: return alive() > 0, 600), "then the wave's enemies come")

	# --- 3: the end drops the save; a new run drops it; the daily keeps it
	game.lives = 1
	await wait_until(func() -> bool: return not hittable().is_empty(), 600)
	game._breach(hittable()[0])
	check(await wait_until(func() -> bool: return in_state("GAME_OVER"), 600), "the last knot ends the run")
	check(prefs.run_save.is_empty(), "the run's end drops the save")
	prefs.run_save = saved.duplicate(true)
	game._to_menu()
	if not await start_run():
		return
	check(prefs.run_save.is_empty(), "a new run leaves the old save behind")
	prefs.run_save = saved.duplicate(true)
	game.lives = 1
	game._breach(await _one())
	await wait_until(func() -> bool: return in_state("GAME_OVER"), 600)
	check(prefs.run_save.is_empty(), "(and its end drops it)")
	prefs.run_save = saved.duplicate(true)
	game._to_menu()
	await wait_until(func() -> bool: return in_state("MAIN_MENU"), 600)
	game.hud.daily = true
	if not await start_run():
		return
	check(game.daily and prefs.run_save == saved, "the daily challenge does not drop the saved run")
	await _win_wave()
	check(prefs.run_save == saved, "... and saves nothing of its own")
	game.lives = 1
	game._breach(await _one())
	await wait_until(func() -> bool: return in_state("GAME_OVER"), 600)
	check(prefs.run_save == saved, "... not even as it ends")
	game.hud.daily = false
	prefs.run_save = {"v": 1, "wave": "two", "lives": 2, "score": 10, "elapsed": 5.0, "perks": {}}
	check(prefs.saved_run().is_empty(), "a damaged save is not offered")
	prefs.run_save = saved.duplicate(true)
	prefs.run_save["v"] = 99
	check(prefs.saved_run().is_empty(), "nor one of another layout")
	prefs.run_save = {}

	# --- 4: Hurtigstart
	prefs.stats = {"best_wave": 5, "runs": 3}
	game._to_menu()
	await wait_until(func() -> bool: return in_state("MAIN_MENU"), 600)
	await frames(40)
	check(not game.hud._m_quick.visible, "Hurtigstart is locked until wave 6 has been reached")
	prefs.stats = {"best_wave": 6, "runs": 4}
	game.hud.close_choice()
	game._to_menu()
	await wait_until(func() -> bool: return in_state("MAIN_MENU"), 600)
	await frames(40)
	check(game.hud._m_quick.visible, "... and there once it has")
	game.hud._m_quick.pressed.emit()
	await frames(20)
	check(prefs.quick_start, "the toggle turns it on")
	if not await start_run():
		return
	check(await wait_until(func() -> bool: return in_state("PLAYING") and game._quick_left == 0, 300), "two upgrades are picked first")
	var n := 0
	for id: String in game.perks:
		n += int(game.perks[id])
	check(n == 2 and game.quick, "a quick start has two upgrades (%d)" % n)
	check(game.director.wave == 3 and game.director.elapsed >= 65.0, "and begins at wave 3, as far in as wave 3 begins")
	check(await wait_until(func() -> bool: return alive() > 0, 600), "wave 3's enemies come")
	game.lives = 1
	game._breach(await _one())
	await wait_until(func() -> bool: return in_state("GAME_OVER"), 600)
	game._to_menu()
	await wait_until(func() -> bool: return in_state("MAIN_MENU"), 600)
	game.hud.daily = true
	if not await start_run():
		return
	check(game.director.wave == 1 and not game.quick and game.perks.is_empty(), "the daily challenge ignores Hurtigstart")
	finish()


## Wins the wave under way (the field emptied, the choice made by the
## harness) and waits for the next to begin.
func _win_wave() -> void:
	var w: int = game.director.wave
	clear_field()
	game._clear_wave()
	check(await wait_until(func() -> bool: return game.director.wave == w + 1, 600), "wave %d begins" % (w + 1))
	await frames(2)


## A hittable enemy, once there is one.
func _one() -> Node:
	await wait_until(func() -> bool: return not hittable().is_empty(), 600)
	var hs := hittable()
	return hs[0] if not hs.is_empty() else null


## The app closed and opened again: what was saved is read back as a
## fresh launch reads it, and the game starts anew.
func _reopen() -> bool:
	var old_id := current_scene.get_instance_id()
	Engine.time_scale = 1.0
	paused = false
	check(prefs.flush(), "the save is written")
	prefs.load_from_disk()
	prefs.intro_seen = true
	prefs.set_lang("en")
	change_scene_to_file("res://scenes/main.tscn")
	var ok := await wait_until(func() -> bool:
		return current_scene != null and current_scene.get_instance_id() != old_id and "layout" in current_scene, 600)
	check(ok, "the game loads again")
	if ok:
		game = current_scene
	return ok
