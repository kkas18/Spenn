extends Node
## Strings (Norwegian / English), language choice and the persisted record.

signal language_changed

const SAVE_PATH := "user://spenn.cfg"

const STRINGS := {
	"no": {
		"level": "NIVÅ %d",
		"record": "REKORD",
		"paused": "PAUSE",
		"resume": "FORTSETT",
		"restart": "START PÅ NYTT",
		"language": "SPRÅK: NORSK",
		"game_over": "SNOREN NÅDDE BUNNEN",
		"play_again": "SPILL IGJEN",
		"new_record": "NY REKORD",
		"hint": "DRA NED OG SLIPP",
		"pierce": "GJENNOMSLAG",
		"combo": "KOMBO ×%d",
		"split": "SPLITT",
		"level_clear": "NIVÅ %d FULLFØRT",
		"wave": "BØLGE %d/%d",
		"level_wave": "NIVÅ %d · BØLGE %d/%d",
		"cut": "SNORKUTT",
		"blocked": "SKJOLD",
		"streak": "SERIE %d",
		"triple": "TREDELT SKUDD",
		"life_lost": "KNUTE RØK",
		"boss": "SPINNEREN",
		"boss_sub": "SKYT I SKJOLDGLIPEN",
		"level_sub": "%d MÅL · %d BØLGER",
		"level_sub1": "%d MÅL",
		"play": "DRA FOR Å SPILLE",
		"menu": "MENY",
		"stat_level": "NIVÅ",
		"stat_acc": "TREFF",
		"stat_streak": "BESTE SERIE",
		"stat_cuts": "SNORKUTT",
		"out_of_knots": "ALLE KNUTENE RØK",
		"sound_on": "LYD PÅ",
		"sound_off": "LYD AV",
	},
	"en": {
		"level": "LEVEL %d",
		"record": "BEST",
		"paused": "PAUSED",
		"resume": "RESUME",
		"restart": "RESTART",
		"language": "LANGUAGE: ENGLISH",
		"game_over": "THE STRING HIT BOTTOM",
		"play_again": "PLAY AGAIN",
		"new_record": "NEW RECORD",
		"hint": "PULL DOWN AND RELEASE",
		"pierce": "PIERCE",
		"combo": "COMBO ×%d",
		"split": "SPLIT",
		"level_clear": "LEVEL %d CLEAR",
		"wave": "WAVE %d/%d",
		"level_wave": "LEVEL %d · WAVE %d/%d",
		"cut": "STRING CUT",
		"blocked": "SHIELD",
		"streak": "STREAK %d",
		"triple": "TRIPLE SHOT",
		"life_lost": "KNOT SNAPPED",
		"boss": "THE SPINNER",
		"boss_sub": "SHOOT THROUGH THE GAP",
		"level_sub": "%d TARGETS · %d WAVES",
		"level_sub1": "%d TARGETS",
		"play": "PULL TO PLAY",
		"menu": "MENU",
		"stat_level": "LEVEL",
		"stat_acc": "ACCURACY",
		"stat_streak": "BEST STREAK",
		"stat_cuts": "STRING CUTS",
		"out_of_knots": "EVERY KNOT SNAPPED",
		"sound_on": "SOUND ON",
		"sound_off": "SOUND OFF",
	},
}

var lang := "no"
var record := 0
var sound_on := true
var _cfg := ConfigFile.new()


func _ready() -> void:
	var sys := OS.get_locale_language()
	lang = "no" if sys in ["nb", "nn", "no"] else "en"
	if _cfg.load(SAVE_PATH) == OK:
		lang = str(_cfg.get_value("settings", "lang", lang))
		record = int(_cfg.get_value("stats", "record", 0))
		sound_on = bool(_cfg.get_value("settings", "sound", true))
	if not STRINGS.has(lang):
		lang = "en"


func t(key: String) -> String:
	return STRINGS[lang].get(key, key)


func toggle_sound() -> void:
	sound_on = not sound_on
	_save()
	language_changed.emit()


func toggle_language() -> void:
	lang = "en" if lang == "no" else "no"
	_save()
	language_changed.emit()


## Returns true when `score` is a new record.
func submit_score(score: int) -> bool:
	if score <= record:
		return false
	record = score
	_save()
	return true


func _save() -> void:
	_cfg.set_value("settings", "lang", lang)
	_cfg.set_value("settings", "sound", sound_on)
	_cfg.set_value("stats", "record", record)
	_cfg.save(SAVE_PATH)
