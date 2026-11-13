extends Node
## Persisted preferences and progress (autoload `Prefs`): language, music
## and effects volume, haptics, reduced motion, aim guide, best score,
## which enemies and intros have been seen, and the meta game: missions,
## lifetime points and stats, the chosen ball skin and the daily record.
## Restored on every launch.

signal changed

const PATH := "user://spenn.cfg"
const LEVELS := 4              # 0 off, 1 low, 2 medium, 3 high
const FORMAT := 2              # the stored layout (2: sealed, with a backup beside it)
const SAVE_DELAY_MS := 800     # changes made close together are written once

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
var hints := {}                # in-field hints already explained in full
var runs := 0                  # runs started (the pause hint shows for the first few)
var total_points := 0          # lifetime points (+ mission rewards), for the stats
var skin_points := 0           # the same, but never reset: unlocks skins
var fresh := {}                # bests set by the last run ("best", "wave"), until seen
var skin := 0
var missions: Array = []       # active: [{"id": String, "level": int}]
var mission_level := 0         # missions completed so far: goals grow with it
var stats := {}                # lifetime counters (see record_run)
var daily_date := 0
var daily_best := 0
var habits := {}               # what the enemies know of the player (see Habits)
var feats := {}                # achievements won: id -> the day (see Feats)
var best_runs: Array = []      # the ten best runs: {"score", "wave", "secs", "acc", "day", "daily"}
var pace: Array = []           # the record run's score as each wave began (wave 2 first): the pace to beat

## Where the progress is kept. Tests point it at a file of their own
## (the SPENN_SAVE environment variable), so they never touch a player's.
var path := PATH
## How the last load went when it was not the plain case: "backup" (the
## file was damaged or missing and the previous one was used), "temp" (a
## save was interrupted between writing and swapping), "partial" (damaged,
## with nothing better beside it), or "" (read as written, or a first run).
var recovered := ""

var _cfg := ConfigFile.new()
var _main_ok := false          # the file at `path` is whole (so it may become the backup)
var _dirty := false
var _flush_at := 0             # ticks (ms) at which the pending changes are written
var _generation := 0           # counts the writes (stored in the seal)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	var over := OS.get_environment("SPENN_SAVE")
	if over != "":
		path = over
	load_from_disk()


## Reads the stored progress (see `path`), falling back to the backup when
## the file is missing, cut short or unreadable. Every value is checked on
## the way in: a damaged entry becomes its default instead of a crash.
func load_from_disk() -> void:
	_cfg = _pick_file()
	lang = str(_cfg.get_value("settings", "lang", ""))
	if not lang in ["", "no", "en"]:
		lang = ""
	# v3.x stored one "volume" for everything: carry it over once.
	var legacy := _int("settings", "volume", 2)
	music_volume = clampi(_int("settings", "music", legacy), 0, LEVELS - 1)
	sfx_volume = clampi(_int("settings", "sfx", legacy), 0, LEVELS - 1)
	haptics = _bool("settings", "haptics", true)
	reduced_motion = _bool("settings", "reduced_motion", false)
	aim_guide = _bool("settings", "aim_guide", true)
	tilt = _bool("settings", "tilt", true)
	record = maxi(0, _int("stats", "record", 0))
	intro_seen = _bool("stats", "intro_seen", false)
	seen = _dict("stats", "seen")
	hints = _dict("stats", "hints")
	runs = maxi(0, _int("stats", "runs", 0))
	total_points = maxi(0, _int("meta", "total_points", 0))
	skin_points = maxi(0, _int("meta", "skin_points", total_points))
	fresh = _dict("meta", "fresh")
	skin = _int("meta", "skin", 0)
	if skin < 0 or skin >= Meta.SKINS.size() or skin_points < int(Meta.SKINS[skin][1]):
		skin = 0
	mission_level = maxi(0, _int("meta", "mission_level", 0))
	missions = []
	for m: Variant in _array("meta", "missions"):
		if m is Dictionary and Meta.MISSIONS.has(m.get("id", "")) and missions.size() < Meta.ACTIVE:
			missions.append({"id": str(m.id), "level": maxi(0, int(m.get("level", 0))), "runs": maxi(0, int(m.get("runs", 0)))})
	stats = _dict("meta", "stats")
	daily_date = _int("meta", "daily_date", 0)
	daily_best = maxi(0, _int("meta", "daily_best", 0))
	habits = _dict("meta", "habits")
	feats = _dict("meta", "feats")
	best_runs = []
	for r: Variant in _array("meta", "best_runs"):
		if r is Dictionary and best_runs.size() < 10:
			best_runs.append(r)
	pace = []
	for v: Variant in _array("meta", "pace"):
		if (v is int or v is float) and pace.size() < 64:
			pace.append(maxi(0, int(v)))
	_generation = _int("seal", "n", 0)
	_dirty = false
	_fill_missions()
	if lang == "":
		lang = "no" if OS.get_locale_language() in ["nb", "nn", "no"] else "en"
	if recovered != "":
		# Whatever was recovered becomes the file again (and its backup).
		save()


