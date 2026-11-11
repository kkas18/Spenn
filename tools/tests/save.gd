extends "res://tools/tests/harness.gd"
## The stored progress: what is written comes back the same; changes made
## close together make one write; and nothing a damaged file can hold (cut
## short, garbage, a missing file, the wrong kind of value) loses the
## progress or stops the game from starting.

const V757 := """[settings]

lang="no"
music=3
sfx=1
haptics=false
reduced_motion=true
aim_guide=true
tilt=false

[stats]

record=4321
intro_seen=true
seen={
0: true,
1: true
}
hints={
"charm.1": true
}
runs=17

[meta]

total_points=50000
skin_points=50000
fresh={}
skin=2
missions=[{
"id": "kills",
"level": 3
}, {
"id": "wave",
"level": 4
}, {
"id": "cut",
"level": 5
}]
mission_level=6
stats={
"best_wave": 5,
"kills": 300,
"runs": 17
}
daily_date=20261001
daily_best=900
habits={}
feats={
"clean": 20261001
}
best_runs=[{
"acc": 71,
"daily": false,
"day": 20261001,
"score": 4321,
"secs": 150,
"wave": 5
}]
"""


func _test() -> void:
	var p: String = prefs.path

	# --- what is written comes back
	prefs.record = 12345
	prefs.music_volume = 1
	prefs.sfx_volume = 3
	prefs.reduced_motion = true
	prefs.stats = {"runs": 7, "kills": 99, "best_wave": 4}
	prefs.feats = {"clean": 20261110}
	prefs.best_runs = [{"score": 12345, "wave": 4, "secs": 200, "acc": 66, "day": 20261110, "daily": false}]
	prefs.total_points = 40000
	prefs.skin_points = 40000
	prefs.skin = 2
	prefs.save()
	check(prefs.flush(), "the progress is written")
	check(FileAccess.file_exists(p) and not FileAccess.file_exists(p + ".tmp"), "one whole file, nothing left half-way")
	_forget()
	prefs.load_from_disk()
	check(prefs.recovered == "", "a whole file loads plainly")
	check(prefs.record == 12345 and prefs.music_volume == 1 and prefs.sfx_volume == 3 and prefs.reduced_motion, "settings and the record come back")
	check(int(prefs.stats.get("kills", 0)) == 99 and prefs.feats.has("clean") and prefs.best_runs.size() == 1 and prefs.skin == 2, "statistics, achievements, best runs and the skin come back")

	# --- changes made close together are written once
	var gen := _generation(p)
	for i in 6:
		prefs.record += 1
		prefs.save()
	check(_generation(p) == gen, "a change is not written the instant it is made")
	prefs.flush()
	check(_generation(p) == gen + 1, "six changes in a row make one write")
	prefs.flush()
	check(_generation(p) == gen + 1, "nothing is written when nothing changed")
	prefs.record = 20000
	prefs.save()
	var until := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until:
		await process_frame
	check(_generation(p) == gen + 2, "a pending change writes itself within a second")
	check(FileAccess.file_exists(p + ".bak"), "the file before stays as the backup")

	# --- the app is sent away: written at once
	prefs.record = 20001
	prefs.save()
	prefs.notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	check(_generation(p) == gen + 3, "leaving the app writes pending progress at once")

	# --- a file cut short: the backup is used, nothing else is lost
	prefs.record = 30000
	prefs.save()
	prefs.flush()
	var whole := FileAccess.get_file_as_bytes(p)
	_put(p, whole.slice(0, whole.size() / 2))
	_forget()
	prefs.load_from_disk()
	check(prefs.recovered == "backup", "a file cut short is noticed (%s)" % prefs.recovered)
	check(prefs.record == 20001, "... and the previous save is used (record %d)" % prefs.record)
	check(int(prefs.stats.get("kills", 0)) == 99 and prefs.feats.has("clean") and prefs.best_runs.size() == 1, "... with statistics, achievements and best runs intact")
	prefs.flush()
	var again := ConfigFile.new()
	check(again.load(p) == OK and again.has_section("seal"), "what was recovered is written back whole")

	# --- garbage
	_put(p, PackedByteArray([0, 255, 13, 10, 91, 91, 61, 61, 0, 7, 200, 93]))
	_forget()
	prefs.load_from_disk()
	check(prefs.record == 20001 and prefs.recovered == "backup", "garbage in the file: the backup is used")

	# --- a save interrupted between writing and swapping
	prefs.flush()
	DirAccess.rename_absolute(p, p + ".tmp")
	_forget()
	prefs.load_from_disk()
	check(prefs.recovered == "temp" and prefs.record == 20001, "a finished save that was never swapped in is used (%s)" % prefs.recovered)

	# --- no file at all: a first run, not a crash
	prefs.flush()
	wipe_save()
	_forget()
	prefs.load_from_disk()
	check(prefs.record == 0 and prefs.recovered == "" and prefs.missions.size() == 3, "no file: a first run with its three missions")

	# --- a file from before the upgrade (v7.57) is taken over as it is
	wipe_save()
	_put(p, V757.to_utf8_buffer())
	_forget()
	prefs.load_from_disk()
	check(prefs.recovered == "" and prefs.record == 4321 and prefs.runs == 17 and prefs.lang == "no", "a v7.57 save loads")
	check(prefs.music_volume == 3 and prefs.sfx_volume == 1 and not prefs.haptics and prefs.reduced_motion and not prefs.tilt, "... with its settings")
	check(prefs.skin == 2 and prefs.total_points == 50000 and prefs.missions.size() == 3 and prefs.mission_level == 6, "... its skin, points and missions")
	check(prefs.best_runs.size() == 1 and prefs.feats.has("clean") and int(prefs.stats.get("kills", 0)) == 300, "... its best runs, achievements and statistics")
	prefs.runs += 1
	prefs.save()
	prefs.flush()
	_forget()
	prefs.load_from_disk()
	check(prefs.runs == 18 and prefs.record == 4321 and prefs.recovered == "", "... and is carried on in the new format")
	# The old version run again after the new one (it writes no seal, and
	# its file is newer than the backup): its progress is the one kept.
	_put(p, V757.replace("record=4321", "record=5555").to_utf8_buffer())
	_forget()
	prefs.load_from_disk()
	check(prefs.record == 5555 and prefs.recovered == "", "a whole v7.57 file beside a backup is still trusted")

	# --- values of the wrong kind are replaced, not crashed on
	wipe_save()
	_put(p, """[settings]
lang=42
music=17
sfx=-3
haptics="yes"
[stats]
record="lots"
seen="x"
hints=[1, 2]
runs=-5
[meta]
total_points=10
skin_points=10
skin=99
missions=[5, {"id": "nope", "level": 1}, {"id": "kills", "level": -2}, {"level": 1}]
mission_level="x"
stats=[]
habits=7
feats="none"
best_runs=[1, "two", {"score": 5}]
""".to_utf8_buffer())
	_forget()
	prefs.load_from_disk()
	check(prefs.lang in ["no", "en"] and prefs.music_volume == 3 and prefs.sfx_volume == 0 and prefs.haptics, "settings of the wrong kind fall back")
	check(prefs.record == 0 and prefs.seen.is_empty() and prefs.hints.is_empty() and prefs.runs == 0, "progress of the wrong kind falls back")
	check(prefs.skin == 0, "a skin that does not exist (or is not won) is not worn")
	check(prefs.missions.size() == 3 and _missions_valid(), "missions that do not exist are replaced")
	check(prefs.stats.is_empty() and prefs.habits.is_empty() and prefs.feats.is_empty() and prefs.best_runs.size() == 1, "collections of the wrong kind are emptied")

	# --- a place that cannot be written: the game goes on, the change waits
	var real: String = prefs.path
	prefs.path = "user://no_such_dir/deeper/spenn.cfg"
	prefs.record = 1
	prefs.save()
	check(not prefs.flush(), "a failed write is reported")
	check(prefs._dirty, "... and the change stays pending")
	prefs.path = real
	check(prefs.flush(), "... until it can be written")
	finish()


## Scrambles what is in memory, so a later check can only pass on what
## was read back from disk.
func _forget() -> void:
	prefs.record = -1
	prefs.runs = -1
	prefs.music_volume = 0
	prefs.sfx_volume = 0
	prefs.stats = {}
	prefs.feats = {}
	prefs.best_runs = []
	prefs.missions = []
	prefs.skin = 0
	prefs.lang = ""


func _put(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _generation(path: String) -> int:
	var c := ConfigFile.new()
	return int(c.get_value("seal", "n", -1)) if c.load(path) == OK else -1


func _missions_valid() -> bool:
	var known: Dictionary = (load("res://scripts/meta.gd") as Script).get_script_constant_map()["MISSIONS"]
	for m: Variant in prefs.missions:
		if not (m is Dictionary and known.has(m.get("id", "")) and int(m.get("level", -1)) >= 0):
			return false
	return true
