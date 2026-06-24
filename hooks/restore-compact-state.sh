#!/bin/bash
# dev-squad: SessionStart hook — post-compaction context restore
# Closes the loop with pre-compact-save.sh. That hook WRITES .dev-squad/pre-compact-state.md
# on PreCompact; this hook READS it back on the SessionStart that fires immediately after a
# compaction (source=compact), so the saved state is deterministically re-injected — instead of
# relying on the agent remembering to open the file in prose (which fires ~50-80%).

DS=".dev-squad"
STATE_FILE="$DS/pre-compact-state.md"

# Nothing to restore outside a dev-squad project, or if no snapshot was ever saved.
[ -f "$STATE_FILE" ] || exit 0

# Only restore after a compaction. On a fresh startup/resume the live context is intact and
# re-injecting an old snapshot would just be stale noise.
INPUT=$(cat - 2>/dev/null || echo '{}')
SOURCE=$(printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('source',''))" 2>/dev/null)

# Fallback if python3 is unavailable: match the raw source field directly.
if [ -z "$SOURCE" ]; then
  printf '%s' "$INPUT" | grep -qE '"source"[[:space:]]*:[[:space:]]*"compact"' && SOURCE="compact"
fi

[ "$SOURCE" = "compact" ] || exit 0

echo "=== RESTORED STATE (re-injected after context compaction — from .dev-squad/pre-compact-state.md) ==="
cat "$STATE_FILE"
echo ""
echo "=== Continue from the state above: this is what was active before the context was compacted. ==="
echo ""

exit 0
