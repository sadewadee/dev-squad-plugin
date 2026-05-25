# SP1 — Autonomous Mode (`--auto`) for dev-squad zero-to-ship

- **Date:** 2026-05-25
- **Status:** Draft for review
- **Scope:** SP1 of the "self-correcting autonomous loop (Architecture A)" program
- **Author:** Claude (brainstorm with Sadewa)

---

## 1. Context & goal

dev-squad today runs `/dev-squad build <description>` mostly autonomously — phase gates are already judged by haiku agents, not humans — but it still stops at up to three human touchpoints: (a) SaaS-mode confirmation (conditional), (b) the 10-question SaaS Scope Intake (conditional), and (c) the mandatory Phase 1 PRD approval checkpoint.

**Goal of SP1:** add an `--auto` mode that closes those three touchpoints so a build runs **hands-off after a single human kickoff** — never pausing to ask — while staying **safe and auditable** via a deterministic envelope (no-interaction enforcement + budget governor + quality-floor/fail-loud termination).

**Why Architecture A (in-session, no headless):** true headless (`claude -p` / Agent SDK) effectively requires `ANTHROPIC_API_KEY` (per-token API billing). The user is subscription-only and will not use the API-key path. Therefore autonomy must run **inside a normal interactive session** (human types the command once, then walks away) and be enforced by **hooks**, not by headless invocation. The accepted tradeoff: "attended-start, hands-off-run" — NOT cron-style true-unattended (that would need headless).

This document specifies SP1 only. It is the foundation the later sub-projects build on.

---

## 2. Scope boundary

**In scope (SP1):**
- `--auto` flag parsing + durable `mode: auto` state
- Intake-inference rules for the 3 touchpoints + conservative-default policy for irreversible decisions
- Assumption ledger (auditable record of every inferred decision)
- No-interaction enforcement hook (`AskUserQuestion` hard-blocked in auto mode)
- Budget governor (dispatch / per-phase iteration / wall-clock caps)
- Termination contract (quality-floor check + fail-loud failure report), reusing the existing Stop verification

**Out of scope (later SPs — do NOT build here):**
- **SP2:** scored generator→evaluator→retry loops (upgrade haiku pass/fail gates to scored evaluators). SP1 uses the *existing* pass/fail gates and Phase 5 P0/P1 veto loop as its quality floor.
- **SP3:** adversarial security pipeline + self-contained verification skill as deep autonomous gates.
- **SP4:** autonomous recovery agents (build-error-resolver, agent-debugging).
- **Headless / cron wrapper:** cancelled — incompatible with the no-headless constraint.

---

## 3. Design principles / constraints

1. **No headless.** In-session only. Attended-start, hands-off-run.
2. **Deterministic enforcement via hooks.** Use dev-squad's proven `exit 2` + echo block pattern (as in `guard-dangerous-ops.sh`). The prompt instructs intent; the hook guarantees it.
3. **Default behavior unchanged.** Without `--auto`, `mode` is `interactive` and every new hook/branch is a no-op. Zero regression to the existing interactive workflow. (Rule 3, Rule 11.)
4. **Conservative defaults for irreversible decisions.** Inference is allowed to guess freely on reversible choices; for irreversible/high-blast-radius decisions it must pick the safe default and flag it loudly.
5. **Fail loud (Rule 12).** A run that does not meet the quality floor must never be presented as "shipped." It writes a failure report and surfaces it.
6. **Surgical.** Extend existing hooks/state/state-file; do not restructure the workflow engine.
7. **Budget is approximate.** Without `--max-budget-usd` (a `-p`-only flag), the governor uses dispatch-count + per-phase-iteration + wall-clock as proxies for cost. This is stated honestly, not hidden.

---

## 4. Architecture overview

The whole mechanism is **flag → durable state → propagation → enforcement**:

