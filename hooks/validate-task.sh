#!/bin/bash
# dev-squad: TaskCompleted hook
# Ensure tests pass before marking a task complete.
# Wraps test invocations in `timeout` so a hanging suite (e.g. integration test
# waiting on network) cannot block TaskCompleted indefinitely. Audit (v4.15.3):
# previously had no timeout, runaway tests could stall forever.

TIMEOUT_SECS=120

run_with_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SECS" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    # macOS via coreutils brew install
    gtimeout "$TIMEOUT_SECS" "$@"
  else
    # No timeout available — run anyway, surface warning
    echo "WARNING: 'timeout' command not found; test run may hang indefinitely. Install coreutils for safety." >&2
    "$@"
  fi
}

# Detect project type and run tests
if [ -f "package.json" ]; then
  run_with_timeout npm test --silent 2>/dev/null
  rc=$?
  if [ $rc -eq 124 ]; then
    echo "Tests timed out after ${TIMEOUT_SECS}s. Check for hanging integration tests or network calls."
    exit 2
  fi
  if [ $rc -ne 0 ]; then
    echo "Tests failing. Fix tests before marking task complete."
    exit 2  # Block completion
  fi
elif [ -f "go.mod" ]; then
  run_with_timeout go test ./... 2>/dev/null
  rc=$?
  if [ $rc -eq 124 ]; then
    echo "Tests timed out after ${TIMEOUT_SECS}s."
    exit 2
  fi
  if [ $rc -ne 0 ]; then
    echo "Tests failing. Fix tests before marking task complete."
    exit 2  # Block completion
  fi
elif [ -f "Makefile" ] && grep -q "^test:" Makefile 2>/dev/null; then
  run_with_timeout make test 2>/dev/null
  rc=$?
  if [ $rc -eq 124 ]; then
    echo "Tests timed out after ${TIMEOUT_SECS}s."
    exit 2
  fi
  if [ $rc -ne 0 ]; then
    echo "Tests failing. Fix tests before marking task complete."
    exit 2  # Block completion
  fi
fi

exit 0
