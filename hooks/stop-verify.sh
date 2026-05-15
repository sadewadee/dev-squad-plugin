#!/bin/bash
# dev-squad: Stop hook — full verification gate
# Inspired by iamfakeguru/claude-md stop-verify.sh
# Runs tsc + lint + tests before agent can claim "done"
# Only activates when project files exist (not in empty dirs)

# Infinite-loop protection: if stop_hook_active is set, let through
HOOK_INPUT=$(cat - 2>/dev/null || echo "{}")
STOP_HOOK_ACTIVE=$(echo "$HOOK_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('stop_hook_active', False))" 2>/dev/null || echo "False")

if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
  exit 0
fi

# Skip if no project files detected (not in a project directory)
if [ ! -f "tsconfig.json" ] && [ ! -f "package.json" ] && [ ! -f "go.mod" ] && [ ! -f "pyproject.toml" ] && [ ! -f "setup.py" ] && [ ! -f "Cargo.toml" ]; then
  exit 0
fi

# Skip if no dev-squad workflow active
if [ ! -f ".dev-squad/workflow-active" ]; then
  exit 0
fi

ERRORS=""

# v4.15.3: per-command timeout to prevent full Stop hook (300s) being consumed by
# a single slow tsc/eslint/test invocation in a large monorepo.
PER_CMD_TIMEOUT=90

run_timed() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$PER_CMD_TIMEOUT" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$PER_CMD_TIMEOUT" "$@"
  else
    "$@"
  fi
}

# Detect project type and run verification
if [ -f "tsconfig.json" ] || [ -f "package.json" ]; then
  # TypeScript/JavaScript project

  # 1. Type check
  if [ -f "tsconfig.json" ] && command -v npx &>/dev/null; then
    TSC_OUTPUT=$(run_timed npx tsc --noEmit 2>&1)
    rc=$?
    if [ $rc -eq 124 ]; then
      ERRORS="${ERRORS}TypeScript: tsc timed out (${PER_CMD_TIMEOUT}s). "
    elif [ $rc -ne 0 ]; then
      ERROR_COUNT=$(echo "$TSC_OUTPUT" | grep -c "error TS")
      ERRORS="${ERRORS}TypeScript: ${ERROR_COUNT} type errors. "
    fi
  fi

  # 2. Lint
  if [ -f "node_modules/.bin/eslint" ]; then
    LINT_OUTPUT=$(run_timed npx eslint . --quiet 2>&1)
    rc=$?
    if [ $rc -eq 124 ]; then
      ERRORS="${ERRORS}ESLint: timed out (${PER_CMD_TIMEOUT}s). "
    elif [ $rc -ne 0 ]; then
      LINT_COUNT=$(echo "$LINT_OUTPUT" | grep -c "error")
      ERRORS="${ERRORS}ESLint: ${LINT_COUNT} errors. "
    fi
  fi

  # 3. Tests
  if [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    TEST_OUTPUT=$(run_timed npm test --silent 2>&1)
    rc=$?
    if [ $rc -eq 124 ]; then
      ERRORS="${ERRORS}Tests: timed out (${PER_CMD_TIMEOUT}s). "
    elif [ $rc -ne 0 ]; then
      ERRORS="${ERRORS}Tests: failing. "
    fi
  fi

elif [ -f "go.mod" ]; then
  # Go project

  # 1. Build check
  BUILD_OUTPUT=$(run_timed go build ./... 2>&1)
  rc=$?
  if [ $rc -eq 124 ]; then
    ERRORS="${ERRORS}Go build: timed out. "
  elif [ $rc -ne 0 ]; then
    ERRORS="${ERRORS}Go build: failed. "
  fi

  # 2. Vet
  VET_OUTPUT=$(run_timed go vet ./... 2>&1)
  rc=$?
  if [ $rc -eq 124 ]; then
    ERRORS="${ERRORS}Go vet: timed out. "
  elif [ $rc -ne 0 ]; then
    ERRORS="${ERRORS}Go vet: issues found. "
  fi

  # 3. Tests
  TEST_OUTPUT=$(run_timed go test ./... 2>&1)
  rc=$?
  if [ $rc -eq 124 ]; then
    ERRORS="${ERRORS}Go tests: timed out. "
  elif [ $rc -ne 0 ]; then
    ERRORS="${ERRORS}Go tests: failing. "
  fi

elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  # Python project

  # 1. Type check
  if command -v mypy &>/dev/null; then
    MYPY_OUTPUT=$(run_timed mypy . 2>&1)
    rc=$?
    if [ $rc -eq 124 ]; then
      ERRORS="${ERRORS}mypy: timed out. "
    elif [ $rc -ne 0 ]; then
      ERRORS="${ERRORS}mypy: type errors. "
    fi
  fi

  # 2. Lint
  if command -v ruff &>/dev/null; then
    RUFF_OUTPUT=$(run_timed ruff check . 2>&1)
    rc=$?
    if [ $rc -eq 124 ]; then
      ERRORS="${ERRORS}ruff: timed out. "
    elif [ $rc -ne 0 ]; then
      ERRORS="${ERRORS}ruff: lint errors. "
    fi
  fi

  # 3. Tests
  if command -v pytest &>/dev/null; then
    TEST_OUTPUT=$(run_timed pytest --quiet 2>&1)
    rc=$?
    if [ $rc -eq 124 ]; then
      ERRORS="${ERRORS}pytest: timed out. "
    elif [ $rc -ne 0 ]; then
      ERRORS="${ERRORS}pytest: failing. "
    fi
  fi
fi

# If no project files detected, skip verification
if [ -z "$ERRORS" ]; then
  exit 0
fi

# Block stop with errors
echo "STOP BLOCKED — verification failed: ${ERRORS}Fix all errors before claiming done."
exit 2
