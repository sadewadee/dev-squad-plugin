# /dev-squad init Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `/dev-squad init` slash command that onboards dev-squad to an existing codebase by generating `docs/architecture.md`, `docs/tech-debt.md`, `.dev-squad/gotchas.md`, and updating `CLAUDE.md`.

**Architecture:** `commands/init.md` defines the slash command; it dispatches a coordinator that runs architect + reviewer in parallel, then synthesizes the four output artifacts. `hooks/suggest-init.sh` prints a one-line hint at SessionStart when the project looks like a code repo but hasn't been initialized yet.

**Tech Stack:** Bash (hook), Markdown + YAML frontmatter (command), JSON (hooks.json)

**Spec:** `docs/superpowers/specs/2026-06-14-init-command-design.md`

---

### Task 0: Create feature branch

**Files:** none

- [ ] **Step 1: Create and switch to feature branch**

```bash
git checkout -b feat/dev-squad-init
```

- [ ] **Step 2: Verify on correct branch**

```bash
git branch --show-current
```

Expected: `feat/dev-squad-init`

---

### Task 1: Create `hooks/suggest-init.sh`

**Files:**
- Create: `hooks/suggest-init.sh`

- [ ] **Step 1: Write the hook script**

Create `hooks/suggest-init.sh` with this exact content:

```bash
#!/bin/bash
# dev-squad: SessionStart hook — suggest /dev-squad init for uninitialized projects
# Prints a one-line tip when the project looks like a code repo but hasn't been
# initialized with dev-squad yet. Silently exits once .dev-squad/gotchas.md exists.

GOTCHAS_FILE=".dev-squad/gotchas.md"

# Already initialized — nothing to say
if [ -f "$GOTCHAS_FILE" ]; then
  exit 0
fi

# Detect common project root files that indicate a real code project
if [ -f "package.json" ] || [ -f "go.mod" ] || [ -f "pyproject.toml" ] || \
   [ -f "Cargo.toml" ] || [ -f "pom.xml" ] || [ -f "build.gradle" ]; then
  echo "TIP: Run /dev-squad init to onboard dev-squad to this project (generates architecture docs, tech debt analysis, and .dev-squad/gotchas.md)."
fi

exit 0
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x hooks/suggest-init.sh
```

- [ ] **Step 3: Verify permissions**

```bash
ls -la hooks/suggest-init.sh
```

Expected output contains `-rwxr-xr-x` (executable bit set).

- [ ] **Step 4: Smoke test — no project files present**

```bash
cd /tmp && bash "/Users/sadewadee/Downloads/Plugin Pro/dev-squad-plugin/hooks/suggest-init.sh"
```

Expected: no output (no package.json / go.mod / etc. in /tmp).

- [ ] **Step 5: Smoke test — project file present, no gotchas**

```bash
cd /tmp && touch package.json && bash "/Users/sadewadee/Downloads/Plugin Pro/dev-squad-plugin/hooks/suggest-init.sh" && rm package.json
```

Expected: `TIP: Run /dev-squad init to onboard dev-squad to this project (generates architecture docs, tech debt analysis, and .dev-squad/gotchas.md).`

- [ ] **Step 6: Smoke test — gotchas.md already exists**

```bash
cd /tmp && touch package.json && mkdir -p .dev-squad && touch .dev-squad/gotchas.md && bash "/Users/sadewadee/Downloads/Plugin Pro/dev-squad-plugin/hooks/suggest-init.sh" && rm package.json && rm -rf .dev-squad
```

Expected: no output (already initialized).

- [ ] **Step 7: Commit**

```bash
git add hooks/suggest-init.sh
git commit -m "feat: add suggest-init.sh SessionStart hint for uninitialized projects"
```

---

### Task 2: Wire `suggest-init.sh` into `hooks/hooks.json`

**Files:**
- Modify: `hooks/hooks.json`

- [ ] **Step 1: Add suggest-init.sh to the SessionStart array**

In `hooks/hooks.json`, find the `SessionStart` hooks array. It currently ends with `check-companions.sh`. Add `suggest-init.sh` as the fifth entry, after `check-companions.sh`:

```json
{
    "type": "command",
    "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/suggest-init.sh\""
}
```

The full SessionStart block after the change:

```json
"SessionStart": [
    {
        "hooks": [
            {
                "type": "command",
                "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/auto-update.sh\""
            },
            {
                "type": "command",
                "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-gotchas.sh\""
            },
            {
                "type": "command",
                "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/validate-workflow-schema.sh\""
            },
            {
                "type": "command",
                "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/check-companions.sh\""
            },
            {
                "type": "command",
                "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/suggest-init.sh\""
            }
        ]
    }
],
```

