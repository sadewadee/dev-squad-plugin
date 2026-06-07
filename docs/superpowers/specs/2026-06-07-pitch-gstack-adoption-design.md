# Design: /dev-squad pitch + gstack pattern adoption (v4.25.0)

Date: 2026-06-07
Status: approved (user-reviewed in session)
Source: patterns adapted from [garrytan/gstack](https://github.com/garrytan/gstack) (MIT, (c) 2026 Garry Tan)

## Problem

dev-squad's zero-to-ship workflow refines the scope of a project that is already
assumed worth building (`build.md` even forbids clarifying questions before
Phase 0). Nothing challenges the premise itself. gstack's `/office-hours`,
`/plan-ceo-review`, and `/design-shotgun` contain proven prompt patterns that
fill three real gaps:

1. No premise-challenging idea diagnostic before any code.
2. Phase 0 infers ambition level silently instead of asking.
3. Designer Phase 3.5 produces one design direction with no variant exploration
   and no taste memory.

`/plan-eng-review` was evaluated and rejected as a command — ~90% duplicate of
the architect agent. Only its review directives carry over.

## What is adopted vs rejected

| Adopt (prompt patterns, MIT) | Reject (infrastructure) |
|---|---|
| Six Forcing Questions + product-stage routing | ~250-line preamble boilerplate per skill (telemetry, gstack-config, gbrain, upgrade prompts) |
| Startup vs Builder dual mode | `design` binary (OpenAI `gpt-image-2` API key dependency) |
| Anti-sycophancy rules + pushback patterns (BAD/GOOD exemplars) | `codex` CLI cross-model dependency |
| Premise challenge with agree/disagree gate | `~/.gstack/` home-dir state (dev-squad uses `.dev-squad/` in-project) |
| Mandatory alternatives (minimal viable / ideal / creative) with STOP gate | Taste confidence decay (5%/week computed at read — complexity not justified; `count` + `last_seen` + "weight recent entries higher" prose suffices) |
| Ambition posture question (simplified from CEO-review scope modes) | |
| Prime Directives (zero silent failures, every error has a name, shadow paths, edge cases, observability-as-scope) | |
| Anti-convergence directive + concept confirmation + comparison board + taste memory | |

## Component 1: new command `commands/pitch.md` (`/dev-squad pitch <idea>`)

Pre-build idea diagnostic. Produces a design doc, never code (HARD GATE: no
implementation skill, no scaffold, no code).

Flow (adapted from gstack office-hours, all gstack infra removed):

1. **Context gathering** — read CLAUDE.md / recent git history if in a project;
   goal question via AskUserQuestion (startup / intrapreneurship / hackathon /
   open source / learning / fun) → maps to **Startup mode** or **Builder mode**;
   product stage assessment (pre-product / has users / paying customers).
2. **Startup mode** — Six Forcing Questions, ONE at a time, stage-routed
   (pre-product: Q1-Q3; has users: Q2, Q4, Q5; paying: Q4-Q6; pure infra: Q2, Q4):
   Q1 Demand Reality, Q2 Status Quo, Q3 Desperate Specificity, Q4 Narrowest
   Wedge, Q5 Observation & Surprise, Q6 Future-Fit. Each with push-until /
   red-flags guidance. Anti-sycophancy rules and pushback patterns
   (BAD/GOOD exemplars) included verbatim-adapted. Escape hatch: impatient user
   gets 2 most critical remaining questions, second pushback is respected.
3. **Builder mode** — generative questions (coolest version / who would you show
   it to / fastest path to shareable / closest existing thing / 10x version).
   Mid-session upgrade path to Startup mode if the vibe shifts.
4. **Prior pitch discovery** — grep `.dev-squad/pitch/*-design.md` for keyword
   overlap; offer build-on vs start-fresh.
5. **Landscape check** — WebSearch with privacy gate (AskUserQuestion first;
   generalized category terms only, never the product name). Skip gracefully if
   WebSearch unavailable. Three-layer synthesis + eureka check.
6. **Premise challenge** — premises as explicit statements, user agrees/disagrees
   via AskUserQuestion before any solution talk. Includes distribution-channel
   check for new artifacts.
7. **Second opinion (optional)** — fresh-context Claude subagent
   (`subagent_type: "general-purpose"`) with a structured summary, NOT the
   conversation. Mode-appropriate prompt (steelman + premise attack + 48h
   prototype). No codex.
8. **Alternatives (MANDATORY)** — 2-3 approaches (one minimal-viable, one
   ideal-architecture, optionally one creative/lateral) with effort/risk/
   pros/cons/reuses. STOP gate: no design doc until user picks.
9. **Design doc** — written to `.dev-squad/pitch/<YYYY-MM-DD>-<slug>-design.md`
   (problem, evidence, premises, chosen approach, alternatives considered,
   narrowest wedge, what's explicitly OUT, next action).
10. **Handoff** — suggest `/dev-squad build` (Phase 0 auto-reads the doc).

Conventions: frontmatter `name: pitch` + `description` only; short MCP names;
no emoji; attribution line in an HTML comment at top of file.

## Component 2: `commands/build.md` Phase 0 enhancements

1. **New Step 0: pitch design doc check.** If `.dev-squad/pitch/*-design.md`
   exists, read the most recent; treat its premises, chosen approach, and
   wedge as pre-answered Phase 0 input (do not re-ask what it answers).
2. **Step 1 addition: ambition posture question** (one AskUserQuestion, after
   SaaS detection so the answer can inform intake):
   - "Narrowest wedge" — smallest version that ships value; everything else
     to the fix-it backlog.
   - "As described" (default/recommended) — build what was asked, bulletproof.
   - "10x expansion" — coordinator runs 10x check + platonic ideal, distills
     concrete scope proposals, each presented as its own opt-in
     AskUserQuestion (accept / defer to backlog / skip). Never silently added.
   - Auto mode: skip the question, infer posture from the description,
     log to the assumption ledger (consistent with SaaS intake handling).
3. **Step 4 Validate additions**: 10x check ("what would make this 10x better
   for 2x the effort — and did the user opt in?") and platonic-ideal framing
   (start from what the user feels, not architecture).

Simplification note: gstack's four scope modes (EXPANSION / SELECTIVE / HOLD /
REDUCTION) collapse to three postures because zero-to-ship has no pre-existing
plan to hold or selectively expand; SELECTIVE merges into the 10x opt-in
ceremony.

## Component 3: `agents/architect.md` — Plan Rigor Directives

New subsection under "Enterprise Design Principles":

- Zero silent failures — every failure mode visible, or it is a defect.
- Every error has a name — the specific exception class, trigger, catcher,
  user-visible result, test. Catch-all handlers are a smell; call them out.
- Data flows have shadow paths — trace nil input, empty input, and upstream
  error for every new flow, not just the happy path.
- Interactions have edge cases — double-click, navigate-away-mid-action, slow
  connection, stale state, back button.
- Observability is scope — logs/metrics/alerts for new codepaths are
  first-class deliverables, not post-launch cleanup.
- Everything deferred must be written down — fix-it backlog
  (`docs/next-iteration.md`, the existing retrospective convention) or it
  doesn't exist.

## Component 4: `agents/designer.md` — Step 0.5 "Direction Shotgun"

Inserted after Step 0 (companion skill check), before Artifact 1. Skipped when
Phase 3.5 is skipped (`--mvp-mode`).

1. **Read taste memory** `.dev-squad/design/taste.json`. Schema:
   ```json
   {
     "version": 1,
     "dimensions": {
       "fonts":      { "approved": [{"value": "", "count": 0, "last_seen": ""}], "rejected": [] },
       "colors":     { "approved": [], "rejected": [] },
       "layouts":    { "approved": [], "rejected": [] },
       "aesthetics": { "approved": [], "rejected": [] }
     }
   }
   ```
   Bias concepts toward strong approved signals (weight recent entries
   higher); avoid strong rejections. Conflict flag if the current request
   contradicts a strong signal. No decay computation.
2. **Concept generation** — 3 one-line direction concepts.
   **Anti-convergence directive (hard requirement):** each variant MUST use a
   different font family, color palette, and layout approach. Test: if the
   headline text could be swapped between two variants without anyone
   noticing, one failed — regenerate it. Variants should feel like they came
   from three different design teams.
3. **Concept confirmation** — AskUserQuestion (generate all / change / add /
   drop) before building anything. Max 2 revision rounds.
4. **Build variants** — 3 self-contained HTML/CSS mockups (no build step, no
   external deps beyond font CDN) at `.dev-squad/design/variants/variant-{a,b,c}.html`
   plus `comparison.html` (side-by-side iframes + labels). Open in browser
   (`open` on macOS / playwright fallback). No image-generation API.
5. **Pick** — AskUserQuestion: which variant wins (or remix elements).
   Winner's font/palette/layout drive the 4 blocking artifacts.
   Update `taste.json`: winner dimensions → approved (increment count, stamp
   last_seen); explicit rejections → rejected.
6. **Auto mode** — no user available: self-select best variant against the
   visual-spec rubric, log choice + reasoning to the assumption ledger, still
   update taste.json.

## Component 5: chores

- Version bump 4.24.0 → 4.25.0 in `.claude-plugin/plugin.json` AND
  `.claude-plugin/marketplace.json`.
- `skills/dev-squad/SKILL.md`: add `/dev-squad pitch` to routing/commands table.
- No new agent, no hook changes, no `tools:` frontmatter anywhere.
- Branch `feat/pitch-gstack-adoption` → PR. No direct commits to main.

## Non-goals

- No `/plan-eng-review` or `/plan-ceo-review` commands.
- No gstack binaries, telemetry, gbrain, codex, or image-generation APIs.
- No changes to hooks or workflow-active phase names (no new phases — all
  changes live inside existing phases).
