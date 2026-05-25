# SP2 — Scored Evaluator Loop (self-correcting phase gates)

- **Date:** 2026-05-25
- **Status:** Draft for review
- **Branch:** `feat/sp2-scored-evaluator-loop`
- **Depends on:** SP1 (merged, v4.18.0)

## Goal

Upgrade dev-squad's phase gates from binary PASS/FAIL ("deliverable present / not broken") to **scored evaluators (0-100 vs a rubric) with retry-on-feedback + plateau detection**. A weak PRD/design/scaffold gets regenerated with specific feedback until it scores above threshold — instead of passing merely because it exists. This is the "self-correcting" engine.

## Current state (grounded)
- `agents/dev-squad/coordinator.md` "Phase Gate Decision (Judge Pattern)" (lines 696-731): a haiku judge returns `PASS | FAIL` + one-line reason; instruction is "Approve unless a deliverable is genuinely missing or broken" (low bar). FAIL → fix + re-dispatch (max 3 → escalate).
- Phase 5 already has a formal iteration loop (re-dispatch → verify → rollback on regression → anti-thrash) for P0/P1 findings — SP2 mirrors that discipline for **gate quality**, not just findings.
- "Confidence Scoring" (0-100, filter <80) already exists in Phase 5 review — SP2 generalizes scoring to phase gates.

## Design

1. **Scored evaluator replaces the pass/fail judge.** The evaluator scores an artifact 0-100 against a per-phase rubric (weighted dimensions) and returns specific, actionable feedback per dimension. Output: overall score + per-dimension scores + feedback list. Model: `haiku` for cheap/structural gates, `sonnet` for PRD + Design (judgment-heavy).
2. **Retry-with-feedback loop.** If `score < threshold`: re-dispatch the phase's lead agent WITH the evaluator feedback → regenerate → re-score. Bounded by `max_iters`. **Plateau detection:** if the score improves by `< plateau_delta` between consecutive iterations, stop (diminishing returns). Mirror Phase 5's rollback + anti-thrashing rules.
3. **Rubrics (inline in coordinator.md, compact).** Concrete rubrics for the 2 highest-value gates — **Phase 1 PRD** and **Phase 3.5 Design**. All other gates use a generic completeness + correctness rubric. (Scope discipline: don't over-rubric every gate.)
4. **Params (defaults; tunable via `zero-to-ship.json` `gate_defaults`):** `threshold: 80`, `max_iters: 3`, `plateau_delta: 5`.
5. **Ties to SP1 `--auto`:** in auto mode, a gate that can't reach threshold after `max_iters` (or plateaus) is a quality-floor concern → record + feed SP1's fail-loud termination. In interactive mode → escalate to the user with the score + feedback.

## Rubric shape (example — Phase 1 PRD)
| Dimension | Weight | What scores high |
|---|---|---|
| Scope clarity | 0.25 | problem, users, success criteria explicit |
| Completeness | 0.25 | all required PRD sections present + concrete (no TBD) |
| Feasibility | 0.20 | scope matches stated stack/constraints |
| Testability | 0.15 | acceptance criteria are verifiable |
| Risk coverage | 0.15 | key risks/edge cases named |

(Design rubric: tokens concrete, ≥3 real references, responsive+motion specified, anti-pattern list project-specific, component inventory complete. Generic rubric: completeness + correctness + no-placeholder.)

## Files
- `agents/dev-squad/coordinator.md` — rewrite "Phase Gate Decision" → scored evaluator + retry/plateau loop; add the 3 rubrics (PRD, Design, generic) inline.
- `commands/build.md` — phase-gate references point to the scored evaluator; PRD (Phase 1) + Design (Phase 3.5) gates name their rubric.
- `.claude-plugin/workflows/zero-to-ship.json` + `_schema.json` — add optional `gate_defaults` (threshold / max_iters / plateau_delta).
- `skills/dev-squad/SKILL.md` — update the "Phase Gate Judge" / Confidence-Scoring pattern notes to reflect scoring.

## Non-goals
- Do NOT change Phase 5's existing P0/P1 iteration loop (already solid).
- SP3 (adversarial security + verification deep gates), SP4 (autonomous recovery) — out of scope.

## Verification (honest)
SP2 is almost entirely prompt/orchestration — NOT unit-testable like SP1's hooks. Verify by: (a) coordinator.md gate logic internally consistent + loop provably terminates (`max_iters` + plateau), (b) interactive-vs-auto branching correct, (c) no contradiction with the existing Phase 5 loop or SP1, (d) `jq` + schema validation if `zero-to-ship.json` is touched. **Real efficacy is only provable by a live `/dev-squad build` run** — same caveat as SP1.

## Risks
- **LLM scoring is subjective/noisy** → mitigate with concrete weighted rubric dimensions + plateau detection (prevents endless regeneration chasing noise) + iter cap.
- **Cost** → each gate now scores + may regenerate. Mitigate: haiku for cheap gates, `max_iters: 3`, and in auto mode the SP1 governor's dispatch/wall-clock budget bounds total work.
