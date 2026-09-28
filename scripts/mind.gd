class_name Mind
extends RefCounted
## How the enemies decide what to do when you aim at them. Each one that
## has watched your aim for its reaction time asks (Target.mind_ask), and
## the Mind weighs what it could do right now:
##  - AWAY: slide along the rail out of the line (the usual answer);
##  - ACROSS: cut back across the line to the other side (the answer to a
##    player who shoots where they flee);
##  - CLIMB: winch up its string (little room to the side);
##  - HOLD: stand its ground, a bluff (a poor shot, a line that only grazes,
##    or a player who leads every dodge);
##  - HIDE: slide in behind a sturdier neighbour lower down;
##  - WAIT: coil and wait for the ball to leave the pouch, then spring aside
##    at the last moment (the answer to a long hold).
## The scores come from the situation (how close the line passes, room on
## the rail, a ball in flight, cover, where the others are going), from its
## personality (bold, wary, sly, social; see Target.personality) and from
## what the enemies know of you (Habits). The choice is a draw weighted by
## exp(score / temperature). Against a new or hard-pressed player the
## temperature is high and they fumble. Against a sharp one it is low and
## they pick among the good answers, so they are smart without being
## predictable (see Habits.iq).
## Every move is shown first: the eye darts to where it is going before it
## goes, a climb tenses, a bluff flinches, a wait trembles, coiled.
## The squad shares a board of where each is going, so they do not all flee
## to the same spot. Once the team has learned it (Director.Tactic.TEAM) it
## also makes plays: one baits, dancing in your line of fire, while a
## partner across the field sinks fast (arrows under it show it).

enum Option { AWAY, ACROSS, CLIMB, HOLD, HIDE, WAIT }
const NAMES := ["away", "across", "climb", "hold", "hide", "wait"]
const TEMP_HI := 0.3            # fumbling
const TEMP_LO := 0.07           # sharp, still a draw among close answers
const TELL := 0.14              # s the eye shows the way first (sharper ones less)
const TELL_MIN := 0.07
const WAIT_MAX := 1.6           # s a coiled one waits for the release
const RESERVE := 1.2            # s a destination stays claimed on the board
const PLAY_EVERY := Vector2(9.0, 14.0)
const BAIT_TIME := 2.6
const SINK_TIME := 2.4

var g: Game
var iq := 0.3
var counts := PackedInt32Array([0, 0, 0, 0, 0, 0])
var plays := 0
var _iq_sum := 0.0              # for the report: the run's average wits
var _iq_n := 0
var _board: Array = []          # [x, y, r, until, owner]: claimed spots
var _play_t := 10.0


func _init(game: Game) -> void:
	g = game


func reset() -> void:
	counts = PackedInt32Array([0, 0, 0, 0, 0, 0])
	plays = 0
	_iq_sum = 0.0
	_iq_n = 0
	_board.clear()
	_play_t = randf_range(PLAY_EVERY.x, PLAY_EVERY.y)


## Once a frame, after the game has read your aim and the balls in flight.
func tick(dt: float) -> void:
	if g.state != Game.State.PLAYING and g.state != Game.State.STARTING:
		return
	var now := g._time
	iq = g.habits.iq(g.director.elapsed, g.run_kills, g.director.wave)
	_iq_sum += iq
	_iq_n += 1
	for i in range(_board.size() - 1, -1, -1):
		if float(_board[i][3]) < now:
			_board.remove_at(i)
	for t: Target in g.targets:
		if not t.is_hittable():
			t.mind_ask = false
			continue
		if t.wait_t > 0.0 and t.incoming:
			_spring(t)
		elif t.mind_ask:
			t.mind_ask = false
			_decide(t)
	_plays(dt)


