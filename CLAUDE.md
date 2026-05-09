# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Type

This is a **Claude Code plugin**, not a runtime application. There is no build/compile/test step — the plugin is consumed by Claude Code directly from the filesystem. "Editing" means modifying agent prompts (`agents/dev-squad/*.md`), command definitions (`commands/*.md`), the skill entrypoint (`skills/dev-squad/SKILL.md`), or hook shell scripts (`hooks/*.sh`).

The plugin is `dev-squad` — an 8-agent swarm (coordinator, architect, backend, frontend, reviewer, devops, git-ops, writer) for full-stack development. Current version is in `.claude-plugin/plugin.json` (also mirrored in `.claude-plugin/marketplace.json` — both must be bumped together when releasing).

## Architecture (read this before editing)

The plugin is wired together via three layers that you must understand to make non-trivial changes:

### 1. Entrypoints
- `commands/build.md` — slash command `/dev-squad build <description>`. Contains the entire 7-phase zero-to-ship orchestration prompt that the coordinator agent receives. Editing this changes what zero-to-ship runs.
- `commands/status.md` — slash command `/dev-squad status`. Reads `.dev-squad/workflow-active` in the user's project.
- `skills/dev-squad/SKILL.md` — entrypoint when invoked as a skill (e.g. via `/dev-squad`, `/dev-squad start`, or `/dev-squad <db|schema|migrate|optimize|deploy-db>`). Routes to the coordinator with the right prompt.

### 2. Agents (`agents/dev-squad/*.md`)
Each agent is a markdown file with YAML frontmatter. Frontmatter fields actually consumed by Claude Code:
- `name` (e.g. `coordinator`) — what the agent is dispatched as. Always referenced as `dev-squad:<name>` from outside the plugin.
- `description` — shown to the dispatcher; also the trigger description.
- `model` — `opus` for coordinator/architect, `sonnet` for the rest.
- `think_harder: true` — only on coordinator and architect.
- `memory: true`, `maxTurns: <n>` — runtime limits.
- `skills: [...]` — skills the agent auto-loads.

**No `tools:` whitelist.** Agents inherit all tools from the parent context (this is intentional — see "Why no tools whitelist" below). The body of each agent file is its system prompt, including a "Bootstrap Context" section telling it which skills/MCP tools to use.

### 3. Hooks (`hooks/hooks.json` + `hooks/*.sh`)
Hooks fire on Claude Code lifecycle events and inject context or block actions. All hook scripts are bash and live in `hooks/`. The wiring is in `hooks/hooks.json`. Key events:

| Event | Script | Purpose |
|-------|--------|---------|
| `SessionStart` | `auto-update.sh`, `session-gotchas.sh` | Auto-pull plugin updates from git tags; remind agent to read `.dev-squad/gotchas.md` |
| `SubagentStart` | `inject-workflow-state.sh` | Injects `.dev-squad/workflow-active` JSON so subagents resume from current phase |
| `SubagentStop` | `check-workflow.sh` | Checks if zero-to-ship workflow has incomplete phases (non-blocking reminder) |
| `PreToolUse` (Bash) | `guard-dangerous-ops.sh` | Blocks `rm -rf /`, `DROP DATABASE`, force-push to main, etc. |
| `PostToolUse` (Write\|Edit) | `auto-lint.sh` (async) | Auto-formats edited files |
| `PostToolUse` (Grep\|Bash) | `truncation-check.sh` | Detects truncated tool output |
| `TaskCreated` / `TaskCompleted` | `validate-task-scope.sh`, `validate-task.sh` | Validate task scope and completion |
| `PreCompact` | `pre-compact-save.sh` | Save state before context compaction |
| `Stop` | `stop-verify.sh` (300s timeout) | Final verification before stopping |

When adding a new hook script, make it executable (`chmod +x`) and reference it in `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}` for the path.

### 4. Workflow state contract
The zero-to-ship orchestration uses `.dev-squad/workflow-active` (JSON) in the **user's project directory** (not in this repo) to track phase progress:
```json
{ "workflow": "zero-to-ship", "phases": { "ultraplan": "pending", "discover": "pending", ... } }
```
`inject-workflow-state.sh` reads this on every subagent start. `check-workflow.sh` reads it on subagent stop. The coordinator updates phase statuses (`pending` → `in_progress` → `complete`). If you change phase names, update **all three**: `commands/build.md`, `hooks/check-workflow.sh` (the for-loop list), and `skills/dev-squad/SKILL.md`.

## Why no `tools:` whitelist on agents

Earlier versions had `tools: Bash, Read, Write, Edit, Grep, Glob, Skill` in agent frontmatter. That whitelist **excluded MCP tools** (`mcp__context7__*`, `mcp__sequential-thinking__*`, etc.), so even when the agent prompt said "use context7", agents couldn't actually call MCP — they were silently restricted. Removing `tools:` makes agents inherit all available tools from the parent, including whatever MCP servers the user has installed. **Do not re-add `tools:` to agent frontmatter.** If you need to restrict an agent, do it in the prompt, not the whitelist.

