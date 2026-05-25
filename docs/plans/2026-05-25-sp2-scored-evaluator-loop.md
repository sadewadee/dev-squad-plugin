# SP2 Scored Evaluator Loop — Implementation Plan

> Executor: subagent-driven, scaled. SP2 is prompt/orchestration (coordinator.md + build.md) — NOT unit-testable like SP1's hooks. Each substantive task gets a coherence+spec review; trivial config/doc tasks get jq/grep verification.

**Goal:** Turn dev-squad's binary PASS/FAIL phase gate into a scored evaluator (0-100 vs rubric) with retry-on-feedback + plateau detection.

**Branch:** `feat/sp2-scored-evaluator-loop` (off main @ v4.18.0). PR at end. Spec: `docs/specs/2026-05-25-sp2-scored-evaluator-loop.md`.

---

## Task 1: `gate_defaults` config (schema + workflow)

**Files:** `.claude-plugin/workflows/_schema.json`, `.claude-plugin/workflows/zero-to-ship.json`

- [ ] Add optional top-level `gate_defaults` to `_schema.json` properties (NOT in `required`):
```json
"gate_defaults": {
  "type": "object",
  "additionalProperties": false,
  "description": "Defaults for the scored phase-gate evaluator (SP2).",
  "properties": {
    "threshold": { "type": "integer", "minimum": 1, "maximum": 100 },
    "max_iters": { "type": "integer", "minimum": 1 },
    "plateau_delta": { "type": "integer", "minimum": 0 }
  }
}
```
- [ ] Add to `zero-to-ship.json` (top-level, after `auto_defaults`):
```json
"gate_defaults": { "threshold": 80, "max_iters": 3, "plateau_delta": 5 },
```
- [ ] Verify: `jq empty` both files; `CLAUDE_PLUGIN_ROOT="$(pwd)" bash hooks/validate-workflow-schema.sh; echo exit=$?` → exit=0.
- [ ] Commit: `feat(sp2): add gate_defaults to workflow schema + zero-to-ship`

---

## Task 2: coordinator.md — Scored Evaluator (the core)

**Files:** `agents/dev-squad/coordinator.md` (replace the "## Phase Gate Decision (Judge Pattern)" section, lines ~696-731)

- [ ] Replace that whole section with the scored evaluator below (keep the anti-pattern warning about `dev-squad:judge` not being a type):

````markdown
## Phase Gate Decision (Scored Evaluator)

Before transitioning between phases, dispatch a SCORED EVALUATOR (not a binary judge). It scores the phase deliverables 0-100 against a rubric and returns actionable feedback. **There is NO `dev-squad:judge` agent type** — the evaluator is `general-purpose` with `model: "haiku"` (structural gates) or `model: "sonnet"` (Phase 1 PRD + Phase 3.5 Design, which are judgment-heavy).

```
Agent({
  subagent_type: "general-purpose",
  model: "haiku",   // sonnet for Phase 1 PRD + Phase 3.5 Design
  description: "Phase {N} scored evaluation",
  prompt: |
    You are a phase-gate evaluator. Score Phase {N} deliverables 0-100 against the rubric, then list specific actionable feedback.

    **Rubric (weighted dimensions — overall = weighted sum):**
    {paste the phase's rubric from "Gate Rubrics" below; use the Generic rubric if the phase has none}

    **Artifact(s) to score:**
    - Files: {paths}
    - State: {tests passing? reviews done?}

    **Output (exactly this shape):**
    SCORE: {0-100 overall}
    DIMENSIONS:
    - {dimension}: {0-100} — {one-line reason}
    FEEDBACK:
    - {specific, actionable change that would raise the score}   (write "none" if SCORE >= threshold)
})
```

Flow (`threshold` / `max_iters` / `plateau_delta` from `zero-to-ship.json` `gate_defaults`; defaults 80 / 3 / 5):
1. Dispatch evaluator → read SCORE + FEEDBACK.
2. `SCORE >= threshold` → transition to next phase.
3. `SCORE < threshold` AND `iter < max_iters`:
   a. Re-dispatch the phase's LEAD agent with the FEEDBACK appended ("address these items to raise the gate score") → regenerate the artifact.
   b. Re-evaluate; increment `iter`; record `iter`, score, feedback to `.dev-squad/iteration-log.md`.
   c. **Plateau:** if `(new SCORE - previous SCORE) < plateau_delta` → stop looping (diminishing returns).
   d. **Rollback:** if regeneration breaks a previously-passing check/test, `git restore` (same rule as the Phase 5 loop).