## The file to trust. A complete file ends with its seal (written last);
## one from before the seal existed (v7.57 and earlier) is known by its
## last key. Otherwise, in order: a finished save that was never swapped
## in, the backup, and at worst whatever could be read.
func _pick_file() -> ConfigFile:
	recovered = ""
	_main_ok = false
	var main := _read(path)
	if main != null and (main.has_section("seal") or main.has_section_key("meta", "best_runs") or not FileAccess.file_exists(path + ".bak")):
		_main_ok = true
		return main
	var tmp := _read(path + ".tmp")
	if main == null and tmp != null and tmp.has_section("seal"):
		# The swap never happened: finish it now.
		recovered = "temp"
		_main_ok = _move(path + ".tmp", path)
		return tmp
	var bak := _read(path + ".bak")
	if bak != null:
		recovered = "backup"
		return bak
	if main != null:
		recovered = "partial"
		return main
	return ConfigFile.new()


static func _read(p: String) -> ConfigFile:
	if not FileAccess.file_exists(p):
		return null
	var c := ConfigFile.new()
	return c if c.load(p) == OK else null


func _int(section: String, key: String, fallback: int) -> int:
	var v: Variant = _cfg.get_value(section, key, fallback)
	return int(v) if (v is int or v is float) else fallback


func _bool(section: String, key: String, fallback: bool) -> bool:
	var v: Variant = _cfg.get_value(section, key, fallback)
	return v if v is bool else fallback


func _dict(section: String, key: String) -> Dictionary:
	var v: Variant = _cfg.get_value(section, key, {})
	return v if v is Dictionary else {}


func _array(section: String, key: String) -> Array:
	var v: Variant = _cfg.get_value(section, key, [])
	return v if v is Array else []


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
## `run_pace`: the run's score as each of its waves began (see `pace`); it
## is kept when the run is the new record, as the pace the next runs are
## measured against.
func submit_score(score: int, run_pace: Array = []) -> bool:
	if score <= record:
		return false
	if record > 0:
		fresh["best"] = true
	record = score
	pace = run_pace.duplicate()
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
	skin_points += pay
	mission_level += 1
	missions.remove_at(i)
	missions.insert(i, {"id": Meta.roll(missions), "level": mission_level})
	save()
	return pay


## A run ended: lifetime counters and points.
## `new_slots`: the mission slots filled during this run (their missions
## were not played for yet).
func record_run(run: Dictionary, new_slots: Array = []) -> void:
	total_points += int(run.get("score", 0))
	skin_points += int(run.get("score", 0))
	# A mission that has gone unfinished for many runs gives up its slot to
	# another (see Meta.STALE_RUNS).
	for i in missions.size():
		if new_slots.has(i):
			continue
		var m: Dictionary = missions[i]
		m["runs"] = int(m.get("runs", 0)) + 1
		if int(m.runs) >= Meta.STALE_RUNS:
			missions[i] = {"id": Meta.roll(missions), "level": mission_level, "runs": 0}
	if int(run.get("wave", 0)) > int(stats.get("best_wave", 0)) and int(stats.get("runs", 0)) > 0:
		fresh["wave"] = true
	for k: String in ["kills", "overloads", "bank", "chain", "cuts", "double", "break", "shots", "hits", "secs", "score"]:
		stats[k] = int(stats.get(k, 0)) + int(run.get(k, 0))
	stats["runs"] = int(stats.get("runs", 0)) + 1
	stats["best_wave"] = maxi(int(stats.get("best_wave", 0)), int(run.get("wave", 0)))
	save()


