# Continuous Learning: Project Instincts (v4.23.0 / PR2)

**Branch:** `feat/continuous-learning-instincts` (stacked on `feat/post-ship-enforcement-memory`)
**Implements:** the deferred PR2 from `docs/specs/2026-06-02-post-ship-enforcement-memory.md`.
**Date:** 2026-06-02

## Goal

Make dev-squad self-improving across sessions: capture what happens, distill it into confidence-scored instincts, recall the high-confidence ones automatically, and graduate the proven ones into reusable skills.

## Key constraint that shaped the design

ECC's continuous-learning-v2 distills observations with a **background Haiku agent**. The user is **subscription-only (no API key)** — headless/background agents are not available. So the ECC *pattern* is kept but the *mechanism* changes: distillation is **in-session**, never a daemon.

## Architecture (three tiers)

| Tier | Mechanism | Deterministic? |
|---|---|---|
| **Capture** | `hooks/observe-learning.sh` (PostToolUse `Write\|Edit\|Bash`, async) → `.dev-squad/observations.jsonl` | Yes (bash, no LLM) |
| **Distill** | `dev-squad:continuous-learning` skill, run at Phase 7 LEARN + `/dev-squad evolve` → `.dev-squad/instincts/*.md` | In-session LLM (coordinator) |
| **Recall** | `hooks/inject-workflow-state.sh` (SubagentStart) injects `confidence >= 0.8` instincts | Yes (from PR1) |
| **Graduate** | `/dev-squad evolve` proposes `skills/dev-squad-learned/<slug>/`, manual confirm | Human gate |

## Instinct model

Markdown + frontmatter in `.dev-squad/instincts/<id>.md`: `trigger`, `action`, `domain`, `confidence` (0.3→0.9), `scope: project`, `evidence_count`, `last_seen`, plus an `## Evidence` trail. Confidence rises +0.1 per repeat (cap 0.9), falls -0.2 on contradiction. Project-scoped by construction (`.dev-squad/` is per-project) → no cross-project contamination; only graduated skills go global. `recursive-decision-ledger` (harvested) supplies the evidence/promotion discipline: confidence is evidence, never proof.

## Files

- **New:** `hooks/observe-learning.sh`, `skills/continuous-learning/SKILL.md`, `skills/recursive-decision-ledger/SKILL.md` (ECC), `commands/evolve.md`, this spec.
- **Edited:** `hooks/hooks.json` (PostToolUse wiring), `agents/dev-squad/coordinator.md` (Phase 7 distillation step + 2 skills), `skills/dev-squad/SKILL.md` (command list + 2 pattern rows + skill-matrix rows), `.claude-plugin/{plugin,marketplace}.json` (4.23.0), `CHANGELOG.md`.

## Verification

- `observe-learning.sh` functionally tested in an isolated dir: correctly wrote `err:1` for an `npm ERR!` failure, `err:0` for success, captured an `Edit` signature, and **no-opped with no `.dev-squad/`** present. `bash -n` clean, executable.
- `hooks.json` + both manifests validate as JSON.

## Not done (future)

- User-prompt/correction capture (needs a `UserPromptSubmit` hook + privacy consideration).
- Observation-log size cap beyond archive rotation.
- Auto-graduation (kept manual on purpose).
