# Workflow Definitions

This directory contains the **canonical runtime contract** for dev-squad workflows. The coordinator agent reads these JSON files at workflow start to drive dispatch decisions.

## Files

| File | Purpose |
|---|---|
| `_schema.json` | JSON Schema Draft 7 validator for all workflow files |
| `zero-to-ship.json` | Full project build: 9 phases (ULTRAPLAN -> LEARN). Triggered by `/dev-squad build`. |
| `feature-development.json` | Add feature to existing project. Diff-scope-aware dispatch. Triggered by `/dev-squad feature`. |
| `bug-fix.json` | Reproduce -> root cause -> fix -> verify. Triggered by `/dev-squad fix`. |
| `refactoring.json` | Restructure with before/after metrics proof. Triggered by `/dev-squad refactor`. |

## Drift policy

**JSON is canonical. Agent prompts must align with JSON, not the other way around.**

When you change a workflow:
1. Edit the relevant `<workflow-id>.json` first.
2. Validate: `jq empty <file>.json` and check against `_schema.json`.
3. Update affected agent prompts in `agents/dev-squad/*.md` to match.
4. Update `docs/workflow-mapping.md` (the human-readable view).
5. Run `bash hooks/validate-workflow-schema.sh` to detect drift.

When you add a workflow:
1. Copy an existing JSON as starting template.
2. Update `workflow_id`, `name`, `description`, `trigger_command`.
3. Add a `commands/<workflow-id>.md` slash command (or extend `skills/dev-squad/SKILL.md` routing).
4. Reference the JSON from coordinator's bootstrap context.

## Schema versioning

`schema_version` field tracks compatibility:
- **MAJOR** bump = breaking changes (existing JSONs need migration)
- **MINOR** bump = additive (new optional fields)

Current schema: `1.0`.

## How coordinator uses this

At workflow start, coordinator:
1. Resolves which workflow JSON to read based on slash command:
   - `/dev-squad build` -> `zero-to-ship.json`
   - `/dev-squad feature` -> `feature-development.json`
   - etc.
2. Reads JSON and uses as dispatch source-of-truth:
   - Phase ID list (drives `.dev-squad/workflow-active` JSON)
   - Lead agent + parallel agents per phase (drives Agent tool dispatch)
   - Inputs/outputs (verifies artifacts exist before/after each phase)
   - Blocking gates (refuses to advance if check fails)
   - Skip conditions (handles `--mvp-mode`, scope-based skips)
   - External skills preferred (invokes if installed, fallback otherwise)
3. Falls back to implicit prompt knowledge if JSON missing (older plugin install).

## External skills (companion plugins)

Each phase can declare `external_skills.preferred[]` with skills agents prefer to invoke:

```json
"external_skills": {
  "preferred": [
    {
      "skill": "ui-ux-pro-max",
      "rationale": "Design intelligence for designer Phase 3.5",
      "graceful_degrade": true,
      "invoked_by": "designer"
    }
  ],
  "fallback": "Manual via WebSearch + frontend-design skill"
}
```

`graceful_degrade: true` means: if skill is not installed, agent continues with fallback. No hard dependency.

See `docs/companion-plugins.md` for the full companion plugin guide.

## Validation

```bash
# Validate all workflow JSONs are valid JSON
for f in *.json; do jq empty "$f" || echo "INVALID: $f"; done

# Validate against schema (requires ajv-cli or similar)
# Optional - jq syntax check is the minimum bar
```

## Related files

- `docs/workflow-mapping.md` - human-readable mapping view (table + mermaid diagrams)
- `docs/companion-plugins.md` - companion plugin integration guide
- `commands/build.md` - descriptive prompt (canonical = JSON; prompt = view)
- `agents/dev-squad/coordinator.md` - reads workflow JSON in bootstrap context
- `hooks/validate-workflow-schema.sh` - drift detection (dev-only)
