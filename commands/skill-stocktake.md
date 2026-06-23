---
name: skill-stocktake
description: Audit the quality of dev-squad's own skills — drift, redundancy, weak descriptions, stale references, missing attribution — as the plugin grows. Quick mode scans frontmatter + overlap; Full mode adds body quality + stale-reference checks. Report only.
---

# /dev-squad skill-stocktake

<!-- Concept adapted from ecc (skill-stocktake), MIT. -->

Audit every skill under `skills/*/SKILL.md` in this plugin for quality and drift. A growing plugin accumulates weak descriptions, overlapping skills, and references to files/agents that no longer exist; this catches that before it rots. **Report only — change nothing.**

## Modes

- **Quick** (default): frontmatter validity + description quality + cross-skill overlap.
- **Full** (`--full`): Quick, plus body-quality and stale-reference checks.

If invoked without an argument, run Quick and note that Full is available.

## Checks

For each `skills/*/SKILL.md`:

**Frontmatter**
- `name` present and matches the directory name.
- `description` present, and (for the trigger to work) names concrete trigger conditions/keywords — not a vague one-liner.
- Ported skills carry an MIT/source attribution line.

**Description quality**
- Flag descriptions under ~15 words or with no trigger keywords (they won't auto-trigger reliably).

**Overlap** (the big one for a growing plugin)
- Cluster skills whose descriptions cover the same ground (e.g. two "simplify" skills, two "debugging" skills). Report suspected duplicates — overlap means the agent can't tell which to load, and maintenance doubles.

**Full mode adds:**
- **Body quality** — does the skill give concrete, actionable guidance (commands, tables, steps) or just prose? Flag prose-only skills.
- **Stale references** — grep the body for referenced files, agents (`dev-squad:<x>`), skills, commands, and hook scripts; flag any that don't exist in the repo (e.g. a renamed skill, a deleted command, `mcp__*` literals which violate the natural-name convention).
- **Size** — flag SKILL.md over ~400 lines (likely doing too much) or under ~10 (likely too thin).

## Output

```
Skill stocktake (<Quick|Full>): <N> skills audited
Issues by severity:
  HIGH   — <skill>: <broken/duplicate/stale-ref issue>
  MEDIUM — <skill>: <weak description / prose-only / oversize>
  LOW    — <skill>: <nit>
Suspected overlaps: <skill-a> ~ <skill-b> (<shared ground>)
Clean: <count> skills with no issues
```

If all clean: `All <N> skills pass. No drift.`

Do not edit skills — this is an audit. Hand the fix-list to the maintainer.
