---
name: simp-audit
description: Audit the whole repository for over-engineering (not just the diff) — reinvented stdlib, redundant dependencies, single-use abstractions, duplicated functions, dead code — ranked biggest cut first. Each finding carries why it got there and the consolidation/replacement to apply.
---

# /dev-squad simp-audit

<!-- Ported from ponytail (https://github.com/DietrichGebert/ponytail), MIT, © Dietrich Gebert. Extended for dev-squad: prescriptive fix + orphan provenance + merge tag. -->

Audit the **entire repository** for over-engineering only, not correctness. Scan the whole tree, not a diff. This is the repo-wide companion to `/dev-squad simp-review`.

A finding is only useful if the reader can act on it. So every line states three things: **what** to cut, **why** it ended up here (provenance — and, for removals, why it is safe to remove), and the **fix** to apply (the specific consolidation, replacement, or absorbing API/dep — never a vague category).

## Instructions

1. Walk the source tree (skip `node_modules/`, `.git/`, build output, vendored deps).
2. Emit **one line per finding, ranked biggest cut first**, format:

   ```
   <tag> <what to cut>. why: <how it got here / why it's safe to cut>. fix: <the consolidation or specific replacement>. [path]
   ```

   - `fix:` is **always** required and must name the concrete target — the exact stdlib/native API, the installed dependency that absorbs the job, or the surviving function and its merged signature. "Use the stdlib" is not a fix; "`Array.prototype.flat()`" is.
   - The fix must be the **leanest correct** option and **net-negative** in code. Prefer delete / inline / call-the-existing over any new abstraction — a `merge` that adds a base class or wrapper to unify two functions is over-engineering the cure. If the simplest correct fix is not smaller than what it replaces, do not propose it. The cure is never bigger than the disease.
   - `why:` is **required for `delete`, `delete?`, and `merge`** (these carry root-cause and safety weight). For `stdlib`/`native`/`shrink`/`yagni` it may be omitted when self-evident.

3. Tags:

   | Tag | Meaning |
   |-----|---------|
   | `delete` | dead code or a speculative feature nobody asked for — and you established *why* it is orphan (see Orphan rule) |
   | `delete?` | looks dead but the orphan-trace was inconclusive — flag, do not assert dead |
   | `merge` | two or more functions/modules doing materially the same job — consolidate into one |
   | `stdlib` | reinvented standard-library functionality |
   | `native` | a dependency doing what the platform/language/DB does natively |
   | `yagni` | an abstraction with exactly one implementation/caller |
   | `shrink` | same logic, fewer lines |

4. **Orphan rule (why something is dead).** Before tagging `delete`, establish *why* the code/dep is orphan — do not assert "dead" from "no callers" alone. Static absence of callers is defeated by dynamic dispatch, reflection, dependency injection, route/registry wiring, build-time codegen, public API surface, and test-only references.
   - Do the cheap trace: grep the symbol across the whole tree; check it is not registered in a route table, DI container, plugin manifest, or codegen input; for an orphan **dependency**, grep its imports and (if quick) `git log -S<name>` to find when its last use was removed.
   - State the result in `why:` — e.g. `no callers; last use removed when feature X was dropped` or `only referenced in its own tests`.
   - If the trace is **inconclusive** (could be reached dynamically, or you cannot find why it became orphan), tag `delete?` and say what blocked the trace. Never upgrade `delete?` to `delete` on a guess.

5. **Merge rule (kill redundancy, don't just delete).** When two or more functions/blocks do materially the same thing under different names or locations, prefer `merge` over flagging each separately. In `fix:` name the **single survivor**, its merged signature, and the count of call sites to repoint — e.g. `fold formatMoney() into formatCurrency(value, currency='USD'); 4 call sites`.

6. **Dependency check (better, not just fewer).** Read `package.json` / `go.mod` / `requirements.txt` for dependencies an **already-installed** dep, the stdlib, or a native feature already covers — flag `native` and name the absorbing target in `fix:`. Only when nothing already present covers the job may you propose a single lighter replacement, and only with a one-clause reason. Do **not** recommend swapping libraries for novelty — this is a consolidation audit, not a shopping list.

7. End with the **net lines and dependencies removable**.
8. If there is nothing to cut: reply exactly `Lean already. Ship.`

## Rules

- Report only. Change nothing — the author applies the fixes (or `simplify` / `dev-squad:code-simplifier` does), then re-verifies build + tests. Keeping report and apply separate is deliberate: the measured code stays the shipped code.
- Do not flag correctness, security, validation, error handling, or accessibility — see the `dev-squad:simp` "When NOT to be lazy" section.
- Prose is limited to the structured `why:`/`fix:` clauses and the net total — no essays. If a `fix:` needs a paragraph to justify, the finding is not ready; trace it further or downgrade it to `delete?`.
