# Post-Ship Sharpening + Memory Resurrection (v4.22.0)

**Branch:** `feat/post-ship-enforcement-memory`
**Status:** PR1 implemented. PR2 (cross-project learning) deferred — see end.
**Date:** 2026-06-02

---

## Problem

The user reported three things: post-zero2ship agents (debugging, review, testing) are "not sharp" and "often debug wrong"; too much `haiku`; and the memory feature is dead ("agents don't create or read memory").

## Root cause (one disease, several symptoms)

dev-squad routed its **critical path through probabilistic prose** instead of deterministic enforcement, then never verified the step happened. Evidence:

1. **Memory dead — invalid value.** All 11 agents shipped `memory: true`. The Claude Code `memory` field only accepts `user | project | local` (scoped-memory feature, ~v2.1.33). `true` is silently ignored → no memory dir, nothing injected/persisted. The plugin's own `SKILL.md` already documented `memory: project` — the implementation had drifted and nothing caught it.
2. **Dead tool name.** Agent prompts said "search/write **agent-memory**" — a name that maps to no tool → no-op even if memory were active.
3. **Self-healing → opus rule was dead text.** The model matrix declared "self-healing fix loop → opus" but no dispatch applied the override, so the fresh-eyes investigator (the highest-leverage debug step) ran on sonnet — the same tier that just failed.
4. **Gates over-used haiku.** Phase gates defaulted to `haiku`; the user found them too weak.
5. **Capabilities existed but were prose-invoked.** `adversarial-security`, `verification`, `debugging` skills exist but fire ~50-80% (ECC's measured skill-vs-hook number) because invocation was buried prose.

The plugin's own "Known Gotchas 1-4" (judge / plan-reviewer / spec-document-reviewer / chrome-devtools) are all the same failure: a critical step that silently skips with nothing enforcing it.

## Design principle

**Hooks enforce (deterministic, 100%). Prose only describes.** Mirrors ECC's v1→v2 lesson and superpowers' own "you MUST invoke" philosophy.

---

## PR1 — what changed

### 1. Memory resurrection
- All 11 agents: `memory: true` → `memory: project`.
- Killed every `agent-memory` reference → concrete `.dev-squad/memory.md` paths (agents + SKILL.md + build.md + retrospective.md).
- `SKILL.md` "Memory Management Standards" rewritten as a **4-tier model** with a single home in `.dev-squad/`:
  - **L1 Episodic** (episodic-memory transcripts) — recall via `search-conversations`, mandatory in debugging Phase 0.
  - **L2 Instincts** (`.dev-squad/instincts/` — PR2).
  - **L3 Project memory** (`.dev-squad/memory.md`) — curated, shared, hook-injected.
  - **L4 Traps** (`.dev-squad/gotchas.md`) — capture-nudged.
  - Native `memory: project` kept as a redundant per-agent safety-net; `.dev-squad/memory.md` is canonical (hook-owned → can't silently die again).

### 2. Enforcement layer (extends existing hooks — no new hook files)
- `hooks/inject-workflow-state.sh` (SubagentStart): now injects, deterministically, L3 memory head + L4 gotchas + high-confidence L2 instincts + a **mandatory episodic-recall directive**.
- `hooks/check-workflow.sh` (SubagentStop): added **capture enforcement** — if self-healing ran (a bug was worked) but no trap was written, emit a non-blocking "CAPTURE REQUIRED" nudge.

### 3. Debugging recall (the memory↔debugging wire)
- `skills/debugging/SKILL.md`: added **Phase 0: Recall** (episodic + gotchas) before Reproduce. Now a 5-phase loop. Updated the SKILL.md descriptions to match.

### 4. Model sharpening (graduated, cost-aware)
- `coordinator.md` self-healing loop now applies explicit overrides at dispatch: iter-1 author = sonnet (+ build-error-resolver), **iter-2 author = opus**, **iter-3 qa-engineer Investigation Mode = opus**, iter-4-5 architect = opus (unchanged).
- **Gate default flipped off haiku:** phase-gate evaluators default to `sonnet`; `haiku` kept ONLY for a trivial structural boolean (build-passes / file-exists). Propagated across `coordinator.md`, `commands/build.md`, `skills/dev-squad/SKILL.md`, `agents/architect.md`, and `.claude-plugin/workflows/{bug-fix,feature-development}.json`.
- `reviewer` + `auditor`: added `think_harder: true`. (reviewer already auto-loads `adversarial-security` + `security-review`.)

### 5. ECC harvest (selective)
- Copied `react-testing` (RTL/Vitest/MSW/axe + RTL-vs-E2E boundary) and `accessibility` (WCAG 2.2 AA) into `skills/`, attribution `origin: ECC` preserved.
- Wired: `react-testing` → qa-engineer + frontend; `accessibility` → qa-engineer + frontend + designer. Documented both in the SKILL.md skill matrix.
- **Dropped `recursive-decision-ledger` from PR1** — on reading, it is repeated-rollout/optimization with an evidence+promotion ledger, not bug debugging. Its real twin is PR2's instinct confidence-ledger; deferred there.

### 6. Release
- Version `4.21.0` → `4.22.0` in `plugin.json` + `marketplace.json`. CHANGELOG entry.

## Verification
- All 11 agents: `memory: project` (0 remaining `memory: true`).
- 0 remaining `agent-memory` references.
- Remaining `haiku` mentions are all the consistent "sonnet-default, haiku only for trivial structural boolean" caveat.
- Both edited workflow JSONs validate; both edited hooks pass `bash -n` and are executable.

---

## PR2 — deferred (cross-project learning)

The instinct system (ECC continuous-learning pattern, **adapted dev-squad-native**, no headless/daemon — the user is subscription-only):
- Observe hooks (PreToolUse/PostToolUse) → `.dev-squad/observations.jsonl`.
- In-session distillation (SubagentStop or Phase 7 LEARN) → `.dev-squad/instincts/*.md` (confidence-scored, project-scoped).
- High-confidence instincts injected by the SubagentStart hook (L2 — plumbing already added in PR1).
- `/dev-squad evolve` → graduate clusters to `skills/dev-squad-learned/`.
- `recursive-decision-ledger` (harvested) backs the instinct evidence/promotion ledger here.
