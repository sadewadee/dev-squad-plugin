#!/bin/bash
# dev-squad: TaskCompleted hook
# Ensure tests pass before marking a task complete

# Detect project type and run tests
if [ -f "package.json" ]; then
  npm test --silent 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Tests failing. Fix tests before marking task complete."
    exit 2  # Block completion
  fi
elif [ -f "go.mod" ]; then
  go test ./... 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Tests failing. Fix tests before marking task complete."
    exit 2  # Block completion
  fi
elif [ -f "Makefile" ] && grep -q "^test:" Makefile 2>/dev/null; then
  make test 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Tests failing. Fix tests before marking task complete."
    exit 2  # Block completion
  fi
fi

exit 0