## Common tasks

### Bump version
Edit both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (the `version` field appears in both). Tag the commit `vX.Y.Z` so `auto-update.sh` picks it up on user sessions.

### Add a new agent
1. Create `agents/dev-squad/<name>.md` with frontmatter (no `tools:` field).
2. Add it to the team rosters in `commands/build.md` (the "Your Team" table) and `skills/dev-squad/SKILL.md` (the "Team Members" table).
3. Add an entry in `agents/dev-squad/config.json` `members` array if relevant for the config-driven invocation.
4. Bump version.

### Edit the zero-to-ship workflow
The orchestration prompt is in `commands/build.md`. Phase definitions, the monorepo standard, and the "Common Beginner Mistakes" enforcement list all live there. Don't duplicate this content elsewhere — `skills/dev-squad/SKILL.md` references it.

### Rules (`rules/common/`, `rules/golang/`, `rules/typescript/`)
Markdown rule files with YAML frontmatter (`description`, `globs`). These are surfaced to agents as conventions to follow. They are reference docs, not orchestration logic — editing them changes what agents read but doesn't change runtime behavior.

## Skills (`skills/`)

`skills/dev-squad/` is the plugin's main skill (the entrypoint). Other folders under `skills/` are **pattern reference skills** loaded by individual agents via their `skills:` frontmatter or via Skill Selection Matrix in agent body.

**SaaS sibling-pair (distinct load contexts):**
- `skills/saas-patterns/` — architectural patterns (code-write context, Phase 4 IMPLEMENT). Part 1 backend + Part 2 frontend admin/drill-down.
- `skills/saas-readiness/` — pre-launch readiness + sprint execution + product-surface audit + provider abstraction + regional + case studies. Load during Phase 5+ audit / Phase 6 SHIP gate / pre-existing project extension.

**Pattern reference skills:**
- `backend-patterns`, `frontend-patterns`, `golang-patterns`, `golang-testing`, `postgres-patterns`, `security-review`, `tdd-workflow`

**Canonical SaaS reference:** `docs/saas-build-checklist.md` — single end-to-end checklist mapping every SaaS-class requirement to dev-squad phase + agent + skill section. Reference this BEFORE invoking `/dev-squad build` for SaaS scope, or during pre-existing SaaS audit. Synthesizes saas-patterns + saas-readiness + 2026 industry sources (WorkOS, IOMETE, Scytale, Zylo, EU regulations).

## Testing changes

There is no automated test suite. To validate a change:
1. Install the plugin into a Claude Code session (or `git pull` if already installed — `auto-update.sh` handles this on session start).
2. Run `/dev-squad <command>` in a scratch project and verify the agent dispatches correctly.
3. For hook changes: `bash hooks/<script>.sh` directly with mocked input where possible, or watch session logs for hook errors.

## Dependencies on external plugins / MCP

Agents reference these plugins and MCP servers by **short natural names** (e.g. "context7", "grep-github") rather than full tool identifiers. This is intentional:

- The plugin ships to many users; not every user installs every MCP. Short names degrade gracefully (the agent no-ops if the MCP isn't installed) instead of leaving broken `mcp__*` literals in prompts.
- Upstream MCPs rename tools (mermaid-mcp tools just disconnected as proof). Hardcoded long names rot fast.

**Do not introduce hardcoded `mcp__*` tool identifiers in agent prompts, `skills/dev-squad/SKILL.md`, `skills/dev-squad/config.json`, or `commands/*.md`.** Use the short MCP name (e.g. "context7", "sequential-thinking", "grep-github", "mermaid-mcp", "episodic-memory", "playwright", "chrome-devtools", "ide diagnostics"). The agent figures out the actual tool ID at runtime.

Plugins/MCPs the agents prefer when available:
- **superpowers** — `brainstorming`, `writing-plans`, `test-driven-development`, `systematic-debugging`, `verification-before-completion`, `dispatching-parallel-agents`, `finishing-a-development-branch`, `using-git-worktrees`
- **context7**, **episodic-memory**, **mermaid-mcp**, **grep-github**, **sequential-thinking** — MCP servers
- **playwright**, **superpowers-chrome**, **code-review**, **frontend-design**, **simplify**, **issuetracker**, **find-skills**, **claude-md-management** — plugins/skills

## Conventions

- **Subagent dispatch**: always use fully-qualified `dev-squad:<name>` (e.g. `dev-squad:architect`). Plain names won't resolve.
- **Commit style**: conventional commits (`feat:`, `fix:`, `chore:`). Recent commits show the format `feat: vX.Y.Z — short description`.
- **No emojis in code or docs** unless the user explicitly asks.
