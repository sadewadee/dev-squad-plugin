#!/bin/bash
# dev-squad: TaskCreated hook
# Validate that new tasks have a clear scope before allowing creation

# Read task details from stdin JSON
TASK_INFO=$(cat - 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
subject = d.get('task_subject', '')
desc = d.get('task_description', '')
print(f'{subject}|{desc}')
" 2>/dev/null)

SUBJECT=$(echo "$TASK_INFO" | cut -d'|' -f1)
DESC=$(echo "$TASK_INFO" | cut -d'|' -f2)

# Block tasks with empty or too-vague subjects
if [ -z "$SUBJECT" ] || [ ${#SUBJECT} -lt 5 ]; then
  echo "Task subject is too vague or empty. Provide a clear, specific task description (min 5 chars)."
  exit 2
fi

# Warn about overly broad tasks (but don't block)
if echo "$SUBJECT" | grep -qi "fix everything\|do everything\|implement all\|build entire"; then
  echo "Warning: Task scope seems very broad. Consider breaking into smaller, specific tasks."
  # Don't block, just warn (exit 0)
fi

exit 0
