class_name Perks
extends RefCounted
## Upgrades chosen between waves: after each cleared wave the player picks
## one of three. Each has a level cap; a run's picks are kept by the game
## (`perks`: id -> level). Pure data and rules; the game applies them.

# id -> the most times it can be taken
const MAX := {
	"heavy": 1,    # hits on armoured (2+ HP) enemies count double
	"edge": 1,     # one strike severs a rope, and cuts come easier
	"flow": 2,     # +2.5 s of flow, the meter fills 20% faster
	"rack": 2,     # +1 ball in the rack
	"reload": 2,   # balls reload 15% faster
	"sight": 1,    # the aim guide reaches twice as far
	"magnet": 2,   # balls curve gently toward the nearest enemy
	"charge": 2,   # overload charges 30% faster
	"knot": 99,    # get a lost knot back (only offered when one is lost)
}
const OFFER := 3


## Up to three different perks that can still be taken, in random order.
static func offer(owned: Dictionary, knot_lost: bool, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = []
	for id: String in MAX:
		if id == "knot" and not knot_lost:
			continue
		if int(owned.get(id, 0)) < int(MAX[id]):
			pool.append(id)
	var out: Array[String] = []
	while out.size() < OFFER and not pool.is_empty():
		var i := rng.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	return out