## Weighs the answers open to `t` and carries out the one drawn.
func _decide(t: Target) -> void:
	var sc: float = g.layout.scale
	var h := g.habits
	var prof: Array = Target.EVADE[t.kind]
	var a := t.aggression
	var released := t.incoming and not t.aimed
	var thr := 1.0 if t.incoming else t.threat_lvl
	var dir := t.dodge_dir
	# How far it goes: a timid one further, a bold one less far.
	var reach: float = float(prof[1]) * lerpf(0.75, 1.2, a) * sc * (0.6 if released else 1.0) * (0.8 if Target.tactic == 0 else 1.0) * [1.0, 1.25, 0.8, 1.0][t.temper]
	var speed: float = float(prof[2]) * lerpf(1.0, 1.4, a) * sc
	if t.charm == Target.Charm.SPRING:
		reach *= 1.7
		speed *= 1.3
		t.charm_flash = 1.0
	if t.mind_beat:
		# Timed to your usual release: a sharper, longer move.
		reach *= 1.25
		speed *= 1.25
	var room_a := (t.slide_hi - t.anchor.x) if dir > 0.0 else (t.anchor.x - t.slide_lo)
	var room_b := (t.anchor.x - t.slide_lo) if dir > 0.0 else (t.slide_hi - t.anchor.x)
	var dest_a := t.anchor.x + dir * minf(reach, room_a)
	var dest_b := t.anchor.x - dir * minf(reach * 1.3, room_b)
	var hide_x := t.anchor.x + (t.cover_x - t.pos.x)
	var u := PackedFloat32Array([-INF, -INF, -INF, -INF, -INF, -INF])
	if room_a > 28.0 * sc:
		u[Option.AWAY] = 0.55 + 0.35 * thr + 0.25 * t.p_wary - 0.45 * h.punish - 0.3 * _crowd(dest_a, t)
	if Target.tactic >= Director.Tactic.FEINT and not t.incoming and room_b > reach * 0.8:
		u[Option.ACROSS] = 0.1 + 0.55 * h.punish + 0.3 * t.p_sly + (0.25 if room_a < reach * 0.6 else 0.0) - 0.3 * _crowd(dest_b, t)
	if t.length > 90.0 * sc and t.kind != Target.Kind.ROD:
		u[Option.CLIMB] = 0.15 + 0.3 * t.p_wary + (0.35 if room_a <= 28.0 * sc else 0.0) + 0.2 * h.punish
	if not released:
		u[Option.HOLD] = 0.05 + 0.45 * t.p_bold + 0.4 * (1.0 - g.director.accuracy) + 0.25 * (1.0 - thr) + 0.3 * h.punish - (0.35 if Target.tactic == 0 else 0.0)
	if t.has_cover:
		u[Option.HIDE] = 0.35 + 0.45 * t.p_social + 0.2 * thr - 0.3 * _crowd(hide_x, t)
	if t.aimed and not t.incoming and Target.tactic >= Director.Tactic.DODGE:
		u[Option.WAIT] = 0.05 + 0.35 * t.p_sly + 0.3 * clampf((h.hold - 0.25) / 0.5, 0.0, 1.0) - 0.4 * h.follow
	var pick := _draw(u, _temperature(t))
	if pick < 0:
		return
	counts[pick] += 1
	var now := g._time
	if released and pick != Option.HOLD:
		# Out of the way of a ball already flying: a faint afterimage stays
		# where it was, so a miss shows why.
		g.fx.afterimage(t.pos, t.radius, t.color(), -dir if pick == Option.ACROSS else dir)
	match pick:
		Option.AWAY:
			t.mind_slide(dest_a, speed, _tell())
			_claim(dest_a, t)
			h.note_dodge(t, now)
		Option.ACROSS:
			t.mind_slide(dest_b, speed * 1.15, _tell() * 1.2)
			_claim(dest_b, t)
			h.note_dodge(t, now)
		Option.CLIMB:
			t.mind_climb(maxf(float(prof[3]), 45.0) * sc * lerpf(0.8, 1.3, a))
			h.note_dodge(t, now)
		Option.HOLD:
			t.mind_hold()
		Option.HIDE:
			t.mind_slide(hide_x, speed * 0.8, _tell())
			_claim(hide_x, t)
		Option.WAIT:
			t.mind_wait(WAIT_MAX)
	# Whatever it chose, if the shot goes by it may laugh at you (a coiled
	# one is judged when it springs).
	if pick != Option.WAIT:
		g.jeers.watch(t, Jeers.Why.BLUFF if pick == Option.HOLD else Jeers.Why.DODGE)
	# A light, hopping kind also bobs up its string as it goes.
	var hop: float = prof[3]
	if (pick == Option.AWAY or pick == Option.ACROSS) and hop > 0.0 and a > 0.35 and t.length > 90.0 * sc:
		t.mind_climb(hop * sc * lerpf(0.8, 1.3, a))
	t.mind_done(pick == Option.HOLD or pick == Option.WAIT)


