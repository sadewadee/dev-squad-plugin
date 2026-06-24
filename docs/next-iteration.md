# dev-squad plugin — maintenance backlog

> This is the **plugin's own** deferred-work list (gaps found auditing dev-squad itself), not the
> `docs/next-iteration.md` that `/dev-squad build` generates inside a *user's* project. Items here
> were surfaced by the adversarial-verification + gap-hunt workflows during the v4.37–v4.39 de-orphan
> work and deliberately deferred (lower severity, pre-existing, or needing their own focused review).
> Each carries evidence (`file:line`) and a proposed fix. Triage before picking up.

## Medium

### M3 — `scope-tier.json` has no explicit writer, so the SaaS "BLOCKING" default is inert
- **Where:** `agents/coordinator.md:92` (parenthetical only), `.claude-plugin/workflows/feature-development.json` (lists it as a Phase 1 output)
- **What:** Six agents gate SaaS-pattern loading on `.dev-squad/scope-tier.json` containing `saas_touch: true`, but no agent prompt contains an explicit "Write `.dev-squad/scope-tier.json`" step. If it is never written, all consumers silently degrade and the advertised blocking behavior never fires.
- **Fix:** Add an explicit write step to the coordinator's Scope Assessment phase, OR have a hook materialize a default `scope-tier.json` at workflow start.

### M4 — P0/P1 veto is a prose handoff; a phase marked `complete` despite a failed gate defeats both stop-verify checks
- **Where:** `hooks/stop-verify.sh:172` (greps iteration-log for `UNRESOLVED P0|P1`), `agents/coordinator.md:739` (prose: write the marker + "Do NOT pass"), `agents/reviewer.md` (veto is prose)
- **What:** The v4.39 phase-completeness check catches a phase left `in_progress`, and the iteration-log grep catches the marker — but if the coordinator marks a phase `complete` AND omits the marker, both are blind. No hook reads `stability-report.md` / `quality-metrics.md` / security findings before Stop.
- **Fix:** Enforce "failed gate ⇒ phase stays `in_progress`, never `complete`" (then the deterministic phase check catches it), OR have stop-verify read the Phase 5 report artifacts for unresolved P0/P1 directly.

### M5 — `dispatch-log.md` is written deterministically but consumed only by prose
- **Where:** writers `agents/coordinator.md:633`, `commands/build.md:352`; consumer = Phase 7 LEARN reviewer (prose only)
- **What:** No hook injects it and no agent bootstrap reads it, so if the reviewer skips bootstrap the accumulated dispatch history is a dead end (same class as the original pre-compact orphan, lower stakes).
- **Fix:** Inject `dispatch-log.md` head into SubagentStart context for Phase 7, or document it as an accepted prose loop.

### SaaS-scope safety default is prose-only
- **Where:** `agents/architect.md:71`, `agents/backend.md:143`, `agents/writer.md:119`
- **What:** Agents must not load saas-patterns/saas-readiness or emit tenancy/billing ADRs unless a trigger is true (master-plan "SaaS Mode: enabled", `scope-tier.json` `saas_touch:true`, `--saas`, or existing SaaS subsystems). No hook enforces the triggers. (Related to M3.)
- **Fix:** Same mechanism as M3 — a deterministic scope signal a hook can read.

## Low

- **L2 — `playbook.md` has no consumer.** Written by `coordinator.md:493`, `auditor.md:531`, `build.md:532`, `retrospective.md:68`; "becomes defaults for future builds" (`zero-to-ship.json:325`) is never mechanically enforced. Fix: inject its head at SubagentStart alongside `memory.md`/`gotchas.md`.
- **L3 — `ship-exceptions.md` P0 gate is prose-only.** `build.md:466` / `zero-to-ship.json:293` allow ship with P0 only if an override is logged here, but `stop-verify.sh` never reads it. Fix: read it in the Phase 6 gate when P0 > 0.
- **L4 — `installed-dev-tools.log` / `installed-skills.log` are write-only.** `auditor.md:41,402`, `coordinator.md:231`. Likely intentional forensic logs, but the re-install-every-session behavior is wasteful if never consulted. Fix: read before re-install, or document as forensic-only.
- **L5 — `docs/api-contract.md` referenced but never produced.** `auditor.md:183` names it; the architect writes API contracts into `docs/architecture.md`. Fix: repoint the reference to `docs/architecture.md#api-contracts`.
- **`security-warnings.log` is write-only** (`guard-unsafe-code.py`). Almost certainly an intentional human-facing forensic log — confirm and annotate as such, or wire a reader.
- **`docs/dev-squad-improvements.md` is unreferenced** — possibly stale; confirm and remove or link.

## Unaudited (completeness-critic blind spots — not yet swept)

These dimensions were explicitly NOT covered by the gap-hunt workflows and could still hide issues:

1. **`rules/` content currency** — files exist and are referenced, but content was not checked for stale patterns (agents read them as conventions; stale rules → subtly wrong code, no hook catches it).
2. **`mcp__*` literal scan** — CLAUDE.md bans hardcoded `mcp__*` identifiers; no grep has confirmed compliance across all agent/command/skill bodies. (Cheap to run — do this first.)
3. **Hook runtime behavior** — all hook analysis was static; none were exercised with real Claude Code event payloads (malformed JSON, missing env vars, empty files).
4. **Generated-app `.claude/` template content** — `docs/templates/claude-md-base.md` was checked for broken links, not for content correctness vs the current architecture.
5. **`saas-patterns` / `saas-readiness` internal cross-references** — existence confirmed; internal section anchors and phase-mapping tables not validated against current dispatch.
6. **`auto-lint.sh` formatter availability** — assumes prettier/gofmt/black are installed; no check. Acceptable degradation, unaudited.
7. **`companions.json` vs external plugin skill names** — entries not cross-checked against current external plugin APIs; a renamed upstream skill would break a `graceful_degrade:false` companion silently.

## How to work this list

- Re-run `/dev-squad hook-stocktake` after any hook change — it now classifies producer/consumer determinism and flags the pre-compact (det-write/prose-read) and fail-open (det-read/prose-write) classes.
- For any safety-hook change, adversarially bypass-hunt before merge: pattern-matching shell commands is leaky; use command-position parsing, not substring regex (lesson from the H2 guard, v4.39).
