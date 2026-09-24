class_name Director
extends RefCounted
## Endless-run pacing. Pressure is a function of survival time ("intensity",
## ~1.0 per 45 s) nudged by how well the player shoots. Like a falling-block
## game's gravity curve it only ever rises; events (formation, rush, boss)
## punctuate it, each followed by a short breather.

enum Event { NONE, FORMATION, RUSH, BOSS }

const EVENT_EVERY := 38.0
const BREATHER := 4.0

var elapsed := 0.0
var accuracy := 0.55            # EMA of shots that hit something
var shots := 0
var hits := 0
var next_event := EVENT_EVERY
var event_count := 0
var breather := 0.0


func reset() -> void:
	elapsed = 0.0
	accuracy = 0.55
	shots = 0
	hits = 0
	next_event = EVENT_EVERY
	event_count = 0
	breather = 0.0


func tick(dt: float) -> void:
	elapsed += dt
	breather = maxf(0.0, breather - dt)


func record_shot(hit: bool) -> void:
	shots += 1
	hits += 1 if hit else 0
	accuracy = lerpf(accuracy, 1.0 if hit else 0.0, 0.15)


func intensity() -> float:
	return elapsed / 45.0


## Displayed phase (1, 2, 3…) and progress toward the next one.
func phase() -> int:
	return int(intensity()) + 1


func phase_progress() -> float:
	return fposmod(intensity(), 1.0)


## 0..1: how sharp enemy reactions are. Good shooting raises it.
func aggression() -> float:
	return clampf(0.1 + 0.17 * intensity() + (accuracy - 0.55) * 0.5, 0.0, 1.0)


## Descent speed (px/s before layout scale). Rises steeply at first, then
## keeps climbing more slowly; no plateau within any realistic run.
func descent(scale: float) -> float:
	var i := intensity()
	return minf(7.0 + 9.0 * pow(i, 0.85), 70.0) * lerpf(0.9, 1.15, aggression()) * scale


## Targets allowed on the field at once.
func alive_cap() -> int:
	return mini(6 + int(2.0 * intensity()), 22)


## The field never runs thin: below this many targets the spawner hurries,
## so a sharp player faces a full field instead of an empty one.
func alive_floor() -> int:
	if breather > 0.0:
		return 3
	return mini(5 + int(1.5 * intensity()), 14)


## Seconds between regular spawns.
func spawn_interval(boss_alive: bool) -> float:
	var t := maxf(0.3, 2.3 / (1.0 + 0.5 * intensity()))
	if breather > 0.0:
		t *= 2.2
	if boss_alive:
		t *= 1.8
	return t


func reload_time() -> float:
	return maxf(0.72, 1.05 - 0.06 * intensity())


## Returns an event when one is due; formation and rush alternate and every
## third is the boss.
func poll_event() -> Event:
	if elapsed < next_event:
		return Event.NONE
	event_count += 1
	next_event = elapsed + EVENT_EVERY * lerpf(1.0, 0.8, clampf(intensity() / 6.0, 0.0, 1.0))
	breather = BREATHER
	if event_count % 3 == 0:
		return Event.BOSS
	return Event.FORMATION if event_count % 3 == 1 else Event.RUSH


## Weighted pick; types unlock as intensity rises, nastier ones gain weight.
func pick_kind(rng: RandomNumberGenerator) -> Target.Kind:
	var i := intensity()
	var a := aggression()
	var table: Array = [[Target.Kind.RING, 3.0]]
	if i >= 0.4:
		table.append([Target.Kind.HEAVY, 1.0 + a])
	if i >= 0.8:
		table.append([Target.Kind.REEL, 0.8 + a])
	if i >= 1.0:
		table.append([Target.Kind.SPLIT, 1.1])
	if i >= 1.4:
		table.append([Target.Kind.ROD, 1.0 + a])
	if i >= 1.8:
		table.append([Target.Kind.DROP, 1.0 + a * 1.5])
	if i >= 2.4:
		table.append([Target.Kind.SHIELD, 0.8 + a * 1.5])
	if i >= 3.0:
		table.append([Target.Kind.SHADE, 0.8 + a * 1.2])
	var total := 0.0
	for e in table:
		total += e[1]
	var r := rng.randf() * total
	for e in table:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return Target.Kind.RING


## Formation kinds unlocked so far (a row of identical targets).
func formation_kind(rng: RandomNumberGenerator) -> Target.Kind:
	var pool: Array[Target.Kind] = [Target.Kind.RING]
	if intensity() >= 1.0:
		pool.append(Target.Kind.HEAVY)
	if intensity() >= 1.8:
		pool.append(Target.Kind.REEL)
	if intensity() >= 2.6:
		pool.append(Target.Kind.SHIELD)
	return pool[rng.randi() % pool.size()]
