# Changelog

All notable changes to the dev-squad plugin are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this plugin adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.9.0] — Workflow mapping schema + companion plugin auto-install

**Why:** Knowledge of "which agent runs in which phase, which artifacts gate next phase, which companion skill should be invoked when" was scattered across 5+ files (coordinator.md, build.md, SKILL.md, individual agents). This caused drift and made it hard for users to install the right companion ecosystem. v4.9.0 introduces a **machine-readable runtime contract** + **declarative companion manifest** + **auto-install bootstrap**.

### Added — Workflow JSON schema (runtime contract)

`.claude-plugin/workflows/` now contains canonical workflow definitions:
- `_schema.json` — JSON Schema Draft 7 validator
- `zero-to-ship.json` — full 9-phase build workflow
- `feature-development.json` — daily feature workflow with diff-scope tier dispatch
- `bug-fix.json` — reproduce → fix → verify
- `refactoring.json` — with before/after metrics proof

Each phase declares: lead agent, parallel agents, inputs/outputs (with blocking flag), skip conditions (`--mvp-mode`, no-UI, etc.), verification command, rate-limit tier, and `external_skills.preferred[]` (companion skills to invoke when available).

**Coordinator now reads workflow JSON at workflow start** as dispatch source-of-truth (with fallback to implicit prompt knowledge if JSON missing).

`hooks/validate-workflow-schema.sh` (SessionStart, dev-only) detects drift between JSON and agent prompt files.

### Added — Companion plugin manifest + auto-install

`.claude-plugin/companions.json` declares all recommended companion plugins + MCP servers with install commands, tier (required/recommended), purpose, and which dev-squad agents use each.

**Companions wired:**
- **ui-ux-pro-max** (recommended) — invoked by designer in Phase 3.5. Translates ui-ux-pro-max design system output into 4 dev-squad artifacts. Without it, designer falls back to manual flow.
- **gsd** (get-shit-done, recommended) — 10 skills wired across 5 agents:
  - `gsd-new-project`, `gsd-execute-phase` → coordinator
  - `gsd-plan-phase`, `gsd-plan-checker` → architect
  - `gsd-verify-work`, `gsd-audit-milestone` → auditor
  - `gsd-secure-phase` → reviewer
  - `gsd-pr-branch`, `gsd-ship` → git-ops
- **superpowers** (required) — already wired

**Auto-install via `/dev-squad bootstrap`:**
- Reads manifest, detects missing
- MCPs auto-installed via `claude mcp add` (per-item user confirm)
- Plugins: outputs batch `/plugin marketplace add` + `/plugin install` commands for user copy-paste (Claude Code design: plugin install is slash-only)
- Plugins MCPs covered: context7, sequential-thinking, mermaid-mcp, grep-github

`hooks/check-companions.sh` (SessionStart) detects missing companions and emits non-blocking warning every session.

### Added — Documentation

- `docs/workflow-mapping.md` — human-readable mapping (master tables + mermaid diagrams + skip-condition decision tree)
- `docs/companion-plugins.md` — full companion plugin guide
- `.claude-plugin/workflows/README.md` — schema docs + drift policy

### Modified

- All 6 agents (coordinator, architect, designer, auditor, reviewer, git-ops): added companion skills to `skills:` frontmatter
- coordinator.md: new "Companion Skills (Optional, On-Demand)" section + workflow JSON bootstrap
- designer.md: Phase 3.5 step 0 (ui-ux-pro-max companion check + invocation + output translation table)
- skills/dev-squad/SKILL.md: added `/dev-squad bootstrap` command with full logic
- commands/build.md: header note pointing to canonical workflow JSON
- README.md: new "Workflow Mapping" + "Companion Plugins" sections
- hooks/hooks.json: registered validate-workflow-schema + check-companions

### Behavior expectations

- **Backward compatible**: v4.8.0 workflows continue to work without companions; agents fall back to native methodology
- **No required new installs**: superpowers was already required in v4.8.0; companion plugins are all recommended
- **Coordinator dispatches more accurately**: workflow JSON eliminates "did coordinator forget to dispatch designer?" failure mode
- **User trust**: missing companions surfaced at session start (not silently degraded)

### Migration notes

