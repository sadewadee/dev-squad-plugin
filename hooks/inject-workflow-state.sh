#!/bin/bash
# dev-squad: SubagentStart hook
# Inject current workflow state into subagent context

WORKFLOW_FILE=".dev-squad/workflow-active"

# Reset reminder flag on new subagent start (fresh chance to remind)
rm -f ".dev-squad/.hook-reminded" 2>/dev/null

if [ -f "$WORKFLOW_FILE" ]; then
  echo "=== DEV-SQUAD WORKFLOW STATE ==="
  cat "$WORKFLOW_FILE"
  echo ""
  echo "=== Current phase status — continue from where the workflow left off ==="
fi

exit 0
