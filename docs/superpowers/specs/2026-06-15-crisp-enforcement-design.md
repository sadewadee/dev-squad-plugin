# CRISP Enforcement — Design Spec
**Date:** 2026-06-15
**Status:** Approved for implementation
**Approach:** C — Hook-Enforced + Protocol Hybrid

## Problem

Dev-squad agents generate UI components without enforcing CRISP principles
(Consistent, Responsive, Intuitive, Simple, Purposeful), resulting in:

- Duplicate components with different styling in the same project
- Arbitrary color/spacing values instead of design tokens
- Missing responsive breakpoints
- Components with no clear justification (ghost components)
- Frontend ignoring designer's component-inventory.md during feature work

Root causes identified in agent prompts:
1. No "reuse-first" check — frontend has no instruction to grep existing components before creating new ones
2. CRISP not named in either designer or frontend agent as an evaluation framework
3. No shared component registry — component-inventory.md is a spec, not a living registry
4. No mechanical enforcement — prose fires ~50-80%, not reliable for consistency

## Architecture (3 layers)

```
LAYER 1: Hook (Mechanical / Deterministic)
  check-component-reuse.sh
  ↳ Trigger: PostToolUse(Write) on *.tsx/*.ts paths
  ↳ Action: grep component-registry.json for similar names → WARNING if duplication likely
  ↳ Non-blocking (warning only — hard block too aggressive for legitimate variants)

LAYER 2: Protocol (Structured Prose in Agent Prompts)
  designer.md → CRISP Output Gate added to Phase 3.5 output check (+5 items)
  frontend.md → "Reuse-First Protocol" added as Step 0 before component work

LAYER 3: Shared Artifact (Component Registry)
  .dev-squad/component-registry.json (lives in user's project, not plugin repo)
  ↳ Designer initializes from component-inventory.md
  ↳ Frontend reads before creating any component
  ↳ Frontend updates after creating a component
  ↳ Hook reads to detect duplication
```

## File Changes

| File | Action | Scope |
|------|--------|-------|
| `agents/designer.md` | Edit — CRISP gate in output check + skill load | +20 lines |
| `agents/frontend.md` | Edit — Reuse-First Protocol as Step 0 + skill load | +35 lines |
| `hooks/check-component-reuse.sh` | New | ~60 lines bash |
| `hooks/hooks.json` | Edit — wire new hook | +5 lines |
| `skills/crisp-patterns/SKILL.md` | New | ~80 lines |

No changes to: `commands/build.md`, coordinator agent, workflow state contract.

## Component Registry Schema

`.dev-squad/component-registry.json` (initialized by designer, updated by frontend):

```json
{
  "version": 1,
  "generated_from": ".dev-squad/design/component-inventory.md",
  "components": [
    {
      "name": "Button",
      "path": "src/components/ui/Button.tsx",
      "aliases": ["Btn", "CTA"],
      "variants": ["primary", "secondary", "ghost", "destructive", "link"],
      "states": ["default", "hover", "active", "focus", "disabled", "loading"],
      "crisp": {
        "purposeful": "Primary action trigger across all pages",
        "simple": true,
        "consistent_token": "--color-primary"
      },
      "owner": "frontend",
      "phase_created": 4
    }
  ]
}
```

Key fields:
- `aliases` — alternative names frontend might search for (prevents miss on fuzzy match)
- `crisp.purposeful` — mandatory one-sentence justification; empty = component not justified
- `crisp.simple` — boolean; false requires `simplicity_note` field explaining why
- `path` — hook uses this to check if file already exists

## Hook: check-component-reuse.sh

```
Input: stdin JSON — parse tool_input.file_path via python3 (same pattern as guard-dangerous-ops.sh)
  FILE_PATH=$(cat - | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))")

1. Filter: only process paths matching src/components/**/*.tsx
   └─ All other paths → exit 0 (no-op)

2. Extract component name from filename (Button.tsx → "button")

3. Read .dev-squad/component-registry.json if exists
   └─ If missing → exit 0 (registry not initialized yet, not an error)

4. Fuzzy match: compare new name vs all "name" + "aliases" in registry
   (lowercase, strip suffix: Form/List/Item/Card)
   └─ Match threshold: exact OR substring OR Levenshtein distance ≤ 2

5. If match found → print WARNING to stderr:
   "[CRISP] Component '{new}' already exists as '{existing}' at {path}.
    If this is a variant, update component-registry.json instead of a new file.
    If genuinely different, fill crisp.purposeful before proceeding."

6. No match → exit 0
```

Non-blocking (always exit 0). Warning breaks the auto-pilot pattern without
hard-blocking legitimate variant components (e.g. `IconButton` vs `Button`).

### hooks.json wiring

