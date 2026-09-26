class_name Director
extends RefCounted
## Endless-run pacing. Pressure is a function of survival time ("intensity",
## ~1.0 per 45 s) nudged by how well the player shoots. Like a falling-block
## game's gravity curve it only ever rises; events (formation, rush, boss)
## punctuate it, each followed by a short breather.

enum Event { NONE, FORMATION, RUSH, BOSS }
# Waves cut the endless pressure into rounds the player can finish, like a
# Space Invaders sheet: a wave spawns its quota, then nothing new comes
# until the field is clear (the last few hurry down). Clearing pays, a
# short break follows, and the next, bigger wave starts.
enum Wave { SPAWNING, CLEARING, BREAK }

const EVENT_EVERY := 38.0
const BREATHER := 4.0
const WAVE_BREAK := 2.0
const HURRY_AT := 2            # this many left of a spent wave: they hurry
# Habits: which side the player favours (-1 left .. 1 right, an average of
# where the shots go). Spawns lean the other way, and past HABIT_TELL the
# game says the enemies have noticed.
const HABIT_TELL := 0.45
# Tactics: what the enemies have learned, unlocked wave by wave and
# announced when it arrives.
enum Tactic { NAIVE, DODGE, FEINT, RHYTHM, TEAM }
const TACTIC_WAVE := [1, 2, 3, 4, 5]
# Rhythm: the player's hold time (EMA and spread) and where shots cross
# the field (columns, slowly forgotten).
const COLS := 6
const RHYTHM_MIN_SHOTS := 6
# Wave moods: from wave 3 each wave rolls a character (never the same
# twice running) that shapes who comes, how fast and in what mood.
enum WaveMood { NORMAL, CALM, CHAOS, GRUMPY, CUTE }
const MOOD_FROM := 2
# Each wave is won by kills (a quota), not by what spawned; near the end
# of it comes a finale: a champion, or on every third wave the boss.
const FINALE_AT := 0.8
const BOSS_EVERY := 3
# Pacing inside a wave: a build-up, a short peak (a flurry), then a breath.
enum Pulse { BUILD, PEAK, RELAX }

var elapsed := 0.0
var accuracy := 0.55            # EMA of shots that hit something
var shots := 0
var hits := 0
var next_event := EVENT_EVERY
var event_count := 0
var breather := 0.0
var wave := 1
var wave_state := Wave.SPAWNING
var wave_spawned := 0
var wave_killed := 0
var wave_break := 0.0
var side_bias := 0.0
var hold_avg := 0.0
var hold_dev := 0.0
var hold_n := 0
var cols := PackedFloat32Array()
var wave_mood := WaveMood.NORMAL
var finale_done := false
var extra_quota := 0             # enemies that got through this wave (x4)
# Each wave's style per kind: kind -> the variant or mood it leans to, so a
# kind acts one way in one wave and another way in the next.
var style := {}
var pulse := Pulse.BUILD
var pulse_t := 12.0
var pulse_len := 12.0
var _rng := RandomNumberGenerator.new()


func reset() -> void:
	elapsed = 0.0
	accuracy = 0.55
	shots = 0
	hits = 0
	next_event = EVENT_EVERY
	event_count = 0
	breather = 0.0
	wave = 1
	wave_state = Wave.SPAWNING
	wave_spawned = 0
	wave_killed = 0
	wave_break = 0.0
	finale_done = false
	extra_quota = 0
	style.clear()
	side_bias = 0.0
	hold_avg = 0.0
	hold_dev = 0.0
	hold_n = 0
	cols.resize(COLS)
	cols.fill(0.0)
	wave_mood = WaveMood.NORMAL
	_set_pulse(Pulse.BUILD)


func tick(dt: float) -> void:
	elapsed += dt
	breather = maxf(0.0, breather - dt)
	if wave_state == Wave.SPAWNING:
		pulse_t -= dt
		if pulse_t <= 0.0:
			_set_pulse([Pulse.PEAK, Pulse.RELAX, Pulse.BUILD][pulse])


func _set_pulse(p: Pulse) -> void:
	pulse = p
	match p:
		Pulse.BUILD:
			pulse_len = _rng.randf_range(10.0, 16.0)
		Pulse.PEAK:
			pulse_len = _rng.randf_range(4.0, 6.0)
		Pulse.RELAX:
			pulse_len = _rng.randf_range(4.0, 7.0)
	pulse_t = pulse_len


