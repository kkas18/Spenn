extends "res://tools/tests/harness.gd"
## A bot player, for balance checks and as a whole-run test. It plays the
## way a person can: it grips the pouch, pulls as far as its skill and the
## screen allow, allows for the ball's drop, leads a moving enemy, and aims
## with a little error. One RESULT line is printed when the run ends (or
## after 12 minutes of play).
##
##   godot --headless --path . --fixed-fps 60 -s res://tools/tests/bot.gd
##
## Environment: SEED (1), SKILL (weak / medium / strong; default medium), or
## the single knobs: NOISE (aim error, rad), POWER (share of a full pull),
## HOLD_MIN / HOLD_MAX (frames the pull is held), CAD (frames between
## shots), LEAD (s the aim leads a moving enemy by).

# A shot takes a person a moment: find the next enemy, press, pull, aim,
# let go. "cadence" is the least time from one press to the next (frames
# at 60 Hz): 1.1 s for a beginner, 0.75 s for a practised player, 0.5 s
# for a very quick one.
const SKILLS := {
	#           noise  power  hold     cadence  lead
	"weak":   [0.085, 0.75, [18, 40], 66, 0.10],
	"medium": [0.050, 0.90, [10, 26], 45, 0.18],
	"strong": [0.025, 1.00, [6, 14], 30, 0.22],
}

var noise := 0.05
var power := 0.9
var hold := [8, 24]
var cadence := 30
var lead := 0.18
var rng := RandomNumberGenerator.new()
var frame := 0
var skill := "medium"
var trace := 0                  # TRACE=n: a line of the run's state every n frames (to compare two runs)


func _configure() -> void:
	super()
	skill = _env("SKILL", "medium")
	var s: Array = SKILLS.get(skill, SKILLS.medium)
	noise = float(_env("NOISE", str(s[0])))
	power = float(_env("POWER", str(s[1])))
	hold = [int(_env("HOLD_MIN", str(s[2][0]))), int(_env("HOLD_MAX", str(s[2][1])))]
	cadence = int(_env("CAD", str(s[3])))
	lead = float(_env("LEAD", str(s[4])))
	rng.seed = int(_env("SEED", "1"))
	trace = int(_env("TRACE", "0"))
	# A fresh player to the enemies every run, so runs compare.
	prefs.habits = {}


func _test() -> void:
	if not await start_run():
		return
	var last_shot := -1000
	while not in_state("GAME_OVER"):
		await process_frame
		frame += 1
		if trace > 0 and frame % trace == 0:
			_trace()
		_trace_detail()
		if frame > 60 * 60 * 12:
			_result(" (capped)")
			return
		if not in_state("PLAYING") or frame - last_shot < cadence or not can_aim():
			continue
		var t := _pick()
		if t == null:
			continue
		last_shot = frame
		await _fire_at(t)
	_result("")


## The most pressing enemy: the lowest solid one.
func _pick() -> Node:
	var best: Node = null
	var best_y := -INF
	for t in game.targets:
		if t.is_solid() and t.pos.y > best_y:
			best_y = t.pos.y
			best = t
	return best


## The launch direction that meets `at` at this pull's speed, allowing for
## the ball's drop on the way.
func _dir_to(at: Vector2) -> Vector2:
	var l = game.layout
	var from: Vector2 = l.pouch_rest()
	var speed: float = lerpf(620.0, 2250.0, pow(_reach(), 1.15)) * l.scale
	var aim := at
	for i in 3:
		var t: float = (aim - from).length() / speed
		aim = at - Vector2(0.0, 0.5 * 320.0 * t * t)
	var d := (aim - from).normalized()
	if d.y > -0.2:
		d = Vector2(signf(d.x) * 0.98, -0.2).normalized()
	return d


## The pull this bot gets on this screen: what it wants, as far as a
## finger that began on the pouch can go before it meets the gesture strip
## at the bottom (a straight pull; a slanting one has a little more room).
func _reach() -> float:
	var l = game.layout
	var bottom: float = l.size.y - maxf(l.safe_bottom, l.MIN_GESTURE_DP * l.dp)
	return minf(power, (bottom - grip().y) / l.drag_range)


## Press on the pouch, pull, track the enemy while holding (as a person
## does), and let go.
func _fire_at(t: Node) -> void:
	var o := grip()
	var err := rng.randf_range(-noise, noise)
	var frames_held := rng.randi_range(hold[0], hold[1])
	touch(o, true)
	var off := Vector2.ZERO
	for i in frames_held:
		if is_instance_valid(t) and t.is_hittable():
			off = pull(_dir_to(t.pos + t.vel * lead).rotated(err), _reach())
		# The pull builds over the first frames; it is not there at once.
		drag(o + off * minf(1.0, (i + 1) / 5.0))
		await process_frame
		frame += 1
		if trace > 0 and frame % trace == 0:
			_trace()
		_trace_detail()
		if not in_state("PLAYING"):
			break
	touch(o + off, false)


## TRACE_FROM / TRACE_TO: every body and ball, each frame in that span,
## and the run ends there (to find where two runs part).
func _trace_detail() -> void:
	var from := int(_env("TRACE_FROM", "0"))
	var to := int(_env("TRACE_TO", "0"))
	if to <= 0 or frame < from:
		return
	# A fingerprint of the shared dice: the next roll, which is then made
	# the seed again (so the run still rolls the same every time, and a
	# roll that one run makes and another does not shows from that frame).
	var dice := randi()
	seed(dice)
	var line := "DETAIL f=%d ts=%.2f dice=%d" % [frame, Engine.time_scale, dice]
	for t in game.targets:
		if t.phase != 0:
			line += " | T%d k%d %.3f,%.3f v%.2f,%.2f a%.1f L%.1f" % [t.get_index(), t.kind, t.pos.x, t.pos.y, t.vel.x, t.vel.y, t.anchor.x, t.length]
	for b in game.balls:
		if b.active:
			line += " | B %.3f,%.3f v%.2f,%.2f" % [b.pos.x, b.pos.y, b.vel.x, b.vel.y]
	print(line)
	if frame >= to:
		finish()


func _trace() -> void:
	var sum := Vector2.ZERO
	var n := 0
	for t in game.targets:
		if t.phase != 0:
			sum += t.pos
			n += 1
	print("TRACE f=%d t=%.3f score=%d alive=%d sum=%.3f,%.3f shots=%d rnd=%d" % [frame, game.director.elapsed, game.score, n, sum.x, sum.y, game.director.shots, game._rng.state])


func _result(suffix: String) -> void:
	var d = game.director
	print("RESULT seed=%d skill=%s time=%.0fs%s score=%d acc=%d%% over=%d wave=%d cuts=%d flows=%d shots=%d reach=%.2f %s" % [rng.seed, skill, d.elapsed, suffix, game.score, int(100.0 * d.hits / maxf(1, d.shots)), game.overloads, d.wave, game.cuts, game.flows, d.shots, _reach(), game.mind.report()])
	check(d.elapsed > 20.0, "the run lasted (%.0f s)" % d.elapsed)
	check(d.shots > 10, "the bot got its shots off (%d)" % d.shots)
	finish()
