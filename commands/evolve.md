---
name: evolve
description: Distill captured observations into confidence-scored instincts, and propose high-confidence instincts for graduation into reusable learned skills. In-session (no headless daemon).
---

# /dev-squad evolve

## INSTRUCTIONS: When `/dev-squad evolve` is invoked

Run the in-session distillation pass for continuous learning. This is the manual counterpart to the automatic Phase 7 LEARN distillation. **Load the `dev-squad:continuous-learning` skill** — it owns the algorithm and the instinct schema. Use `dev-squad:recursive-decision-ledger` for the evidence/promotion discipline.

Handle this directly (do NOT dispatch to the coordinator unless a full build is also active).

### Steps

1. **Read inputs**
   - `.dev-squad/observations.jsonl` — captured tool-use signals (from the `observe-learning.sh` hook). If absent or empty: report "no observations captured yet — run some dev-squad work first" and stop.
   - `.dev-squad/instincts/*.md` — existing instincts (to update, not duplicate).

2. **Distill** (per `dev-squad:continuous-learning` algorithm)
   - Detect the three pattern classes: **error→fix resolutions** (`err:1` then a later `err:0` on a similar signature), **repeated workflows** (same signature ≥3×), **conventions** (repeated Write/Edit shape).
   - For each pattern: create a new instinct at `confidence 0.3`, or bump an existing one (`+0.1`, cap `0.9`, `evidence_count += 1`, refresh `last_seen`). Decrement (`-0.2`) any instinct the observations contradict.

3. **Write** instincts to `.dev-squad/instincts/<id>.md` (schema in the continuous-learning skill). Keep the `## Evidence` trail — confidence is evidence, never proof.

4. **Rotate** processed lines from `observations.jsonl` into `.dev-squad/observations.archive/` so they are not double-counted and the log stays small.

5. **Propose graduation** (do NOT auto-graduate)
   - List instincts with `confidence >= 0.8` AND `evidence_count >= 3`.
   - For each, propose a `skills/dev-squad-learned/<slug>/SKILL.md` (frontmatter `learned: true` + source instinct id).
   - **Ask the user to confirm** each graduation before writing the skill — auto-generated skills are not trusted blind.

6. **Log** the run to `.dev-squad/learning-log.md` (one line: timestamp, instincts created/updated, graduations proposed).

### Report format

```
[Dev Squad Evolve]
==================================================
Observations processed: {N}  (archived)
Instincts created:  {list of new ids @ confidence}
Instincts updated:  {list of bumped ids: old -> new confidence}
Instincts decayed:  {list, or "none"}

Graduation candidates (confidence >= 0.8, evidence >= 3):
  - {id}  (confidence {c}, evidence {e})  -> propose skills/dev-squad-learned/{slug}/
    Confirm graduation? [y/N]

High-confidence instincts now injected at every agent start: {count}
==================================================
```

### Notes

- **No headless.** All distillation is done here, in-session, by reading files and reasoning — never a background agent (the user is subscription-only).
- **Project-scoped.** `.dev-squad/instincts/` is per-project by construction; only graduated skills go global (`skills/dev-squad-learned/`).
- Recall is automatic: the `inject-workflow-state.sh` SubagentStart hook injects `confidence >= 0.8` instincts into every agent — you do not need to do anything for recall here.