```
/dev-squad build "..." --auto
   │
   ▼
[Coordinator parses --auto]  (build.md; precedent: --mvp-mode, --saas)
   │  writes mode:auto + auto-config block
   ▼
.dev-squad/workflow-active   ← single source of truth for the run mode
   │
   ├──(read on every subagent start)──► inject-workflow-state.sh
   │        → every agent sees "mode: auto" and follows auto-mode rules
   │
   ├──(read by)──► auto-guard.sh  (PreToolUse: AskUserQuestion)
   │        → if mode==auto: BLOCK the question (exit 2), instruct: infer + log to ledger
   │
   ├──(read by)──► auto-governor  (PreToolUse on dispatch + SubagentStop counter)
   │        → if over budget: BLOCK further dispatch (exit 2), instruct: stop + write report
   │
   ▼
[stop-verify.sh extension]  (Stop hook)
        → if mode==auto: check quality floor (P0/P1 resolved + verification clean + not halted)
          PASS → success report ;  FAIL → write auto-failure-report.md + block stop (exit 2)
```

Nothing new is invented at the engine level. SP1 reuses three existing surfaces — the `workflow-active` state file, the `inject-workflow-state.sh` propagation, and the `exit 2` hook-block convention — and adds inference rules + a ledger.

---

## 5. Components

### C1 — `--auto` flag + mode state

- **Files:** `commands/build.md`, `.claude-plugin/workflows/zero-to-ship.json`, (writes) `.dev-squad/workflow-active`
- **Behavior:** coordinator parses the argument string for `--auto` (same way it already handles `--mvp-mode` / `--saas`). On detection it writes `mode: "auto"` plus an `auto` config block into `.dev-squad/workflow-active` at workflow start. Absent the flag, it writes `mode: "interactive"` (or omits `mode`, treated as interactive).
- **Why state, not just prompt:** the flag is soft (model text-matching). Persisting `mode:auto` to the state file makes it readable by hooks (deterministic) and by every subagent (via `inject-workflow-state.sh`). Belt (prompt) + suspenders (hook).
- **Dependency:** none new.

### C2 — Intake-inference + conservative-default policy

- **Files:** `commands/build.md` (Phase 0 Step 2.5 / 2.5b, Phase 1 checkpoint), `skills/dev-squad/SKILL.md` (user-checkpoints note)
- **Behavior in auto mode:**
  1. **SaaS-mode detection (Step 2.5):** apply the existing keyword heuristic deterministically (3+ keywords → SaaS enabled, else standard). No confirmation question. Record decision + matched keywords + confidence in the ledger.
  2. **SaaS Scope Intake (Step 2.5b, 10 dimensions):** infer each dimension from the description + sensible defaults. Split by reversibility:
     - **Reversible dimensions** → infer freely from the description.
     - **Irreversible / high-blast-radius dimensions** (tenancy strategy / ADR-001, identity hierarchy / Intake Q2, billing+payment provider / ADR-002, compliance scope / Intake Q10) → pick the **conservative default** (e.g., shared-DB + RLS tenancy; no compliance regime unless strongly signalled in the description), mark **LOW confidence**, and surface prominently in the final report. This mirrors build.md's existing "No, standard app" safe-default posture.
  3. **PRD approval checkpoint (Phase 1):** skip the human checkpoint. The existing Phase 1 haiku phase-gate judge becomes the substitute approver (SP2 later upgrades it to a scored evaluator). Record "PRD auto-approved by Phase 1 gate" in the ledger.
- **Note:** inference here is legitimate model judgment (classification/extraction), consistent with Rule 5.

### C3 — Assumption ledger

- **File (runtime, in user project):** `.dev-squad/assumption-ledger.md`
- **Written by:** coordinator (Phase 0 decisions), architect (intake + PRD inferences), and any agent that would otherwise have called `AskUserQuestion`.
- **Read by:** Phase 7 final report (surfaces all LOW-confidence rows prominently); the human on return.
- **Schema (markdown table):**

  | # | Phase | Decision point | Inferred value | Confidence | Source | Risk if wrong |
  |---|-------|----------------|----------------|-----------|--------|---------------|

  - `Confidence`: `high` / `med` / `low`
  - `Source`: `description-derived` / `default` / `heuristic`
  - LOW-confidence + irreversible rows must be visually flagged (e.g., a `**LOW**` marker) so the final report can extract them.

### C4 — `auto-guard.sh` (no-interaction enforcement)

