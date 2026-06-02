#!/bin/bash
# dev-squad: SubagentStart hook
# Deterministic context injection (fires 100% — does NOT depend on the agent
# remembering to read memory in prose). Injects, in order:
#   1. Workflow state (resume from current phase)
#   2. L3 curated project memory (.dev-squad/memory.md)
#   3. L4 known traps (.dev-squad/gotchas.md)
#   4. L2 high-confidence learned instincts (.dev-squad/instincts/ — populated by continuous-learning, PR2)
#   5. L1 mandatory episodic-recall directive (the instruction fires 100%; the recall is the agent's to run)

DS=".dev-squad"
WORKFLOW_FILE="$DS/workflow-active"

# Reset reminder flag on new subagent start (fresh chance to remind)
rm -f "$DS/.hook-reminded" 2>/dev/null

# Nothing to inject outside a dev-squad project
[ -d "$DS" ] || exit 0

# 1. Workflow state
if [ -f "$WORKFLOW_FILE" ]; then
  echo "=== DEV-SQUAD WORKFLOW STATE ==="
  cat "$WORKFLOW_FILE"
  echo ""
  echo "=== Current phase status — continue from where the workflow left off ==="
  echo ""
fi

# 2. L3 — curated project memory (decisions/conventions). Head-limited to keep context small.
if [ -f "$DS/memory.md" ]; then
  echo "=== PROJECT MEMORY (.dev-squad/memory.md — read before acting; do NOT re-derive decisions already made) ==="
  head -80 "$DS/memory.md"
  echo ""
fi

# 3. L4 — known traps (mistakes not to repeat)
if [ -f "$DS/gotchas.md" ]; then
  echo "=== KNOWN TRAPS (.dev-squad/gotchas.md — do NOT repeat these) ==="
  cat "$DS/gotchas.md"
  echo ""
fi

# 4. L2 — high-confidence instincts (auto-distilled patterns; continuous-learning populates these in PR2)
if [ -d "$DS/instincts" ]; then
  HIGH=$(grep -rl 'confidence: 0\.[89]' "$DS"/instincts/*.md 2>/dev/null)
  if [ -n "$HIGH" ]; then
    echo "=== LEARNED INSTINCTS (high-confidence patterns observed in this project) ==="
    for f in $HIGH; do sed -n '1,8p' "$f"; echo "---"; done
    echo ""
  fi
fi

# 5. L1 — mandatory episodic recall. The directive is deterministic; running the search is the agent's job.
echo "=== MANDATORY RECALL (before debugging / review / any 'this is new' assumption) ==="
echo "Dispatch the 'search-conversations' agent (episodic-memory) for this task's topic BEFORE forming hypotheses."
echo "Past sessions hold tried-and-rejected approaches and prior root causes. Skipping recall = re-deriving solved problems — the #1 cause of wrong debugging."
echo ""

exit 0
