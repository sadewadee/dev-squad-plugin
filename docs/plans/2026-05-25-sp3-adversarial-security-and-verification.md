# SP3 Implementation Plan — Adversarial Security + Self-Contained Verification

> Executor: subagent-driven, scaled. Mostly new skill content + agent-prompt wiring — not unit-testable. Substantive tasks get a coherence+spec review; trivial ones get grep/jq verification.

**Branch:** `feat/sp3-adversarial-security` (off main @ v4.19.0). Spec: `docs/specs/2026-05-25-sp3-adversarial-security-and-verification.md`. PR at end.

---

## Task 1: `skills/verification/SKILL.md` (self-contained verification)

**Files:** Create `skills/verification/SKILL.md`

- [ ] Create the skill with a self-contained "before done" protocol (NO external dependency). Frontmatter `name: verification`, `description:` (when to use: before any agent claims a task done). Body = an ordered checklist the agent runs and reports:
  1. Build (detect: package.json/go.mod/pyproject.toml/Cargo.toml → run the build/compile).
  2. Typecheck (tsc --noEmit / go vet / mypy).
  3. Lint (eslint / golangci-lint / ruff).
  4. Tests (npm test / go test ./... / pytest).
  5. Secrets scan on staged diff (grep for key patterns).
  6. Diff self-review (does the change match the task; any leftover TODO/stub).
  7. Report card: PASS only if all green; otherwise list failures. "Evidence before claims — run the commands fresh, do not assert from memory."
  Keep it language-agnostic + aligned with what `hooks/stop-verify.sh` already runs (so they don't contradict).
- [ ] Verify: `Skill` frontmatter valid (name/description present); content has the 7 steps; no `mcp__*` literals.
- [ ] Commit: `feat(sp3): self-contained verification skill`

---

## Task 2: `skills/adversarial-security/SKILL.md` (3-pass pipeline)

**Files:** Create `skills/adversarial-security/SKILL.md`

- [ ] Create the skill defining the attacker→defender→synthesizer protocol, scoped to the diff. Frontmatter `name: adversarial-security`, `description:` (when to use: Phase 5 security review on a non-trivial diff). Body:
  - **Scope:** run on `git diff` of the feature branch only; skip trivial diffs (docs/formatting).
  - **Pass 1 Attacker** (dispatch `general-purpose`, model sonnet): input = diff + threat model; output = ranked exploit hypotheses (auth bypass, IDOR, SQL/NoSQL/command injection, SSRF, XSS, race conditions, missing authz, secret leakage, logic flaws) each with file:line + exploit path.
  - **Pass 2 Defender** (dispatch `general-purpose`, sonnet): for each hypothesis, is there an existing protection (validation/parameterization/authz/rate-limit/escaping)? Output per-hypothesis: mitigated | partial | exposed + evidence.
  - **Pass 3 Synthesizer** (dispatch `general-purpose`, sonnet): merge → findings with severity P0-P3 + 0-100 confidence; **filter <80**; write `.dev-squad/adversarial-findings.md`.
  - **Handoff:** confirmed P0/P1 → reviewer feeds them into the Phase 5 iteration loop (reviewer keeps veto).
  - **Anti-pattern note:** these are dispatched `general-purpose` passes, NOT new agent types; do not use `subagent_type: "attacker"` etc.
- [ ] Verify: frontmatter valid; 3 passes concrete; diff-scoped + trivial-skip stated; confidence filter present; no `mcp__*` literals.
- [ ] Commit: `feat(sp3): adversarial-security skill (attacker/defender/synthesizer on diff)`

---

## Task 3: reviewer.md — wire adversarial pipeline into Phase 5 Pass 1

**Files:** `agents/dev-squad/reviewer.md`

- [ ] In "Multi-Angle Review (Phase 5)" Pass 1 SECURITY (~line 252), add: on a non-trivial diff, invoke `dev-squad:adversarial-security` (attacker→defender→synthesizer on the diff) IN ADDITION to the OWASP checklist; feed confirmed P0/P1 synthesizer findings into the Phase 5 iteration loop; keep the OWASP/`security-review` checklist as the baseline. Surgical/additive.
- [ ] Add `adversarial-security` to the reviewer's `skills:` frontmatter list if present.
- [ ] Verify (coherence): Pass 1 now references the adversarial skill, diff-scoped, complements (not replaces) OWASP; veto/iteration-loop handoff intact.
- [ ] Commit: `feat(sp3): reviewer invokes adversarial-security pipeline in Phase 5`

---

## Task 4: build.md — Phase 5 reviewer lane mentions adversarial pipeline

**Files:** `commands/build.md`

- [ ] In Phase 5 REVIEW, the reviewer-lane line (static security) — add that on non-trivial diffs the reviewer runs the adversarial-security 3-pass on the diff (per reviewer.md). Surgical.
- [ ] Verify (grep): Phase 5 reviewer lane mentions adversarial; no unrelated change.
- [ ] Commit: `feat(sp3): build.md Phase 5 reviewer runs adversarial pipeline`

---

## Task 5: verification skill primary in agent prompts (replace external-only dependency)

**Files:** `agents/dev-squad/backend.md`, `auditor.md`, `coordinator.md`, `frontend.md`

- [ ] In each, where `superpowers:verification-before-completion` is the "before done" skill (frontmatter `skills:` + skill-matrix rows + coordinator's "Iron Rule" ~line 1163): make `dev-squad:verification` the PRIMARY skill and keep `superpowers:verification-before-completion` as an OPTIONAL enhancement ("also use if installed"). Do NOT remove superpowers — make it optional so it degrades gracefully. Keep edits surgical.
- [ ] Verify (grep): each of the 4 agents now references `dev-squad:verification` as primary; superpowers still present as optional.
- [ ] Commit: `feat(sp3): agents use self-contained verification skill (superpowers optional)`

---

## Task 6: SKILL.md skill matrix + version bump 4.20.0 + PR

**Files:** `skills/dev-squad/SKILL.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

- [ ] Add `dev-squad:adversarial-security` + `dev-squad:verification` to the Skill matrix in SKILL.md (when-to-use rows).
- [ ] Bump 4.19.0 → 4.20.0 in both JSONs; `jq empty` both.
- [ ] Commit: `chore(sp3): v4.20.0 — adversarial security + self-contained verification`
- [ ] Push; open PR (summary + live-run caveat in test plan).

---

## Self-review (against spec)
Spec items → tasks: adversarial skill (T2), verification skill (T1), reviewer wiring (T3), build.md Phase 5 (T4), agent verification-primary (T5), skill matrix + version (T6). Non-goals honored: no AgentShield npm, no new permanent agents, SP4 out.
