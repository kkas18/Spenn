extends Node
## Localization (autoload `Loc`). Every visible string lives here under a
## dotted key; UI never hardcodes text. Switching language emits
## `language_changed`, and every screen re-reads its strings live.

signal language_changed

const LANGS := ["no", "en"]

const STRINGS := {
	"no": {
		"game.title": "SPENN",
		"game.tagline": "HOLD SNORENE UNNA LINJEN",
		"menu.play": "DRA FOR Å SPILLE",
		"menu.best": "REKORD",
		"menu.settings": "INNSTILLINGER",
		"menu.skip": "TRYKK FOR Å HOPPE OVER",
		"hud.phase": "FASE %d",
		"pause.title": "PAUSE",
		"pause.resume": "FORTSETT",
		"pause.restart": "START PÅ NYTT",
		"pause.settings": "INNSTILLINGER",
		"pause.mainMenu": "HOVEDMENY",
		"pause.best": "REKORD  %s",
		"pause.hint": "DOBBELTTRYKK FOR PAUSE",
		"gameOver.title": "SPILLET ER OVER",
		"gameOver.score": "POENG",
		"gameOver.bestScore": "BESTE RESULTAT",
		"gameOver.time": "TID",
		"gameOver.accuracy": "TREFF",
		"gameOver.restart": "PRØV IGJEN",
		"gameOver.mainMenu": "HOVEDMENY",
		"record.new": "NY REKORD",
		"settings.title": "INNSTILLINGER",
		"settings.music": "MUSIKK",
		"settings.effects": "EFFEKTER",
		"settings.haptics": "VIBRASJON",
		"settings.reducedMotion": "REDUSERTE ANIMASJONER",
		"settings.aimGuide": "SIKTELINJE",
		"settings.language": "SPRÅK",
		"settings.languageName": "NORSK",
		"settings.back": "TILBAKE",
		"settings.on": "PÅ",
		"settings.off": "AV",
		"settings.level.0": "AV",
		"settings.level.1": "LAV",
		"settings.level.2": "MIDDELS",
		"settings.level.3": "HØY",
		"event.survive": "OVERLEV",
		"event.surviveSub": "HOLD DEM UNNA LINJEN",
		"event.formation": "FORMASJON",
		"event.formationSub": "EN HEL REKKE PÅ EN GANG",
		"event.rush": "STORM",
		"event.rushSub": "DYKKERE FRA BJELKEN",
		"event.boss": "SPINNEREN",
		"event.bossSub": "SKYT I SKJOLDGLIPEN",
		"popup.pierce": "GJENNOMSLAG",
		"popup.combo": "KOMBO ×%d",
		"popup.split": "SPLITT",
		"popup.cut": "SNORKUTT",
		"popup.blocked": "SKJOLD",
		"popup.streak": "SERIE %d",
		"popup.triple": "TREDELT SKUDD",
		"popup.lifeLost": "KNUTE RØK",
		"popup.chain": "KJEDE ×%d",
		"popup.close": "NÆRE PÅ",
		"popup.extraKnot": "+1 KNUTE",
		"enemy.new": "NY FIENDE",
		"enemy.0": "VAKT|Søker dekning bak andre når du sikter. Slipp før den flytter seg.",
		"enemy.1": "TUNGVEKT|To treff. Blir rasende og stuper etter det første.",
		"enemy.2": "SPLITTER|Deler seg i to dykkere.",
		"enemy.3": "PENDEL|Svinger alltid. Tim vendepunktet.",
		"enemy.4": "DYKKER|Skjelver, så stuper den. Skyt mens den skjelver.",
		"enemy.5": "VOKTER|Skjoldet vender mot deg. Bank via veggen eller kapp snoren.",
		"enemy.6": "SPINNEREN|Skyt i glipen mellom skjoldene.",
		"enemy.7": "SNELLE|Vinsjer seg opp når du sikter. Vær rask, eller bank via veggen.",
		"enemy.8": "SKYGGE|Blir usynlig i perioder. Skudd går gjennom den da.",
	},
	"en": {
		"game.title": "SPENN",
		"game.tagline": "KEEP THE STRINGS OFF THE LINE",
		"menu.play": "PULL TO PLAY",
		"menu.best": "BEST",
		"menu.settings": "SETTINGS",
		"menu.skip": "TAP TO SKIP",
		"hud.phase": "PHASE %d",
		"pause.title": "PAUSED",
		"pause.resume": "RESUME",
		"pause.restart": "RESTART",
		"pause.settings": "SETTINGS",
		"pause.mainMenu": "MAIN MENU",
		"pause.best": "BEST  %s",
		"pause.hint": "DOUBLE-TAP TO PAUSE",
		"gameOver.title": "GAME OVER",
		"gameOver.score": "SCORE",
		"gameOver.bestScore": "BEST SCORE",
		"gameOver.time": "TIME",
		"gameOver.accuracy": "ACCURACY",
		"gameOver.restart": "TRY AGAIN",
		"gameOver.mainMenu": "MAIN MENU",
		"record.new": "NEW RECORD",
		"settings.title": "SETTINGS",
		"settings.music": "MUSIC",
		"settings.effects": "EFFECTS",
		"settings.haptics": "VIBRATION",
		"settings.reducedMotion": "REDUCED MOTION",
		"settings.aimGuide": "AIM GUIDE",
		"settings.language": "LANGUAGE",
		"settings.languageName": "ENGLISH",
		"settings.back": "BACK",
		"settings.on": "ON",
		"settings.off": "OFF",
		"settings.level.0": "OFF",
		"settings.level.1": "LOW",
		"settings.level.2": "MEDIUM",
		"settings.level.3": "HIGH",
		"event.survive": "SURVIVE",
		"event.surviveSub": "KEEP THEM OFF THE LINE",
		"event.formation": "FORMATION",
		"event.formationSub": "A WHOLE ROW AT ONCE",
		"event.rush": "RUSH",
		"event.rushSub": "DIVERS FROM THE RAIL",
		"event.boss": "THE SPINNER",
		"event.bossSub": "SHOOT THROUGH THE GAP",
		"popup.pierce": "PIERCE",
		"popup.combo": "COMBO ×%d",
		"popup.split": "SPLIT",
		"popup.cut": "STRING CUT",
		"popup.blocked": "SHIELD",
		"popup.streak": "STREAK %d",
		"popup.triple": "TRIPLE SHOT",
		"popup.lifeLost": "KNOT SNAPPED",
		"popup.chain": "CHAIN ×%d",
		"popup.close": "CLOSE CALL",
		"popup.extraKnot": "+1 KNOT",
		"enemy.new": "NEW ENEMY",
		"enemy.0": "WARDEN|Seeks cover behind others when aimed at. Release before it moves.",
		"enemy.1": "HEAVY|Two hits. Enrages and dives after the first.",
		"enemy.2": "SPLITTER|Breaks into two divers.",
		"enemy.3": "PENDULUM|Always swinging. Time the turn.",
		"enemy.4": "DIVER|Trembles, then dives. Shoot while it shakes.",
		"enemy.5": "SENTRY|Its shield faces you. Bank off a wall or cut the string.",
		"enemy.6": "THE SPINNER|Shoot through the gap between the plates.",
		"enemy.7": "REEL|Winches up when aimed at. Be quick, or bank off a wall.",
		"enemy.8": "SHADE|Fades out at times. Shots pass straight through.",
	},
}

var lang: String:
	get:
		return Prefs.lang


func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(lang, STRINGS["en"])
	if table.has(key):
		return table[key]
	push_warning("Missing string: %s/%s" % [lang, key])
	return STRINGS["en"].get(key, key)


## "MUSIKK: MIDDELS" style setting line.
func setting(key: String, value_key: String) -> String:
	return "%s: %s" % [t(key), t(value_key)]


func on_off(v: bool) -> String:
	return "settings.on" if v else "settings.off"


func next_language() -> void:
	var i := LANGS.find(lang)
	Prefs.set_lang(LANGS[(i + 1) % LANGS.size()])
	language_changed.emit()
