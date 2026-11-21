#!/bin/bash
# Balance by bot: whole runs at three skill levels, several seeds each, on
# the phone screen the tests use. Prints every run and, per skill, the
# median time survived, wave reached and hit rate. Not part of run.sh (it
# takes a while); run it before and after anything that touches the game's
# difficulty and compare.
#
#   tools/tests/balance.sh [path/to/godot]
#   SEEDS="1 2 3 4 5 6 7 8" SKILLS="weak medium strong" JOBS=3 tools/tests/balance.sh
set -uo pipefail
G=${1:-godot}
cd "$(dirname "$0")/../.."
OUT=$(mktemp -d)
SEEDS=${SEEDS:-1 2 3 4 5 6 7 8}
SKILLS=${SKILLS:-weak medium strong}
JOBS=${JOBS:-3}

for skill in $SKILLS; do
	for s in $SEEDS; do
		while [ "$(jobs -r | wc -l)" -ge "$JOBS" ]; do sleep 1; done
		# Each run on a save of its own: runs in parallel must not share one.
		(SEED=$s SKILL=$skill SPENN_TEST_TAG="${skill}_$s" timeout 1200 "$G" --headless --path . --fixed-fps 60 -s res://tools/tests/bot.gd 2>&1 | grep -E "^RESULT|SCRIPT ERROR" >"$OUT/${skill}_$s.txt") &
	done
done
wait
python3 - "$OUT" $SKILLS <<'PY'
import glob, re, statistics, sys
out, skills = sys.argv[1], sys.argv[2:]
for skill in skills:
    rows = []
    for f in sorted(glob.glob(f"{out}/{skill}_*.txt")):
        for line in open(f):
            print(line.rstrip()[:150])
            m = re.search(r"time=(\d+)s.*? score=(\d+) acc=(\d+)% over=(\d+) wave=(\d+)", line)
            if m:
                rows.append(tuple(int(x) for x in m.groups()))
    if rows:
        t = sorted(r[0] for r in rows)
        print("BALANCE %-6s n=%d  time: median %ds (min %d, max %d)  wave: median %s  hit rate: median %d%%  score: median %d  overloads: median %s" % (
            skill, len(rows), statistics.median(t), t[0], t[-1], statistics.median(r[4] for r in rows),
            statistics.median(r[2] for r in rows), statistics.median(r[1] for r in rows), statistics.median(r[3] for r in rows)))
PY
