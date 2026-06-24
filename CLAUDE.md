# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# 12-rule base (applies to all work on this plugin)

These rules apply to every task in this project unless explicitly overridden. Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

## Rule 1 — Think Before Coding
State assumptions explicitly. If uncertain, ask rather than guess. Present multiple interpretations when ambiguity exists. Push back when a simpler approach exists. Stop when confused. Name what's unclear.

## Rule 2 — Simplicity First
Minimum code that solves the problem. Nothing speculative. No features beyond what was asked. No abstractions for single-use code. Test: would a senior engineer say this is overcomplicated? If yes, simplify.

## Rule 3 — Surgical Changes
Touch only what you must. Clean up only your own mess. Don't "improve" adjacent code, comments, or formatting. Don't refactor what isn't broken. Match existing style.

## Rule 4 — Goal-Driven Execution
Define success criteria. Loop until verified. Don't follow steps. Define success and iterate. Strong success criteria let you loop independently.

## Rule 5 — Use the model only for judgment calls
Use me for: classification, drafting, summarization, extraction. Do NOT use me for: routing, retries, deterministic transforms. If code can answer, code answers.
**Plugin-specific note:** dev-squad's coordinator uses model for agent dispatch (which IS routing via judgment). That's the agent SDK pattern. Outside coordinator dispatch logic, this rule applies normally.

## Rule 6 — Token budgets are not advisory
Per-task: 4,000 tokens. Per-session: 30,000 tokens. If approaching budget, summarize and start fresh. Surface the breach. Do not silently overrun.
**Plugin-specific note:** SaaS-class build sessions may exceed default budget (Phase 0-7 + 9 agents). Coordinator may negotiate higher budget at workflow start. Always surface the breach, don't silently overrun.

## Rule 7 — Surface conflicts, don't average them
If two patterns contradict, pick one (more recent / more tested). Explain why. Flag the other for cleanup. Don't blend conflicting patterns.

## Rule 8 — Read before you write
Before adding code, read exports, immediate callers, shared utilities. "Looks orthogonal" is dangerous. If unsure why code is structured a way, ask.

## Rule 9 — Tests verify intent, not just behavior
Tests must encode WHY behavior matters, not just WHAT it does. A test that can't fail when business logic changes is wrong.

## Rule 10 — Checkpoint after every significant step
Summarize what was done, what's verified, what's left. Don't continue from a state you can't describe back. If you lose track, stop and restate.

## Rule 11 — Match the codebase's conventions, even if you disagree
Conformance > taste inside the codebase. If you genuinely think a convention is harmful, surface it. Don't fork silently.

## Rule 12 — Fail loud
"Completed" is wrong if anything was skipped silently. "Tests pass" is wrong if any were skipped. Default to surfacing uncertainty, not hiding it.

---

## Repository Type

This is a **Claude Code plugin**, not a runtime application. There is no build/compile/test step — the plugin is consumed by Claude Code directly from the filesystem. "Editing" means modifying agent prompts (`agents/*.md`), command definitions (`commands/*.md`), the skill entrypoint (`skills/dev-squad/SKILL.md`), or hook shell scripts (`hooks/*.sh`).

The plugin is `dev-squad` — an 11-agent swarm (coordinator, architect, designer, backend, frontend, reviewer, qa-engineer, auditor, devops, git-ops, writer) for full-stack development. Current version is in `.claude-plugin/plugin.json` (also mirrored in `.claude-plugin/marketplace.json` — both must be bumped together when releasing).

## Architecture (read this before editing)

The plugin is wired together via three layers that you must understand to make non-trivial changes:

