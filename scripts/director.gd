class_name Director
extends RefCounted
## Adaptive difficulty and wave planning. Reads how well the player shoots
## (an exponential moving average of shots that hit) and turns that, with the
## level, into aggression, descent speed, wave sizes and the enemy mix.

var accuracy := 0.55           # EMA of shots that hit something
var shots := 0
var hits := 0


func reset() -> void:
	accuracy = 0.55
	shots = 0
	hits = 0


func record_shot(hit: bool) -> void:
	shots += 1
	hits += 1 if hit else 0
	accuracy = lerpf(accuracy, 1.0 if hit else 0.0, 0.15)


## 0..1: how sharp enemy reactions are. Good shooting raises it, a slump
## eases it, so pressure tracks skill instead of only the level number.
func aggression(level: int) -> float:
	return clampf(0.08 + (level - 1) * 0.07 + (accuracy - 0.55) * 0.7, 0.0, 1.0)


func descent(level: int, scale: float) -> float:
	var base := minf(6.0 + 1.35 * (level - 1), 24.0)
	return base * lerpf(0.85, 1.25, aggression(level)) * scale


static func is_boss_level(level: int) -> bool:
	return level % 5 == 0


func wave_count(level: int) -> int:
	if is_boss_level(level):
		return 2
	return 1 if level <= 2 else (2 if level <= 6 else 3)


func wave_size(level: int, wave: int) -> int:
	if is_boss_level(level):
		return 5 + wave * 2
	return clampi(5 + level / 2 + wave, 5, 11)


## Weighted pick; nastier types gain weight as aggression rises.
func pick_kind(level: int, rng: RandomNumberGenerator) -> Target.Kind:
	var a := aggression(level)
	var table: Array = [[Target.Kind.RING, 3.0]]
	if level >= 2:
		table.append([Target.Kind.HEAVY, 1.2 + a])
	if level >= 3:
		table.append([Target.Kind.SPLIT, 1.2])
	if level >= 4:
		table.append([Target.Kind.ROD, 1.0 + a])
	if level >= 5:
		table.append([Target.Kind.DROP, 1.0 + a * 1.5])
	if level >= 3:
		table.append([Target.Kind.REEL, 0.7 + a])
	if level >= 6:
		table.append([Target.Kind.SHIELD, 0.8 + a * 1.5])
	if level >= 7:
		table.append([Target.Kind.SHADE, 0.7 + a * 1.2])
	var total := 0.0
	for e in table:
		total += e[1]
	var r := rng.randf() * total
	for e in table:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return Target.Kind.RING
