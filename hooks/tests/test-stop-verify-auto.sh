#!/bin/bash
# Unit test for the auto-mode termination path in hooks/stop-verify.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/stop-verify.sh"
TMP=$(mktemp -d); cd "$TMP"; fail=0
mkdir -p .dev-squad
# Minimal project so stop-verify does not early-exit, but no real build to run:
echo '{}' > package.json   # has package.json, no "test" script, no tsconfig -> verification no-ops cleanly

# Case A: auto mode, governor halted -> floor FAIL: writes report + exit 2
echo '{"workflow":"zero-to-ship","mode":"auto","phases":{}}' > .dev-squad/workflow-active
echo '{"total_dispatches":999,"halted":true,"halt_reason":"max_total_dispatches"}' > .dev-squad/auto-run.json
out=$(echo '{"stop_hook_active":false}' | bash "$HOOK" 2>&1); rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL A rc: expected 2 got $rc"; fail=1; }
[ -f .dev-squad/auto-failure-report.md ] || { echo "FAIL A: failure report not written"; fail=1; }

# Case B: auto mode, clean floor -> exit 0, no failure report
rm -f .dev-squad/auto-failure-report.md
echo '{"total_dispatches":3,"halted":false,"halt_reason":null}' > .dev-squad/auto-run.json
rc=$(echo '{"stop_hook_active":false}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
[ "$rc" -eq 0 ] || { echo "FAIL B: expected 0 got $rc"; fail=1; }
[ ! -f .dev-squad/auto-failure-report.md ] || { echo "FAIL B: should not write failure report on clean floor"; fail=1; }

# Case C: interactive mode unaffected -> exit 0
echo '{"workflow":"zero-to-ship","mode":"interactive","phases":{}}' > .dev-squad/workflow-active
rc=$(echo '{"stop_hook_active":false}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
[ "$rc" -eq 0 ] || { echo "FAIL C: expected 0 got $rc"; fail=1; }

# Case D: re-entrancy guard honored (stop_hook_active true -> exit 0 even if halted)
echo '{"workflow":"zero-to-ship","mode":"auto","phases":{}}' > .dev-squad/workflow-active
echo '{"total_dispatches":999,"halted":true,"halt_reason":"x"}' > .dev-squad/auto-run.json
rc=$(echo '{"stop_hook_active":true}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
[ "$rc" -eq 0 ] || { echo "FAIL D: expected 0 got $rc"; fail=1; }

cd /; rm -rf "$TMP"
if [ "$fail" -eq 0 ]; then echo "PASS test-stop-verify-auto"; else exit 1; fi