## A finished run for the list of best runs: its place (1..10), or 0
## when it did not make the list.
func add_run(run: Dictionary) -> int:
	var place := best_runs.size()
	for i in best_runs.size():
		if int(run.get("score", 0)) > int(best_runs[i].get("score", 0)):
			place = i
			break
	if place >= 10:
		return 0
	best_runs.insert(place, run)
	if best_runs.size() > 10:
		best_runs.resize(10)
	save()
	return place + 1


## Clears the record, the statistics, today's best, the missions, the
## achievements, the best runs and what the enemies have learned about you.
## Unlocked ball skins (and the one in use), settings and the enemies
## already introduced are kept.
func reset_progress() -> void:
	record = 0
	habits = {}
	feats = {}
	best_runs = []
	pace = []
	stats = {}
	total_points = 0
	daily_best = 0
	daily_date = 0
	missions = []
	mission_level = 0
	fresh = {}
	_fill_missions()
	_commit()


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


## Marks the progress as changed. It is written shortly after (several
## changes in a row, as at the end of a run, make one write), and at once
## when the app is paused, loses focus or closes (see flush).
func save() -> void:
	if not _dirty:
		# The wait runs from the first change: later ones ride along, and
		# cannot put the write off.
		_flush_at = Time.get_ticks_msec() + SAVE_DELAY_MS
	_dirty = true
	set_process(true)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _flush_at:
		flush()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST, NOTIFICATION_EXIT_TREE:
			flush()


## Writes pending changes now. The new file is written beside the old one
## and swapped in whole, and the old one stays as the backup, so a kill or
## a full disk mid-write can never leave a half-written save.
func flush() -> bool:
	set_process(false)
	if not _dirty:
		return true
	var c := ConfigFile.new()
	c.set_value("settings", "lang", lang)
	c.set_value("settings", "music", music_volume)
	c.set_value("settings", "sfx", sfx_volume)
	c.set_value("settings", "haptics", haptics)
	c.set_value("settings", "reduced_motion", reduced_motion)
	c.set_value("settings", "aim_guide", aim_guide)
	c.set_value("settings", "tilt", tilt)
	c.set_value("stats", "record", record)
	c.set_value("stats", "intro_seen", intro_seen)
	c.set_value("stats", "seen", seen)
	c.set_value("stats", "hints", hints)
	c.set_value("stats", "runs", runs)
	c.set_value("meta", "total_points", total_points)
	c.set_value("meta", "skin_points", skin_points)
	c.set_value("meta", "fresh", fresh)
	c.set_value("meta", "skin", skin)
	c.set_value("meta", "missions", missions)
	c.set_value("meta", "mission_level", mission_level)
	c.set_value("meta", "stats", stats)
	c.set_value("meta", "daily_date", daily_date)
	c.set_value("meta", "daily_best", daily_best)
	c.set_value("meta", "habits", habits)
	c.set_value("meta", "feats", feats)
	c.set_value("meta", "best_runs", best_runs)
	c.set_value("meta", "pace", pace)
	# The seal goes last: a file without it was cut short.
	c.set_value("seal", "format", FORMAT)
	c.set_value("seal", "n", _generation + 1)
	var tmp := path + ".tmp"
	if c.save(tmp) != OK:
		push_warning("Prefs: could not write %s" % tmp)
		_retry()
		return false
	# Only a whole file becomes the backup: a damaged one is simply
	# replaced, and the backup it was recovered from stays.
	if _main_ok and FileAccess.file_exists(path):
		_move(path, path + ".bak")
	if not _move(tmp, path):
		push_warning("Prefs: could not swap in %s" % path)
		_main_ok = false
		_retry()
		return false
	_main_ok = true
	_generation += 1
	_cfg = c
	_dirty = false
	return true


## A write failed (a full disk, say): the changes stay pending and are
## tried again in a while, without holding the game up.
func _retry() -> void:
	_flush_at = Time.get_ticks_msec() + 5000
	set_process(true)


static func _move(from: String, to: String) -> bool:
	if DirAccess.rename_absolute(from, to) == OK:
		return true
	# Where a rename will not replace a file, clear the way and try again.
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	return DirAccess.rename_absolute(from, to) == OK
