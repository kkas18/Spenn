extends "res://tools/tests/harness.gd"
## Soak test: a crowded late-game field (a dozen extra enemies of every
## kind, time pushed on, lives topped up) under steady fire for 20 s of
## game time. Fails if the node count grows (something is created every
## frame and never freed) or an effect pool outgrows its size.

const RUN_FRAMES := 1200


func _test() -> void:
	if not await start_run():
		return
	await frames(60)
	game.director.elapsed = 170.0
	game.lives = 99
	for k: int in [1, 2, 3, 4, 5, 7, 8, 0, 0, 1, 2, 7]:
		game._spawn_one(k)
	await frames(60)
	var nodes_at_start := get_node_count()
	var nodes_max := nodes_at_start
	var o := grip()
	for f in RUN_FRAMES:
		game.lives = 99
		nodes_max = maxi(nodes_max, get_node_count())
		# Keep shooting up the field so hits, bursts and popups happen.
		if f % 20 == 0:
			touch(o, true)
		elif f % 20 == 8:
			drag(o + pull(Vector2.UP.rotated(randf_range(-0.4, 0.4)), 0.8))
		elif f % 20 == 12:
			touch(o + pull(Vector2.UP, 0.8), false)
		await process_frame
	var grew := nodes_max - nodes_at_start
	note("frames=%d alive=%d nodes=%d..%d" % [RUN_FRAMES, alive(), nodes_at_start, nodes_max])
	check(grew <= 8, "the node count does not grow (by %d)" % grew)
	check(game.fx._popups.size() == game.fx.POPUP_POOL and game.fx._frags.size() == game.fx.FRAG_POOL, "the effect pools keep their size")
	check(game.director.shots > 20, "the field was under fire (%d shots)" % game.director.shots)
	finish()