```json
{
  "PostToolUse": [
    {
      "matcher": "Write",
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/hooks/check-component-reuse.sh"
        }
      ]
    }
  ]
}
```

## Agent: designer.md changes

### Frontmatter addition
```yaml
skills:
  - dev-squad:crisp-patterns   # add to existing list
```

### Output check — CRISP Gate (5 new items after existing 9)

```markdown
### CRISP Gate (mandatory — same weight as the 9 items above)

- [ ] Every component in component-inventory.md has a `purposeful` justification
      (one sentence: "this component exists to ___")
- [ ] No two components have overlapping function — if overlap exists, merge or
      remove the redundant one before handoff to frontend
- [ ] Initialize `.dev-squad/component-registry.json` from component-inventory.md
      using the schema defined in the crisp-patterns skill (name/path/aliases/variants/states/crisp/owner/phase_created)
- [ ] Every token in design-tokens.md has at least one component using it —
      tokens with no consumer = dead tokens, remove them
- [ ] Responsive spec covers ALL components in inventory, not just pages
```

## Agent: frontend.md changes

### Frontmatter addition
```yaml
skills:
  - dev-squad:crisp-patterns   # add to existing list
```

### Step 0: Reuse-First Protocol (new, inserted before existing Step 1)

```markdown
### Step 0: Reuse-First Protocol (BLOCKING — before any component work)

Before creating ANY new component file:

1. Query component registry
   Read `.dev-squad/component-registry.json` (if exists).
   Search for intended component name + common aliases.

2. Decision tree:
   - Exact match in registry → USE existing, do not create new file
   - Partial match (similar name/function) → EXTEND via new variant/prop,
     update registry entry
   - No match → CREATE new file, then ADD to registry with all fields filled
   - Registry doesn't exist → skip, flag missing initialization to coordinator

3. Registry update (mandatory after creating new component):
   Edit `.dev-squad/component-registry.json` — add entry with ALL fields:
   name, path, aliases, variants, states, crisp.purposeful, owner, phase_created.
   Empty crisp.purposeful = incomplete task, coordinator rejects.

4. CRISP self-check per component (before submitting):
   - Consistent: uses tokens from design-tokens.md, never arbitrary values
   - Responsive: implements breakpoints per responsive-spec.md
   - Intuitive: state transitions visible, interactions predictable
   - Simple: no props/abstractions unused by any current screen
   - Purposeful: crisp.purposeful in registry is filled and honest

Hook will warn if duplication is detected. Do not dismiss the warning without
updating registry or adding purposeful justification.
```

## Skill: crisp-patterns/SKILL.md

Lightweight reference skill — not a workflow skill. Loaded by designer and
frontend on demand. Defines CRISP as 5 evaluation lenses with a concrete
"test" for each dimension.

```markdown
# CRISP Component Quality Framework

## C — Consistent
Uses same tokens as other components for the same property type.
Test: swap this component into another page — does the visual rhythm stay cohesive?

## R — Responsive
Works at all breakpoints in responsive-spec.md. Mobile-first. Touch targets ≥44px.
Test: resize browser to 375px — is it still usable?

## I — Intuitive
States are visible (hover/focus/disabled/loading). Error feedback near the source.
Test: show to someone who hasn't seen the app — do they know what to click?

## S — Simple
One thing done well. Props minimum for current screens. File ≤200 lines.
Test: remove one prop — does any screen break? If not, the prop doesn't belong.

## P — Purposeful
crisp.purposeful in component-registry.json is filled and honest.
No overlap with other components. No ghost components (not rendered anywhere).
Test: can you complete "this component exists to ___" in one sentence?
```

## Constraints and Decisions

- Hook is PostToolUse(Write) only — not Edit/MultiEdit, because edits to existing
  files are extending, not duplicating. Duplication only happens on new file creation.
- Hook is non-blocking — warn, not hard block. Legitimate variants (IconButton,
  SubmitButton) should not be hard-blocked; judgment belongs to the agent.
- Registry lives in `.dev-squad/` (user's project), same pattern as workflow-active.
  Plugin repo does not ship a registry — it only ships the schema contract.
- CRISP skill is reference-only. It does not trigger a workflow. Designer and frontend
  load it when they need the framework definition, not on every task.
- No change to Phase numbering, coordinator dispatch, or workflow state contract.

## Success Criteria

- Frontend agent queries component-registry.json before creating any component file
- Designer initializes component-registry.json as part of Phase 3.5 output
- Hook emits warning when new *.tsx file name fuzzy-matches an existing registry entry
- crisp.purposeful is non-empty for every component in the registry
- Arbitrary color/spacing values trigger P1 in existing reviewer static lane
  (no change needed — this was already specced; Reuse-First Protocol reinforces it)