- [ ] **Step 2: Validate JSON is well-formed**

```bash
python3 -m json.tool hooks/hooks.json > /dev/null && echo "JSON valid"
```

Expected: `JSON valid`

- [ ] **Step 3: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat: wire suggest-init.sh into SessionStart hooks"
```

---

### Task 3: Create `commands/init.md`

**Files:**
- Create: `commands/init.md`

- [ ] **Step 1: Write the command file**

Create `commands/init.md` with this exact content:

```markdown
---
name: init
description: Onboard dev-squad to an existing project. Analyzes the codebase and generates docs/architecture.md, docs/tech-debt.md, .dev-squad/gotchas.md, and updates CLAUDE.md. For new projects, use /dev-squad build instead.
---

# /dev-squad init

## INSTRUCTIONS: When `/dev-squad init` is invoked

Onboard dev-squad to an **existing** project. Do NOT use this for new projects — new projects use `/dev-squad build`.

### Step 0: Idempotency check

Before dispatching any agents, check whether all three init artifacts already exist:
- `docs/architecture.md`
- `docs/tech-debt.md`
- `.dev-squad/gotchas.md`

If all three exist AND the user did not include `--force` in the command:

Print exactly:
```
Already initialized. Run /dev-squad init --force to re-generate.
```
Stop. Do not dispatch any agents.

### Step 1: Read project context

Before launching the coordinator, read:
- `CLAUDE.md` (if present — note whether it exists, you will pass this to the coordinator)
- Top-level directory listing
- `git log --oneline -20` (if this is a git repo)
- `docs/` directory listing (if present)

### Step 2: Launch coordinator

Use the Agent tool to launch `dev-squad:coordinator`:

```
Agent tool with:
  subagent_type: "dev-squad:coordinator"
  description:   "Init: onboard dev-squad to existing project"
  prompt: (see below)
```

Coordinator prompt — substitute the project context you read in Step 1:

---

You are the coordinator running `/dev-squad init` for an existing project.

## Project Context

```
<insert top-level directory listing>
<insert CLAUDE.md content if it exists, otherwise write "CLAUDE.md: not present">
<insert git log if available, otherwise "not a git repo">
```

## Your job: three steps in order

### Step A — Parallel dispatch

Launch these two agents **concurrently** using the Agent tool. Do NOT wait for one before launching the other. Start both immediately.

**Agent 1 — `dev-squad:architect`**

Brief:
```
Read this existing codebase thoroughly. Produce docs/architecture.md.

Create the docs/ directory if it does not exist.

Cover ALL of the following — skip a section only if there is genuinely nothing to say:
- Tech stack: languages, frameworks, databases, infra tools
- Directory structure: purpose of each top-level folder (not just a listing — explain what lives there)
- Entry points: where requests/events/jobs enter the system; main execution flows
- Key modules: what each major module/package does and how they relate
- External integrations: third-party APIs, services, queues, storage
- Deployment topology: if Dockerfile / docker-compose / CI files / infra-as-code present, describe the deployment shape

Be specific. Use real names from the codebase. Do not write generic boilerplate.
Write the file to docs/architecture.md.
```

**Agent 2 — `dev-squad:reviewer`**

Brief:
```
Read this existing codebase thoroughly. Produce docs/tech-debt.md.

Create the docs/ directory if it does not exist.

Cover ALL of the following — skip a section only if nothing was found:
- TODOs and FIXMEs: list them grouped by severity (High / Med / Low), with file:line for each
- Anti-patterns: naming inconsistencies, mixed conventions, duplicated logic, unclear abstractions
- Complexity hotspots: files over 500 lines, deeply nested logic, functions doing too many things
- Testing gaps: missing test suite, untested critical paths, tests that only assert happy path
- Top 3 priority recommendations: concrete, actionable, ordered by impact

Use real findings from the codebase. Do not write generic advice.
Write the file to docs/tech-debt.md.
```

Wait for BOTH agents to complete before proceeding to Step B.

### Step B — Create `.dev-squad/gotchas.md`

Read `docs/architecture.md` and `docs/tech-debt.md`.

Create the `.dev-squad/` directory if it does not exist.

Write `.dev-squad/gotchas.md` — a curated list of pitfalls specific to THIS codebase that any agent should read before starting work. Pull real, specific findings from both docs. Do not write a blank template. Do not write generic advice.

Format:
```markdown
# Gotchas
_Generated by /dev-squad init — update as you discover new pitfalls._

## [Category derived from findings]
- [Specific pitfall with file reference if relevant]

## [Another category]
- [Another specific pitfall]
```

### Step C — Update CLAUDE.md

Check if `CLAUDE.md` exists in the project root.