- **File:** `hooks/auto-guard.sh` (bash) + wiring in `hooks/hooks.json`
- **Wiring:** new `PreToolUse` matcher `"AskUserQuestion"`.
- **Contract (proven pattern, from `guard-dangerous-ops.sh`):**
  - Read tool input from stdin JSON (python3 one-liner, same as existing hooks).
  - Read `.dev-squad/workflow-active`; if absent or `mode != auto` → `exit 0` (no-op, preserves interactive default).
  - If `mode == auto` → echo an instruction and `exit 2` to block the call. Message: `"AUTO MODE: do not ask the user. Infer this decision from the project description and conservative defaults, record it in .dev-squad/assumption-ledger.md with a confidence score, then continue. See commands/build.md auto-mode intake-inference rules."`
- **Why reliable:** `exit 2` + message is the same block mechanism dev-squad already uses successfully for dangerous Bash. The agent receives the message and proceeds with inference (which build.md also pre-instructs).

### C5 — `auto-governor.sh` (budget governor)

- **Files:** `hooks/auto-governor.sh` (bash) + wiring in `hooks/hooks.json`. Counters in `.dev-squad/auto-run.json`.
- **Two responsibilities:**
  1. **Increment** counters — wired on `SubagentStop` (alongside `check-workflow.sh`): bump `total_dispatches`.
  2. **Gate** — wired on `PreToolUse` with a **broad matcher (`*`)**, filtering on `tool_name` from the payload to catch a subagent dispatch (resolved, see §13 Q1): before allowing a new dispatch, read counters + `auto.started_at`; if any cap is exceeded → write `halted: true` + `halt_reason` to `auto-run.json`, echo "AUTO GOVERNOR: budget exceeded ({which cap}). Stop dispatching, finalize, and let the termination hook write the report." and `exit 2`.
- **Caps (defaults; tunable in `zero-to-ship.json` `auto` block):**
  - `wall_clock_cap_min`: 480 (8 hours — user accepts long runs for optimal results; this is the PRIMARY budget)
  - `max_total_dispatches`: 300 (runaway / infinite-loop backstop, not a tight budget)
  - `max_iterations_per_phase`: 5 (per-phase anti-thrash; matches the existing Phase 5 loop cap — independent of total runtime)
- **Honest limitation:** no exact USD/token accounting in-session; these are proxies. The governor is a runaway backstop, NOT a cost optimizer — the user has explicitly prioritized optimal results over speed/quota (an 8-hour run is acceptable).
- **Matcher resolution (Q1):** no plugin (incl. ECC) gates the dispatch tool by matcher name, and tool names vary across harnesses (ECC normalizes via a `TOOL_MAP`). So gate with `*` + read `tool_name` (`Task` in standard Claude Code; normalize defensively) rather than betting on one matcher string.

### C6 — Termination (quality-floor + fail-loud)

- **File:** extend `hooks/stop-verify.sh` (Stop hook; already has the `stop_hook_active` re-entrancy guard and skips when no `.dev-squad/workflow-active`).
- **Behavior:** after the existing build/type/lint/test verification:
  - If `mode != auto` → unchanged behavior (current logic).
  - If `mode == auto` → evaluate the **quality floor** (all of):
    1. existing verification clean (no `ERRORS` — reuses current logic),
    2. no unresolved P0/P1 (read `.dev-squad/iteration-log.md` / Phase 5 findings state),
    3. governor did not halt the run (`auto-run.json` not flagged `halted`),
    4. all phases marked complete in `workflow-active`.
  - **Floor met** → `exit 0`; coordinator writes the success completion report (Phase 7).
  - **Floor NOT met** → write `.dev-squad/auto-failure-report.md` (what was attempted, which floor condition failed, blast radius, link to assumption ledger, recommended human action) and `exit 2` to block a false "done". Never present a sub-floor run as shipped.
- **Note:** SP1's floor is **boolean gates** (P0/P1 resolved + verification clean), not a numeric score. The scored floor is SP2.

---

## 6. Data contracts

### 6.1 `.dev-squad/workflow-active` extension

