# Changelog

All notable changes to the dev-squad plugin are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this plugin adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.5.0] — PDCA cycle, evidence-grounding, MCP cleanup

This release adds a full PDCA (Plan-Do-Check-Act) cycle to the swarm, mandates evidence-grounded research/review/debugging, and cleans up MCP tool references throughout.

### Added — PDCA cycle
- **Phase 7 LEARN** added to zero-to-ship workflow. After SHIP, coordinator runs a retrospective: gathers PRD success metrics, Phase 5 metrics report, gotchas, rework counts. Reviewer produces `.dev-squad/retrospective.md`. Wins append to new `.dev-squad/playbook.md`. Gaps go to `docs/next-iteration.md`. Lessons write to agent-memory + episodic memory.
- **`/dev-squad retrospective [scope]`** — new command. Triggers an explicit Act phase outside zero-to-ship (after a feature, sprint, or post-incident). Recommended cadence: weekly via `/schedule`.
- **PRD "Evidence Sources" table — mandatory.** PRDs now require ≥3 documented external lookups (WebSearch, context7, grep-github) before they ship. Empty Evidence Sources = PRD rejected by reviewer.
- **PRD "Goals & Success Criteria" — numeric targets mandatory.** `fast` and `secure` are no longer accepted; every metric requires a number + measurement source. These targets feed Phase 5 Check.
- **Phase 5 Metrics Report** — reviewer now produces a quantitative artifact (target vs actual + Δ + measurement source per metric) alongside the findings list. The metrics report feeds Phase 7 LEARN.

### Added — evidence-grounding
- **CVE Audit (reviewer)** — local tooling alone (`npm audit`, `govulncheck`, `pip-audit`) is no longer sufficient. Reviewer must WebSearch GitHub Security Advisories + NVD for every dependency on auth/data/API changes. Local tools lag new CVEs by days/weeks.
- **Self-healing loop step 1.5: LOOKUP** — coordinator's self-healing loop now mandates WebSearch + context7 + grep-github BEFORE diagnosing. "Most bugs are 5min if Googled, 30min if guessed."
- **Debugging Phase 0: EXTERNAL LOOKUP** — backend and frontend agents must WebSearch the exact error message + context7 the failing library + grep-github the pattern as the FIRST debugging action. Phase 1 (root cause investigation) now starts only after Phase 0.
- **Architect DISCOVER phase** — WebSearch added as mandatory market/post-mortem research (in addition to grep-github + context7) and as a fallback when context7 has no docs for a library.

### Changed
- **Removed `tools:` whitelist from all 8 agent frontmatters.** Earlier versions whitelisted `Bash, Read, Write, Edit, Grep, Glob, Skill` but did NOT include MCP tools, so agents technically could not call MCPs even when the prompt instructed them to. Removing the whitelist makes agents inherit all available tools (including whatever MCP servers the user has installed).
- **MCP references in prompts/docs use short natural names** (e.g. `context7`, `mermaid-mcp`, `episodic-memory`) instead of full tool identifiers (`mcp__context7__query-docs`, `mcp__plugin_episodic-memory_episodic-memory__search`, etc.). Applied across all 8 agent prompts, `skills/dev-squad/SKILL.md`, and `skills/dev-squad/config.json`. Reasons: hardcoded long names rot when upstream MCPs rename tools (mermaid-mcp tools recently disconnected as proof), and short names degrade gracefully when the MCP isn't installed on the user's machine.
- **Zero-to-ship is now 8 phases**, not 7. Phase 0 ULTRAPLAN through Phase 7 LEARN. Phases 0-2 = Plan, Phases 3-4-6 = Do, Phase 5 = Check, Phase 7 = Act.
- `hooks/check-workflow.sh` phase list updated to include `learn`.

### Added — repo hygiene
- `CLAUDE.md` at the repo root — guidance for future Claude Code instances working on this plugin (architecture, hook event matrix, version sync rules, MCP naming convention).
- `CHANGELOG.md` — this file.

### Documentation
- README updated: corrected version reference (was stuck on `v2.0`), team composition now lists all 8 agents (writer was missing), directory tree updated to reflect actual layout.

## [4.4.1] — Earlier release

### Added
- Enforce MCP usage (context7 + sequential-thinking) in agent prompts across all 8 agents.

## [4.4.0]

### Added
- **Writer agent** — eighth team member. Produces production-ready page copy, microcopy, legal pages, SEO metadata, and documentation. Frontend agent now uses writer's content constants instead of hardcoding text.
- Design taste overhaul for the frontend agent — anti-slop rules, design token workflow before coding, reference-driven aesthetics.
- Auto-install skills hook — coordinator can install approved skills at workflow start.

## [4.3.0]

### Added
- External skill integration — agents can load skills from approved marketplaces (anthropics/, supabase/, vercel-labs/, obra/superpowers, softaworks/, muratcankoylan/, ehmo/).
- Supporting hooks & rules.

## [4.2.x]

### Added
- `maxTurns` per agent (`coordinator: 50`, `architect/backend/frontend/writer: 30`, `devops/reviewer: 21`, `git-ops: 15`) to prevent premature stop.
- Expanded max parallel agents from 12 to 21.
- **Phase 0 ULTRAPLAN** — coordinator thinks deeply (scope, entities, tech stack, risks) and writes `.dev-squad/master-plan.md` BEFORE dispatching any agent.

### Fixed
- `check-workflow.sh` removed from `Stop` event (conflicted with ralph-loop/double-shot-latte plugins).
- `check-workflow.sh` made non-blocking to prevent infinite stop loops.
- Stop hook only blocks once per session.
- `stop-verify.sh` skips silently when no project or workflow is active.

## [4.1.x]

### Added
- Continuous learning protocol — every agent must write learnings to agent-memory and append mistakes to `.dev-squad/gotchas.md` before reporting done.
- Stop verification gate.
- Truncation detection hook.
- Self-correction log (`gotchas.md` pattern).

## [4.0.0]

### Added
- 7 skills + 20 rules adopted from ECC patterns.
- Memory bootstrap and completion definitions for all agents (carried over from v3.4).

## [3.x]

### Added
- v3.4: memory bootstrap + explicit "you are NOT done until..." completion definitions for every agent.
- v3.3: cross-plugin skill access + MCP server access.
- v3.2: advanced hooks system (9 hooks total).
- v3.1: smart model routing (opus for critical/integration, sonnet for standard, haiku for gates) + self-healing loop (max 5 retries).
- v3.0: native orchestration upgrade with dual-mode Agent Teams (TeamCreate when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, subagent fan-out as fallback).

### Fixed
- Hardcoded `.mcp.json` removed — MCP installation is the user's responsibility.
- Agent naming format corrected to `dev-squad:{name}` (not the doubled `dev-squad:dev-squad:{name}`).

## [2.x]

### Added
- v2.1: monorepo standard structure (apps/ + packages/ + infra/) and production-grade checklists.
- v2.0: **Zero-to-Ship** workflow — build a full project from one sentence through 6 automated phases.
- Auto-update via SessionStart hook.

## [1.0.0]

Initial release. Core agent swarm with coordinator, architect, backend, frontend, reviewer, devops, git-ops.
