---
name: simp-audit
description: Audit the whole repository for over-engineering (not just the diff) — reinvented stdlib, redundant dependencies, single-use abstractions, dead code — ranked biggest cut first.
---

# /dev-squad simp-audit

<!-- Ported from ponytail (https://github.com/DietrichGebert/ponytail), MIT, © Dietrich Gebert. -->

Audit the **entire repository** for over-engineering only, not correctness. Scan the whole tree, not a diff. This is the repo-wide companion to `/dev-squad simp-review`.

## Instructions

1. Walk the source tree (skip `node_modules/`, `.git/`, build output, vendored deps).
2. Emit **one line per finding, ranked biggest cut first**, format:

   ```
   <tag> <what to cut>. <replacement>. [path]
   ```

3. Tags:

   | Tag | Meaning |
   |-----|---------|
   | `delete` | dead code or a speculative feature nobody asked for |
   | `stdlib` | reinvented standard-library functionality |
   | `native` | a dependency doing what the platform/language/DB does natively |
   | `yagni` | an abstraction with exactly one implementation/caller |
   | `shrink` | same logic, fewer lines |

4. Also check `package.json` / `go.mod` / `requirements.txt` for **dependencies that an installed dep, the stdlib, or a native feature already covers** — flag with `native` and name the removable dependency.
5. End with the **net lines and dependencies removable**.
6. If there is nothing to cut: reply exactly `Lean already. Ship.`

## Rules

- Report only. Change nothing.
- Do not flag correctness, security, validation, error handling, or accessibility — see the `dev-squad:simp` "When NOT to be lazy" section.
- No prose beyond the finding lines and the net total.