## How much faster (<1) or slower (>1) spawns come in this moment of the
## wave's pulse: tightening through the build, a flurry at the peak, then air.
func pulse_factor() -> float:
	match pulse:
		Pulse.BUILD:
			return lerpf(1.1, 0.75, 1.0 - pulse_t / pulse_len)
		Pulse.PEAK:
			return 0.45
	return 1.8


## Rolls this wave's mood (the first waves are plain).
func roll_mood() -> WaveMood:
	var prev := wave_mood
	if wave < MOOD_FROM:
		wave_mood = WaveMood.NORMAL
		return wave_mood
	var pool: Array = [WaveMood.NORMAL, WaveMood.NORMAL, WaveMood.CALM, WaveMood.CHAOS, WaveMood.GRUMPY, WaveMood.CUTE]
	while true:
		wave_mood = pool[_rng.randi() % pool.size()]
		if wave_mood != prev or wave_mood == WaveMood.NORMAL:
			break
	return wave_mood


## Chances of a grumpy and a cute enemy in this wave's mood.
func mood_odds() -> Vector2:
	match wave_mood:
		WaveMood.GRUMPY:
			return Vector2(0.7, 0.1)
		WaveMood.CUTE:
			return Vector2(0.1, 0.7)
		WaveMood.CALM:
			return Vector2(0.35, 0.35)
	return Vector2(0.25, 0.25)


func record_shot(hit: bool) -> void:
	shots += 1
	hits += 1 if hit else 0
	accuracy = lerpf(accuracy, 1.0 if hit else 0.0, 0.15)


## Aim direction of a shot (x of the unit launch direction).
func record_aim(dir_x: float) -> void:
	side_bias = lerpf(side_bias, clampf(dir_x * 2.0, -1.0, 1.0), 0.06)


## How long the band was held before a shot (s).
func record_hold(s: float) -> void:
	hold_n += 1
	if hold_n == 1:
		hold_avg = s
		hold_dev = s * 0.5
	else:
		hold_dev = lerpf(hold_dev, absf(s - hold_avg), 0.2)
		hold_avg = lerpf(hold_avg, s, 0.2)


## Where a shot crossed the field, 0..1 across.
func record_column(u: float) -> void:
	if cols.size() != COLS:
		cols.resize(COLS)
		cols.fill(0.0)
	for i in COLS:
		cols[i] *= 0.93
	cols[clampi(int(u * COLS), 0, COLS - 1)] += 1.0


## True once the player shoots to a steady beat the enemies can read.
func rhythm_known() -> bool:
	return hold_n >= RHYTHM_MIN_SHOTS and hold_dev < maxf(0.08, hold_avg * 0.3)


## 0..1: how much the player shoots at column position `u` (0..1 across).
func heat_at(u: float) -> float:
	if cols.size() != COLS:
		return 0.0
	var top := 0.0
	for c in cols:
		top = maxf(top, c)
	return cols[clampi(int(u * COLS), 0, COLS - 1)] / top if top > 0.5 else 0.0


## Centre (0..1 across) of the column the player shoots at least.
func cold_u() -> float:
	if cols.size() != COLS:
		return 0.5
	var best := 0
	for i in COLS:
		if cols[i] < cols[best]:
			best = i
	return (best + 0.5) / COLS


func tactic() -> Tactic:
	var t := 0
	for i in TACTIC_WAVE.size():
		if wave >= TACTIC_WAVE[i]:
			t = i
	return t as Tactic


## Kills needed to win the wave.
func wave_quota() -> int:
	return mini(30 + 10 * (wave - 1), 120) + extra_quota


func count_spawn(n := 1) -> void:
	wave_spawned += n


## Spawning stops once the kills so far plus what is still hanging would
## reach the quota; if some get through and the field empties short of it,
## reinforcements come.
func update_wave(alive: int) -> void:
	if wave_state == Wave.SPAWNING and wave_killed + alive >= wave_quota():
		wave_state = Wave.CLEARING
	elif wave_state == Wave.CLEARING and alive == 0 and wave_killed < wave_quota():
		wave_state = Wave.SPAWNING


## A new wave's style: a leaning per kind (variant or mood), chosen at random.
func roll_style() -> void:
	style.clear()
	if wave < 2:
		return
	style[Target.Kind.DROP] = ["var", [Target.Var.STD, Target.Var.BOB, Target.Var.TWIN, Target.Var.BIG][_rng.randi() % 4]]
	style[Target.Kind.RING] = ["var", [Target.Var.STD, Target.Var.HOPPER, Target.Var.BIG][_rng.randi() % 3]]
	for k in [Target.Kind.HEAVY, Target.Kind.SPLIT, Target.Kind.REEL, Target.Kind.SHIELD, Target.Kind.MEDIC, Target.Kind.MIRROR, Target.Kind.PIPP, Target.Kind.PAKKIS, Target.Kind.SHADE, Target.Kind.ROD]:
		style[k] = ["mood", [Target.Mood.NEUTRAL, Target.Mood.GRUMPY, Target.Mood.CUTE][_rng.randi() % 3]]


