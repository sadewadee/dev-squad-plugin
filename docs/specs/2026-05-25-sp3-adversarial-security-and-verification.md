# SP3 — Adversarial Security Pipeline + Self-Contained Verification

- **Date:** 2026-05-25
- **Status:** Draft for review
- **Branch:** `feat/sp3-adversarial-security`
- **Depends on:** SP1 (v4.18.0), SP2 (v4.19.0) merged

## Goal
Two deep autonomous quality gates:
- **Part A — Adversarial security (#18):** replace the reviewer's single-pass OWASP checklist with a 3-pass **attacker → defender → synthesizer** pipeline that runs **on the diff** (cost-bounded). Catches logic bugs / auth-bypass chains / race conditions that static OWASP misses — the highest-value quality win for SaaS.
- **Part B — Self-contained verification (#1):** dev-squad agents (backend, auditor, coordinator, frontend) currently depend on the EXTERNAL `superpowers:verification-before-completion` skill for their "is it actually done" check. If superpowers isn't installed, that discipline silently no-ops. Ship a self-contained verification skill so the guarantee holds standalone; keep superpowers as an optional enhancement.

## Current state (grounded)
- `agents/dev-squad/reviewer.md` "Multi-Angle Review (Phase 5)" (line 246): 5 parallel passes; Pass 1 SECURITY is an OWASP/auth/injection/XSS/CSRF/secrets checklist + "penetration mindset" — but single-pass, not adversarial.
- `skills/security-review/` exists (10-area checklist) — Part A complements it (adversarial, on diff), does not replace it.
- `superpowers:verification-before-completion` referenced in `backend.md`, `auditor.md`, `coordinator.md` (incl. "Iron Rule" line 1163), `frontend.md` frontmatter + skill matrices — the external dependency Part B addresses.
- Phase 5 already has a P0/P1 iteration loop (coordinator) — adversarial findings feed it (reviewer is the security lead with veto).

## Design

### Part A — `skills/adversarial-security/SKILL.md` (new)
3-pass protocol, **scoped to the diff** (`git diff` of the feature), dispatched by the reviewer during Phase 5 Pass 1:
1. **Attacker** (`general-purpose`, sonnet): given the diff + threat model, enumerate concrete exploit chains — auth bypass, IDOR, injection (SQL/NoSQL/command), SSRF, XSS, race conditions, missing authz checks, secret leakage, logic flaws. Output: ranked attack hypotheses with the exact file:line + the exploit path.
2. **Defender** (`general-purpose`, sonnet): for each attack hypothesis, check whether an existing protection in the code defeats it (validation, parameterization, authz middleware, rate limit, escaping). Output: per-hypothesis "mitigated / partially / exposed" + evidence.
3. **Synthesizer** (`general-purpose`, sonnet): merge attacker + defender → final findings, each with severity (P0-P3) + a 0-100 confidence (reuse SP2/Phase-5 scoring; filter <80 as non-actionable). Output: `.dev-squad/adversarial-findings.md`.
- The reviewer feeds confirmed P0/P1 findings into the existing Phase 5 iteration loop (reviewer keeps veto).
- **Cost control:** runs on the diff only; skipped for trivial diffs (per the existing Diff-Scope Heuristic); the 3 passes are sonnet (not opus) on a bounded diff.

### Part B — `skills/verification/SKILL.md` (new, self-contained)
A standalone "before done" verification protocol with NO external dependency: build → typecheck → lint → tests → secrets scan (staged) → diff self-review → report card (PASS/items). Mirrors what `superpowers:verification-before-completion` did, owned by dev-squad.
- Update `backend.md`, `auditor.md`, `coordinator.md`, `frontend.md`: make `dev-squad:verification` the PRIMARY "before done" skill; keep `superpowers:verification-before-completion` as an OPTIONAL enhancement ("if installed, also use…"). This removes the silent-no-op fragility.
- coordinator.md "Verification-Before-Completion (Iron Rule)" (line ~1163): reference the self-contained skill as the floor; superpowers as a bonus.

## Files
- **New:** `skills/adversarial-security/SKILL.md`, `skills/verification/SKILL.md`
- **Modified:** `agents/dev-squad/reviewer.md` (Pass 1 → invoke adversarial pipeline on non-trivial diff), `commands/build.md` (Phase 5 reviewer lane mentions adversarial pipeline), `agents/dev-squad/{backend,auditor,coordinator,frontend}.md` (verification skill primary + superpowers optional), `skills/dev-squad/SKILL.md` (skill matrix: add the 2 new skills), version bump → 4.20.0.

## Non-goals
- Do NOT build the external AgentShield npm tool — this is native (dispatched general-purpose agents per the skill), no API key, no new dependency.
- Do NOT add permanent attacker/defender/synthesizer agents to the 11-agent roster — they are dispatched passes defined by the skill (keeps the swarm curated).
- SP4 (autonomous recovery) out of scope.

## Verification (honest)
Mostly prompt/skill content — not unit-testable. Verify: skill protocols are concrete + terminate; reviewer wiring scopes to diff + non-trivial only (cost); verification-skill agent references make superpowers OPTIONAL (graceful degrade) not removed; no `mcp__*` literals; adversarial findings feed the existing Phase 5 loop without conflict; `jq`/schema if JSON touched. Real efficacy needs a live run (same caveat as SP1/SP2).

## Risks
- **Cost:** 3 extra sonnet passes per Phase 5. Mitigate: diff-only + skip trivial diffs + sonnet not opus + (in `--auto`) bounded by SP1 governor budget.
- **False positives from the attacker pass** → mitigate with the defender pass + synthesizer confidence filter (<80 dropped), same discipline as the PR-review scoring.
- **Verification skill drift from stop-verify.sh** → keep it aligned with the checks stop-verify already runs (build/type/lint/test) so they don't contradict.
