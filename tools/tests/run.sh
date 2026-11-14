#!/bin/bash
# The headless test suite. Fails on any script or engine error, a broken
# check, a leak, a crash or a run that never finishes.
#
#   tools/tests/run.sh [path/to/godot]      (default: godot on PATH)
#   SEEDS="1 2 3" tools/tests/run.sh         (bot seeds, default "1 2")
#   ONLY="flow save" tools/tests/run.sh      (just these tests)
#
# What runs:
#   import, boot   the project loads and starts without an error
#   layout         the screen layout on nine phone shapes
#   flow           a whole session: menu, play, pause, resume, restart, losing
#   save           the stored progress survives damage and interrupted writes
#   timing         real time and game time (hit-stop, slow motion, overload)
#   physics        frame-rate independence, no tunnelling, nothing stuck
#   repeat         one seed is one run, whatever missions are held
#   soak           a crowded late game under fire: no leaks
#   bot            whole runs by a bot player, one per seed
set -uo pipefail
G=${1:-godot}
cd "$(dirname "$0")/../.."
LOG=$(mktemp -d)
fail=0
BAD='SCRIPT ERROR|Parse Error|^ERROR:|Invalid (get|set|call)'

check() {  # name, log file, [expected error lines to let through]
	local hits
	hits=$(grep -E "$BAD" -A3 "$2" | grep -Ev "${3:-^__none__$}" | grep -E "$BAD" -A3)
	if [ -n "$hits" ]; then
		echo "FAIL $1"
		echo "$hits" | head -20
		fail=1
	else
		echo "ok   $1"
	fi
}

wanted() {  # is this test asked for?
	[ -z "${ONLY:-}" ] || [[ " $ONLY " == *" $1 "* ]]
}

run_test() {  # name, timeout (s), [expected error lines]
	wanted "$1" || return 0
	timeout "$2" "$G" --headless --path . --fixed-fps 60 -s "res://tools/tests/$1.gd" >"$LOG/$1.log" 2>&1
	local code=$?
	check "$1" "$LOG/$1.log" "${3:-}"
	grep -E "^TEST $1( FAIL|:)" "$LOG/$1.log"
	if [ $code -ne 0 ] || ! grep -q "^TEST $1 OK" "$LOG/$1.log"; then
		echo "FAIL $1 (exit $code)"
		grep -E "^TEST $1 (OK|FAILED)" "$LOG/$1.log" || echo "     it never finished"
		fail=1
	fi
}

if wanted import; then
	"$G" --headless --path . --import >"$LOG/import.log" 2>&1
	check import "$LOG/import.log"
fi
if wanted boot; then
	"$G" --headless --path . --quit-after 240 >"$LOG/boot.log" 2>&1
	check boot "$LOG/boot.log"
fi
run_test layout 120
run_test flow 300
# The save test feeds the game damaged files on purpose: the engine's own
# complaints about those are expected.
run_test save 120 'ConfigFile parse error|config_file.cpp'
run_test timing 300
run_test physics 600
run_test repeat 300
run_test soak 600
if wanted bot; then
	for s in ${SEEDS:-1 2}; do
		SEED=$s timeout 900 "$G" --headless --path . --fixed-fps 60 -s res://tools/tests/bot.gd >"$LOG/bot_$s.log" 2>&1
		code=$?
		check "bot seed $s" "$LOG/bot_$s.log"
		if ! grep "^RESULT" "$LOG/bot_$s.log" || [ $code -ne 0 ]; then
			echo "FAIL bot seed $s: the run never finished (exit $code)"
			fail=1
		fi
	done
fi
exit $fail
