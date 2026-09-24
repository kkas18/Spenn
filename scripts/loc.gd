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
		"sound_0": "LYD AV",
		"sound_1": "LYD LAV",
		"sound_2": "LYD MIDDELS",
		"sound_3": "LYD HØY",
		"haptics_on": "VIBRASJON PÅ",
		"haptics_off": "VIBRASJON AV",
		"guide_on": "SIKTELINJE PÅ",
		"guide_off": "SIKTELINJE AV",
		"settings": "INNSTILLINGER",
		"back": "TILBAKE",
		"new_enemy": "NY FIENDE",
		"hidden": "SKJULT",
		"e0": "VAKT|Søker dekning bak andre når du sikter. Slipp før den flytter seg.",
		"e1": "TUNGVEKT|To treff. Blir rasende og stuper etter det første.",
		"e2": "SPLITTER|Deler seg i to dykkere.",
		"e3": "PENDEL|Svinger alltid. Tim vendepunktet.",
		"e4": "DYKKER|Skjelver, så stuper den. Skyt mens den skjelver.",
		"e5": "VOKTER|Skjoldet vender mot deg. Bank via veggen eller kapp snoren.",
		"e6": "SPINNEREN|Skyt i glipen mellom skjoldene.",
		"e7": "SNELLE|Vinsjer seg opp når du sikter. Vær rask, eller bank via veggen.",
		"e8": "SKYGGE|Blir usynlig i perioder. Skudd går gjennom den da.",
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
		"sound_0": "SOUND OFF",
		"sound_1": "SOUND LOW",
		"sound_2": "SOUND MEDIUM",
		"sound_3": "SOUND HIGH",
		"haptics_on": "VIBRATION ON",
		"haptics_off": "VIBRATION OFF",
		"guide_on": "AIM GUIDE ON",
		"guide_off": "AIM GUIDE OFF",
		"settings": "SETTINGS",
		"back": "BACK",
		"new_enemy": "NEW ENEMY",
		"hidden": "HIDDEN",
		"e0": "WARDEN|Seeks cover behind others when aimed at. Release before it moves.",
		"e1": "HEAVY|Two hits. Enrages and dives after the first.",
		"e2": "SPLITTER|Breaks into two divers.",
		"e3": "PENDULUM|Always swinging. Time the turn.",
		"e4": "DIVER|Trembles, then dives. Shoot while it shakes.",
		"e5": "SENTRY|Its shield faces you. Bank off a wall or cut the string.",
		"e6": "THE SPINNER|Shoot through the gap between the plates.",
		"e7": "REEL|Winches up when aimed at. Be quick, or bank off a wall.",
		"e8": "SHADE|Fades out at times. Shots pass straight through.",
	},
}

var lang := "no"
var record := 0
var volume := 2                 # 0 off, 1 low, 2 medium, 3 high
var haptics := true
var aim_guide := true
var seen := {}                  # enemy kinds already introduced
var sound_on: bool:
	get:
		return volume > 0
var _cfg := ConfigFile.new()


func _ready() -> void:
	var sys := OS.get_locale_language()
	lang = "no" if sys in ["nb", "nn", "no"] else "en"
	if _cfg.load(SAVE_PATH) == OK:
		lang = str(_cfg.get_value("settings", "lang", lang))
		record = int(_cfg.get_value("stats", "record", 0))
		volume = int(_cfg.get_value("settings", "volume", 2))
		haptics = bool(_cfg.get_value("settings", "haptics", true))
		aim_guide = bool(_cfg.get_value("settings", "aim_guide", true))
		seen = _cfg.get_value("stats", "seen", {})
	if not STRINGS.has(lang):
		lang = "en"


func t(key: String) -> String:
	return STRINGS[lang].get(key, key)


## Cycles off → low → medium → high.
func toggle_sound() -> void:
	volume = (volume + 1) % 4
	_save()
	Sfx.apply_volume()
	language_changed.emit()


func toggle_haptics() -> void:
	haptics = not haptics
	_save()
	language_changed.emit()


func toggle_aim_guide() -> void:
	aim_guide = not aim_guide
	_save()
	language_changed.emit()


func sound_label() -> String:
	return t("sound_%d" % volume)


## True the first time a kind shows up (persisted), so it gets an intro.
func first_sight(kind: int) -> bool:
	if seen.has(kind):
		return false
	seen[kind] = true
	_save()
	return true


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
	_cfg.set_value("settings", "volume", volume)
	_cfg.set_value("settings", "haptics", haptics)
	_cfg.set_value("settings", "aim_guide", aim_guide)
	_cfg.set_value("stats", "seen", seen)
	_cfg.set_value("stats", "record", record)
	_cfg.save(SAVE_PATH)
