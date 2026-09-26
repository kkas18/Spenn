class_name Meta
extends RefCounted
## The long game around the runs: missions (three at a time, each a goal
## for a single run, growing harder as you complete them), cosmetic ball
## skins bought with lifetime points, and the daily challenge seed. Pure
## data and rules; progress is stored by `Prefs`.

# Mission templates: id -> [string key, run stat, base goal, goal step per level]
const MISSIONS := {
	"kills": ["mission.kills", "kills", 25, 10],
	"score": ["mission.score", "score", 3000, 1500],
	"wave": ["mission.wave", "wave", 3, 1],
	"bank": ["mission.bank", "bank", 3, 1],
	"overload": ["mission.overload", "overloads", 2, 1],
	"chain": ["mission.chain", "chain", 1, 1],
	"cut": ["mission.cut", "cuts", 1, 1],
	"double": ["mission.double", "double", 3, 2],
	"survive": ["mission.survive", "secs", 90, 30],
	"break": ["mission.break", "break", 1, 1],
}
const ACTIVE := 3
const REWARD_BASE := 1000       # lifetime points for a completed mission
const REWARD_STEP := 500        # ... more per mission level

# Ball skins: [string key, lifetime points to unlock, dark, base, light]
const SKINS := [
	["skin.gold", 0, Color("8F6B2C"), Color("D4A94F"), Color("E6C47C")],
	["skin.copper", 15000, Color("7A3E22"), Color("C8703F"), Color("E9A57A")],
	["skin.chrome", 40000, Color("4A525E"), Color("A9B4C2"), Color("EEF2F7")],
	["skin.jade", 80000, Color("1E5E48"), Color("3FA37E"), Color("9BE0C4")],
	["skin.obsidian", 150000, Color("0C0D11"), Color("2C2F3A"), Color("8A8FA6")],
	["skin.ember", 300000, Color("7A1E12"), Color("E0512F"), Color("FFC06B")],
]


## Goal of a mission at a given level.
static func goal(id: String, level: int) -> int:
	var m: Array = MISSIONS[id]
	return int(m[2]) + int(m[3]) * level


## Its line of text, e.g. "Knus 35 fiender i én runde".
static func describe(id: String, level: int) -> String:
	var n := goal(id, level)
	var key: String = MISSIONS[id][0]
	if n == 1 and Loc.STRINGS["en"].has(key + ".one"):
		return Loc.t(key + ".one")
	return Loc.t(key) % (Hud._group(n) if id == "score" else str(n))


## How far a run got toward it.
static func progress(id: String, run: Dictionary) -> int:
	return int(run.get(MISSIONS[id][1], 0))


## A mission not already active, picked at random.
static func roll(active: Array) -> String:
	var ids := MISSIONS.keys().filter(func(k: String) -> bool:
		for m: Dictionary in active:
			if m.id == k:
				return false
		return true)
	return ids[randi() % ids.size()]


static func reward(level: int) -> int:
	return REWARD_BASE + REWARD_STEP * level


static func skin_colors(i: int) -> Array:
	var s: Array = SKINS[clampi(i, 0, SKINS.size() - 1)]
	return [s[2], s[3], s[4]]


static func skin_unlocked(i: int, total: int) -> bool:
	return total >= int(SKINS[i][1])


## Today as yyyymmdd (local time): the daily challenge's seed and key.
static func today() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)
