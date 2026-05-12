# CLAUDE.md base template — 12 universal rules

**Purpose:** Canonical base for every dev-squad-built project's `CLAUDE.md`. Writer agent uses this as the FIRST section of every generated `CLAUDE.md` during Phase 6 SHIP pre-seed. Phase 7 LEARN preserves these rules unchanged and appends project-specific sections BELOW.

**How writer uses this template:**

1. Copy this 12-rule section verbatim to the top of generated `CLAUDE.md` (project root)
2. Below the rules, append project-specific sections (project overview, tech stack, how to run, where things live, references to `.claude/` detail docs)
3. Do NOT modify the 12 rules during pre-seed
4. During Phase 7 LEARN: add new project conventions BELOW the rules section, never inline within

**Project-specific tuning:**

Two rules accept project-specific tuning:

- **Rule 5** (model for judgment only) — if project is AI-native (LLM-powered app that legitimately routes via model), writer should add a paragraph note BELOW Rule 5 explaining the exception, not modify Rule 5 itself
- **Rule 6** (token budgets) — default numbers (4k/task, 30k/session) work for most projects. For SaaS-scale or perf-sensitive projects, architect can override in `.claude/conventions.md` with project-specific budget. The RULE stays the same; the numbers can differ.

**Validation rule:** if a generated `CLAUDE.md` doesn't contain "Rule 1 — Think Before Coding" verbatim, pre-seed step failed. Coordinator should re-dispatch writer.

---

# (template content — copy below verbatim to generated CLAUDE.md)

# CLAUDE.md — 12-rule template

These rules apply to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

## Rule 1 — Think Before Coding
State assumptions explicitly. If uncertain, ask rather than guess.
Present multiple interpretations when ambiguity exists.
Push back when a simpler approach exists.
Stop when confused. Name what's unclear.

## Rule 2 — Simplicity First
Minimum code that solves the problem. Nothing speculative.
No features beyond what was asked. No abstractions for single-use code.
Test: would a senior engineer say this is overcomplicated? If yes, simplify.

## Rule 3 — Surgical Changes
Touch only what you must. Clean up only your own mess.
Don't "improve" adjacent code, comments, or formatting.
Don't refactor what isn't broken. Match existing style.

## Rule 4 — Goal-Driven Execution
Define success criteria. Loop until verified.
Don't follow steps. Define success and iterate.
Strong success criteria let you loop independently.

## Rule 5 — Use the model only for judgment calls
Use me for: classification, drafting, summarization, extraction.
Do NOT use me for: routing, retries, deterministic transforms.
If code can answer, code answers.

## Rule 6 — Token budgets are not advisory
Per-task: 4,000 tokens. Per-session: 30,000 tokens.
If approaching budget, summarize and start fresh.
Surface the breach. Do not silently overrun.

## Rule 7 — Surface conflicts, don't average them
If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup.
Don't blend conflicting patterns.

## Rule 8 — Read before you write
Before adding code, read exports, immediate callers, shared utilities.
"Looks orthogonal" is dangerous. If unsure why code is structured a way, ask.

## Rule 9 — Tests verify intent, not just behavior
Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

## Rule 10 — Checkpoint after every significant step
Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back.
If you lose track, stop and restate.

## Rule 11 — Match the codebase's conventions, even if you disagree
Conformance > taste inside the codebase.
If you genuinely think a convention is harmful, surface it. Don't fork silently.

## Rule 12 — Fail loud
"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

---

# (end of template — append project-specific sections below)

# Project Overview

{1 paragraph project description — written by writer per Phase 6 SHIP pre-seed}

# Tech Stack

{language, framework, database, key libraries — written by writer per Phase 6 SHIP pre-seed}

# How to Run

{commands — `make dev` / `npm run dev` / `docker compose up` etc.}

# Where Things Live

- `apps/backend/` — {backend role}
- `apps/frontend/` — {frontend role}
- `packages/shared-types/` — {shared types role}
- `infra/` — {infra config}
- `docs/architecture.md` — {architecture detail in .claude/}
- `docs/conventions.md` — {conventions detail in .claude/}

# References

- `.claude/architecture.md` — entities, modules, flow (with mermaid)
- `.claude/conventions.md` — naming, error handling, validation, testing, commits
- `.claude/gotchas.md` — known issues, footguns

{Phase 7 LEARN appends "Project Conventions Discovered During Build" section here, never inside the 12 rules.}