```json
{
  "workflow": "zero-to-ship",
  "mode": "auto",
  "auto": {
    "started_at": "2026-05-25T10:00:00Z",
    "max_total_dispatches": 300,
    "max_iterations_per_phase": 5,
    "wall_clock_cap_min": 480,
    "on_floor_miss": "fail_loud"
  },
  "phases": { "...": "..." }
}
```
(When `mode` is `interactive` or absent, the `auto` block is omitted and all new hooks no-op.)

### 6.2 `.dev-squad/auto-run.json` (governor counters)

```json
{
  "total_dispatches": 0,
  "halted": false,
  "halt_reason": null
}
```

### 6.3 `.dev-squad/assumption-ledger.md` — see C3 schema.

### 6.4 `.dev-squad/auto-failure-report.md` — written only on floor miss; human-facing.

---

## 7. End-to-end control flow (auto run)

1. Human: `/dev-squad build "internal CRM with billing" --auto`, then walks away.
2. Coordinator parses `--auto` → writes `mode:auto` + `auto` block to `workflow-active`.
3. Phase 0: keyword heuristic → SaaS enabled (logs matched keywords to ledger). Infers the 10 intake dimensions; irreversible ones get conservative defaults + LOW flags in ledger. No questions asked.
4. Any agent that tries `AskUserQuestion` → `auto-guard.sh` blocks (exit 2) → agent infers + logs instead.
5. Phases proceed; phase-gate haiku judges substitute for human approval (incl. PRD checkpoint). `auto-governor` increments counters on each SubagentStop and blocks new dispatch if a cap is hit.
6. Phase 5 P0/P1 veto loop runs as today (max 5 iterations).
7. Coordinator finishes → Stop hook (`stop-verify.sh`) runs. Auto-mode floor check:
   - met → success report + assumption ledger surfaced;
   - not met → `auto-failure-report.md` + blocked stop.
8. Human returns, reads completion/failure report + ledger (especially LOW-confidence irreversible assumptions).

---

## 8. Default-mode preservation (regression safety)

Every new behavior keys off `mode == auto` read from `workflow-active`. In interactive mode:
- `auto-guard.sh` → `exit 0` immediately (AskUserQuestion works normally).
- `auto-governor.sh` → `exit 0` (no caps).
- `stop-verify.sh` → existing logic unchanged.
- `build.md` auto-mode branches are gated behind the flag.

Result: an interactive `/dev-squad build` behaves exactly as in v4.17.0.

---

## 9. Error handling & edge cases

1. **Plain-text question leak.** An agent could end a turn with a question in prose (not via `AskUserQuestion`) — in interactive mode this would hang waiting for the absent human. *Mitigation:* build.md auto-mode rule: "never end a turn with a question; make a decision, log it to the ledger, and continue." The hook cannot catch prose, so this is prompt-enforced. Flag for empirical testing.
2. **Hook block not honored.** If `exit 2` somehow does not propagate the message in a given Claude Code version. *Mitigation:* the `exit 2` block is already proven in `guard-dangerous-ops.sh`; low risk. Still, verify empirically (§10).
3. **Governor counter race under Agent-Teams (Mode A parallel).** Concurrent `SubagentStop` increments to `auto-run.json` could race. *Mitigation:* keep increments small and idempotent-ish; accept approximate counts (the cap is a safety backstop, not an exact meter). Document.
4. **Wrong irreversible inference (tenancy/compliance/payment).** Worst-case outcome (expensive retrofit). *Mitigation:* conservative-default policy (C2) + LOW-confidence flag + prominent surfacing in the final report; a future "semi-auto" mode (not SP1) could re-introduce confirmation for just these.
5. **No project files yet (early phases).** `stop-verify.sh` already skips when no build files / no `workflow-active`; auto termination check must also handle "run aborted before scaffold" → treat as floor-miss with a clear reason.

---

## 10. Testing & verification plan (no API key, no headless)

1. **Hook unit tests** (per CLAUDE.md convention — `bash hooks/<script>.sh` with mocked stdin):
   - `auto-guard.sh`: pipe mock `AskUserQuestion` tool-input JSON with `mode:auto` state present → expect `exit 2` + message; with no/`interactive` state → expect `exit 0`.
   - `auto-governor.sh`: seed `auto-run.json` over a cap → expect `exit 2`; under cap → `exit 0` + incremented counter.
   - `stop-verify.sh`: with `mode:auto` + simulated unresolved P0/P1 → expect failure report written + `exit 2`; with clean floor → `exit 0`.
