#!/bin/bash
# validate-workflow-schema.sh
# SessionStart hook (dev-only) — validates workflow JSON files for drift.
# Runs ONLY when cwd is the dev-squad-plugin repo itself (not in user projects).
# Output is informational; never blocking.

set +e

# Detect: only run in dev-squad-plugin repo
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(pwd)}"
PLUGIN_JSON="${PLUGIN_ROOT}/.claude-plugin/plugin.json"

if [ ! -f "$PLUGIN_JSON" ]; then
  exit 0
fi

# Verify this IS the dev-squad-plugin repo (not user installing dev-squad as dependency)
PLUGIN_NAME=$(jq -r '.name // empty' "$PLUGIN_JSON" 2>/dev/null)
if [ "$PLUGIN_NAME" != "dev-squad" ]; then
  exit 0
fi

# Verify cwd is the source repo (has agents/ + workflows/ source dirs)
if [ ! -d "${PLUGIN_ROOT}/.claude-plugin/workflows" ] || [ ! -d "${PLUGIN_ROOT}/agents" ]; then
  exit 0
fi

WORKFLOWS_DIR="${PLUGIN_ROOT}/.claude-plugin/workflows"
AGENTS_DIR="${PLUGIN_ROOT}/agents"

DRIFT_COUNT=0
WARNINGS=()

# Use null-delimited find + while loop to handle paths with spaces
while IFS= read -r -d '' wf; do
  WF_NAME=$(basename "$wf")

  # 1. Validate JSON syntax
  if ! jq empty "$wf" 2>/dev/null; then
    WARNINGS+=("[$WF_NAME] INVALID JSON syntax")
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    continue
  fi

  # 2. Required top-level fields
  for field in workflow_id schema_version version name phases; do
    if ! jq -e ".$field" "$wf" >/dev/null 2>&1; then
      WARNINGS+=("[$WF_NAME] missing required field: .$field")
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
    fi
  done

  # 3. Verify each lead_agent file exists
  while IFS= read -r agent; do
    [ -z "$agent" ] && continue
    [ "$agent" = "self" ] && continue
    AGENT_NAME="${agent#dev-squad:}"
    if [ ! -f "${AGENTS_DIR}/${AGENT_NAME}.md" ]; then
      WARNINGS+=("[$WF_NAME] references missing agent file: ${AGENT_NAME}.md")
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
    fi
  done < <(jq -r '.phases[].lead_agent' "$wf" 2>/dev/null | sort -u)

  # 4. Verify parallel_agents files exist
  while IFS= read -r agent; do
    [ -z "$agent" ] && continue
    AGENT_NAME="${agent#dev-squad:}"
    if [ ! -f "${AGENTS_DIR}/${AGENT_NAME}.md" ]; then
      WARNINGS+=("[$WF_NAME] parallel reference missing: ${AGENT_NAME}.md")
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
    fi
  done < <(jq -r '.phases[].parallel_agents[]?' "$wf" 2>/dev/null | sort -u)

done < <(find "$WORKFLOWS_DIR" -maxdepth 1 -name "*.json" ! -name "_schema.json" -print0 2>/dev/null)

# Output results
if [ $DRIFT_COUNT -gt 0 ]; then
  echo "[dev-squad workflow drift] $DRIFT_COUNT issue(s) detected:" >&2
  for w in "${WARNINGS[@]}"; do
    echo "  - $w" >&2
  done
  echo "  Edit .claude-plugin/workflows/*.json + agents/*.md to resolve." >&2
fi

exit 0