- Existing dev-squad users: no action required. Existing workflows will keep running.
- For maximum capability: run `/dev-squad bootstrap` once after upgrade.
- Plugin install commands for missing companions are surfaced; users decide what to install.

## [4.8.0] — Designer agent + Phase 3.5 anti-AI-slop gate

User reported persistent failure mode: zero-to-ship UI output looks generic — default shadcn slate palette, AI-cliché purple-to-blue gradients, emoji used as icons, responsive skipped, no motion, "modern minimal" boilerplate. Diagnosis: no agent exists to **reject** AI-slop; frontend agent is an implementer, not a designer. v4.8.0 adds the missing role.

### Added — `agents/dev-squad/designer.md` (11th agent — sonnet, `think_harder`)
Owns Phase 3.5 DESIGN. Anti-AI-slop authority. Produces 4 BLOCKING artifacts in `.dev-squad/design/` before frontend can write any UI code:

1. **`design-tokens.md`** — concrete color palette, typography ladder, spacing scale, radius, motion timings + easings, shadow tokens. No TBD placeholders allowed.
2. **`visual-spec.md`** — ≥3 reference URLs with playwright-captured screenshots in `.dev-squad/design/refs/`, brand vibe (concrete adjectives, not "modern minimal"), project-specific anti-pattern list (emoji-as-icon, default shadcn slate, AI-cliché gradients, missing responsive, missing motion).
3. **`component-inventory.md`** — every component × variants × states (loading / error / empty / focus / hover / active / disabled).
4. **`responsive-spec.md`** — mermaid wireframes per page × mobile / tablet / desktop breakpoints.

Designer uses WebSearch + grep-github + playwright (screenshots references) + chrome-devtools (study computed styles of refs) — designing from imagination = AI slop, blocked.

### Added — Phase 3.5 DESIGN in zero-to-ship workflow (`commands/build.md`, `coordinator.md`)
Sits between Phase 3 SCAFFOLD and Phase 4 IMPLEMENT. BLOCKING gate — frontend cannot start UI work until all 4 designer artifacts exist. `--mvp-mode` flag exists for rapid prototyping (slim deliverable: tokens + slim visual-spec only). Workflow tracking JSON now includes `ui_design` phase.

### Added — Visual Gate in `qa-engineer.md` Phase 5.5
qa-engineer's Phase 5.5 functional verification now runs designer's anti-pattern list against shipped UI:
- **Emoji-as-icon detection** (P0): regex `[\u{1F300}-\u{1F9FF}]` in `.tsx`/`.jsx`
- **Inline arbitrary value detection** (P1): grep for Tailwind `[#hex]`, `[Npx]` patterns
- **Responsive presence check** (P0): playwright at 375 / 768 / 1280 viewports + screenshot per page; identical layout at all = P0
- **Motion presence check** (P1): observe DOM transitions on speced-animated states
- **Default shadcn palette check** (P1): computed `backgroundColor` of primary button vs design-tokens.md
- **Anti-pattern list scan** (P1-P2): targeted detection per row in `visual-spec.md`

Visual Gate findings auto-CC'd to designer via direct message.

### Added — Pass 5: DESIGN COMPLIANCE in `reviewer.md` static lane
reviewer's multi-angle review now has a fifth pass: design token discipline lint. Greps for inline arbitrary values, emoji codepoints in JSX, missing responsive classes on layout components, missing motion classes on speced-animated components. Cross-checks component usage against `component-inventory.md`. Hands runtime visual concerns to qa-engineer Visual Gate; reviewer's lane is static lint only.

### Added — Designer in 5 daily-routine workflows (`coordinator.md`)
- **Feature Development** — designer dispatched if feature has UI (skipped if backend-only or `--mvp-mode`)
- **Refactoring** — designer dispatched if visual change in scope (updated tokens / inventory / responsive for affected components only)
- **New Project Setup** — designer mandatory after architect (skipped only if `--mvp-mode`)
- Per-task review (Diff-Scope Heuristic) — added "New UI surface from scratch" row → reviewer + qa-engineer + designer (light pass: tokens used, anti-pattern compliance)

### Added — Dispatch Decision Log includes designer
`.dev-squad/dispatch-log.md` entries now include `designer: {yes|no}` row + designer findings count per dispatch.

