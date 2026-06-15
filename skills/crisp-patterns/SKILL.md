---
name: crisp-patterns
description: CRISP component quality framework for dev-squad agents. Five evaluation lenses — Consistent, Responsive, Intuitive, Simple, Purposeful — each with a concrete field-test. Used by designer (Phase 3.5 output gate) and frontend (Reuse-First Protocol Step 0).
---

# CRISP Component Quality Framework

CRISP is a 5-dimension quality check for every UI component.
Use as evaluation lenses, not a mechanical checklist — each has a field test.

## C — Consistent

Component uses the same design tokens as every other component for the same
property type. No arbitrary color, spacing, or motion values.

- Color: always from `design-tokens.md`, never raw hex
- Spacing: always from spacing scale, never arbitrary `px`
- Motion: always from motion tokens, never hardcoded `ms`

**Field test:** Swap this component into a different page in the same app —
does the visual rhythm stay cohesive, or does it feel out of place?

## R — Responsive

Component works correctly at every breakpoint defined in `responsive-spec.md`.

- Breakpoints: base styles for `sm`, scaled up with `md`/`lg`/`xl` prefixes (mobile-first)
- Touch targets: ≥ 44px on mobile
- No hover-only affordances on touch devices

**Field test:** Resize the browser to 375px — is the component still usable,
or does it overflow, collapse, or become untappable?

## I — Intuitive

Users know how to interact with the component without instruction.

- States: hover, focus, disabled, and loading are visually distinct
- Error feedback: appears near the source of the error, not in a distant toast
- Interactions: clicking a button does what its label says — no surprises

**Field test:** Show the component to someone who hasn't seen the app.
Do they immediately know what to click, or do they pause and look around?

## S — Simple

Component does one thing well.

- Props: minimum needed for screens that exist right now — no hypothetical future props
- File size: ≤ 200 lines; if longer, extract a sub-component
- No speculative complexity: every branch of logic must be exercised by a real current screen

**Field test:** Remove one prop from the component. Does any currently-rendered
screen break? If not, that prop doesn't belong yet — remove it.

## P — Purposeful

The component exists for a specific, articulable reason.

- Registry entry: `crisp.purposeful` in `.dev-squad/component-registry.json` is filled and honest
- No overlap: no functional duplication with other components in the registry
- No ghosts: every component defined must be rendered somewhere in the current app

**Field test:** Can you complete "this component exists to ___" in one sentence?
If you can't, or if another component already does that job, don't build it.

---

## Component Registry Schema

When designer initializes or frontend updates `.dev-squad/component-registry.json`,
every entry must conform to this schema:

```json
{
  "version": 1,
  "generated_from": ".dev-squad/design/component-inventory.md",
  "components": [
    {
      "name": "Button",
      "path": "src/components/ui/Button.tsx",
      "aliases": ["Btn", "CTA", "ActionButton"],
      "variants": ["primary", "secondary", "ghost", "destructive", "link"],
      "states": ["default", "hover", "active", "focus", "disabled", "loading"],
      "crisp": {
        "purposeful": "Primary action trigger across all interactive surfaces",
        "simple": true,
        "consistent_token": "--color-primary"
      },
      "owner": "frontend",
      "phase_created": 4
    }
  ]
}
```

Field rules:
- `aliases`: other names frontend might search before creating a duplicate
- `crisp.purposeful`: mandatory one-sentence justification — empty = unjustified component
- `crisp.simple`: false requires a `simplicity_note` field explaining the complexity
- `path`: used by hook to verify file existence
