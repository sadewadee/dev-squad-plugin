# SP4 Implementation Plan — Autonomous Recovery

> Executor: subagent-driven, scaled. New skill content + agent wiring — not unit-testable; substantive tasks get coherence review, trivial get grep/jq. Branch `feat/sp4-autonomous-recovery` (off main @ v4.20.0). Spec: `docs/specs/2026-05-25-sp4-autonomous-recovery.md`. PR at end. FINAL SP.

## Task 1: `skills/debugging/SKILL.md` (self-contained)
- [ ] Create the skill (read `skills/verification/SKILL.md` for style first). Frontmatter `name: debugging`, `description:` (triggers on any bug/test-failure/unexpected behavior before proposing a fix). Body = self-contained 4-phase loop: (1) Reproduce — get the exact failing command + output; (2) Locate — read the error, narrow to file:line, read the relevant code; (3) Hypothesize — root cause not symptom, one hypothesis at a time; (4) Fix minimally + Verify — re-run the EXACT failing command, confirm green. Rules: "fix root cause not symptom; one change at a time; evidence before claims — never assume the fix worked, re-run." End note: "self-contained; if `superpowers:systematic-debugging` is installed, use it as an additional technique — but this skill does not depend on it." No `mcp__*` literals, no emojis.
- [ ] Verify: valid frontmatter; `grep -c 'mcp__' skills/debugging/SKILL.md` → 0.
- [ ] Commit: `feat(sp4): self-contained debugging skill`

## Task 2: `skills/build-error-resolver/SKILL.md`
- [ ] Create the skill. Frontmatter `name: build-error-resolver`, `description:` (triggers on build/compile/type errors during the self-healing author-retry tier). Body: (1) capture exact error + file:line (build output / `ide diagnostics`); (2) MINIMAL diff fix — NO refactor, NO architecture change, NO new abstraction, NO silencing (no `any`, no `// @ts-ignore` unless already the codebase norm); (3) re-run the SAME build/type command → confirm green; (4) if still failing after 2 attempts on the same error → STOP, escalate to the self-healing loop's next tier (don't thrash). Rule: "minimal diff only; if the real fix needs a design change, escalate — do not change architecture to silence a build error." No `mcp__*` literals, no emojis.
- [ ] Verify: valid frontmatter; `grep -c 'mcp__'` → 0; body has the minimal-diff rule + 2-attempt escalation.
- [ ] Commit: `feat(sp4): build-error-resolver skill (minimal-diff, iterate-until-green)`

## Task 3: debugging skill primary across 6 references
**Files:** `agents/dev-squad/{auditor,backend,qa-engineer,devops,reviewer}.md` + `skills/dev-squad/SKILL.md`
- [ ] For each `superpowers:systematic-debugging` reference (frontmatter `skills:`, skill-matrix rows, decision-flow lines): make `dev-squad:debugging` PRIMARY; KEEP `superpowers:systematic-debugging` as OPTIONAL ("additional technique if installed"). Do NOT remove superpowers. Surgical.
- [ ] Verify: `grep -rln "dev-squad:debugging"` covers the 5 agents; `grep -rln "superpowers:systematic-debugging"` still present in each (optional).
- [ ] Commit: `feat(sp4): agents use self-contained debugging skill (superpowers optional)`

## Task 4: wire build-error-resolver into the self-healing loop
**Files:** `agents/dev-squad/coordinator.md` (Self-Healing Loop, ~lines 832-868, iters 1-2 author retries)
- [ ] In ITERATION 1-2 (author retries), add: for build/compile/type errors specifically, the author invokes `dev-squad:build-error-resolver` (minimal-diff, iterate-until-green; escalate to next tier after 2 same-error attempts — aligns with the existing thrashing rule). Do NOT rewrite the loop's tiers/thrashing/logging — additive reference only.
- [ ] Verify (coherence): the reference is additive; the 3-tier structure + thrashing detection + self-healing-log intact; build-error-resolver's 2-attempt escalation aligns with the existing thrashing rule (no contradiction).
- [ ] Commit: `feat(sp4): self-healing loop uses build-error-resolver for build errors`

## Task 5: SKILL.md matrix + version 4.21.0 + PR
**Files:** `skills/dev-squad/SKILL.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- [ ] Add `dev-squad:debugging` + `dev-squad:build-error-resolver` rows to the skill matrix.
- [ ] Bump 4.20.0 → 4.21.0 both JSONs; `jq empty` both.
- [ ] Commit: `chore(sp4): v4.21.0 — autonomous recovery (debugging + build-error-resolver)`
- [ ] Push; open PR (summary + live-run caveat).

## Self-review (against spec)
Spec → tasks: debugging skill (T1), build-error-resolver skill (T2), debugging primary across 6 refs (T3), build-error-resolver wired into self-healing (T4), matrix+version (T5). Non-goals honored: self-healing loop not rewritten, no new permanent agents.
