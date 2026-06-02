---
name: continuous-learning
description: dev-squad-native instinct learning. Distills .dev-squad/observations.jsonl (captured deterministically by the observe-learning hook) into confidence-scored, project-scoped instinct files IN-SESSION (no headless daemon). Triggers at Phase 7 LEARN and on /dev-squad evolve. Graduates high-confidence instincts into skills/dev-squad-learned/.
---

# Continuous Learning - Instinct Distillation (dev-squad-native)

## Why this exists

ECC's continuous-learning-v2 distills observations with a **background Haiku agent**. dev-squad cannot use that — the user is subscription-only (no API key for headless agents). So dev-squad keeps ECC's *model* (deterministic capture → confidence-scored instincts → graduation) but does the distillation **in-session**: the already-running coordinator reads the observation log and writes instincts. No daemon, no API key, no Python service.

## The three tiers (this skill owns the middle one)

1. **Capture (deterministic, hook):** `hooks/observe-learning.sh` (PostToolUse) appends one JSONL line per tool call to `.dev-squad/observations.jsonl`. No LLM. Already running.
2. **Distill (in-session, THIS skill):** at Phase 7 LEARN or on `/dev-squad evolve`, read the observations, detect patterns, write/update instincts.
3. **Recall (deterministic, hook):** `hooks/inject-workflow-state.sh` (SubagentStart) injects high-confidence instincts (`confidence >= 0.8`) into every agent at start. Already running.

## Instinct schema (`.dev-squad/instincts/<id>.md`)

```markdown
---
id: prefer-pnpm-over-npm
trigger: "installing or running workspace scripts in this monorepo"
action: "use pnpm, not npm — npm install corrupts the workspace symlinks here"
domain: workflow            # code-style|testing|debugging|git|workflow|security|db|frontend|backend|infra
confidence: 0.7             # 0.3 tentative .. 0.9 near-certain
scope: project
evidence_count: 4
last_seen: 2026-06-02
---

# Prefer pnpm over npm

## Action
Use `pnpm install` / `pnpm <script>`. `npm install` was observed to fail or corrupt state 4×.

## Evidence
- obs 2026-05-30: `npm install` -> err, then `pnpm install` -> ok
- obs 2026-06-01: same resolution
```

## Distillation algorithm (run in-session)

1. **Read** `.dev-squad/observations.jsonl`. If absent/empty → nothing to learn, stop.
2. **Detect patterns** (the three ECC instinct sources):
   - **Error→fix resolution:** an `err:1` record on a command/signature followed later by an `err:0` record on a *similar* signature → instinct "when {X} fails, do {Y}". This is the highest-value class for the "debugs wrong" problem — it captures fixes so they are not re-derived.
   - **Repeated workflow:** the same tool+signature pattern appearing ≥3× → instinct encoding the established step.
   - **Convention:** repeated Write/Edit to the same area with the same shape → a structural convention instinct.
3. **Write/update** an instinct file per pattern:
   - New pattern → create at `confidence: 0.3`, `evidence_count: 1`.
   - Seen-again pattern → `confidence += 0.1` (cap `0.9`), `evidence_count += 1`, update `last_seen`.
   - Contradicted (the established action later failed) → `confidence -= 0.2`; drop the file if it falls below `0.2`.
4. **Rotate:** move processed lines to `.dev-squad/observations.archive/` so the log does not grow unbounded and observations are not double-counted.
5. **Log** what was distilled to `.dev-squad/self-healing-log.md` (or a `learning-log.md`) so the capture-enforcement hook sees a learning was recorded.

## Confidence scoring (use the recursive-decision-ledger discipline)

Use `dev-squad:recursive-decision-ledger` for the evidence/promotion ledger: every distillation round records prior winner, fresh evidence, trial count, and a promotion-gate result. **Confidence is evidence, not proof** — an instinct at 0.9 is a strong default, never a certainty. Keep the evidence trail in each instinct's `## Evidence` section so a wrong instinct can be audited and reversed.

| Score | Meaning | Behavior |
|---|---|---|
| 0.3 | tentative | recorded, NOT injected |
| 0.5 | moderate | recorded, NOT injected |
| 0.8 | strong | injected at SubagentStart; graduation-eligible |
| 0.9 | near-certain | injected; core project behavior |

## Graduation (project instinct → reusable skill)

An instinct with `confidence >= 0.8` AND `evidence_count >= 3` is eligible to graduate into `skills/dev-squad-learned/<slug>/SKILL.md` (frontmatter `learned: true` + the source instinct id). **Graduation is a manual gate** (`/dev-squad evolve` proposes; a human confirms) — auto-generated skills are not trusted blind. This is the cross-project payoff: a pattern proven in one project becomes a reusable skill.

## Scope

`.dev-squad/instincts/` is project-scoped by construction (`.dev-squad/` is per-project), so React conventions stay in the React project and Go conventions stay in the Go project — no cross-project contamination. Only **graduated skills** become global.

**Git:** commit `.dev-squad/instincts/` (curated, reviewable knowledge). Gitignore `.dev-squad/observations.jsonl` and `.dev-squad/observations.archive/` (transient raw capture — noise, and potentially command text you don't want in history).
