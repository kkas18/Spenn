extends Node
## Persisted preferences and progress (autoload `Prefs`): language, music
## and effects volume, haptics, reduced motion, aim guide, best score,
## which enemies and intros have been seen, and the meta game: missions,
## lifetime points and stats, the chosen ball skin and the daily record.
## Restored on every launch.

signal changed

const PATH := "user://spenn.cfg"
const LEVELS := 4              # 0 off, 1 low, 2 medium, 3 high

var lang := ""
var music_volume := 2
var sfx_volume := 2
var haptics := true
var reduced_motion := false
var aim_guide := true
var tilt := true               # tilt parallax and gloss follow the phone
var record := 0
var intro_seen := false
var seen := {}                 # enemy kinds already introduced
var runs := 0                  # runs started (the pause hint shows for the first few)
var total_points := 0          # lifetime points (+ mission rewards): unlocks skins
var skin := 0
var missions: Array = []       # active: [{"id": String, "level": int}]
var mission_level := 0         # missions completed so far: goals grow with it
var stats := {}                # lifetime counters (see record_run)
var daily_date := 0
var daily_best := 0

var _cfg := ConfigFile.new()


func _ready() -> void:
	if _cfg.load(PATH) == OK:
		lang = str(_cfg.get_value("settings", "lang", ""))
		# v3.x stored one "volume" for everything: carry it over once.
		var legacy := int(_cfg.get_value("settings", "volume", 2))
		music_volume = int(_cfg.get_value("settings", "music", legacy))
		sfx_volume = int(_cfg.get_value("settings", "sfx", legacy))
		haptics = bool(_cfg.get_value("settings", "haptics", true))
		reduced_motion = bool(_cfg.get_value("settings", "reduced_motion", false))
		aim_guide = bool(_cfg.get_value("settings", "aim_guide", true))
		tilt = bool(_cfg.get_value("settings", "tilt", true))
		record = int(_cfg.get_value("stats", "record", 0))
		intro_seen = bool(_cfg.get_value("stats", "intro_seen", false))
		seen = _cfg.get_value("stats", "seen", {})
		runs = int(_cfg.get_value("stats", "runs", 0))
		total_points = int(_cfg.get_value("meta", "total_points", 0))
		skin = int(_cfg.get_value("meta", "skin", 0))
		missions = _cfg.get_value("meta", "missions", [])
		mission_level = int(_cfg.get_value("meta", "mission_level", 0))
		stats = _cfg.get_value("meta", "stats", {})
		daily_date = int(_cfg.get_value("meta", "daily_date", 0))
		daily_best = int(_cfg.get_value("meta", "daily_best", 0))
	_fill_missions()
	if lang == "":
		lang = "no" if OS.get_locale_language() in ["nb", "nn", "no"] else "en"


func cycle_music() -> void:
	music_volume = (music_volume + 1) % LEVELS
	_commit()


func cycle_sfx() -> void:
	sfx_volume = (sfx_volume + 1) % LEVELS
	_commit()


func set_music(v: int) -> void:
	music_volume = clampi(v, 0, LEVELS - 1)
	_commit()


func set_sfx(v: int) -> void:
	sfx_volume = clampi(v, 0, LEVELS - 1)
	_commit()


func toggle_haptics() -> void:
	haptics = not haptics
	_commit()


func toggle_reduced_motion() -> void:
	reduced_motion = not reduced_motion
	_commit()


func toggle_tilt() -> void:
	tilt = not tilt
	_commit()


func toggle_aim_guide() -> void:
	aim_guide = not aim_guide
	_commit()


func set_lang(code: String) -> void:
	lang = code
	_commit()


func mark_intro_seen() -> void:
	if not intro_seen:
		intro_seen = true
		save()


## Returns true when `score` is a new record.
func submit_score(score: int) -> bool:
	if score <= record:
		return false
	record = score
	save()
	return true


## True the first time a kind shows up (persisted), so it gets an intro.
func first_sight(kind: int) -> bool:
	if seen.has(kind):
		return false
	seen[kind] = true
	save()
	return true


func _fill_missions() -> void:
	while missions.size() < Meta.ACTIVE:
		missions.append({"id": Meta.roll(missions), "level": mission_level})


## Mission `i` is done: pays its reward, the next one takes its slot (a
## level harder). Returns the reward.
func complete_mission(i: int) -> int:
	var pay := Meta.reward(int(missions[i].level))
	total_points += pay
	mission_level += 1
	missions.remove_at(i)
	missions.insert(i, {"id": Meta.roll(missions), "level": mission_level})
	save()
	return pay


## A run ended: lifetime counters and points.
func record_run(run: Dictionary) -> void:
	total_points += int(run.get("score", 0))
	for k: String in ["kills", "overloads", "bank", "chain", "cuts", "double", "break", "shots", "hits", "secs", "score"]:
		stats[k] = int(stats.get(k, 0)) + int(run.get(k, 0))
	stats["runs"] = int(stats.get("runs", 0)) + 1
	stats["best_wave"] = maxi(int(stats.get("best_wave", 0)), int(run.get("wave", 0)))
	save()


func set_skin(i: int) -> void:
	skin = i
	_commit()


## Today's best in the daily challenge (0 on a new day).
func daily_record() -> int:
	return daily_best if daily_date == Meta.today() else 0


func submit_daily(score: int) -> bool:
	if daily_date != Meta.today():
		daily_date = Meta.today()
		daily_best = 0
	if score <= daily_best:
		save()
		return false
	daily_best = score
	save()
	return true


func _commit() -> void:
	save()
	changed.emit()


func save() -> void:
	_cfg.set_value("settings", "lang", lang)
	_cfg.set_value("settings", "music", music_volume)
	_cfg.set_value("settings", "sfx", sfx_volume)
	_cfg.set_value("settings", "haptics", haptics)
	_cfg.set_value("settings", "reduced_motion", reduced_motion)
	_cfg.set_value("settings", "aim_guide", aim_guide)
	_cfg.set_value("settings", "tilt", tilt)
	_cfg.set_value("stats", "record", record)
	_cfg.set_value("stats", "intro_seen", intro_seen)
	_cfg.set_value("stats", "seen", seen)
	_cfg.set_value("stats", "runs", runs)
	_cfg.set_value("meta", "total_points", total_points)
	_cfg.set_value("meta", "skin", skin)
	_cfg.set_value("meta", "missions", missions)
	_cfg.set_value("meta", "mission_level", mission_level)
	_cfg.set_value("meta", "stats", stats)
	_cfg.set_value("meta", "daily_date", daily_date)
	_cfg.set_value("meta", "daily_best", daily_best)
	_cfg.save(PATH)
