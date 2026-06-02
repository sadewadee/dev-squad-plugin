#!/usr/bin/env bash
# check-workflow.sh
# SubagentStop + Stop hook. Two NON-BLOCKING checks (never blocks stop — blocking
# caused infinite loops when an agent needed user input):
#   1. Workflow-incomplete reminder (resume the current phase).
#   2. Memory-capture enforcement: if self-healing ran (a bug was diagnosed/fixed)
#      but no trap/decision was captured, nudge to write it (Rule 12 — un-captured
#      learnings = repeated bugs next session).

WORKFLOW_FILE=".dev-squad/workflow-active"

# Outside a dev-squad project there is nothing to check.
[ -f "$WORKFLOW_FILE" ] || exit 0

MSG=""

# --- Check 1: workflow incomplete ---
CONTENT=$(cat "$WORKFLOW_FILE")
for phase in ultraplan discover design scaffold ui_design implement review ship learn; do
  STATUS=$(echo "$CONTENT" | grep -o "\"$phase\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | grep -o '"[^"]*"$' | tr -d '"')
  if [ "$STATUS" != "complete" ] && [ -n "$STATUS" ]; then
    MSG="Workflow reminder: Phase '$phase' has status '$STATUS'. Continue when ready. "
    break
  fi
done

# --- Check 2: memory-capture enforcement ---
# If a self-healing / iteration log exists and is newer than gotchas.md (or gotchas.md
# is absent), a bug was worked but no trap was captured.
NEWEST_LOG=$(ls -t ".dev-squad/self-healing-log.md" ".dev-squad/iteration-log.md" 2>/dev/null | head -1)
if [ -n "$NEWEST_LOG" ]; then
  if [ ! -f ".dev-squad/gotchas.md" ] || [ "$NEWEST_LOG" -nt ".dev-squad/gotchas.md" ]; then
    MSG="${MSG}CAPTURE REQUIRED: self-healing ran but no trap was written. Before stopping, append the root cause to .dev-squad/gotchas.md and any resulting convention to .dev-squad/memory.md. Un-captured learnings = the same bug re-debugged next session. "
  fi
fi

# Emit combined reminder only if something fired.
if [ -n "$MSG" ]; then
  # Escape double quotes for JSON safety.
  MSG_ESCAPED=$(printf '%s' "$MSG" | sed 's/"/\\"/g')
  echo "{\"additionalContext\": \"$MSG_ESCAPED\"}"
fi

exit 0
