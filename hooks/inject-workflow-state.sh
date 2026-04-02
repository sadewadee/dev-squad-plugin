#!/bin/bash
# dev-squad: SubagentStart hook
# Inject current workflow state into subagent context

WORKFLOW_FILE=".dev-squad/workflow-active"

if [ -f "$WORKFLOW_FILE" ]; then
  echo "=== DEV-SQUAD WORKFLOW STATE ==="
  cat "$WORKFLOW_FILE"
  echo ""
  echo "=== Current phase status — continue from where the workflow left off ==="
fi

exit 0