### 1. Entrypoints
- `commands/build.md` — slash command `/dev-squad build <description>`. Contains the entire 9-phase zero-to-ship orchestration prompt (phases 0-7 plus the 3.5 design gate) that the coordinator agent receives. Editing this changes what zero-to-ship runs.
- `commands/status.md` — slash command `/dev-squad status`. Reads `.dev-squad/workflow-active` in the user's project.
- `commands/init.md` — slash command `/dev-squad init`. Onboards dev-squad to an **existing** project: analyzes the codebase and generates `docs/architecture.md`, `docs/tech-debt.md`, `.dev-squad/gotchas.md`, and updates CLAUDE.md. For greenfield projects use `/dev-squad build` instead.
- `commands/pitch.md`, `commands/evolve.md`, `commands/retrospective.md` — slash commands for the pre-build idea diagnostic, instinct distillation, and PDCA retrospective respectively.
- `commands/simp-review.md`, `commands/simp-audit.md`, `commands/simp-debt.md` — over-engineering review tools (adapted from ponytail, MIT). Review the diff / audit the whole repo / harvest `simp:` debt comments. After-the-fact companions to the `simp` skill, which fires at write time.
- `commands/skill-stocktake.md` — maintenance audit of this plugin's own `skills/` (frontmatter validity, weak descriptions, overlap, stale references). Quick/Full mode. Report-only. Run it as the plugin grows. Adapted from ecc, MIT.
- `commands/hook-stocktake.md` — maintenance audit of this plugin's own hook artifact loops: every `.dev-squad/*` file a hook writes should have a consumer, and vice versa. Catches write-only orphans (state saved but never restored) and dangling reads. Report-only. The hook-layer companion to `skill-stocktake`.
- `skills/dev-squad/SKILL.md` — entrypoint when invoked as a skill (e.g. via `/dev-squad`, `/dev-squad start`, or `/dev-squad <db|schema|migrate|optimize|deploy-db>`). Routes to the coordinator with the right prompt.

### 2. Agents (`agents/*.md`)
Each agent is a markdown file with YAML frontmatter. Frontmatter fields actually consumed by Claude Code:
- `name` (e.g. `coordinator`) — what the agent is dispatched as. Always referenced as `dev-squad:<name>` from outside the plugin.
- `description` — shown to the dispatcher; also the trigger description.
- `model` — `opus` for coordinator/architect, `sonnet` for the rest.
- `think_harder: true` — on coordinator, architect, designer, reviewer, and auditor (the judgment-heavy roles).
- `memory: true`, `maxTurns: <n>` — runtime limits.
- `skills: [...]` — skills the agent auto-loads.

**No `tools:` whitelist.** Agents inherit all tools from the parent context (this is intentional — see "Why no tools whitelist" below). The body of each agent file is its system prompt, including a "Bootstrap Context" section telling it which skills/MCP tools to use.

### 3. Hooks (`hooks/hooks.json` + `hooks/*.sh`)
Hooks fire on Claude Code lifecycle events and inject context or block actions. All hook scripts are bash and live in `hooks/`. The wiring is in `hooks/hooks.json`. Key events:

