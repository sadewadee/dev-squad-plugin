#!/bin/bash
# Unit test for hooks/auto-governor.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/auto-governor.sh"
TMP=$(mktemp -d); cd "$TMP"; fail=0
mkdir -p .dev-squad

# auto mode with generous budget
cat > .dev-squad/workflow-active <<'JSON'
{"mode":"auto","auto":{"started_at":"2999-01-01T00:00:00Z","max_total_dispatches":2,"wall_clock_cap_min":480}}
JSON

# Case 1: SubagentStop increments total_dispatches 0 -> 1
echo '{"hook_event_name":"SubagentStop"}' | bash "$HOOK" >/dev/null 2>&1
n=$(python3 -c "import json; print(json.load(open('.dev-squad/auto-run.json'))['total_dispatches'])" 2>/dev/null)
[ "$n" = "1" ] || { echo "FAIL case1: expected 1 got '$n'"; fail=1; }

# Case 2: PreToolUse dispatch under budget (1 < 2) -> allow (exit 0)
echo '{"hook_event_name":"PreToolUse","tool_name":"Task"}' | bash "$HOOK" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL case2: expected 0 got $rc"; fail=1; }

# Bump to the cap
echo '{"hook_event_name":"SubagentStop"}' | bash "$HOOK" >/dev/null 2>&1  # ->2

# Case 3: PreToolUse dispatch at/over budget (2 >= 2) -> block (exit 2)
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Task"}' | bash "$HOOK" 2>&1); rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL case3 rc: expected 2 got $rc"; fail=1; }
echo "$out" | grep -qi "GOVERNOR" || { echo "FAIL case3 msg: '$out'"; fail=1; }

# Case 4: non-dispatch tool (Bash) never blocked even over budget -> exit 0
rc=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash"}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
[ "$rc" -eq 0 ] || { echo "FAIL case4: expected 0 got $rc"; fail=1; }

# Case 5: interactive mode -> no-op (no auto-run.json writes, exit 0)
rm -f .dev-squad/auto-run.json; echo '{"mode":"interactive"}' > .dev-squad/workflow-active
rc=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Task"}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
[ "$rc" -eq 0 ] || { echo "FAIL case5: expected 0 got $rc"; fail=1; }
[ ! -f .dev-squad/auto-run.json ] || { echo "FAIL case5: should not create auto-run.json in interactive"; fail=1; }

cd /; rm -rf "$TMP"
if [ "$fail" -eq 0 ]; then echo "PASS test-auto-governor"; else exit 1; fi