2. **In-session integration test** (interactive, uses subscription auth): run `/dev-squad build "tiny todo app" --auto` in a scratch project. Verify: never prompts; `assumption-ledger.md` populated; build completes; success report surfaces ledger.
3. **Forced fail-loud test:** inject an unresolvable P0 (or set a tiny `max_total_dispatches`) → verify `auto-failure-report.md` is written and stop is blocked, NOT reported as shipped.
4. **Empirical unknowns to confirm** (flagged version-dependent): exact behavior of `exit 2` message propagation on `AskUserQuestion`, and the dispatch-tool matcher name (`Task` vs `Agent`).
5. **Regression:** run a normal `/dev-squad build "tiny todo app"` (no flag) → confirm identical-to-v4.17.0 behavior, all new hooks no-op.

---

## 11. Risks & mitigations (summary)

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Wrong irreversible SaaS inference | High | Conservative defaults + LOW flag + surfaced; semi-auto later |
| Prose question hangs interactive run | Med | build.md "never end turn with a question" rule; empirical test |
| Governor counter race (parallel) | Low | Approximate counts; cap is a backstop |
| Dispatch-tool matcher name differs | Low | Resolved: gate with `*` matcher + `tool_name` filter (not a fixed matcher string) |
| Budget proxy ≠ real cost | Low | Documented; dispatch/iter/wall-clock proxies |

---

## 12. File-level change list

**New:**
- `hooks/auto-guard.sh` (PreToolUse: AskUserQuestion → block in auto mode)
- `hooks/auto-governor.sh` (SubagentStop increment + PreToolUse dispatch gate)
- `docs/specs/2026-05-25-sp1-autonomous-mode.md` (this doc)

**Modified:**
- `hooks/hooks.json` (wire 2 new hooks; add AskUserQuestion + dispatch matchers, with `${CLAUDE_PLUGIN_ROOT}` paths; `chmod +x` the scripts)
- `hooks/stop-verify.sh` (auto-mode termination + fail-loud report)
- `commands/build.md` (`--auto` parse; auto-mode rules for the 3 touchpoints; conservative-default policy; "never end a turn with a question" rule; update user-checkpoints section)
- `.claude-plugin/workflows/zero-to-ship.json` (add `mode` + `auto` config block to schema)
- `skills/dev-squad/SKILL.md` (document auto mode; update "User checkpoints" note)
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` (version bump per release convention)

**Runtime artifacts (written in user project, not committed):**
- `.dev-squad/assumption-ledger.md`, `.dev-squad/auto-run.json`, `.dev-squad/auto-failure-report.md`

---

## 13. Decisions (resolved 2026-05-25)

1. **Dispatch-tool matcher — RESOLVED.** Do NOT bet on a fixed matcher string. Checked: no plugin (incl. ECC) gates the dispatch tool by matcher, and tool names vary across harnesses (ECC normalizes via `TOOL_MAP`). Governor gate uses matcher `*` + reads `tool_name` from the payload (`Task` in standard Claude Code; normalize defensively).
2. **Conservative defaults — RESOLVED.** Explicit conservative defaults for the **4 irreversible dimensions only** (tenancy / identity hierarchy / billing+payment provider / compliance scope). The other 6 intake dimensions are inferred ad hoc from the description.
3. **Governor caps — RESOLVED.** Long runs are acceptable for optimal results (an 8-hour run is fine). Defaults: `wall_clock_cap_min: 480` (primary budget), `max_total_dispatches: 300` (runaway backstop), `max_iterations_per_phase: 5` (anti-thrash).
4. **Auto-mode trigger — RESOLVED.** Flag `--auto` only for SP1. (A config default can be added later if needed.)
5. **Commit — PENDING.** Spec lives on branch `feat/sp1-autonomous-mode` at `docs/specs/`. User reviews first; commit after review (per "always branch + PR" rule).