func wants_finale() -> bool:
	return not finale_done and wave_state == Wave.SPAWNING and wave_progress() >= FINALE_AT


func boss_wave() -> bool:
	return wave % BOSS_EVERY == 0


func count_kill() -> void:
	wave_killed += 1


func wave_progress() -> float:
	return clampf(float(wave_killed) / wave_quota(), 0.0, 1.0)


## The field is clear: pause, then the next wave.
func end_wave() -> void:
	wave_state = Wave.BREAK
	wave_break = WAVE_BREAK


func next_wave() -> void:
	wave += 1
	wave_state = Wave.SPAWNING
	wave_spawned = 0
	wave_killed = 0
	finale_done = false
	extra_quota = 0
	roll_style()


func intensity() -> float:
	# Time drives it, and each wave reached adds its own weight.
	return elapsed / 45.0 + (wave - 1) * 0.2


## Displayed phase (1, 2, 3…) and progress toward the next one.
func phase() -> int:
	return int(intensity()) + 1


func phase_progress() -> float:
	return fposmod(intensity(), 1.0)


## 0..1: how sharp enemy reactions are. Good shooting raises it.
func aggression() -> float:
	var calm := 0.15 if wave_mood == WaveMood.CALM else (-0.05 if wave_mood == WaveMood.CHAOS else 0.0)
	return clampf(0.1 + 0.17 * intensity() + (accuracy - 0.55) * 0.5 + calm, 0.0, 1.0)


## Descent speed (px/s before layout scale). Rises steeply at first, then
## keeps climbing more slowly; no plateau within any realistic run.
func descent(scale: float) -> float:
	var i := intensity()
	return minf(7.5 + 9.8 * pow(i, 0.85), 72.0) * lerpf(0.9, 1.15, aggression()) * scale


## Targets allowed on the field at once.
func alive_cap() -> int:
	var d := -2 if wave_mood == WaveMood.CALM else (2 if wave_mood == WaveMood.CHAOS else 0)
	return maxi(4, mini(6 + int(2.0 * intensity()), 22) + d)


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
	t *= pulse_factor()
	if wave_mood == WaveMood.CALM:
		t *= 1.25
	elif wave_mood == WaveMood.CHAOS:
		t *= 0.7
	return t


func reload_time() -> float:
	return maxf(0.6, 0.88 - 0.05 * intensity())


## Returns an event when one is due; formation and rush alternate and every
## third is the boss.
func poll_event() -> Event:
	if elapsed < next_event or wave_state != Wave.SPAWNING:
		return Event.NONE
	event_count += 1
	next_event = elapsed + EVENT_EVERY * lerpf(1.0, 0.8, clampf(intensity() / 6.0, 0.0, 1.0))
	breather = BREATHER
	# The boss is now a wave's finale; events alternate formation and rush.
	return Event.FORMATION if event_count % 2 == 1 else Event.RUSH


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
	if i >= 2.0:
		table.append([Target.Kind.MEDIC, 0.6 + a])
	if i >= 2.8:
		table.append([Target.Kind.MIRROR, 0.7 + a])
	if i >= 3.0:
		table.append([Target.Kind.SHADE, 0.8 + a * 1.2])
	if i >= 1.2:
		table.append([Target.Kind.PIPP, 0.9])
	if i >= 2.2:
		table.append([Target.Kind.PAKKIS, 0.55 + a * 0.5])
	# The wave's mood tips the mix.
	for e in table:
		match wave_mood:
			WaveMood.CHAOS:
				if e[0] == Target.Kind.PIPP or e[0] == Target.Kind.DROP:
					e[1] *= 3.0
			WaveMood.GRUMPY:
				if e[0] == Target.Kind.HEAVY or e[0] == Target.Kind.SHIELD:
					e[1] *= 1.8
			WaveMood.CUTE:
				if e[0] == Target.Kind.PIPP or e[0] == Target.Kind.PAKKIS:
					e[1] *= 2.5
	if wave_mood == WaveMood.CHAOS and i >= 0.6 and not table.any(func(e: Array) -> bool: return e[0] == Target.Kind.PIPP):
		table.append([Target.Kind.PIPP, 3.0])
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