4. Still `< threshold` after `max_iters` OR plateau:
   - **Interactive mode:** escalate to the user with the SCORE + FEEDBACK (do not silently pass).
   - **Auto mode** (`.dev-squad/workflow-active` `mode == auto`): record a quality-floor miss to `.dev-squad/iteration-log.md` (line `UNRESOLVED P1: phase {N} gate score {x} < {threshold}`) so SP1's `stop-verify.sh` fail-loud picks it up. Do NOT pass.

**Anti-pattern:** `subagent_type: "judge"` / `"dev-squad:judge"` do not exist → fail "agent type not available" → gate silently skipped. Use the canonical `general-purpose` + model pattern above.

### Gate Rubrics

**Phase 1 PRD** (model: sonnet)
| Dimension | Weight | High score = |
|---|---|---|
| Scope clarity | 0.25 | problem, target users, success criteria explicit |
| Completeness | 0.25 | all PRD sections present + concrete (no TBD) |
| Feasibility | 0.20 | scope matches stated stack/constraints |
| Testability | 0.15 | acceptance criteria are verifiable |
| Risk coverage | 0.15 | key risks/edge cases named |

**Phase 3.5 Design** (model: sonnet)
| Dimension | Weight | High score = |
|---|---|---|
| Token concreteness | 0.25 | real values (hex/rem/ms), not placeholders |
| Reference grounding | 0.20 | >=3 real references with screenshots |
| Responsive + motion | 0.20 | both specified across breakpoints |
| Anti-pattern specificity | 0.20 | project-specific anti-pattern list (not generic) |
| Component completeness | 0.15 | inventory covers the page set |

**Generic** (any other gate; model: haiku)
| Dimension | Weight | High score = |
|---|---|---|
| Completeness | 0.45 | every required deliverable present |
| Correctness | 0.40 | builds/tests pass, no broken artifact |
| No-placeholder | 0.15 | no TBD/TODO/stub left |
````

- [ ] Verify (coherence review): the loop provably terminates (max_iters + plateau), interactive vs auto branch both handled, the `dev-squad:judge` anti-pattern warning retained, no contradiction with the Phase 5 loop (lines ~454-477) or SP1 stop-verify.
- [ ] Commit: `feat(sp2): coordinator scored evaluator + retry/plateau loop + rubrics`

---

## Task 3: build.md — point phase gates at the scored evaluator

**Files:** `commands/build.md`

- [ ] Find the phase-gate references (e.g. "PHASE GATE: Dispatch ... haiku ... verify Phase N deliverables", the Phase 3.5 artifact gate, the Phase 1 gate). Update each to: "dispatch the **Scored Evaluator** (coordinator.md 'Phase Gate Decision (Scored Evaluator)') — Phase 1 uses the PRD rubric (sonnet), Phase 3.5 uses the Design rubric (sonnet), others use the Generic rubric (haiku); loop on feedback until score >= threshold or max_iters/plateau."
- [ ] Keep changes additive/surgical; do not alter unrelated phase logic.
- [ ] Verify (coherence review): every former pass/fail gate now references the scored evaluator; PRD + Design name their rubric; interactive behavior otherwise unchanged.
- [ ] Commit: `feat(sp2): build.md phase gates use scored evaluator`

---

## Task 4: SKILL.md — update gate/scoring pattern notes

**Files:** `skills/dev-squad/SKILL.md`

- [ ] Update the "Phase Gate Judge" row + "Confidence Scoring" row in the v3.0 Orchestration Patterns table to describe the scored evaluator (0-100 + feedback + retry/plateau) instead of pass/fail. Update Gotcha 2 if it says "pass/fail" — keep the "no dev-squad:judge type" point, just reflect scoring.
- [ ] Verify (grep): table mentions scored evaluator; gotcha 2 still warns about the missing judge type.
- [ ] Commit: `docs(sp2): document scored evaluator in SKILL.md`

---

## Task 5: Version bump + PR

**Files:** `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

- [ ] Bump 4.18.0 → 4.19.0 in both; `jq empty` both.
- [ ] Commit: `chore(sp2): v4.19.0 — scored evaluator phase gates`
- [ ] Push branch; open PR (title `feat: SP2 scored evaluator phase gates (self-correcting)`, body = summary + the live-run caveat as an unchecked test-plan item).

---

## Self-review (against spec)
SP2 spec items → tasks: scored evaluator (T2), retry+plateau (T2), rubrics PRD/Design/generic (T2), params (T1), build.md wiring (T3), SP1/auto tie-in (T2 step 4), docs (T4). All mapped. Non-goal honored: Phase 5 P0/P1 loop untouched.
