extends "res://tools/tests/harness.gd"
## The upgrades and the choice after a wave (v8.9):
##  1. a cleared wave opens the choice: three different upgrades, at least
##     one of them one that changes how a run plays. The run holds while it
##     is open (no time passes, nothing is fired), a tap in its first moment
##     picks nothing, and the card picked is taken, goes to the tray, and
##     the next wave comes;
##  2. each upgrade that changes a run does what its card says: Splitt,
##     Rikosjett, Smell, Frost, Stor kule, Vegg-mester, Glasskanon, Fokus.
##
## The effects are tested on enemies hung by hand in an otherwise empty
## field, with the game stepped by hand (nothing else spawns meanwhile).

const SUB := 1.0 / 120.0
var kinds: Dictionary
var ball_script: Script


func _test() -> void:
	auto_pick = false
	kinds = (load("res://scripts/target_body.gd") as Script).get_script_constant_map()["Kind"]
	ball_script = load("res://scripts/ball.gd") as Script
	if not await start_run():
		return
	await _choice_flow()
	game.lives = 99
	game.set_process(false)
	_split()
	_ricochet()
	_blast()
	_freeze()
	_big_and_walls()
	_glass()
	game.set_process(true)
	await _focus()
	finish()


# ---------------------------------------------------------------- 1

func _choice_flow() -> void:
	await frames(30)
	check(in_state("PLAYING"), "the run is under way")
	clear_field()
	var wave: int = game.director.wave
	game._clear_wave()
	check(await wait_until(func() -> bool: return game.choosing(), 400), "a cleared wave opens the choice")
	var ids: Array = game.choice_ids()
	check(ids.size() == 3, "three upgrades are on offer (%d)" % ids.size())
	check(ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "all three are different")
	var shapers: Array = (load("res://scripts/perks.gd") as Script).get_script_constant_map()["SHAPERS"]
	check(ids.any(func(i: String) -> bool: return shapers.has(i)), "at least one changes how a run plays (%s)" % str(ids))
	check(game.hud._choice.visible and game.hud.modal_open(), "the choice panel is up")
	# A tap in its first moment picks nothing (it may be meant for the last shot).
	game.hud._choice_cards[0].pressed.emit()
	await frames(1)
	check(game.choosing() and game.perks.is_empty(), "a tap as the panel opens picks nothing")
	# The run holds.
	var t0: float = game.director.elapsed
	var wb: float = game.director.wave_break
	await frames(60)
	check(game.choosing(), "the choice waits for a pick")
	check(game.director.elapsed == t0 and game.director.wave_break == wb, "no time passes in the run while choosing")
	touch(grip(), true)
	await frames(2)
	drag(grip() + pull(Vector2.UP))
	await frames(2)
	check(not game.slingshot.is_aiming(), "the slingshot cannot be pulled while choosing")
	touch(grip() + pull(Vector2.UP), false)
	await frames(2)
	check(active_balls().is_empty(), "nothing is fired while choosing")
	# Pick the second card, the way a finger does.
	var want: String = ids[1]
	game.hud._choice_cards[1].pressed.emit()
	await frames(2)
	check(game.perk(want) == 1, "the card picked is taken (%s)" % want)
	check(in_state("PLAYING"), "play goes on after the pick")
	check(game.hud.perk_order.has(want), "its icon goes to the tray")
	check(await wait_until(func() -> bool: return not game.hud._choice.visible, 60), "the panel closes")
	check(await wait_until(func() -> bool: return game.director.wave == wave + 1, 600), "the next wave comes after the pick")
	game.perks.clear()
	game._apply_perks()


# ---------------------------------------------------------------- 2

## One enemy of `kind` hanging still at `x` (frozen in place, so it cannot
## slide away), its string at the same height as the others'.
func _hang_at(kind: int, x: float) -> Node:
	var t = game._spawn_one(kind, 0.3)
	if t == null:
		return null
	t.delay = 0.0
	t.anchor.x = x
	t.length = t.goal_length
	t.pos = Vector2(x, t.anchor.y + t.length)
	t.vel = Vector2.ZERO
	t.prev_pos = t.pos
	t.freeze(999.0)
	for i in 150:
		game._step(SUB)
	return t


func _fresh(perks: Dictionary) -> void:
	clear_field()
	game.fx.reset_time()
	game._shots.clear()
	game.perks = perks
	game._apply_perks()


## A ball fired up into `t` from just below (left or right of its middle
## by `side` px), as one shot of its own. Returns the ball.
func _shoot_at(t: Node, side := 0.0, speed := 1500.0) -> Node:
	game._shot_seq += 1
	var sid: int = game._shot_seq
	var b = game.balls[0]
	var from: Vector2 = t.pos + Vector2(side, t.radius + 70.0)
	var aim: Vector2 = (t.pos - from).normalized()
	b.fire(from, aim * speed * game.layout.scale, false, sid)
	b.grow = ball_script.get("grow_all")
	game._shots[sid] = {"balls": 1, "hit": false}
	return b


