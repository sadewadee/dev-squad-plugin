#!/bin/bash
# Dev-Squad Plugin Auto-Update Check
# Runs on SessionStart — checks GitHub for newer version, auto-pulls if available

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"

# Get current installed version
CURRENT_VERSION=$(grep '"version"' "$PLUGIN_JSON" 2>/dev/null | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')

if [ -z "$CURRENT_VERSION" ]; then
  exit 0  # Can't determine version, skip silently
fi

# Check if this is a git repo
if [ ! -d "$PLUGIN_DIR/.git" ]; then
  exit 0  # Not a git repo, skip
fi

cd "$PLUGIN_DIR" || exit 0

# Fetch latest tags silently (timeout 5s to not block session)
timeout 5 git fetch --tags --quiet 2>/dev/null || exit 0

# Get latest remote tag
LATEST_TAG=$(git tag -l 'v*' --sort=-v:refname 2>/dev/null | head -1)
LATEST_VERSION="${LATEST_TAG#v}"

if [ -z "$LATEST_VERSION" ]; then
  exit 0  # No tags found, skip
fi

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  exit 0  # Already up to date
fi

# New version available — auto-pull
echo "[dev-squad] Updating: v$CURRENT_VERSION → v$LATEST_VERSION" >&2

git checkout main --quiet 2>/dev/null
git pull origin main --quiet 2>/dev/null

if [ $? -eq 0 ]; then
  echo "[dev-squad] Updated to v$LATEST_VERSION. Restart Claude Code to apply." >&2
else
  echo "[dev-squad] Update available: v$LATEST_VERSION (auto-pull failed, run: cd $PLUGIN_DIR && git pull)" >&2
fi

exit 0
