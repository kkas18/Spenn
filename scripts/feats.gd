class_name Feats
extends RefCounted
## Achievements: fourteen feats kept for good (Prefs.feats, id -> the day
## it was won), each with an engraved glyph and a line saying how
## (Loc "feat.<id>": "NAME|how"). The game checks them as you play (see
## Game._feat) and shows a brass card the first time each is won.

const LIST := [
	["first", "burst"],     # break your first enemy
	["bank", "bank"],       # three bank shots in one run
	["chain", "chain"],     # a chain of five
	["cuts", "scissors"],   # cut three strings in one run
	["wave5", "flag"],      # reach wave 5
	["clean", "shield"],    # clear a wave without losing a knot
	["boss", "crown"],      # break the Spinneren
	["captain", "helmet"],  # take down a Kommandør
	["seer", "eye"],        # hit a Leser while it is tired
	["sneak", "hood"],      # hit a Luring while it creeps
	["overload", "bolt"],   # three overloads in one run
	["five", "clock"],      # last five minutes
	["sharp", "aim"],       # 90 % hits over 40 shots or more in a run
	["team", "arrows"],     # break a sinker while its partner baits
]


static func has(id: String) -> bool:
	return Prefs.feats.has(id)


## Wins `id`; true when it is new (the caller shows it).
static func unlock(id: String) -> bool:
	if Prefs.feats.has(id):
		return false
	Prefs.feats[id] = Meta.today()
	Prefs.save()
	return true


static func count() -> int:
	return Prefs.feats.size()


static func glyph(id: String) -> String:
	for f: Array in LIST:
		if f[0] == id:
			return f[1]
	return "burst"
