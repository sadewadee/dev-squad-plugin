---
name: simp-review
description: Review the current diff for over-engineering only (not correctness) and hand back an actionable cut-list — reinvented stdlib, dependencies doing what the platform does, single-use abstractions, duplicated functions, code that can shrink. Each finding names the consolidation/replacement to apply.
---

# /dev-squad simp-review

<!-- Ported from ponytail (https://github.com/DietrichGebert/ponytail), MIT, © Dietrich Gebert. Extended for dev-squad: prescriptive fix + orphan provenance + merge tag. -->

Review the current code changes (the working diff) for **over-engineering only, not correctness.** This is the after-the-fact companion to the `dev-squad:simp` skill (which fires before code is written).

Every finding states **what** to cut, **why** it's safe (provenance), and the **fix** to apply — never a vague category.

## Instructions

1. Get the diff: `git diff` (unstaged + staged) against the base branch. If nothing is staged/changed, fall back to the most recent commit's diff.
2. Emit **one line per finding**, format:

   ```
   L<line>: <tag> <what to cut>. why: <how it got here / why it's safe to cut>. fix: <the consolidation or specific replacement>.
   ```

   - `fix:` is **always** required and names the concrete target — the exact stdlib/native API, the installed dep that absorbs the job, or the surviving function and its merged signature.
   - The fix must be the **leanest correct** option and **net-negative** — prefer delete / inline / reuse over any new abstraction. If the simplest correct fix isn't smaller than what it replaces, don't propose it. The cure is never bigger than the disease.
   - `why:` is **required for `delete`, `delete?`, and `merge`**; optional for the rest when self-evident.

3. Tags:

   | Tag | Meaning |
   |-----|---------|
   | `delete` | dead code or a speculative feature nobody asked for — and you established *why* it is orphan |
   | `delete?` | looks dead but you could not confirm it's unreachable — flag, do not assert dead |
   | `merge` | this change duplicates a function/block that already exists — consolidate into one |
   | `stdlib` | reinvented standard-library functionality |
   | `native` | a dependency doing what the platform/language/DB does natively |
   | `yagni` | an abstraction with exactly one implementation/caller |
   | `shrink` | same logic, fewer lines |

4. **Orphan rule.** Before tagging `delete`, confirm *why* it's dead — grep the symbol across the tree; check it is not wired via route/DI/registry/codegen/reflection or referenced only in tests. "No callers" alone is not proof. If you cannot confirm it's unreachable, tag `delete?` and say what blocked the trace.
5. **Merge rule.** If the diff reintroduces logic that already exists elsewhere, prefer `merge` — in `fix:` name the existing function to reuse and the call site(s) to repoint, rather than letting the duplicate land.
6. End with the **net lines removable**.
7. If there is nothing to cut: reply exactly `Lean already. Ship.`

## Rules

- Report only. Change nothing — this is a review, not an edit pass (use `simplify` / `dev-squad:code-simplifier` to apply, then re-verify build + tests).
- Do not flag correctness, security, validation, error handling, or accessibility. Those are never "over-engineering" — see the `dev-squad:simp` "When NOT to be lazy" section.
- Prose is limited to the structured `why:`/`fix:` clauses and the net total — no essays.
