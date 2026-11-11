extends "res://tools/tests/harness.gd"
## The same seed is the same run. What happens in a run follows from its
## seed and from what the player does, and from nothing else: not from
## which missions the player holds, not from what an earlier game left
## behind. Two games are played here on one seed with the same shots; in
## the first, missions are completed in the middle of the run (and their
## successors drawn there), in the second none is within reach. Until v8.0
## a successor was drawn from the run's own dice, so from the first
## completed mission on, the run rolled differently for every player (the
## daily challenge too), and no two test runs on one seed were alike.
##
##   godot --headless --path . --fixed-fps 60 -s res://tools/tests/repeat.gd

const SECONDS := 100.0          # of play in each game (the easiest missions fall within it)
const CADENCE := 45             # frames from one shot to the next


func _configure() -> void:
	set_seed(11)


func _test() -> void:
	var first := await _play([["survive", 0], ["kills", 0], ["score", 0]])
	if first.is_empty():
		return
	var done: int = game._missions_done.size()
	check(done >= 1, "missions were completed in the middle of the first run (%d)" % done)
	if not await fresh_game():
		return
	var second := await _play([["chain", 30], ["cut", 30], ["break", 30]])
	if second.is_empty():
		return
	check(game._missions_done.is_empty(), "no mission was within reach in the second run (%d completed)" % game._missions_done.size())
	var n := mini(first.size(), second.size())
	var at := -1
	for i in n:
		if first[i] != second[i]:
			at = i
			break
	check(at == -1 and first.size() == second.size(), "one seed and the same shots are one run, whatever missions are held (%d and %d steps; they part at step %d)" % [first.size(), second.size(), at])
	if at >= 0:
		note("first:  %s" % str(first[at]).left(300))
		note("second: %s" % str(second[at]).left(300))
	note("two games of %d s on one seed: %d steps alike, %d missions completed in the first" % [int(SECONDS), n, done])
	finish()


## One game on this test's seed with a fixed way of shooting; returns the
## state of the field at every step.
func _play(missions: Array) -> Array:
	prefs.missions = []
	for m: Array in missions:
		prefs.missions.append({"id": m[0], "level": m[1]})
	if not await start_run():
		return []
	game.lives = 99
	var states: Array = []
	var frame := 0
	var last_shot := -1000
	while game.director.elapsed < SECONDS:
		await process_frame
		frame += 1
		states.append(_state())
		if not in_state("PLAYING") or frame - last_shot < CADENCE or not can_aim():
			continue
		var t := _lowest()
		if t == null:
			continue
		last_shot = frame
		await shoot(aim_at(t.pos), 0.9, 8)
		frame += 14
	return states


func _lowest() -> Node:
	var best: Node = null
	for t in game.targets:
		if t.is_solid() and (best == null or t.pos.y > best.pos.y):
			best = t
	return best


func _state() -> String:
	var s := "%.4f %d %d %d" % [game.director.elapsed, game.score, game.director.wave, game._rng.state]
	for t in game.targets:
		if t.phase != 0:
			s += " %d:%.3f,%.3f" % [t.kind, t.pos.x, t.pos.y]
	for b in game.balls:
		if b.active:
			s += " b%.3f,%.3f" % [b.pos.x, b.pos.y]
	return s
