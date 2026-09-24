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
		"score": "POENG",
		"play_again": "SPILL IGJEN",
		"new_record": "NY REKORD",
		"hint": "DRA NED OG SLIPP",
		"pierce": "GJENNOMSLAG",
		"combo": "KOMBO ×%d",
		"split": "SPLITT",
		"level_clear": "NIVÅ %d FULLFØRT",
		"pause_a11y": "PAUSE",
	},
	"en": {
		"level": "LEVEL %d",
		"record": "BEST",
		"paused": "PAUSED",
		"resume": "RESUME",
		"restart": "RESTART",
		"language": "LANGUAGE: ENGLISH",
		"game_over": "THE STRING HIT BOTTOM",
		"score": "SCORE",
		"play_again": "PLAY AGAIN",
		"new_record": "NEW RECORD",
		"hint": "PULL DOWN AND RELEASE",
		"pierce": "PIERCE",
		"combo": "COMBO ×%d",
		"split": "SPLIT",
		"level_clear": "LEVEL %d CLEAR",
		"pause_a11y": "PAUSE",
	},
}

var lang := "no"
var record := 0
var _cfg := ConfigFile.new()


func _ready() -> void:
	var sys := OS.get_locale_language()
	lang = "no" if sys in ["nb", "nn", "no"] else "en"
	if _cfg.load(SAVE_PATH) == OK:
		lang = str(_cfg.get_value("settings", "lang", lang))
		record = int(_cfg.get_value("stats", "record", 0))
	if not STRINGS.has(lang):
		lang = "en"


func t(key: String) -> String:
	return STRINGS[lang].get(key, key)


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
	_cfg.set_value("stats", "record", record)
	_cfg.save(SAVE_PATH)
