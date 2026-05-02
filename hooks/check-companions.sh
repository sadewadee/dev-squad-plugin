#!/bin/bash
# check-companions.sh
# SessionStart hook — detects missing dev-squad companion plugins + MCP servers.
# Outputs non-blocking warning. Runs every session (no throttling in v4.9.0).

set +e

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"
MANIFEST="${PLUGIN_ROOT}/.claude-plugin/companions.json"

if [ ! -f "$MANIFEST" ]; then
  exit 0
fi

# Quick sanity: jq + manifest valid
if ! command -v jq >/dev/null 2>&1; then
  echo "[dev-squad] companion check skipped: jq not installed" >&2
  exit 0
fi

if ! jq empty "$MANIFEST" 2>/dev/null; then
  echo "[dev-squad] companion check skipped: manifest invalid JSON" >&2
  exit 0
fi

# Detect installed plugins (via filesystem)
INSTALLED_PLUGINS=""
if [ -d "$HOME/.claude/plugins" ]; then
  INSTALLED_PLUGINS=$(ls -1 "$HOME/.claude/plugins" 2>/dev/null)
fi

# Detect installed MCPs (via claude CLI if available)
INSTALLED_MCPS=""
if command -v claude >/dev/null 2>&1; then
  INSTALLED_MCPS=$(claude mcp list 2>/dev/null | awk '{print $1}')
fi

MISSING_REQUIRED=()
MISSING_RECOMMENDED=()
MISSING_MCPS=()

# Check plugins
while IFS= read -r row; do
  [ -z "$row" ] && continue
  id=$(echo "$row" | jq -r '.id')
  tier=$(echo "$row" | jq -r '.tier')
  marketplace=$(echo "$row" | jq -r '.marketplace')

  # Match by id substring in installed plugin dir names
  if echo "$INSTALLED_PLUGINS" | grep -qiE "^${id}|${id}-skill|${id}-marketplace|^.+-${id}"; then
    continue
  fi

  if [ "$tier" = "required" ]; then
    MISSING_REQUIRED+=("$id|$marketplace")
  else
    MISSING_RECOMMENDED+=("$id|$marketplace")
  fi
done < <(jq -c '.companions.plugins[]' "$MANIFEST")

# Check MCPs
while IFS= read -r row; do
  [ -z "$row" ] && continue
  id=$(echo "$row" | jq -r '.id')
  if [ -n "$INSTALLED_MCPS" ] && echo "$INSTALLED_MCPS" | grep -qE "^${id}$"; then
    continue
  fi
  MISSING_MCPS+=("$id")
done < <(jq -c '.companions.mcp_servers[]' "$MANIFEST")

# Output
TOTAL_MISSING=$((${#MISSING_REQUIRED[@]} + ${#MISSING_RECOMMENDED[@]} + ${#MISSING_MCPS[@]}))

if [ $TOTAL_MISSING -eq 0 ]; then
  exit 0
fi

echo "[dev-squad] Companion check ($TOTAL_MISSING missing):" >&2

if [ ${#MISSING_REQUIRED[@]} -gt 0 ]; then
  echo "  REQUIRED (install before use):" >&2
  for item in "${MISSING_REQUIRED[@]}"; do
    id="${item%|*}"
    marketplace="${item#*|}"
    echo "    - $id ($marketplace)" >&2
  done
fi

if [ ${#MISSING_RECOMMENDED[@]} -gt 0 ]; then
  echo "  RECOMMENDED (degraded mode without):" >&2
  for item in "${MISSING_RECOMMENDED[@]}"; do
    id="${item%|*}"
    marketplace="${item#*|}"
    echo "    - $id ($marketplace)" >&2
  done
fi

if [ ${#MISSING_MCPS[@]} -gt 0 ]; then
  echo "  MCP servers missing:" >&2
  for id in "${MISSING_MCPS[@]}"; do
    echo "    - $id" >&2
  done
fi

echo "" >&2
echo "  Run /dev-squad bootstrap to install missing companions." >&2

exit 0