### Changed — `frontend.md` reads designer artifacts (no more ad-hoc design)
Replaced "DESIGN REFERENCE WORKFLOW" (frontend improvising design) with **DESIGN ARTIFACTS WORKFLOW**:
1. Read all 4 designer artifacts (BLOCKING — STOP if missing)
2. Translate `design-tokens.md` to code (no inline arbitrary values allowed)
3. Implement components per `component-inventory.md` — every variant + state
4. Wire motion per token system + reduced-motion fallback
5. Implement responsive per `responsive-spec.md` mermaid wireframes
6. SVG icons only — emoji-as-icon is P0 violation
Frontend Bootstrap Context now includes mandatory step: read all 4 design artifacts before any UI code.

### Changed — Cross-agent communication tables (5 agents)
- `architect.md` — added Designer row (handoff page list + component boundaries to Phase 3.5)
- `frontend.md` — added Designer row (escalate spec ambiguity, request new variant)
- `qa-engineer.md` — added Designer row (Visual Gate findings CC)
- `reviewer.md` — added Designer row (token violation found in static lane)
- `architect.md` "To Designer" handoff section added between architect-to-frontend handoff

### Changed — `skills/dev-squad/SKILL.md`
- Description: 10 → 11 agents
- Team Members table updated
- Designer Extended Responsibilities section added
- Agent Communication Matrix expanded 10×10 → 11×11 (designer row + column)
- Common Cross-Agent Scenarios table — 17 new designer-related rows (Phase 3.5 dispatch, artifact handoff, visual gate findings, anti-pattern detection, MVP-mode escape)
- v3.0 Orchestration Patterns — added "Phase 3.5 DESIGN gate" row
- Agent-Specific Tool Matrix — Designer section added (frontend-design, brainstorming, WebSearch, grep-github, playwright, chrome-devtools, context7, mermaid-mcp, episodic-memory)

### Changed — `commands/build.md`
- Workflow renamed: 8 phases → 9 phases (added Phase 3.5)
- Team table 10 → 11 agents
- Phase 4 IMPLEMENT updated: frontend MUST read all 4 design artifacts before UI work; design tokens enforced; SVG icons only; responsive per spec; motion wired
- Phase 5 Lane 2 (qa-engineer) updated to include Visual Gate execution

