#!/bin/bash
# dev-squad: --auto budget governor.
# SubagentStop -> increment total_dispatches.
# PreToolUse(dispatch tool) -> block when over budget (total_dispatches or wall-clock).
# No-op unless mode==auto.
# Note: concurrent SubagentStop fires may undercount total_dispatches; acceptable for a non-exact runaway backstop. Do NOT add flock (deadlock risk in hooks).

WORKFLOW_FILE=".dev-squad/workflow-active"
RUN_FILE=".dev-squad/auto-run.json"
[ -f "$WORKFLOW_FILE" ] || exit 0

INPUT=$(cat - 2>/dev/null || echo '{}')

MODE=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('mode',''))" "$WORKFLOW_FILE" 2>/dev/null)
[ "$MODE" = "auto" ] || exit 0

EVENT=$(printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))" 2>/dev/null)
TOOL=$(printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)

# Ensure run file exists
[ -f "$RUN_FILE" ] || printf '%s' '{"total_dispatches":0,"halted":false,"halt_reason":null}' > "$RUN_FILE"

if [ "$EVENT" = "SubagentStop" ]; then
  python3 - "$RUN_FILE" <<'PY' 2>/dev/null
import json,sys
p=sys.argv[1]
d=json.load(open(p))
d["total_dispatches"]=int(d.get("total_dispatches",0))+1
json.dump(d,open(p,"w"))
PY
  exit 0
fi

if [ "$EVENT" = "PreToolUse" ]; then
  TL=$(printf '%s' "$TOOL" | tr '[:upper:]' '[:lower:]')
  case "$TL" in
    task|agent) ;;
    *) exit 0 ;;
  esac

  VERDICT=$(python3 - "$WORKFLOW_FILE" "$RUN_FILE" <<'PY' 2>/dev/null
import json,sys,datetime
wf=json.load(open(sys.argv[1])); run=json.load(open(sys.argv[2]))
auto=wf.get("auto",{})
maxd=int(auto.get("max_total_dispatches",300))
maxmin=int(auto.get("wall_clock_cap_min",480))
n=int(run.get("total_dispatches",0))
if n>=maxd:
    print(f"EXCEEDED: max_total_dispatches ({n}>={maxd})"); sys.exit(0)
started=auto.get("started_at")
if started:
    try:
        t0=datetime.datetime.fromisoformat(started.replace("Z","+00:00"))
        now=datetime.datetime.now(datetime.timezone.utc)
        if (now-t0).total_seconds()/60.0 > maxmin:
            print(f"EXCEEDED: wall_clock_cap_min ({maxmin})"); sys.exit(0)
    except Exception:
        pass
print("OK")
PY
)

  if [ "${VERDICT#EXCEEDED}" != "$VERDICT" ]; then
    REASON="${VERDICT#EXCEEDED: }"
    python3 - "$RUN_FILE" "$REASON" <<'PY' 2>/dev/null
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d["halted"]=True; d["halt_reason"]=sys.argv[2]
json.dump(d,open(p,"w"))
PY
    echo "AUTO GOVERNOR: budget exceeded ($REASON). Stop dispatching, finalize, and let the termination hook write the report."
    exit 2
  fi
  exit 0
fi

exit 0
