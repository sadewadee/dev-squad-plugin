#!/usr/bin/env bash
# check-workflow.sh
# SubagentStop hook: checks if zero-to-ship workflow is active and incomplete.
# Exit codes:
#   0 = no active workflow or workflow complete (no action needed)
#   2 = workflow active but incomplete (injects reminder to continue)

WORKFLOW_FILE=".dev-squad/workflow-active"

# If no workflow file exists, nothing to do
if [ ! -f "$WORKFLOW_FILE" ]; then
  exit 0
fi

# Read the workflow file and check phase statuses
CONTENT=$(cat "$WORKFLOW_FILE")

# Check if all phases are complete
ALL_COMPLETE=true
for phase in discover design scaffold implement review ship; do
  STATUS=$(echo "$CONTENT" | grep -o "\"$phase\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | grep -o '"[^"]*"$' | tr -d '"')
  if [ "$STATUS" != "complete" ]; then
    ALL_COMPLETE=false
    CURRENT_PHASE="$phase"
    CURRENT_STATUS="$STATUS"
    break
  fi
done

if [ "$ALL_COMPLETE" = true ]; then
  # Workflow is complete, nothing to remind
  exit 0
fi

# Workflow is active but not complete -- inject reminder
echo "WORKFLOW REMINDER: Zero-to-ship workflow is still active. Phase '$CURRENT_PHASE' has status '$CURRENT_STATUS'. Continue to the next phase. Do not stop until all 6 phases (DISCOVER, DESIGN, SCAFFOLD, IMPLEMENT, REVIEW, SHIP) are complete." >&2
exit 2
