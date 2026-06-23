#!/bin/bash
# dev-squad: SubagentStart hook
# Deterministic context injection (fires 100% — does NOT depend on the agent
# remembering to read memory in prose). Injects layered memory in priority order:
#   0. L0 System of Record (.dev-squad/record.md) — AUTHORITATIVE, overrides on conflict
#   1. Workflow state (resume from current phase)
#   2. L3 working memory (.dev-squad/memory.md)
#   3. L4 known traps (.dev-squad/gotchas.md)
#   4. L2 semantic/instincts (.dev-squad/instincts/ — populated by continuous-learning)
#   5. L1 mandatory episodic-recall directive

DS=".dev-squad"
WORKFLOW_FILE="$DS/workflow-active"

# Reset reminder flag on new subagent start (fresh chance to remind)
rm -f "$DS/.hook-reminded" 2>/dev/null

# Nothing to inject outside a dev-squad project
[ -d "$DS" ] || exit 0

# 0. L0 — System of Record (structured, versioned, authoritative; injected FIRST — wins on conflict)
if [ -f "$DS/record.md" ]; then
  echo "=== SYSTEM OF RECORD (.dev-squad/record.md — AUTHORITATIVE: on conflict with any other memory, this wins) ==="
  cat "$DS/record.md"
  echo ""
fi

# 1. Workflow state
if [ -f "$WORKFLOW_FILE" ]; then
  echo "=== DEV-SQUAD WORKFLOW STATE ==="
  cat "$WORKFLOW_FILE"
  echo ""
  echo "=== Current phase status — continue from where the workflow left off ==="
  echo ""
fi

# 2. L3 — working memory (decisions/conventions). Head-limited to keep context small.
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

# 4.5 Design system — make the Phase 3.5 design spec a LIVING GATE, not an inert doc.
#      The designer writes .dev-squad/design/*.md in Phase 3.5; without this the frontend
#      agent is only told in prose to read it (fires ~50-80%) and silently defaults to raw
#      shadcn/Tailwind values. Injecting the tokens here guarantees every UI-writing subagent
#      sees the binding palette/type/spacing, head-limited, with a pointer to the rest.
if [ -f "$DS/design/design-tokens.md" ]; then
  echo "=== DESIGN SYSTEM (.dev-squad/design/design-tokens.md — BINDING for any UI/component code; do NOT default to raw shadcn/Tailwind values) ==="
  head -60 "$DS/design/design-tokens.md"
  echo ""
  echo "Full design spec — read the relevant file before writing UI:"
  for f in visual-spec component-inventory responsive-spec drill-down-spec; do
    [ -f "$DS/design/$f.md" ] && echo "  - .dev-squad/design/$f.md"
  done
  echo ""
fi

# 5. L1 — mandatory episodic recall. The directive is deterministic; running the search is the agent's job.
echo "=== MANDATORY RECALL (before debugging / review / any 'this is new' assumption) ==="
echo "Dispatch the 'search-conversations' agent (episodic-memory) for this task's topic BEFORE forming hypotheses."
echo "Past sessions hold tried-and-rejected approaches and prior root causes. Skipping recall = re-deriving solved problems — the #1 cause of wrong debugging."
echo ""

# 6. Minimalism ladder — fires 100% before any subagent writes code (the prose Rule 2
#    in CLAUDE.md only fires ~50-80%). Kills the most expensive failure mode: building
#    your own thing instead of using the stdlib / native feature / installed dep that
#    already exists. Full reflex + commands: dev-squad:simp skill, /dev-squad simp-review.
echo "=== MINIMALISM LADDER (before writing any non-trivial code — stop at the first rung that holds) ==="
echo "1. Does this need to exist at all? Speculative = skip it, say so in one line. (YAGNI)"
echo "2. Stdlib does it? Use it."
echo "3. Native platform feature covers it? (<input type=date> over a lib, CSS over JS, DB constraint over app code) Use it."
echo "4. Already-installed dependency solves it? Check the manifest FIRST. Never add a new dep for what an installed one — or a few lines — already does."
echo "5. Can it be one line? One line. Only then: the minimum code that works."
echo "Verify rungs 2-4 (check the manifest, query context7, grep-github) — do not guess that a custom build is needed."
echo "NEVER lazy on: input validation at trust boundaries, data-loss error handling, security, accessibility, anything explicitly requested."
echo ""

exit 0
