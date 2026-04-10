#!/usr/bin/env bash
# check-workflow.sh
# SubagentStop + Stop hook: checks if zero-to-ship workflow is active and incomplete.
#
# IMPORTANT: Only blocks ONCE per session to prevent infinite loop.
# If agent needs user input, it must be allowed to stop.
#
# Exit codes:
#   0 = no active workflow, workflow complete, or already reminded (let stop)
#   2 = workflow active, first reminder (block stop once)

WORKFLOW_FILE=".dev-squad/workflow-active"
REMINDER_FLAG=".dev-squad/.hook-reminded"

# If no workflow file exists, nothing to do
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

# If we already reminded this session, let the agent stop
# This prevents infinite block loop when agent needs user input
if [ -f "$REMINDER_FLAG" ]; then
  exit 0
fi

# Read the workflow file and check phase statuses
CONTENT=$(cat "$WORKFLOW_FILE")

# Check if all phases are complete
ALL_COMPLETE=true
for phase in ultraplan discover design scaffold implement review ship; do
  STATUS=$(echo "$CONTENT" | grep -o "\"$phase\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | grep -o '"[^"]*"$' | tr -d '"')
  if [ "$STATUS" != "complete" ] && [ -n "$STATUS" ]; then
    ALL_COMPLETE=false
    CURRENT_PHASE="$phase"
    CURRENT_STATUS="$STATUS"
    break
  fi
done

if [ "$ALL_COMPLETE" = true ]; then
  rm -f "$REMINDER_FLAG" 2>/dev/null
  exit 0
fi

# First reminder — block once, set flag
touch "$REMINDER_FLAG"
echo "WORKFLOW REMINDER: Zero-to-ship workflow is still active. Phase '$CURRENT_PHASE' has status '$CURRENT_STATUS'. Continue to the next phase or explain why you need to stop." >&2
exit 2
