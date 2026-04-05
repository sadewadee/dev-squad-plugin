#!/bin/bash
# dev-squad: SessionStart hook — self-correction log
# Inspired by iamfakeguru/claude-md gotchas.md pattern
# At session start, remind agent to check past mistakes

GOTCHAS_FILE=".dev-squad/gotchas.md"

if [ -f "$GOTCHAS_FILE" ]; then
  LINES=$(wc -l < "$GOTCHAS_FILE" | tr -d ' ')
  if [ "$LINES" -gt 0 ]; then
    echo "REMINDER: .dev-squad/gotchas.md has ${LINES} lines of past mistakes/lessons. Read it before starting work to avoid repeating errors."
  fi
fi

exit 0