**If `CLAUDE.md` exists:** append this section at the very end of the file:

```markdown

## dev-squad context
Tech stack: [1-line summary: e.g. "Go 1.22 / Gin / PostgreSQL / Docker"]
Conventions found: [2-3 key conventions: e.g. "snake_case DB columns, no ORM, migrations via golang-migrate"]
See: docs/architecture.md | docs/tech-debt.md
```

**If `CLAUDE.md` does not exist:** generate a full CLAUDE.md in the project root:

```markdown
# CLAUDE.md

[Project name and one-paragraph overview of what this project does]

## Tech Stack
[Derived from codebase — languages, frameworks, databases, key tools]

## Key Commands
[Derived from package.json scripts / Makefile / README — build, test, run, lint commands]

## Architecture
[2-3 paragraph summary. Full detail: docs/architecture.md]

## Conventions
[Key conventions found in the codebase — naming, structure, patterns]

## dev-squad context
Tech stack: [1-line summary]
Conventions found: [2-3 key conventions]
See: docs/architecture.md | docs/tech-debt.md
```

### Done — print summary

After Step C completes, print:

```
/dev-squad init complete.

Generated:
  docs/architecture.md        — architecture overview
  docs/tech-debt.md           — tech debt inventory
  .dev-squad/gotchas.md       — agent pitfall guide
  CLAUDE.md                   — [created | updated with dev-squad context]

Next: run /dev-squad build <feature> to start building on this project.
```

---
```

- [ ] **Step 2: Verify frontmatter is valid**

```bash
head -5 commands/init.md
```

Expected:
```
---
name: init
description: Onboard dev-squad to an existing project. ...
---
```

- [ ] **Step 3: Verify command appears in commands/ listing**

```bash
ls commands/
```

Expected: `build.md  evolve.md  init.md  pitch.md  retrospective.md  status.md`

- [ ] **Step 4: Commit**

```bash
git add commands/init.md
git commit -m "feat: add /dev-squad init command for existing projects"
```

---

### Task 4: Bump version to v4.28.0

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Bump version in `plugin.json`**

In `.claude-plugin/plugin.json`, change:
```json
"version": "4.27.0",
```
to:
```json
"version": "4.28.0",
```

- [ ] **Step 2: Bump version in `marketplace.json`**

In `.claude-plugin/marketplace.json`, change:
```json
"version": "4.27.0",
```
to:
```json
"version": "4.28.0",
```

- [ ] **Step 3: Verify both files updated**

```bash
grep '"version"' .claude-plugin/plugin.json .claude-plugin/marketplace.json
```

Expected:
```
.claude-plugin/plugin.json:  "version": "4.28.0",
.claude-plugin/marketplace.json:  "version": "4.28.0",
```

- [ ] **Step 4: Commit and tag**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat: v4.28.0 — /dev-squad init command for existing projects"
```

Note: tag `v4.28.0` is pushed **after** the PR is merged to main (see Task 5).

---

### Task 5: Open PR

- [ ] **Step 1: Push branch and open PR**

```bash
gh pr create \
  --title "feat: v4.28.0 — /dev-squad init for existing projects" \
  --body "$(cat <<'EOF'
## What

Adds `/dev-squad init` — a one-command onboarding flow for existing codebases.

## Output

- `docs/architecture.md` — tech stack, structure, entry points, key modules (architect agent)
- `docs/tech-debt.md` — TODOs, anti-patterns, complexity hotspots, test gaps (reviewer agent)
- `.dev-squad/gotchas.md` — codebase-specific pitfalls for agents (coordinator, from both)
- `CLAUDE.md` — created if missing; appended with `## dev-squad context` if already present

## Discoverability

`hooks/suggest-init.sh` (new, wired into SessionStart) prints a one-line tip when the project looks like a code repo (`package.json` / `go.mod` / etc.) but `.dev-squad/gotchas.md` doesn't yet exist. Tip disappears after init runs.

## Idempotency

If all three init artifacts exist and `--force` is not passed, command prints "Already initialized" and stops.

## Honest limitations

Quality of generated docs depends on codebase expressiveness. Effects verified from repo structure only — not from a live `/dev-squad init` run in a scratch project.
EOF
)"
```

- [ ] **Step 2: Verify PR opened**

```bash
gh pr list --state open
```

Expected: PR for `feat: v4.28.0 — /dev-squad init for existing projects` appears.

- [ ] **Step 3: After PR is merged — tag and push**

```bash
git checkout main && git pull origin main
git tag v4.28.0
git push origin v4.28.0
```

Expected: tag `v4.28.0` appears on GitHub. `auto-update.sh` will pick it up on next user session.
