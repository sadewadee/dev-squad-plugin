#!/bin/bash
# Unit test for hooks/auto-guard.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/auto-guard.sh"
TMP=$(mktemp -d); cd "$TMP"; fail=0

# Case 1: no workflow file -> no-op (exit 0)
echo '{"tool_name":"AskUserQuestion","tool_input":{}}' | bash "$HOOK" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL case1: expected 0 got $rc"; fail=1; }

# Case 2: interactive mode -> no-op (exit 0)
mkdir -p .dev-squad; echo '{"mode":"interactive"}' > .dev-squad/workflow-active
echo '{"tool_name":"AskUserQuestion","tool_input":{}}' | bash "$HOOK" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL case2: expected 0 got $rc"; fail=1; }

# Case 3: auto mode -> block (exit 2) + message mentions AUTO MODE
echo '{"mode":"auto"}' > .dev-squad/workflow-active
out=$(echo '{"tool_name":"AskUserQuestion","tool_input":{}}' | bash "$HOOK" 2>&1); rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL case3 rc: expected 2 got $rc"; fail=1; }
echo "$out" | grep -qi "AUTO MODE" || { echo "FAIL case3 msg: '$out'"; fail=1; }

cd /; rm -rf "$TMP"
if [ "$fail" -eq 0 ]; then echo "PASS test-auto-guard"; else exit 1; fi
