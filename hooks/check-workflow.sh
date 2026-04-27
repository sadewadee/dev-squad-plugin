#!/usr/bin/env bash
# check-workflow.sh
# SubagentStop + Stop hook: checks if zero-to-ship workflow is active and incomplete.
# NON-BLOCKING: only injects reminder as context, never blocks stop.
# Blocking caused infinite loops when agent needed user input.

WORKFLOW_FILE=".dev-squad/workflow-active"

# If no workflow file exists, nothing to do
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

# Read the workflow file and check phase statuses
CONTENT=$(cat "$WORKFLOW_FILE")

# Check if all phases are complete
ALL_COMPLETE=true
for phase in ultraplan discover design scaffold implement review ship learn; do
  STATUS=$(echo "$CONTENT" | grep -o "\"$phase\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | grep -o '"[^"]*"$' | tr -d '"')
  if [ "$STATUS" != "complete" ] && [ -n "$STATUS" ]; then
    ALL_COMPLETE=false
    CURRENT_PHASE="$phase"
    CURRENT_STATUS="$STATUS"
    break
  fi
done

if [ "$ALL_COMPLETE" = true ]; then
  exit 0
fi

# Non-blocking reminder (exit 0, not exit 2)
echo "{\"additionalContext\": \"Workflow reminder: Phase '$CURRENT_PHASE' has status '$CURRENT_STATUS'. Continue when ready.\"}"
exit 0