### Changed — `README.md`
- Agent count 10 → 11
- Designer row in team composition table
- Frontend description updated (implements designer's spec)
- New "Phase 3.5 DESIGN Gate (Anti-AI-Slop)" feature section
- Zero-to-ship phase listing updated to 9 phases including Phase 3.5
- Directory tree updated with `designer.md`

### Behavior expectations
- **Backward compatible**: existing v4.7.1 zero-to-ship runs continue to work; if user explicitly sets `--mvp-mode`, behavior matches old flow (frontend designs ad-hoc).
- **No opus quota impact**: designer is sonnet (with `think_harder` for design judgment). No new opus-tier dispatches added.
- **Rate limit impact**: +1 dispatch per zero-to-ship build. Mitigated by designer being skip-able in workflows where it doesn't apply (backend-only feature, pure code refactor, hotfix, bug fix).

### Migration notes for existing projects
- Existing projects continue without change. Designer artifacts in `.dev-squad/design/` are produced on first re-build or when running `/dev-squad start` on a feature with UI.
- Frontend agent will fail-soft if designer artifacts are missing in a non-zero-to-ship context (escalates to coordinator instead of improvising).

## [4.7.1] — Wire qa-engineer + auditor into all daily-routine workflows

Patch release. v4.7.0 introduced qa-engineer + auditor agents and 3-way Phase 5 review for zero-to-ship, but only Bug Fix and Performance Optimization daily workflows actually dispatched the new agents. Other daily workflows (Feature Development, Refactoring, Security Audit, Data Migration, New Project Setup) and per-task two-stage review still routed exclusively to reviewer — meaning the new agents only fired during the heaviest workflow (zero-to-ship). User reported this gap; v4.7.1 closes it.

This release also wires cross-agent communication so other agents know **when** to escalate to qa-engineer or auditor (previously they could only contact reviewer for QA/perf concerns). And adds a **Diff-Scope Dispatch Heuristic** so coordinator picks the right combo of agents per task — not always 3-way (waste) and not always reviewer-only (gap).

### Added — Diff-Scope Dispatch Heuristic (`coordinator.md`)
Decision table coordinator applies BEFORE every review dispatch. Picks reviewer / qa-engineer / auditor combo based on diff scope:
- Trivial / tiny → reviewer only (or skip)
- New endpoint → reviewer + auditor (Bucket C hammer)
- New interactive UI → reviewer + qa-engineer (verify wired)
- DB schema/queries/migrations → reviewer + auditor (Bucket B safety + perf)
- Auth/payment/data flow → full 3-way
- Refactor ≥200 LOC → reviewer + auditor (before/after metrics) + qa-engineer (no behavior drift)
- Bug fix <50 LOC → reviewer + qa-engineer (verify bug gone in runtime)
- Performance fix → auditor (prove improvement) + reviewer (no security regression)
- Pre-merge final gate → full 3-way
- Hotfix to production → reviewer + qa-engineer (skip auditor for speed)

Default for ambiguous: lean MORE coverage, not less. Cost of missed bug > cost of extra dispatch.

### Added — Dispatch Decision Log (`coordinator.md`)
Coordinator writes append-only entries to `.dev-squad/dispatch-log.md` per dispatch decision: diff stats, areas touched, heuristic row matched, agents dispatched + why, outcome (P0/P1/P2 counts per agent), time to complete. Phase 7 LEARN reads the log + assesses heuristic accuracy ("was the dispatch right?"). Updates heuristic table based on miss patterns. Rolls over per build; weekly archive for long-running projects.

### Changed — 5 daily workflows updated (`coordinator.md`)
- **Feature Development** — pre-merge review now applies Diff-Scope Heuristic; reviewer always + qa-engineer for new endpoints/UI + auditor for DB/large diff
- **Refactoring** — auditor BEFORE baseline metrics + AFTER metrics (prove improvement) + qa-engineer (no behavior drift) + reviewer (intent preserved)
- **Security Audit** — reviewer (static OWASP) + auditor (Bucket C endpoint hammer + Bucket D failure injection + Bucket A config drift) + qa-engineer (auth flow live test)
- **Data Migration** — auditor migration safety scan (Bucket B): NOT NULL on big tables, missing CONCURRENTLY, ACCESS EXCLUSIVE locks; qa-engineer runs migration on staging + hits endpoints during; auditor post-migration regression check
- **New Project Setup** — auditor post-scaffold audit (Bucket A: config drift, env validator, docker compose parse, /health, CORS, TLS) + qa-engineer smoke test scaffold

### Changed — Two-Stage Review Protocol (`coordinator.md`, `commands/build.md`)
- Spec compliance pass: qa-engineer for new endpoint/UI (functional verification = ground truth); reviewer for static spec match
- Code quality pass: auditor for DB/perf/large diff (real metrics); reviewer for security/patterns
- Per-task review uses heuristic; not always reviewer-only

### Added — cross-agent communication tables now know about qa-engineer + auditor
- `architect.md` "Who You Talk To" — added qa-engineer (vague acceptance criteria) + auditor (architecture-level perf concern from audit)
- `backend.md` "Who You Talk To" — added qa-engineer (functional verification request, runtime trace) + auditor (DB perf, migration safety)
- `frontend.md` "Who You Talk To" — added qa-engineer (browser-state bug) + auditor (bundle size, dead exports, type-escape)
- `devops.md` "Who You Talk To" — added qa-engineer (staging ready) + auditor (config drift, pool/max_connections mismatch)
- `git-ops.md` "Who You Talk To" — added qa-engineer (PR touches new endpoint/UI per heuristic) + auditor (PR touches DB/migration per heuristic)

### Changed — `skills/dev-squad/SKILL.md` cross-references
- **Agent Communication Matrix** updated 7×7 → 10×10 (added qa-engineer, auditor, writer rows/columns)
- **Common Cross-Agent Scenarios** table — added 17 new scenarios involving qa-engineer/auditor (500 leak detection, hydration mismatch, button without onClick, slow query, missing index, pool sanity, config drift, complexity threshold, Investigation Mode handoff, PR-ready dispatches per heuristic)
- **v3.0 Orchestration Patterns** table — added "3-Way Phase 5 Review" and "Diff-Scope Dispatch Heuristic" rows; clarified Multi-Angle Review is reviewer's static lane within Phase 5
- **Schema Design workflow diagram** — auditor migration safety scan + reviewer security check (was reviewer doing both)
- **Migration workflow diagram** — auditor migration safety pre-deploy + qa-engineer staging runtime verification + auditor post-migration regression check

### Why this patch
v4.7.0 audit (commissioned by user before release) revealed 18 findings across 5 P0 (workflow gaps), 9 P1 (cross-agent communication gaps), 3 P2 (SKILL.md diagram drift), 1 P3 (pattern table). Without this patch, daily routine usage of dev-squad effectively bypassed the new agents — they only ran during full zero-to-ship builds, which is the rarest workflow. v4.7.1 closes all 18 findings.

### Backward compatibility
No breaking changes. Existing zero-to-ship Phase 5 dispatch unchanged. Bug Fix and Performance Optimization workflows unchanged (already wired in v4.7.0). Other workflows now dispatch additional agents per heuristic — slight runtime increase per workflow (+sonnet calls), but each lane is bounded and parallelizable. No opus impact.

## [4.7.0] — Agent split: qa-engineer + auditor; multi-language metrics; DB perf execution

This release splits execution responsibilities out of `reviewer` into two new agents and extends Phase 5 to a 3-way parallel review (static + runtime + automated). Closes the v4.6 reviewer overload (~770 lines, 9 distinct roles) and adds polyglot support (Go + Python in addition to JS/TS), database performance execution (slow query log + connection leak + migration safety + pool sanity), and API pattern compliance enforcement (REST/GraphQL/gRPC anti-patterns).

### Added — two new agents

- **`qa-engineer`** (sonnet, maxTurns 35) — runtime QA. Owns Phase 5.5 FUNCTIONAL VERIFICATION (boot app, drive golden path via playwright, audit interactive elements, smoke-test API endpoints, browser console gate) and Investigation Mode (fresh-eyes debugger when self-healing iter 3 triggers). Skills: `playwright-skill`, `superpowers-chrome:browsing`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`, `dev-squad:tdd-workflow`. Veto on P0 functional findings + P1 in golden path.
- **`auditor`** (sonnet, maxTurns 30) — automated stability + quality metrics. Owns Phase 5.6 STABILITY EXECUTION (5 buckets: config drift, DB perf, endpoint hammer, failure injection, API pattern compliance) and Phase 5.7 CODE QUALITY METRICS (multi-language tool runner). Skills: `superpowers:verification-before-completion`, `superpowers:systematic-debugging`, `dev-squad:postgres-patterns`, `dev-squad:golang-patterns`, `dev-squad:golang-testing`, `dev-squad:backend-patterns`, `dev-squad:security-review`. Installs missing analyzer tools on demand.

### Changed — reviewer slimmed to original mandate

- `reviewer.md` removed Phase 5.5 FUNCTIONAL VERIFICATION (moved to qa-engineer) and Investigation Mode (moved to qa-engineer). Reviewer is now **static analysis only** — security review, code review on diff, multi-angle review (security/perf/spec/architecture passes), and **Phase 5 Metrics Report synthesis** (combines its own findings + qa-engineer's functional report + auditor's stability and quality reports into single PDCA Check artifact).
- `reviewer.md` `maxTurns` 35 → 25 (back closer to original 21, reflects narrower scope).
- `reviewer.md` skills removed: `playwright-skill`, `superpowers-chrome:browsing` (those moved to qa-engineer).
- File size impact: reviewer was ~770 lines after v4.6; back to ~580 lines.

### Changed — Phase 5 is now 3-way parallel

- Coordinator dispatches **reviewer + qa-engineer + auditor** in parallel during Phase 5. Each owns a distinct lane and is not interchangeable. After all three return, reviewer synthesizes the single Phase 5 Metrics Report.
- All three have veto in their domain: reviewer (security), qa-engineer (functional), auditor (stability/quality).
- Self-healing loop iteration 3 (fresh-eyes investigation) now hands off to **qa-engineer**, not reviewer — qa-engineer has playwright + chrome-devtools for browser-state inspection that reviewer lacks.
- Self-healing iteration log's `Tier:` field now uses `qa-engineer-investigation` (was `reviewer-investigation`).
- Bug Fix workflow updated: dispatch qa-engineer first for reproduce + root cause; reviewer for static regression check.
- Performance Optimization workflow updated: dispatch auditor for profiling + DB perf bucket + benchmark validation (was reviewer).

### Added — multi-language code quality metrics (Phase 5.7)

`auditor` detects project language(s) at audit start by scanning for `package.json`, `tsconfig.json`, `go.mod`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`. Tool set per language:

| Concern | JS/TS | Go | Python |
|---|---|---|---|
| Cyclomatic complexity | `eslint --max-complexity=10` | `gocyclo -over 10` | `radon cc -n B` |
| Duplication | `jscpd --threshold 5` | `dupl -t 50` | `jscpd` |
| Dead code | `ts-prune`, `unimported` | `staticcheck U1000`, `deadcode` | `vulture` |
| Circular deps | `madge --circular` | n/a (compile-time) | `pylint cyclic-import` |
| Type escape | grep `\bany\b`, `@ts-ignore` | grep `interface{}`, `\bany\b` | grep `: Any\b`, `# type: ignore` |
| Outdated deps | `npm-check-updates` | `go list -u -m all` | `pip list --outdated` |
| Linter aggregator | `eslint --max-warnings 0` | `golangci-lint run` | `ruff check` |

Go-specific gates: `go vet`, `staticcheck`, `errcheck`, `go mod tidy -diff`, `go test -race`. JS/TS-specific gates: `tsc --noEmit`, unjustified `@ts-ignore` detection.

For polyglot projects (e.g., Go backend + TS frontend), auditor runs the appropriate tool set per language directory and merges findings.

### Added — Phase 5.6 STABILITY EXECUTION (focuses on 500-class + DB perf)

Five buckets in `auditor`:

- **Bucket A: Config Drift** — diff `.env.example` vs env vars actually consumed in code; validator coverage; `docker compose config` parse; boot health; CORS/TLS/port sanity.
- **Bucket B: Database Stability** — pool size vs `max_connections`; slow query capture via `pg_stat_statements`; index coverage cross-reference; idle-in-transaction connection leak detection; migration safety scan (NOT NULL on large tables, missing CONCURRENTLY, ACCESS EXCLUSIVE locks); N+1 detection from query log.
- **Bucket C: Endpoint Hammering** — every endpoint tested with valid/invalid/malformed/oversized payload + missing-auth + expired-token + SQL-injection-shaped string. Any 500 response = P0 (unhandled exception leak). Stack trace in error body = P0 (info disclosure).
- **Bucket D: Failure Injection** — DB unavailability, network drop, config key delete, worker SIGTERM. Hard guard: refuses to run without `.dev-squad/staging-env` flag (prevents accidental prod-like data loss).
- **Bucket E: API Pattern Compliance** — REST (pagination, idempotency keys, versioning, Retry-After), GraphQL (depth limit, complexity limit, DataLoader, introspection-disabled-in-prod), gRPC (deadlines, error code mapping, streaming pattern correctness).

### Added — failure injection hard guard

`.dev-squad/staging-env` flag file required before auditor runs Bucket D failure injection. Without it, auditor refuses (prints error, exits). Mitigates risk of running chaos tests against shared/prod environments.

### Why these changes
- User feedback during v4.7 design: "jika agent terlalu besar sebaiknya pecah jadi beberapa agent baru" — reviewer was at ~770 lines / 9 distinct roles after v4.6. Splitting respects single responsibility, reduces prompt bloat per dispatch, enables Phase 5 parallel execution.
- "performance and stability improvement" + "code quality improvement" + "support golang tidak hanya js" + "include database performance, merge, maxconnections, sampe pemilihan cara penggunaan api" — direct asks. Stability + DB perf go to auditor Phase 5.6; code quality goes to auditor Phase 5.7 with multi-language tool matrix; API pattern compliance is Bucket E.
- Performance load testing (k6 / lighthouse) deliberately deferred per user direction — "untuk k6 dan lighthouse kurasa belum saatnya, atau bisa dibuatkan skill terpisah". Future release as separate plugin/skill.

### Documentation
- README updated: team table 8 → 10, agent count corrected, new agents documented.
- `commands/build.md` Phase 5 section rewritten for 3-way parallel dispatch with detailed lane responsibilities.
- `skills/dev-squad/SKILL.md` Team Members table updated; Database/Query Optimization workflow diagrams updated to use auditor for DB perf work.
- No opus quota impact — both new agents are sonnet.

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
