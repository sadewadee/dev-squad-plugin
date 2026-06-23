---
name: intent-drift
description: >
  Detect scope creep — the operational form of "surgical changes" (dev-squad
  Rule 3). Compares the actual diff against the declared goal and flags
  everything the change touched that the task did not ask for: unrelated
  refactors, drive-by reformatting, speculative features, adjacent "while I'm
  here" edits. Use during Phase 5 review and before opening a PR, or when the
  user says "intent drift", "scope creep", "did this stay in scope", "is the PR
  doing too much", or "compare the diff to the goal".
license: MIT
---

# Intent-drift — did the change stay in scope?

Rule 3 says touch only what you must. A diff drifts when it does more than the
declared goal: a bugfix that also reformats a file, a feature that also
"improves" adjacent code, a refactor that smuggles in a behavior change. Drift
inflates review surface, hides the real change, and breaks things the task never
meant to touch. This pass makes drift visible before it ships.

## When this fires

Phase 5 (REVIEW) and pre-PR. It is a comparison pass: declared goal vs actual diff.

## Step 1 — establish the declared goal

Read the intent from the most authoritative source available, in order:

1. `.dev-squad/master-plan.md` (the workflow's stated scope) or the current task/phase
2. The PR/issue description, or the branch name
3. If none exists: ask the coordinator/user for the one-line goal — do NOT infer silently, an unstated goal makes every change look in-scope.

State it explicitly: **Declared goal: "<one line>"**.

## Step 2 — map the diff against it

```bash
git diff --stat <base>...HEAD          # the surface
git diff <base>...HEAD                  # the hunks
```

Classify every changed file (and notable hunk) into exactly one bucket:

- **In-scope** — directly implements the declared goal.
- **Supporting** — required for in-scope to work (a new import, a type the feature needs, a test for the new code). Legitimate.
- **DRIFT** — not needed for the goal: unrelated refactor, formatting/whitespace churn, renamed-for-taste, speculative abstraction, an adjacent bug "fixed" along the way, dependency bumps the task did not require.

## Step 3 — report and recommend

For each DRIFT item, recommend one: **split** into its own PR/commit, **revert** (out of scope, do later), or **justify** (genuinely required — explain why and reclassify). Do not auto-edit; this is a review verdict the author acts on.

## Output

```
Declared goal: "<one line>"
In-scope: <n files>  Supporting: <n>  Drift: <n>
Drift findings:
- <file> (+/-LOC) — <what drifted> → recommend: split | revert | justify (<reason>)
Verdict: <SURGICAL — no drift | DRIFT — N items outside the goal>
```

If clean: `Diff matches the declared goal. Surgical.`

Note: a legitimately broad task (e.g. "rename X across the repo") is wide but not
drift — width that the goal demands is in-scope. Drift is width the goal did not.

<!-- Concept adapted from claude-code-plugins-plus-skills (pr-to-spec / intent-drift detection), MIT. -->
