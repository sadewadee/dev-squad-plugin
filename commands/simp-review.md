---
name: simp-review
description: Review the current diff for over-engineering only (not correctness) and hand back a delete-list — reinvented stdlib, dependencies doing what the platform does, single-use abstractions, code that can shrink.
---

# /dev-squad simp-review

<!-- Ported from ponytail (https://github.com/DietrichGebert/ponytail), MIT, © Dietrich Gebert. -->

Review the current code changes (the working diff) for **over-engineering only, not correctness.** This is the after-the-fact companion to the `dev-squad:simp` skill (which fires before code is written).

## Instructions

1. Get the diff: `git diff` (unstaged + staged) against the base branch. If nothing is staged/changed, fall back to the most recent commit's diff.
2. Emit **one line per finding**, format:

   ```
   L<line>: <tag> <what to cut>. <replacement>.
   ```

3. Tags:

   | Tag | Meaning |
   |-----|---------|
   | `delete` | dead code or a speculative feature nobody asked for |
   | `stdlib` | reinvented standard-library functionality |
   | `native` | a dependency doing what the platform/language/DB does natively |
   | `yagni` | an abstraction with exactly one implementation/caller |
   | `shrink` | same logic, fewer lines |

4. End with the **net lines removable**.
5. If there is nothing to cut: reply exactly `Lean already. Ship.`

## Rules

- Report only. Change nothing — this is a review, not an edit pass (use `simplify` to apply).
- Do not flag correctness, security, validation, error handling, or accessibility. Those are never "over-engineering" — see the `dev-squad:simp` "When NOT to be lazy" section.
- No prose beyond the finding lines and the net total.
