#!/bin/bash
# dev-squad: PreCompact hook
# Save critical state before context compaction (~167K tokens)
# Producer half of the compaction loop: restore-compact-state.sh re-injects this file
# deterministically on the SessionStart that fires right after compaction (source=compact).

STATE_DIR=".dev-squad"
STATE_FILE="$STATE_DIR/pre-compact-state.md"
WORKFLOW_FILE="$STATE_DIR/workflow-active"
PLAN_FILE="$STATE_DIR/master-plan.md"

# Only save if we're in a dev-squad project
if [ ! -d "$STATE_DIR" ]; then
  exit 0
fi

mkdir -p "$STATE_DIR"

{
  echo "# Pre-Compact State (auto-saved before context compaction)"
  echo "Saved at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""

  # Save workflow phase
  if [ -f "$WORKFLOW_FILE" ]; then
    echo "## Workflow State"
    cat "$WORKFLOW_FILE"
    echo ""
  fi

  # Save master plan summary
  if [ -f "$PLAN_FILE" ]; then
    echo "## Master Plan (first 50 lines)"
    head -50 "$PLAN_FILE"
    echo ""
  fi

  # Save recently modified files
  echo "## Recently Modified Files"
  if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
    git diff --name-only HEAD 2>/dev/null | head -20
  else
    find . -name "*.ts" -o -name "*.tsx" -o -name "*.go" -o -name "*.py" | xargs ls -t 2>/dev/null | head -20
  fi
  echo ""

  # Save gotchas
  if [ -f "$STATE_DIR/gotchas.md" ]; then
    echo "## Gotchas (mistakes to avoid)"
    cat "$STATE_DIR/gotchas.md"
    echo ""
  fi

} > "$STATE_FILE"

exit 0
