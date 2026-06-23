---
name: simp-debt
description: Harvest every `simp:` comment in the repo into a tracked debt ledger so deliberate simplifications with a named ceiling do not rot into "later means never". Report only.
---

# /dev-squad simp-debt

<!-- Ported from ponytail (https://github.com/DietrichGebert/ponytail), MIT, © Dietrich Gebert. -->

Harvest every `simp:` comment in the repository into a debt ledger. These markers are deliberate simplifications the `dev-squad:simp` skill told agents to leave behind, each naming a ceiling and an upgrade path. This command makes "later" visible so it does not become "never".

## Instructions

1. Grep the whole tree for the markers, skipping vendored/build dirs:

   ```
   grep -rnE '(#|//|--) ?simp:' . \
     --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build
   ```

2. Emit **one row per marker, grouped by file**:

   ```
   <file>:<line> — <what was simplified>. ceiling: <the limit named>. upgrade: <the trigger to revisit>.
   ```

3. Tag any marker that names **no upgrade path or trigger** as `no-trigger` — those rot silently and are the real risk.
4. End with the **count of markers** and **how many lack a trigger**.
5. If none: reply exactly `No simp: debt. Clean ledger.`

## Rules

- Report only. Change nothing.
- Do not invent ceilings/upgrades the comment does not state — if absent, tag `no-trigger` rather than guessing.