func _steps(n: int, until := Callable()) -> void:
	for i in n:
		game._step(SUB)
		if until.is_valid() and until.call():
			return


func _split() -> void:
	_fresh({"split": 1})
	var t = _hang_at(kinds.HEAVY, game.layout.center_x)
	var b = _shoot_at(t)
	var id: int = t.get_instance_id()
	_steps(40, func() -> bool: return not b.can_touch(id))
	var live := active_balls()
	check(live.size() == 2, "Splitt: the first hit throws off a piece (%d balls)" % live.size())
	var piece = live[1] if live.size() == 2 and live[0] == b else (live[0] if live.size() == 2 else null)
	check(piece != null and piece.fragment and piece.grow < b.grow and piece.shot_id == b.shot_id, "the piece is a smaller ball of the same shot")
	check(game._shots.has(b.shot_id) and game._shots[b.shot_id].balls == 2, "the shot waits for both before it counts as a hit or a miss")
	check(piece != null and not piece.can_touch(id), "the piece does not strike the enemy just hit")
	# Level 2: two pieces.
	_fresh({"split": 2})
	t = _hang_at(kinds.HEAVY, game.layout.center_x)
	b = _shoot_at(t)
	id = t.get_instance_id()
	_steps(40, func() -> bool: return not b.can_touch(id))
	check(active_balls().size() == 3, "level 2 splits it in three (%d balls)" % active_balls().size())
	clear_field()


func _ricochet() -> void:
	_fresh({"ricochet": 1})
	var cx: float = game.layout.center_x
	var a = _hang_at(kinds.RING, cx - 120.0)
	var c = _hang_at(kinds.HEAVY, cx + 120.0)
	var far = _hang_at(kinds.HEAVY, cx + 330.0)
	a.hp = 1
	var b = _shoot_at(a)
	var aid: int = a.get_instance_id()
	_steps(40, func() -> bool: return not b.can_touch(aid))
	check(not a.is_hittable(), "the first one goes down")
	var to_c: Vector2 = (c.pos - b.pos).normalized()
	check(b.ricochets == 1 and b.vel.normalized().dot(to_c) > 0.9, "Rikosjett: a ball that takes one down turns on to the nearest enemy")
	var cid: int = c.get_instance_id()
	_steps(90, func() -> bool: return not b.can_touch(cid))
	check(not b.can_touch(cid), "... and strikes it")
	check(b.ricochets == 1, "level 1 jumps once (%d)" % b.ricochets)
	check(far.hp == 2, "the one further off is left alone")
	# A hit that takes nothing down does not jump.
	_fresh({"ricochet": 1})
	a = _hang_at(kinds.HEAVY, cx - 120.0)
	c = _hang_at(kinds.HEAVY, cx + 120.0)
	b = _shoot_at(a)
	aid = a.get_instance_id()
	_steps(40, func() -> bool: return not b.can_touch(aid))
	check(a.is_hittable() and b.ricochets == 0, "a hit that takes nothing down does not jump")
	clear_field()


func _blast() -> void:
	_fresh({"blast": 1})
	var cx: float = game.layout.center_x
	var a = _hang_at(kinds.RING, cx)
	var near = _hang_at(kinds.HEAVY, cx + 95.0)
	var far = _hang_at(kinds.HEAVY, cx + 330.0)
	a.hp = 1
	var near_hp: int = near.hp
	var far_hp: int = far.hp
	var b = _shoot_at(a)
	var aid: int = a.get_instance_id()
	_steps(40, func() -> bool: return not b.can_touch(aid))
	check(not a.is_hittable(), "the first one goes down")
	check(near.hp < near_hp, "Smell: the kill bursts and strikes the one hanging close")
	check(far.hp == far_hp, "... but not one further off")
	clear_field()