| Event | Script | Purpose |
|-------|--------|---------|
| `SessionStart` | `auto-update.sh`, `restore-compact-state.sh`, `session-gotchas.sh`, `validate-workflow-schema.sh`, `check-companions.sh` | Auto-pull plugin updates from git tags; re-inject `.dev-squad/pre-compact-state.md` when the session start is a post-compaction (`source=compact`) — the consumer half of `pre-compact-save.sh`; remind agent to read `.dev-squad/gotchas.md`; validate workflow JSONs; warn about missing companion plugins |
| `SubagentStart` | `inject-workflow-state.sh` | Injects `.dev-squad/workflow-active` JSON so subagents resume from current phase; also injects the minimalism ladder (the `simp` reflex) so it fires deterministically before any subagent writes code; and injects `.dev-squad/design/design-tokens.md` (when present) so the Phase 3.5 design spec is a binding live gate on Phase 4 UI code, not an inert doc |
| `SubagentStop` | `check-workflow.sh`, `auto-governor.sh` | Checks if zero-to-ship workflow has incomplete phases (non-blocking reminder); enforce auto-mode dispatch budget |
| `PreToolUse` (Bash) | `guard-dangerous-ops.sh` | Blocks `rm -rf` of filesystem roots, `DROP DATABASE`, force-push to main, etc. |
| `PreToolUse` (Write\|Edit\|MultiEdit\|NotebookEdit) | `guard-unsafe-code.py` | Blocks introducing dangerous code patterns (eval, injection, etc.) |
| `PreToolUse` (AskUserQuestion) | `auto-guard.sh` | In `--auto` mode, block user questions — agent must infer + log to ledger instead |
| `PreToolUse` (*) | `auto-governor.sh` | Auto-mode runaway backstop (dispatch budget, wall clock) |
| `PostToolUse` (Write\|Edit) | `auto-lint.sh` (async) | Auto-formats edited files |
| `PostToolUse` (Grep\|Bash) | `truncation-check.sh` | Detects truncated tool output |
| `PostToolUse` (Write\|Edit\|Bash) | `observe-learning.sh` (async) | Captures observations for continuous learning |
| `TaskCreated` / `TaskCompleted` | `validate-task-scope.sh`, `validate-task.sh` | Validate task scope and completion |
| `PreCompact` | `pre-compact-save.sh` | Save state before context compaction (producer half; `restore-compact-state.sh` re-injects it on the next `source=compact` SessionStart) |
| `Stop` | `stop-verify.sh` (300s timeout) | Final verification before stopping |
| `TeammateIdle` | `check-teammate.sh` | Block teammate from going idle while workflow tasks are incomplete |

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
1. Create `agents/<name>.md` with frontmatter (no `tools:` field).
2. Add it to the team rosters in `commands/build.md` (the "Your Team" table) and `skills/dev-squad/SKILL.md` (the "Team Members" table).
3. Add an entry in `skills/dev-squad/config.json` `members` array if relevant for the config-driven invocation.
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
- **Quality enforcers** (operationalize prose Rules into review-time tools; auto-loaded by reviewer/qa-engineer, run in Phase 5): `mutation-testing` (Rule 9 — test quality via mutation score, per-language tool table), `silent-failure-hunt` (catches swallowed errors / ignored returns the explicit-failure checks miss — grep candidates + triage), `intent-drift` (Rule 3 — diff vs declared goal, flags scope creep). Adapted from ecc + claude-code-plugins-plus-skills, MIT.
- `changelog` — git history since the last tag → user-facing release notes (Keep a Changelog format), grouped by impact, internal noise dropped. Auto-loaded by `git-ops` at Phase 6/7 SHIP before tagging. Adapted from claude-code-plugins-plus-skills, MIT.
- `simp` — the minimalism ladder (adapted from ponytail, MIT, © Dietrich Gebert; renamed `simp` to avoid colliding with a standalone ponytail install; single-mode, intensity levels dropped). Fires BEFORE writing code: YAGNI → stdlib → native feature → installed dependency → one line. Wired into the code-writer agents (backend, frontend, architect) via `skills:` frontmatter + Skills trigger table, and injected deterministically by `inject-workflow-state.sh`. Generalizes the `crisp-patterns` Reuse-First Protocol from frontend components to all code. Companion commands: `simp-review`/`-audit`/`-debt`.
- `code-simplifier` — the apply-half of the simp family (CLAUDE.md-driven, language-agnostic). Where `simp` *prevents* over-engineering pre-write, `code-simplifier` *reduces* complexity in already-written code while preserving behavior. Loaded by the code-writer agents (backend, frontend) and run in the **Phase 5 fix step** when Phase 5.7 metrics flag duplication / cyclomatic complexity above threshold — applied by the author, then re-verified (build + tests). Review lanes (reviewer/auditor) never invoke it: Phase 5 reports, authors fix, so the measured code stays the shipped code.

**User-facing tool skill:**
- `skills/seo-audit/` — SEO / GEO / AEO website audit. Unlike the pattern-reference skills, this is an interactive workflow tool: invoke directly as `/dev-squad:seo-audit`, or it is loaded by the `writer` agent. Crawls a live site via WebFetch and delivers an in-chat Markdown report (in-chat only — no docx/pdf toolchain). It detects context: interactive runs ask Quick-vs-Full; auto/subagent runs skip the question, default to Quick, and log the assumption (auto-guard hook blocks AskUserQuestion in `--auto` mode).

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
