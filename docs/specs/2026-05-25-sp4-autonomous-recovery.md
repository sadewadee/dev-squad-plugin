# SP4 — Autonomous Recovery (self-contained debugging + build-error-resolver)

- **Date:** 2026-05-25
- **Status:** Draft for review
- **Branch:** `feat/sp4-autonomous-recovery`
- **Depends on:** SP1 (4.18), SP2 (4.19), SP3 (4.20) merged

## Goal
Make dev-squad's autonomous recovery self-contained, so an unattended (`--auto`) run self-heals without depending on an external plugin:
- **Part A — Self-contained debugging (#2):** 6 agents (auditor, backend, qa-engineer, devops, reviewer + SKILL.md) currently depend ONLY on the EXTERNAL `superpowers:systematic-debugging`. If not installed, structured debugging silently no-ops. Ship `skills/debugging/` (self-contained 4-phase loop) as primary; keep superpowers optional. (Same pattern as SP3's verification fix.)
- **Part B — build-error-resolver (#16):** the self-healing loop's author-retry tier (iters 1-2) handles build/compile errors ad hoc. Add `skills/build-error-resolver/` — a focused minimal-diff, no-architecture-change, iterate-until-green protocol — invoked at iter 1-2 for build/compile/type errors specifically.

## Current state (grounded)
- `superpowers:systematic-debugging` referenced in auditor/backend/qa-engineer/devops/reviewer `.md` + SKILL.md — the external dependency.
- coordinator.md "Self-Healing Loop" (lines 827-951) is already robust: 3 tiers (author retries 1-2 → fresh-eyes qa-engineer Investigation Mode at iter 3 → architect re-design 4-5), thrashing detection (verbatim-identical error → skip tier), `.dev-squad/self-healing-log.md`. SP4 does NOT rewrite this — it makes its building blocks (debugging, build-fix) self-contained.
- Build errors today: author retries + `issuetracker` skill + `ide diagnostics` MCP — no dedicated minimal-diff build-fix protocol.

## Design

### Part A — `skills/debugging/SKILL.md` (new, self-contained)
4-phase evidence-based loop (matches dev-squad's documented "investigate → analyze → hypothesize → implement"): reproduce → locate (read error, narrow to file:line) → hypothesize (root cause, not symptom) → fix minimally → verify (re-run the exact failing command). Rule: "fix root cause, not symptom; one hypothesis at a time; verify with evidence." No external dependency. Note superpowers:systematic-debugging as optional additional technique if installed.
- Update the 6 references: make `dev-squad:debugging` PRIMARY; keep `superpowers:systematic-debugging` OPTIONAL (not removed).

### Part B — `skills/build-error-resolver/SKILL.md` (new)
Focused protocol for build/compile/type errors: (1) capture the exact error + file:line (`ide diagnostics` / build output), (2) fix with the MINIMAL diff — no refactors, no architecture changes, no new abstractions, (3) re-run the SAME build/type command to verify green, (4) if still failing after 2 attempts on the same error → escalate to the self-healing loop's next tier (don't thrash). Explicitly: "minimal diff only; never change architecture to silence a build error; if the fix needs design change, escalate."
- Wire into coordinator.md Self-Healing Loop iter 1-2 (author retries): for build/compile/type errors, the author uses `dev-squad:build-error-resolver`.

## Files
- **New:** `skills/debugging/SKILL.md`, `skills/build-error-resolver/SKILL.md`
- **Modified:** `agents/dev-squad/{auditor,backend,qa-engineer,devops,reviewer}.md` (debugging primary, superpowers optional), `agents/dev-squad/coordinator.md` (self-healing iter 1-2 references build-error-resolver; debugging skill ref if present), `skills/dev-squad/SKILL.md` (matrix + Gotcha/skill list), version → 4.21.0.

## Non-goals
- Do NOT rewrite the existing Self-Healing Loop (it's solid) — only make its building blocks self-contained + add the build-fix protocol.
- Do NOT add permanent recovery agents to the 11-roster — these are skills the existing agents/loop invoke.
- This is the final SP of the autonomous-loop program.

## Verification (honest)
Prompt/skill content — not unit-testable. Verify: skill protocols concrete + terminate; debugging-skill made primary across all 6 refs with superpowers RETAINED optional (graceful); build-error-resolver wired into self-healing iter 1-2 without rewriting the loop; no `mcp__*` literals; version synced; names map `dev-squad:<slug>`. Real efficacy needs a live run.

## Risks
- **build-error-resolver over-fixing** (changing architecture to silence errors) → mitigated by the explicit "minimal diff only, escalate if design change needed" rule + the 2-attempt cap feeding the existing thrashing/escalation logic.
- **Drift from the self-healing loop** → SP4 references the loop's existing tiers rather than duplicating; build-error-resolver is the *technique* used within iter 1-2, not a parallel loop.
