#!/bin/bash
# Headless test suite: import, boot, a soak of a crowded late game, and
# bot runs. Fails on any script or engine error, a leak or a crash.
#
#   tools/tests/run.sh [path/to/godot]      (default: godot on PATH)
#   SEEDS="1 2 3" tools/tests/run.sh         (bot seeds, default "1 2")
set -uo pipefail
G=${1:-godot}
cd "$(dirname "$0")/../.."
LOG=$(mktemp -d)
fail=0

check() {  # name, log file
	if grep -E "SCRIPT ERROR|Parse Error|^ERROR:|Invalid (get|set|call)" "$2" >/dev/null; then
		echo "FAIL $1"
		grep -E "SCRIPT ERROR|Parse Error|^ERROR:|Invalid (get|set|call)" -A3 "$2" | head -20
		fail=1
	else
		echo "ok   $1"
	fi
}

"$G" --headless --path . --import >"$LOG/import.log" 2>&1
check import "$LOG/import.log"
"$G" --headless --path . --quit-after 240 >"$LOG/boot.log" 2>&1
check boot "$LOG/boot.log"
timeout 600 "$G" --headless --path . --fixed-fps 60 --quit-after 3000 -s res://tools/tests/soak.gd >"$LOG/soak.log" 2>&1
code=$?
check soak "$LOG/soak.log"
grep "^SOAK" "$LOG/soak.log"
if [ $code -ne 0 ] || ! grep -q "^SOAK OK" "$LOG/soak.log"; then echo "FAIL soak (exit $code)"; fail=1; fi
for s in ${SEEDS:-1 2}; do
	SEED=$s timeout 900 "$G" --headless --path . --fixed-fps 60 --quit-after 45000 -s res://tools/tests/bot.gd >"$LOG/bot_$s.log" 2>&1
	check "bot seed $s" "$LOG/bot_$s.log"
	if ! grep "^RESULT" "$LOG/bot_$s.log"; then
		echo "FAIL bot seed $s: the run never finished"
		fail=1
	fi
done
exit $fail
