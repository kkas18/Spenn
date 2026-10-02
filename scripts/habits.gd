class_name Habits
extends RefCounted
## What the enemies know of you, kept between runs (saved in Prefs) and
## partly forgotten at the start of each one, so a changed style is noticed
## and you can outplay what they learned:
##  - hold: how long you usually hold the band before a release (and how
##    steady that is);
##  - side: the side you favour (-1 left .. 1 right);
##  - bank: how often your shots bank off a wall;
##  - punish: how often a dodge is answered with a hit on the dodger (you
##    shoot where they flee to);
##  - follow: how often a second ball follows quickly on the first;
##  - skill: a rating (0..1) of how well you play, from your accuracy and
##    pace, which sets how sharp the enemies are (see iq).
## Within a run it also keeps `strain`: how hard-pressed you are right now
## (lives just lost, enemies at the line). Strain dulls their wits for a
## while, so a bad moment does not snowball.

const DEFAULTS := {"skill": 0.45, "hold": 0.4, "hold_dev": 0.18, "side": 0.0, "bank": 0.1, "punish": 0.2, "follow": 0.1}
const FORGET := 0.25            # share of what was learned that fades each run
const PUNISH_WINDOW := 1.2      # s after a dodge in which a hit on the dodger punishes it
const FOLLOW_GAP := 0.45        # s: a ball this soon after the last is a follow-up
const STRAIN_FADE := 25.0       # s for strain to fall to a third

var skill := 0.45
var hold := 0.4
var hold_dev := 0.18
var side := 0.0
var bank := 0.1
var punish := 0.2
var follow := 0.1
var runs := 0
var strain := 0.0
var _skill0 := 0.45             # the rating this run started from
var _shots := 0
var _hits := 0
var _last_shot := -10.0
var _dodges: Array = []         # [target, its life, when]: dodges not yet judged


func restore(d: Dictionary) -> void:
	for k: String in DEFAULTS:
		var v := float(d.get(k, DEFAULTS[k]))
		# What was learned fades a little each run.
		set(k, lerpf(v, float(DEFAULTS[k]), FORGET) if d.has(k) else v)
	runs = int(d.get("runs", 0))
	_skill0 = skill


func store() -> Dictionary:
	var d := {"runs": runs}
	for k: String in DEFAULTS:
		d[k] = get(k)
	return d


func begin_run() -> void:
	_skill0 = skill
	_shots = 0
	_hits = 0
	_last_shot = -10.0
	_dodges.clear()
	strain = 0.0


## A ball released at `now` (s).
func note_shot(now: float) -> void:
	follow = lerpf(follow, 1.0 if now - _last_shot < FOLLOW_GAP else 0.0, 0.08)
	_last_shot = now


## A release judged: whether it hit, and whether it banked off a wall.
func note_result(hit: bool, banked: bool) -> void:
	_shots += 1
	_hits += 1 if hit else 0
	bank = lerpf(bank, 1.0 if banked else 0.0, 0.06)


func note_hold(s: float) -> void:
	hold_dev = lerpf(hold_dev, absf(s - hold), 0.15)
	hold = lerpf(hold, s, 0.15)


## The launch direction's x (-1 .. 1).
func note_side(dir_x: float) -> void:
	side = lerpf(side, clampf(dir_x * 2.0, -1.0, 1.0), 0.05)


## An enemy dodged at `now`: judged by whether it is hit soon after.
func note_dodge(t: Target, now: float) -> void:
	_dodges.append([t, t.life, now])


## An enemy was hit by a ball at `now`.
func note_hit(t: Target, now: float) -> void:
	for i in range(_dodges.size() - 1, -1, -1):
		var e: Array = _dodges[i]
		if e[0] == t and int(e[1]) == t.life and now - float(e[2]) <= PUNISH_WINDOW:
			punish = lerpf(punish, 1.0, 0.1)
			_dodges.remove_at(i)
			return


func note_life_lost() -> void:
	strain = minf(1.0, strain + 0.35)


## Once a frame: dodges that went unpunished are judged, strain fades and
## rises while enemies press at the line (`danger` 0..1, the worst).
func tick(dt: float, now: float, danger: float) -> void:
	for i in range(_dodges.size() - 1, -1, -1):
		var e: Array = _dodges[i]
		if now - float(e[2]) > PUNISH_WINDOW:
			punish = lerpf(punish, 0.0, 0.1)
			_dodges.remove_at(i)
	strain *= exp(-dt / STRAIN_FADE)
	if danger > 0.85:
		strain = minf(1.0, strain + 0.08 * dt)


## How well you are playing this run: your rating, moved toward what this
## run shows (hit rate and kills a minute) as the shots add up.
func live_skill(elapsed: float, kills: int) -> float:
	return lerpf(_skill0, _perf(elapsed, kills), minf(1.0, _shots / 40.0) * 0.6)


## How sharp the enemies are (0..1): your skill, a little more each wave,
## eased while you are hard-pressed.
func iq(elapsed: float, kills: int, wave: int) -> float:
	return clampf(0.2 + 0.6 * live_skill(elapsed, kills) + 0.04 * (wave - 1) - 0.5 * strain, 0.05, 1.0)


func end_run(elapsed: float, kills: int) -> void:
	if _shots >= 8:
		skill = lerpf(_skill0, _perf(elapsed, kills), 0.35)
	runs += 1


## This run's showing (0..1): the hit rate (from a neutral start, so a few
## shots say little) and the kills a minute.
func _perf(elapsed: float, kills: int) -> float:
	var rate := (_hits + 2.75) / (_shots + 5.0)
	var acc := clampf((rate - 0.45) / 0.4, 0.0, 1.0)
	var pace := clampf(kills / maxf(elapsed / 60.0, 0.5) / 60.0, 0.0, 1.0)
	return 0.6 * acc + 0.4 * pace
