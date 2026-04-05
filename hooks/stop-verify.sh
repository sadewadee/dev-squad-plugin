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

ERRORS=""

# Detect project type and run verification
if [ -f "tsconfig.json" ] || [ -f "package.json" ]; then
  # TypeScript/JavaScript project

  # 1. Type check
  if [ -f "tsconfig.json" ] && command -v npx &>/dev/null; then
    TSC_OUTPUT=$(npx tsc --noEmit 2>&1)
    if [ $? -ne 0 ]; then
      ERROR_COUNT=$(echo "$TSC_OUTPUT" | grep -c "error TS")
      ERRORS="${ERRORS}TypeScript: ${ERROR_COUNT} type errors. "
    fi
  fi

  # 2. Lint
  if [ -f "node_modules/.bin/eslint" ]; then
    LINT_OUTPUT=$(npx eslint . --quiet 2>&1)
    if [ $? -ne 0 ]; then
      LINT_COUNT=$(echo "$LINT_OUTPUT" | grep -c "error")
      ERRORS="${ERRORS}ESLint: ${LINT_COUNT} errors. "
    fi
  fi

  # 3. Tests
  if [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    TEST_OUTPUT=$(npm test --silent 2>&1)
    if [ $? -ne 0 ]; then
      ERRORS="${ERRORS}Tests: failing. "
    fi
  fi

elif [ -f "go.mod" ]; then
  # Go project

  # 1. Build check
  BUILD_OUTPUT=$(go build ./... 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}Go build: failed. "
  fi

  # 2. Vet
  VET_OUTPUT=$(go vet ./... 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}Go vet: issues found. "
  fi

  # 3. Tests
  TEST_OUTPUT=$(go test ./... 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}Go tests: failing. "
  fi

elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  # Python project

  # 1. Type check
  if command -v mypy &>/dev/null; then
    MYPY_OUTPUT=$(mypy . 2>&1)
    if [ $? -ne 0 ]; then
      ERRORS="${ERRORS}mypy: type errors. "
    fi
  fi

  # 2. Lint
  if command -v ruff &>/dev/null; then
    RUFF_OUTPUT=$(ruff check . 2>&1)
    if [ $? -ne 0 ]; then
      ERRORS="${ERRORS}ruff: lint errors. "
    fi
  fi

  # 3. Tests
  if command -v pytest &>/dev/null; then
    TEST_OUTPUT=$(pytest --quiet 2>&1)
    if [ $? -ne 0 ]; then
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
