# QA Engineer — Core Responsibilities Reference

This document expands on the four core responsibilities listed in `agents/qa-engineer.md`.
Each responsibility maps to concrete Phase 5.5 steps and the tools that execute them.

---

## 1. Test Design & Execution

**Description:** Create and execute test scenarios — both manual and automated — for every feature listed in the PRD acceptance criteria. Test cases must cover happy paths, failure paths, edge cases, and auth boundaries.

**Deliverable:** Test case documents (written inline in `functional-verification.md`) + execution reports with actual vs expected outcomes.

**Phase 5.5 mapping:**
- Step 1 (boot) — environment readiness prerequisite
- Step 2 (golden path via Playwright) — automated execution of acceptance-criteria scenarios
- Step 4 (API smoke tests via curl) — manual + scripted test execution per endpoint
- Step 5 (cross-boundary integration) — end-to-end scenario execution

**Tools:** `playwright` MCP (`browser_navigate`, `browser_click`, `browser_type`, `browser_snapshot`), `curl`, `Bash`

---

## 2. Bug Reporting

**Description:** Identify defects at runtime, document exact reproduction steps (environment, input, sequence of actions), and record severity and expected vs actual behavior. Reports must be self-contained enough for another developer to reproduce without asking follow-up questions.

**Deliverable:** Detailed bug reports written into `functional-verification.md` — each finding includes: file:line where applicable, severity (P0–P2), observed behavior, expected behavior, and reproduction steps.

**Severity classification:**
| Level | Meaning | Examples |
|---|---|---|
| P0 | Blocks ship — app unusable or security broken | 500 on login, protected route returns 200, missing endpoint |
| P1 | Blocks approve — feature broken or UX dead-end | Button with no onClick, hydration mismatch, wrong response shape |
| P2 | Should fix before release | Console warning, minor visual inconsistency |

**Phase 5.5 mapping:**
- All steps produce findings that feed directly into `functional-verification.md`
- Auth Endpoint Gate (5.5-A) — highest-priority bug surface

**Tools:** `playwright` (`browser_console_messages`, `browser_network_requests`), `curl -w "%{http_code}"`, `Bash`

---

## 3. Regression Testing

**Description:** After every fix applied by backend, frontend, or other agents, re-run the affected test scenarios to confirm the fix works AND that existing passing tests have not regressed. Regression testing is not optional — new code always carries risk of breaking prior functionality.

**Deliverable:** Regression test results appended to `functional-verification.md` with before/after status per test case, plus a stability confirmation statement.

**When triggered:**
- After any P0 or P1 fix is applied by another agent
- After a coordinator-initiated re-spin (self-healing loop)
- Before final Phase 5.5 PASS verdict is issued

**Regression scope per fix:**
- Re-run the failing scenario (verify fix)
- Re-run the Auth Endpoint Gate (5.5-A) — auth regressions are highest risk
- Re-run any golden path flow that touches the same module/endpoint as the fix
- Re-run browser console gate on affected pages

**Phase 5.5 mapping:**
- Regression runs are a second pass of Steps 1–6 scoped to the changed area
- Final verdict (`P0 count`, `P1 count`) in `functional-verification.md` reflects post-regression state

**Tools:** Same as Test Design & Execution — Playwright, curl, Bash

---

## 4. Quality Control

**Description:** Ensure the final product is secure, performant, and user-friendly per the original PRD standards before the coordinator marks the workflow `ship`. QC is the synthesis gate — it aggregates findings from all prior steps and makes a binary ship/no-ship recommendation.

**Deliverable:** A stable, release-ready application. Final `functional-verification.md` Verdict section must show: Auth Gate PASS, P0 = 0, P1 ≤ budget, Visual Gate complete.

**QC dimensions:**

| Dimension | Gate |
|---|---|
| Security | Auth Gate (5.5-A) PASS; no 500s on invalid input; no info leakage in error responses |
| Performance | No N+1 network calls in browser log; no spinner-forever on page load |
| Usability | Every interactive element wired; every form gives feedback; no dead-end UX flows |
| Visual fidelity | Visual Gate passed (anti-slop checklist, responsive, motion, design tokens) |
| Regression safety | No previously passing flows broken by the current change set |

**Ship/no-ship authority:**
- QA engineer can veto ship on: Auth Gate incomplete, any P0, P1 count > 0 in golden path
- Coordinator cannot override QA veto without explicit user instruction
- QC gate is the last checkpoint before `git-ops` creates the release PR

**Phase 5.5 mapping:**
- Final Verdict section of `functional-verification.md`
- Feeds directly into reviewer's metrics report and coordinator's ship decision
