# Changelog

All notable changes to the dev-squad plugin are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this plugin adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.6.0] — QA hardening: functional verification, LOOKUP enforcement, fresh-eyes debugging

This release closes three quality gaps observed in earlier versions: (1) reviewer never executed the app — bugs caught only at user manual test, (2) MCP lookup was prompt-only and skipped under turn pressure during debug, (3) authors debugged their own code with no fresh-eyes intervention for complex multi-service / browser / multi-module bugs.

### Added — Phase 5.5 FUNCTIONAL VERIFICATION (reviewer)
- **Reviewer must EXECUTE the app, not just read diff.** New mandatory phase between Multi-Angle Review (5) and Metrics Report. Boots backend + frontend, drives golden path via `playwright`, audits every interactive element (no-action buttons, dead links, dead forms = findings), smoke-tests every API endpoint against contract, captures browser console + network logs, traces full data round-trip.
- Output: `.dev-squad/functional-verification.md` with golden-path table, interactive-element audit, API smoke results, console findings, severity verdict.
- **Veto extended**: P0 functional findings (runtime crash, missing endpoint, broken auth, button without onClick) and P1 in golden path now block APPROVE — matching the existing P0/P1 security veto.
- Graceful degrade: if `playwright` / `superpowers-chrome` MCP not installed, document degraded status and fall back to `curl` + `Bash` artifact checks. Coordinator decides ship/no-ship.
- `reviewer.md` `maxTurns` raised 21 → 35 to accommodate execution overhead. Skills added: `playwright-skill:playwright-skill`, `superpowers-chrome:browsing`.

### Added — LOOKUP enforcement via output format (backend, frontend, coordinator)
- **Required output format for ANY debug response** in `backend.md` and `frontend.md`: `## LOOKUP / ## HYPOTHESES / ## DIAGNOSIS / ## FIX / ## VERIFICATION` blocks. LOOKUP must contain verbatim quotes from WebSearch + context7 + grep-github. Frontend version adds mandatory browser inspection (playwright/chrome-devtools console + network + DOM snapshot) when bug is browser-reproducible.
- **HYPOTHESES block via sequential-thinking MCP** is mandatory for complex bugs (multi-service, multi-module, race condition, hydration, intermittent). Authors must generate ≥3 ranked hypotheses before fixing.
- **Coordinator validates LOOKUP block on receipt** (`coordinator.md` self-healing loop). New "LOOKUP Validation Rules" table — coordinator auto-rejects responses with empty LOOKUP, placeholder text in verbatim quotes, all-three-no-result without justification, missing HYPOTHESES on complex bug, DIAGNOSIS not citing LOOKUP findings, or VERIFICATION without verbatim output. Three rejections in a row on same iteration = advance to next tier.

### Added — Fresh-eyes investigation tier (coordinator + reviewer)
- **Self-healing loop is now 3-tiered**: iterations 1-2 = author retries (with LOOKUP enforcement), iteration 3 = reviewer in **Investigation Mode** (fresh eyes, NOT fix), iterations 4-5 = architect re-design.
- **Trigger conditions for fresh-eyes handoff**: same error persists across 2 iterations (author thrashing), error crosses service/module/browser boundary, browser-runtime state involved, or author's iteration-2 LOOKUP returned all "no relevant result".
- **Investigation Mode produces an Investigation Report**, not a fix: re-done LOOKUP, minimal repro, cross-boundary trace, browser-state inspection (playwright/chrome), git-history analysis, ≥3 hypotheses via sequential-thinking, root cause + recommended fix. Author then applies the fix in their context (separation of diagnosis from ownership).
- Investigation Mode escalation paths: `UNABLE TO REPRODUCE` → ask coordinator for environment/data state; `NEEDS ARCHITECT` → jump to iteration 4.
- New section in `reviewer.md`: "Investigation Mode (Fresh-Eyes Debugger)" with full investigation steps, output format, escalation triggers.

### Added — self-healing iteration log
- Coordinator maintains `.dev-squad/self-healing-log.md` per build. Each iteration writes: tier (author / reviewer-investigation / architect), agent dispatched, LOOKUP audit (verbatim queries + URLs), hypothesis tested, result. Feeds Phase 7 LEARN — recurring iteration patterns reveal which bug classes need preventive fix.

### Added — anti-thrashing rule (iterations must show progress)
- **Iteration count is not progress.** Coordinator now compares each iteration's error output against the previous iteration's. Same error verbatim, same root cause with moved symptom, or same hypothesis re-tried = THRASHING detected → skip remaining retries at this tier and advance immediately (fresh-eyes if at iter 2, architect if at iter 4).
- **Required: each iteration produces a Progress Marker.** Author response must include `## Progress Since Last Iteration` block: what changed in code, what changed in error, what was definitively learned. Missing or empty Progress Marker = reject and advance tier.
- **Hard stop at 3 thrashing detections per build** → escalate to user immediately regardless of iteration counter. Three thrashes = systemic issue (tooling, environment, fundamentally wrong approach), more iterations cannot fix.

### Added — current-info enforcement at project start (not just debug)
- **Phase 0 ULTRAPLAN (coordinator)** now mandates a CURRENT-INFO LOOKUP step before any tech-stack pre-decision. WebSearch with current-year filter ("{tech} latest version {year}", "{framework} known issues {year}", "{tool} deprecated") + context7 for current API surface. master-plan.md must include an "Evidence" section with ≥3 verified lookups. Pre-deciding from training data alone is now blocked — coordinator's recall of "the standard library for X" may already be deprecated.
- **Architect DISCOVER phase** strengthened: explicit current-year WebSearch queries, currency cross-check ("{library} GitHub releases" / "{library} npm latest" for every recommended library to confirm not superseded), context7 fallback to WebSearch when docs are >6 months old for fast-moving libraries.
- **Architect Tech Stack Recommendation template** Evidence section now requires WebSearch row covering recency check + post-mortem/outage research, in addition to context7 + grep-github + benchmarks.

### Why these additions
User feedback during v4.6.0 development:
- "pastikan iteration benar benar menyelesaikan masalah tidak hanya perulangan sia sia" — without anti-thrashing, the new 5-iteration self-healing tier could burn iterations on the same bad fix.
- "gunakan tooling websearch atau semacamnya saat proses information gathering... untuk debugging atau starting project untuk memastikan informasi terupdate" — v4.5 mandated WebSearch for debug; v4.6 extends it to project start (Phase 0 + DISCOVER) since training data lags reality by months and pre-decisions from memory introduce silent risk.

### Why these changes
Observed symptoms in v4.5 builds:
- Bugs ketangkap di manual test atau bahkan bikin app error — reviewer pure static analysis, never boots app. Logic errors at backend level and silent button-without-onClick at frontend lolos review.
- `context7` and `sequential-thinking` MCP **never called during debugging**, only during early phases. Prompt instruction in v4.5 was insufficient — agents rationalize-skipped under maxTurns pressure.
- Complex bugs (multi-service, browser, multi-module) failed self-healing because author = bug-introducer = blind to own pattern.

### Documentation
- README directory tree updated.
- v4.6.0 changes are reviewer-side and orchestrator-side; no opus-tier dispatch added (reviewer remains sonnet). User's weekly opus quota is not impacted by this release.

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
