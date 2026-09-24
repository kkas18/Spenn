extends Node
## Persisted preferences and progress (autoload `Prefs`): language, music
## and effects volume, haptics, reduced motion, aim guide, best score and
## which enemies and intros have been seen. Restored on every launch.

signal changed

const PATH := "user://spenn.cfg"
const LEVELS := 4              # 0 off, 1 low, 2 medium, 3 high

var lang := ""
var music_volume := 2
var sfx_volume := 2
var haptics := true
var reduced_motion := false
var aim_guide := true
var record := 0
var intro_seen := false
var seen := {}                 # enemy kinds already introduced
var runs := 0                  # runs started (the pause hint shows for the first few)

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
		record = int(_cfg.get_value("stats", "record", 0))
		intro_seen = bool(_cfg.get_value("stats", "intro_seen", false))
		seen = _cfg.get_value("stats", "seen", {})
		runs = int(_cfg.get_value("stats", "runs", 0))
	if lang == "":
		lang = "no" if OS.get_locale_language() in ["nb", "nn", "no"] else "en"


func cycle_music() -> void:
	music_volume = (music_volume + 1) % LEVELS
	_commit()


func cycle_sfx() -> void:
	sfx_volume = (sfx_volume + 1) % LEVELS
	_commit()


func toggle_haptics() -> void:
	haptics = not haptics
	_commit()


func toggle_reduced_motion() -> void:
	reduced_motion = not reduced_motion
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
	_cfg.set_value("stats", "record", record)
	_cfg.set_value("stats", "intro_seen", intro_seen)
	_cfg.set_value("stats", "seen", seen)
	_cfg.set_value("stats", "runs", runs)
	_cfg.save(PATH)
