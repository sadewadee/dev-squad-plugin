# Design: /dev-squad init
Date: 2026-06-14 | Status: APPROVED

## Problem

`/dev-squad build` starts a project from scratch. There is no equivalent entry point for existing codebases — users who want to bring dev-squad into an established project have no structured onboarding path. `/init` (Claude Code built-in) generates a CLAUDE.md but does not set up `.dev-squad/` state, architecture docs, or a tech debt inventory that agents need to work effectively in an existing repo.

## Goal

One command that reads an existing codebase and produces four artifacts agents can rely on:
1. `docs/architecture.md` — stack, structure, entry points, key modules
2. `docs/tech-debt.md` — TODOs, anti-patterns, complexity hotspots, test gaps
3. `.dev-squad/gotchas.md` — codebase-specific pitfalls agents must read before working
4. `CLAUDE.md` — created if missing; appended with a `## dev-squad context` section if already present

## Agreed Premises

1. This command is for **existing** projects only. New projects use `/dev-squad build`.
2. CLAUDE.md handling: if file exists, append `## dev-squad context` section. Never overwrite the full file.
3. The command must be idempotent: if all four artifacts already exist, print a message and stop. Re-generation requires `--force`.
4. A non-destructive SessionStart hint makes the command discoverable without requiring the user to know it exists.

## Architecture

### Files created/modified

| File | Action |
|------|--------|
| `commands/init.md` | New — slash command definition |
| `hooks/suggest-init.sh` | New — SessionStart discoverability hint |
| `hooks/hooks.json` | Modified — add suggest-init.sh to SessionStart array |

### Flow

```
/dev-squad init [--force]
```

**Step 0 — Idempotency check**
If `docs/architecture.md`, `docs/tech-debt.md`, and `.dev-squad/gotchas.md` all exist (and `--force` is not set):
print "Already initialized. Run /dev-squad init --force to re-generate." and exit.

**Step 1 — Coordinator reads project context**
Read: existing `CLAUDE.md` (if any), `docs/` contents, `git log --oneline -20`, top-level directory structure.

**Step 2 — Parallel dispatch**
- `dev-squad:architect` → produces `docs/architecture.md`
- `dev-squad:reviewer` → produces `docs/tech-debt.md`
Both run concurrently. Coordinator waits for both before Step 3.

**Step 3 — Coordinator synthesizes**
Using architect + reviewer outputs:
- Writes `.dev-squad/gotchas.md` (populated from findings, not a blank template)
- If `CLAUDE.md` exists: appends `## dev-squad context` section
- If `CLAUDE.md` absent: coordinator generates full CLAUDE.md from architect + reviewer findings (equivalent to `/init` output + dev-squad context section)

### Output spec per artifact

**`docs/architecture.md`** (architect writes):
- Tech stack (languages, frameworks, databases, infra)
- Directory structure with purpose per top-level folder
- Entry points and main request/event flows
- Key modules and their responsibilities
- External integrations and dependencies
- Deployment topology (if Dockerfile / CI / infra files present)

**`docs/tech-debt.md`** (reviewer writes):
- TODOs and FIXMEs found in codebase (grouped by severity)
- Anti-patterns or style inconsistencies
- Complexity hotspots (large files, deep nesting, unclear naming)
- Testing gaps (missing coverage areas, no test suite)
- Top 3 priority recommendations

**`.dev-squad/gotchas.md`** (coordinator writes, from both outputs):
- Pitfalls specific to this codebase that agents should know before starting work
- Populated with real findings — not generic advice, not a blank template

**`CLAUDE.md` append section:**
```markdown
## dev-squad context
Tech stack: [summary]
Conventions found: [key conventions]
See: docs/architecture.md | docs/tech-debt.md
```

### `hooks/suggest-init.sh`

Runs at SessionStart. Logic:
1. If `.dev-squad/gotchas.md` exists → exit 0 (already initialized, no hint needed)
2. If any of `package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `pom.xml`, `build.gradle` exists → print one line:
   `TIP: Run /dev-squad init to onboard dev-squad to this project.`
3. Otherwise → exit 0 silently

The hint disappears naturally after init runs (gotchas.md now exists).

## Explicitly OUT of scope

- `workflow-active` — that file belongs to `/dev-squad build`, not init
- API/endpoint inventory doc — not requested
- Interactive prompts during init (no AskUserQuestion) — analysis is fully automated
- Modifying existing `docs/architecture.md` or `docs/tech-debt.md` if they already exist (unless `--force`)

## Version bump

Both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` bumped to v4.28.0.
Tag: `v4.28.0`.
