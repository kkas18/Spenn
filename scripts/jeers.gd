class_name Jeers
extends RefCounted
## Who laughs at you, and when. An enemy that gets one over on you may
## laugh at you out loud (Sfx.laugh), its face and body laughing along
## (Target.start_laugh):
##  - DODGE: it moved out of your line and the shot went by (judged once a
##    ball released after the move has had PASS s to fly past it, and it
##    was not hit);
##  - BLUFF: it stood its ground, and still you missed it (the same way);
##  - NEAR: a ball brushed past it (Target.startle, then its taunt);
##  - TAUNT: smug near the line, it taunts you anyway;
##  - BREACH: one of them got through: the boldest near it always laughs;
##  - LAST: the breach that ends the run: always laughed at, by anyone.
## Only some of them laugh: the bold, the grumpy, the proud and the big
## (Target.jeer), never the timid. One laugh at a time, GAP s apart, rarer
## the more they have laughed lately, never over an overload or outside
## play, so each one lands and none of them becomes noise. A breach is
## rare and big enough to break the quiet.

enum Why { NEAR, DODGE, BLUFF, TAUNT, BREACH, LAST }
const CHANCE := [0.3, 0.55, 0.7, 0.18]   # NEAR, DODGE, BLUFF, TAUNT (a breach always)
const PASS := 0.8               # s after the release: the ball has gone by
const STALE := 4.0              # s: a dodge no shot followed is forgotten
const GAP := Vector2(4.0, 7.0)  # s of quiet after a laugh
const RECENT := 30.0            # s: each laugh this recent makes the next rarer
const NEAR_BREACH := 280.0      # px (at scale 1): who sees a breach

var g: Game
var laughs := 0                 # this run (the bot's report)
var by_why := PackedInt32Array([0, 0, 0, 0, 0, 0])
var _watch: Array = []          # [target, its life, since, why]: moves not yet judged
var _next := 0.0                # game time before which no one laughs
var _recent: Array[float] = []


func _init(game: Game) -> void:
	g = game


func reset() -> void:
	laughs = 0
	by_why = PackedInt32Array([0, 0, 0, 0, 0, 0])
	_watch.clear()
	_recent.clear()
	_next = 0.0


## `t` dodged (or bluffed, `why`) the shot you are lining up or have fired.
func watch(t: Target, why: int) -> void:
	_watch.append([t, t.life, g._time, why])


## A ball hit `t`: whatever it tried, it did not get away with it.
func hit(t: Target) -> void:
	for i in range(_watch.size() - 1, -1, -1):
		if _watch[i][0] == t:
			_watch.remove_at(i)


## Once a frame: a move that got away with it may earn a laugh.
func tick() -> void:
	var now: float = g._time
	var fired: float = g._last_shot_t
	for i in range(_watch.size() - 1, -1, -1):
		var e: Array = _watch[i]
		var t: Target = e[0]
		var since: float = e[2]
		if t.life != int(e[1]) or now - since > STALE:
			_watch.remove_at(i)
		elif fired >= since - 0.6 and now - fired >= PASS:
			# A ball was loosed at it (or just before it moved) and has gone by.
			_watch.remove_at(i)
			offer(t, int(e[3]))


## A breach: the boldest one hanging near it laughs (and when it was the
## last knot, someone always does).
func breach(at: Vector2, last: bool) -> void:
	var best: Target = null
	var reach: float = NEAR_BREACH * g.layout.scale
	for t in g.targets:
		if not t.is_hittable() or t.laughing() or t.jeer <= 0.0:
			continue
		var near := t.pos.distance_to(at) < reach
		if not near and not last:
			continue
		if best == null or _bolder(t, best, at):
			best = t
	if best != null:
		offer(best, Why.LAST if last else Why.BREACH)


func _bolder(a: Target, b: Target, at: Vector2) -> bool:
	if absf(a.jeer - b.jeer) > 0.05:
		return a.jeer > b.jeer
	return a.pos.distance_squared_to(at) < b.pos.distance_squared_to(at)


## `t` may laugh at you for `why`: true if it does.
func offer(t: Target, why: int) -> bool:
	if not is_instance_valid(t) or not t.is_hittable() or t.laughing() or t.posed:
		return false
	if why == Why.BREACH and Sfx.laughing():
		return false
	if why < Why.BREACH:
		if t.jeer <= 0.0 or g.state != Game.State.PLAYING or g.overload_t > 0.0:
			return false
		var now: float = g._time
		if now < _next or Sfx.laughing():
			return false
		while not _recent.is_empty() and now - _recent[0] > RECENT:
			_recent.pop_front()
		var p: float = CHANCE[why] * t.jeer / (1.0 + 0.6 * _recent.size())
		if g._rng.randf() >= p:
			return false
	var v := t.laugh_voice()
	var r := Sfx.laugh(v[0], v[1], t)
	if r.is_empty():
		return false
	t.start_laugh(r.curve, v[1])
	_next = g._time + float(r.secs) + g._rng.randf_range(GAP.x, GAP.y)
	_recent.append(g._time)
	laughs += 1
	by_why[why] += 1
	return true


## The run's laughs by cause, for the bot's report.
func report() -> String:
	return "laughs=%d (near %d dodge %d bluff %d taunt %d breach %d last %d)" % ([laughs] + Array(by_why))