func _freeze() -> void:
	_fresh({"freeze": 1})
	var cx: float = game.layout.center_x
	var a = _hang_at(kinds.HEAVY, cx)
	var near = _hang_at(kinds.HEAVY, cx + 85.0)
	var far = _hang_at(kinds.HEAVY, cx + 330.0)
	for t in [a, near, far]:
		t.frozen_t = 0.0
		t.frost_rest = 0.0
		t.hp = 9
	var b = _shoot_at(a)
	var aid: int = a.get_instance_id()
	_steps(40, func() -> bool: return not b.can_touch(aid))
	check(a.frozen_t > 1.0 and near.frozen_t > 1.0, "Frost: a hit freezes what it struck and those hanging close")
	check(far.frozen_t == 0.0, "... but not one further off")
	var near_len: float = near.length
	var far_len: float = far.length
	_steps(120)
	check(game.director.descent(game.layout.scale) > 0.0, "the enemies are sinking (the wave is under way)")
	check(near.length == near_len, "a frozen enemy does not sink")
	check(far.length > far_len, "one that is not frozen does")
	_steps(int(1.0 / SUB))
	check(near.frozen_t == 0.0, "the frost thaws after 1.5 s")
	near_len = near.length
	_steps(60)
	check(near.length > near_len, "thawed, it sinks again")
	# Just thawed, frost cannot take it again for a while (the lowest can
	# never be held for good), and then it can.
	near.freeze(1.5)
	check(near.frozen_t == 0.0, "frost cannot take one again just after it thawed")
	_steps(int(2.6 / SUB))
	near.freeze(1.5)
	check(near.frozen_t > 0.0, "... and can once the rest is over")
	clear_field()


func _big_and_walls() -> void:
	_fresh({"big": 1, "walls": 1})
	check(is_equal_approx(float(ball_script.get("bounce")), 1.0), "Vegg-mester: balls keep their speed off the walls")
	check(is_equal_approx(float(ball_script.get("grow_all")), 4.0), "Stor kule: balls are 4 px bigger")
	check(is_equal_approx(game._reload_time(), game.director.reload_time() * 1.1), "... and reload 10% slower")
	# A ball fired the ordinary way takes the run's size.
	game.ammo.clear()
	for i in 3:
		game.ammo.append(0)
	game._on_launched(game.layout.pouch_rest(), Vector2(0.0, -900.0), 0)
	var fired := active_balls()
	check(fired.size() == 1 and is_equal_approx(fired[0].grow, 4.0), "a ball fired takes the run's size")
	clear_field()
	# Off the left wall at full speed.
	var b = game.balls[0]
	var y: float = game.layout.rail_y + game.layout.play_h * 0.5
	b.fire(Vector2(120.0, y), Vector2(-1200.0, 0.0), false, 0)
	b.grow = 4.0
	_steps(60, func() -> bool: return b.banks > 0)
	check(b.banks == 1 and absf(b.vel.x) > 1200.0 * 0.98, "a ball comes off the wall as fast as it went in (%.0f px/s)" % absf(b.vel.x))
	check(b.pos.x >= 13.0 + 4.0 - 0.01, "the bigger ball bounces where its edge meets the wall")
	clear_field()
	# The bigger ball reaches further: a pass that would graze past a body
	# with an ordinary ball strikes it.
	var t = _hang_at(kinds.HEAVY, game.layout.center_x)
	var gap: float = 13.0 + t.radius + 2.0
	b.fire(t.pos + Vector2(gap, 60.0), Vector2(0.0, -1500.0), false, 0)
	b.grow = 4.0
	var id: int = t.get_instance_id()
	for i in 20:
		b.pos += b.vel * SUB
		game.contacts.collide(b)
		if not b.can_touch(id):
			break
	check(not b.can_touch(id), "a big ball strikes a body an ordinary one would just miss")
	clear_field()
	_fresh({})
	check(is_equal_approx(float(ball_script.get("bounce")), 0.85) and is_equal_approx(float(ball_script.get("grow_all")), 0.0), "a run without them has the ordinary walls and balls")


func _glass() -> void:
	_fresh({})
	game.lives = 3
	game.hud.bar.lives = 3
	var m0: int = game._mult()
	game._take_perk("glass")
	check(game.lives == 2, "Glasskanon costs a knot at once")
	check(game._mult() == m0 + 1, "... and adds one to the multiplier")
	check(game.hud.bar.max_lives == 2, "the bar shows the knot given up")
	game._add_score(game._next_life_at - game.score + 1)
	check(game.lives == 2, "a knot won back by points never goes past the cap")
	game.lives = 1
	game._take_perk("knot")
	check(game.lives == 2, "a knot back fills the cap")
	check(not game.choice_ids().has("glass"), "nothing is offered while no choice is open")
	game.lives = 99
	_fresh({})


func _focus() -> void:
	_fresh({"slowmo": 1})
	game.ammo.clear()
	for i in 3:
		game.ammo.append(0)
	check(in_state("PLAYING"), "playing again")
	touch(grip(), true)
	await frames(2)
	drag(grip() + pull(Vector2.UP, 0.8))
	await frames(40)
	check(game.slingshot.is_aiming(), "aiming")
	check(absf(Engine.time_scale - 0.8) < 0.02, "Fokus: time runs at 80%% while you aim (%.2f)" % Engine.time_scale)
	touch(grip() + pull(Vector2.UP, 0.8), false)
	await frames(40)
	check(absf(Engine.time_scale - 1.0) < 0.02, "... and at full speed again once the shot is away (%.2f)" % Engine.time_scale)
	_fresh({})
