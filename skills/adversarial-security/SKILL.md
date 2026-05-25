---
name: adversarial-security
description: Adversarial 3-pass security pipeline for dev-squad Phase 5 review. Run on the feature diff when changes touch auth, billing, data handling, or multi-tenant boundaries. Dispatches general-purpose attacker, defender, and synthesizer passes to surface concrete exploit paths, verify mitigations, and write surviving high-confidence findings to .dev-squad/adversarial-findings.md. Complements (does not replace) the security-review OWASP checklist.
---

# Adversarial Security - 3-Pass Attacker/Defender/Synthesizer on Diff

## INSTRUCTIONS: When this skill is invoked

The reviewer agent invokes this skill during Phase 5 when the feature diff touches non-trivial security surfaces: authentication/authorization, billing/payment flows, user data handling, multi-tenant resource isolation, secrets management, or inter-service trust boundaries.

This skill runs 3 sequential passes via dispatched general-purpose agents. Each pass receives the outputs of the previous pass. The reviewer retains veto authority over all findings and feeds confirmed P0/P1 findings into the existing Phase 5 iteration loop.

---

## Scope and Skip Conditions

Run against: `git diff main..HEAD` of the feature branch (the diff, not the full codebase).

Skip this skill entirely when the diff is trivial:
- Documentation or comment-only changes
- Formatting or whitespace changes
- Test-only changes with no production code modification
- Dependency version bumps with no API surface changes

State the skip reason explicitly before halting. Do not invoke the 3 passes on a trivial diff.

---

## Pass 1 — Attacker

Dispatch a general-purpose agent (model: sonnet) with the following inputs:
- The full feature diff (output of `git diff main..HEAD`)
- The threat model file at `.dev-squad/threat-model.md` if it exists; otherwise note its absence and proceed without it

The attacker agent enumerates concrete exploit hypotheses. For each hypothesis the attacker MUST provide:
- The specific file and line reference from the diff (file:line)
- The concrete exploit path (what the attacker does, what they gain)
- The vulnerability class from the list below

Vulnerability classes to cover (check each; skip with explicit "not present in diff" if not applicable):
- Auth bypass (unauthenticated access to protected resources)
- IDOR / broken object-level authorization (accessing another user's or tenant's data via ID manipulation)
- SQL injection (parameterized query bypassed or absent)
- NoSQL injection (query operator injection, e.g. MongoDB $where)
- Command injection (shell metacharacters in exec/spawn calls)
- SSRF (user-controlled URLs fetched server-side)
- Stored or reflected XSS (unsanitized output in HTML context)
- CSRF (state-changing operations without same-origin protection)
- Race conditions / TOCTOU (check-then-act gaps exploitable by concurrent requests)
- Missing authorization checks (resource mutation without ownership verification)
- Secret leakage (credentials, tokens, or keys exposed in logs, responses, or error messages)
- Business-logic flaws (price manipulation, free-tier abuse, quantity bypasses, step-skipping in multi-step flows)

Output from Pass 1: a ranked list of exploit hypotheses, ordered by likely impact (highest first). Each entry: vulnerability class, file:line, concrete exploit path.

---

## Pass 2 — Defender

Dispatch a general-purpose agent (model: sonnet) with the following inputs:
- The full feature diff
- The complete output from Pass 1 (the ranked hypothesis list)

The defender agent inspects the diff for existing protections that would mitigate each attacker hypothesis. For each hypothesis the defender MUST output one of:
- `mitigated`: a specific protection exists in the diff or the surrounding codebase, with file:line of the protection as evidence
- `partial`: a protection exists but has a gap (state the gap explicitly)
- `exposed`: no effective protection found

The defender does not propose fixes. The defender only determines whether the current code mitigates each hypothesis.

Output from Pass 2: the Pass 1 hypothesis list annotated with defender verdicts and evidence.

---

## Pass 3 — Synthesizer

Dispatch a general-purpose agent (model: sonnet) with the following inputs:
- The full feature diff
- The complete annotated output from Pass 2

The synthesizer merges attacker hypotheses and defender verdicts into final findings. For each `partial` or `exposed` verdict the synthesizer produces a finding with:
- Severity: P0 (critical — immediate exploitation possible), P1 (high — exploitable with moderate effort), P2 (medium — defense-in-depth gap), P3 (low — best-practice gap)
- Confidence score: 0-100 (how certain the synthesizer is that this is a real, exploitable issue in the actual codebase — not a theoretical concern)
- Vulnerability class
- File:line reference
- Concrete impact statement (one sentence: what an attacker achieves)
- Remediation direction (one sentence: what change closes the gap)

Filter rule: discard any finding with confidence score below 80. These are too speculative to be actionable. Do not include them in the output.

Write the surviving findings (confidence >= 80) to `.dev-squad/adversarial-findings.md` in this format:

```
# Adversarial Security Findings
Generated: <timestamp>
Diff scope: <git ref range>

## Findings

### [P0|P1|P2|P3] <Vulnerability Class> — <File:Line>
Confidence: <score>/100
Impact: <one-sentence impact>
Remediation: <one-sentence direction>

---
```

If no findings survive the confidence filter, write the file with a "No findings above confidence threshold" summary. Do not omit the file.

---

## Handoff to Phase 5 Iteration Loop

After Pass 3 completes:
- The reviewer reads `.dev-squad/adversarial-findings.md`
- Confirmed P0 findings: block merge immediately; feed into Phase 5 iteration loop as hard blockers
- Confirmed P1 findings: feed into Phase 5 iteration loop; must be resolved before reviewer approves merge
- P2 and P3 findings: log as recommendations; do not block merge unless the reviewer judges otherwise
- The reviewer retains veto authority — the synthesizer output is a recommendation, not a gate

---

## Cost Control

- Diff-only scope (not full codebase scan) bounds the input size for all three passes
- Skip-trivial gate prevents unnecessary runs on non-security diffs
- All three passes use sonnet, not opus
- In `--auto` mode this skill is further bounded by the SP1 governor budget; if budget is exhausted, halt after the highest-completed pass and surface that fact explicitly

---

## Anti-Pattern Note

These are three dispatched general-purpose agent passes. Do NOT attempt to dispatch agents with `subagent_type: "attacker"`, `subagent_type: "defender"`, or `subagent_type: "synthesizer"`. Those agent types do not exist. Use `general-purpose` for all three passes.

---

## Relationship to Existing Security Review

This skill complements, and does not replace, the `security-review` skill. The OWASP-area checklist in `security-review` covers breadth (10 areas, full codebase conventions). This skill covers depth on the specific diff using adversarial reasoning. Both should run during Phase 5 on non-trivial feature work.

Run order: `security-review` first (for broad coverage), then `adversarial-security` (for exploit-path depth on the diff).