## A coiled one sees the ball leave the pouch: it springs aside now, the
## way with more room (the coil was its tell).
func _spring(t: Target) -> void:
	var sc: float = g.layout.scale
	var prof: Array = Target.EVADE[t.kind]
	var need := t.radius + Ball.RADIUS + 14.0 * sc
	var dir := t.dodge_dir
	var room := (t.slide_hi - t.anchor.x) if dir > 0.0 else (t.anchor.x - t.slide_lo)
	if room < need * 0.7:
		dir = -dir
	var x := t.anchor.x + dir * need * 1.2
	t.wait_t = 0.0
	g.fx.afterimage(t.pos, t.radius, t.color(), dir)
	t.mind_slide(x, float(prof[2]) * 1.5 * sc, 0.03)
	# Hanging on a string, the body would lag the hook: it springs too.
	t.vel.x += dir * 260.0 * sc
	_claim(x, t)
	g.habits.note_dodge(t, g._time)
	g.jeers.watch(t, Jeers.Why.DODGE)
	t.mind_done(false)


func _temperature(t: Target) -> float:
	var k := lerpf(TEMP_HI, TEMP_LO, iq)
	if t.temper == Target.Temper.ERRATIC:
		k *= 1.6
	if Target.tactic == 0:
		k *= 1.3
	return k


func _tell() -> float:
	return maxf(TELL_MIN, TELL * lerpf(1.0, 0.55, iq))


## Draws an option with weight exp(score / temperature); -1 if none is open.
static func _draw(u: PackedFloat32Array, temp: float) -> int:
	var top := -INF
	for v in u:
		top = maxf(top, v)
	if top == -INF:
		return -1
	var w := PackedFloat32Array()
	var sum := 0.0
	for v in u:
		var e := exp((v - top) / temp) if v > -INF else 0.0
		w.append(e)
		sum += e
	var r := randf() * sum
	for i in w.size():
		r -= w[i]
		if r <= 0.0 and w[i] > 0.0:
			return i
	return u.find(top)


## How crowded the rail is at `x` at `t`'s height, by the spots others
## have just claimed (0 free .. 1 taken).
func _crowd(x: float, t: Target) -> float:
	var c := 0.0
	for e: Array in _board:
		if e[4] == t or absf(float(e[1]) - t.pos.y) > float(e[2]) + t.radius + 20.0:
			continue
		c += clampf(1.0 - absf(x - float(e[0])) / (float(e[2]) + t.radius + 10.0), 0.0, 1.0)
	return minf(c, 1.0)


func _claim(x: float, t: Target) -> void:
	_board.append([x, t.pos.y, t.radius, g._time + RESERVE, t])


## The team's plays: a bait and a sinker (once the team has learned it).
func _plays(dt: float) -> void:
	if Target.tactic < Director.Tactic.TEAM or g.director.wave_state != Director.Wave.SPAWNING or g.overload_t > 0.0 or g.director.breather > 0.0:
		return
	_play_t -= dt
	if _play_t > 0.0:
		return
	_play_t = randf_range(PLAY_EVERY.x, PLAY_EVERY.y) * lerpf(1.3, 0.8, iq)
	var bait: Target = null
	var best := 0.35
	for t: Target in g.targets:
		if not _free_for_play(t) or t.danger > 0.5:
			continue
		var s := t.p_bold + 0.3 * (1.0 - t.danger)
		if s > best:
			best = s
			bait = t
	if bait == null:
		return
	var sink: Target = null
	var far := 150.0 * g.layout.scale
	for t: Target in g.targets:
		if t == bait or not _free_for_play(t) or t.danger > 0.45:
			continue
		var d := absf(t.pos.x - bait.pos.x)
		if d > far:
			far = d
			sink = t
	if sink == null:
		return
	bait.mind_bait(BAIT_TIME)
	sink.mind_rush(SINK_TIME)
	plays += 1


func _free_for_play(t: Target) -> bool:
	return t.is_hittable() and t.kind != Target.Kind.BOSS and t.leader == null and not t.is_leader and t.guard_of == null and t.bait_t <= 0.0 and t.rush_t <= 0.0 and t.playdead <= 0.0 and not t.golden


## One line on how the enemies chose (for tests and balancing): the share
## of each answer and how predictable the mix is (entropy, bits: 0 always
## the same, 2.58 all six alike).
func report() -> String:
	var n := 0
	for c in counts:
		n += c
	if n == 0:
		return "mind n=0"
	var s := "mind n=%d iq=%.2f kills=%d plays=%d" % [n, _iq_sum / maxi(_iq_n, 1), g.run_kills, plays]
	var ent := 0.0
	for i in counts.size():
		var p := float(counts[i]) / n
		s += " %s=%d%%" % [NAMES[i], roundi(p * 100.0)]
		if p > 0.0:
			ent -= p * log(p) / log(2.0)
	return s + " entropy=%.2f" % ent
