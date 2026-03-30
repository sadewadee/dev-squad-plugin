#!/bin/bash
# dev-squad: TeammateIdle hook
# Block teammate from going idle if they have incomplete tasks in the workflow

WORKFLOW_FILE=".dev-squad/workflow-active"

if [ -f "$WORKFLOW_FILE" ]; then
  INCOMPLETE=$(grep -c '"pending"\|"in_progress"' "$WORKFLOW_FILE" 2>/dev/null || echo 0)
  if [ "$INCOMPLETE" -gt 0 ]; then
    echo "dev-squad workflow has $INCOMPLETE incomplete phases. Continue working or hand off remaining tasks to coordinator before going idle."
    exit 2  # Block idle
  fi
fi

exit 0
