# dev-squad

**Ship full-stack projects autonomously with 11 specialized AI agents.** Built-in anti-AI-slop UI design gate, 3-way code review (static + runtime + tooling), and SaaS-class readiness checks. A plugin for [Claude Code](https://claude.com/claude-code).

## Who is this for?

| You are... | What dev-squad gives you |
|---|---|
| **Solo indie / weekend builder** | `/dev-squad start <task>` dispatches the right specialist instead of you context-switching. `--mvp-mode` skips heavy artifacts. |
| **Startup founder shipping V1** | `/dev-squad build <description>` runs 9-phase zero-to-ship. One user checkpoint (PRD approval), rest is autonomous. |
| **SaaS founder** | `saas-patterns` + `saas-readiness` skills cover multi-tenancy, billing, plan management, audit logs, SOC 2 / GDPR / EU AI Act readiness. |
| **Agency / consultancy** | Reuse the workflow across client builds. Generated apps include `.claude/` self-docs for clean handoff. |
| **Engineer at an existing project** | `/dev-squad start` handles feature work, bug fixes, refactors, security audits, perf optimization. |

## Quickstart

```bash
# 1. Install plugin (one-time)
claude plugins marketplace add dev-squad-marketplace https://github.com/sadewadee/dev-squad-plugin
claude plugins install dev-squad

# 2. Install the one truly required companion
claude plugins install superpowers

# 3. Ship something
cd my-new-project
/dev-squad build A real-time collaborative task manager with team workspaces
```

You're asked **once** to approve the PRD (Phase 1). Everything else runs autonomously. Use `/dev-squad status` to check progress anytime.

## What makes dev-squad different

- **Phase 3.5 DESIGN gate** — designer agent produces 4 BLOCKING artifacts (tokens, visual spec with references, component inventory, responsive spec) BEFORE frontend writes a single line of UI. Prevents the default-shadcn-slate / purple-gradient / emoji-as-icon AI-slop pattern.
- **3-way Phase 5 review** — static reviewer + runtime qa-engineer (real browser via playwright) + auditor (analyzer tools: slow query log, jscpd, golangci-lint, ts-prune) run in parallel, each with veto.
- **Fresh-eyes debugger** — after 3 self-healing iterations on the same bug, coordinator hands off to qa-engineer in Investigation Mode. Separation of diagnosis from ownership prevents author bias.
- **SaaS-class scope** — multi-tenancy with RLS, subscription billing, audit logs, compliance (GDPR + EU AI Act 2026 + DORA + SOC 2) baked into skills.
- **Self-documenting output** — Phase 6 SHIP pre-seeds generated apps with `.claude/CLAUDE.md` (12-rule engineering base), architecture.md, conventions.md, gotchas.md so future Claude sessions arrive informed.

## When NOT to use dev-squad

- **One-line code fixes** — direct Claude Code chat is faster than orchestrating 11 agents.
- **Pure research / exploration** — no shipping target, no orchestration needed.
- **Projects without git** — git-ops agent and several hooks assume a git repo.
- **You've already built your own multi-agent workflow** — dev-squad's opinions may conflict; pick one.

## Safety: SaaS scope is opt-in only

Multi-tenancy, RLS, billing modules, audit logs, plan management, and admin dashboards are **never** applied unless you explicitly opt in. The plugin defaults to **standard application mode**. SaaS scope activates only when ALL of these are explicit:

- `/dev-squad build`: Phase 0 Step 2.5 asks you with `AskUserQuestion`. The default option is **"No, build a standard app"**. SaaS scope is only enabled if you actively select "Yes, full SaaS scope" or pass `--saas` flag. If you dismiss the question or cancel, plugin locks to non-SaaS.
- `/dev-squad start <feature>`: coordinator's Diff-Scope Heuristic only flags `saas_touch: true` when the feature description explicitly touches multi-tenancy, billing, webhooks, audit, api-keys, or admin scope.
- Existing project: plugin detects SaaS only when file structure already contains SaaS subsystems (`tenants/`, `billing/`, `webhooks/`, `audit-log/`, `plans/`). It does not retrofit SaaS patterns into non-SaaS code.

The decision is recorded in `.dev-squad/master-plan.md` (`SaaS Mode: enabled` or `disabled`) and locked for the project lifetime — multi-tenancy retrofit is a data-leak risk, removal is wasted code. Once decided, it stays.

Every SaaS-capable agent (coordinator, architect, backend, frontend, designer, devops, writer) carries a **"SaaS Scope Safety Default (BLOCKING)"** clause: when uncertain, ask the user via the coordinator. Default-deny, never default-allow.

## Team Composition

| Agent | Role | Model | Key Responsibilities |
|-------|------|-------|---------------------|
| **coordinator** | Lead/Coordinator + Memory Manager | opus | Task decomposition, agent orchestration, conflict resolution, project knowledge management |
| **architect** | System Architect | opus | System design, tech stack decisions, database schema, ADRs, infrastructure planning |
| **designer** | UI/UX Designer | sonnet (think_harder) | Phase 3.5 DESIGN gate. Produces 4 BLOCKING artifacts before frontend codes UI: design-tokens.md, visual-spec.md (with ≥3 references + screenshots), component-inventory.md (variants × states), responsive-spec.md (mermaid wireframes per breakpoint). Anti-AI-slop authority — vetoes emoji-as-icon, default shadcn palette, AI-cliché gradients, missing responsive/motion. |
| **backend** | Backend Developer | sonnet | API development, database operations, business logic, migrations, auth implementation |
| **frontend** | Frontend Developer | sonnet | UI implementation per designer's spec — translates design tokens / component inventory / responsive spec into code. Cannot start UI until all 4 designer artifacts exist. |
| **reviewer** | Security Lead + Static Code Reviewer | sonnet | End-to-end security, threat modeling, OWASP, static code review on diff, Phase 5 metrics report synthesis |
| **qa-engineer** | Runtime QA + Visual Gate + Investigation Mode | sonnet | Phase 5.5 functional verification (boot app, drive golden path via playwright, audit interactive elements, smoke-test endpoints, browser console gate). Visual Gate runs designer's anti-pattern list against shipped UI (emoji-as-icon scan, inline arbitrary value scan, responsive presence at 3 breakpoints, motion presence, default shadcn palette check). Fresh-eyes debugger when self-healing iter 3 triggers. |
| **auditor** | Stability + Quality Metrics | sonnet | Phase 5.6 stability execution (config drift, DB perf, endpoint hammer, failure injection, API pattern compliance) + Phase 5.7 code quality metrics (multi-language: JS/TS, Go, Python). Installs analyzer tools on demand. |
| **devops** | DevOps Engineer | sonnet | Docker/Compose, Traefik, CI/CD, monitoring, secrets management, deployment strategies |
| **git-ops** | Git Operations Manager | sonnet | Branch management, PR workflows, merge strategies, release management, changelog generation |
| **writer** | Content Writer | sonnet | Page copy, microcopy, legal pages, SEO metadata, documentation — production-ready content, not placeholders |

## Supported Workflows

- **Zero-to-Ship** -- build a full project from a single description through 9 automated PDCA phases: ULTRAPLAN, DISCOVER, DESIGN, SCAFFOLD, **UI DESIGN (3.5 — anti-AI-slop gate)**, IMPLEMENT, REVIEW, SHIP, LEARN
- **Feature Development** -- coordinator orchestrates architect design, parallel backend+frontend implementation, security review, deployment, and PR creation
- **Bug Fix** -- reviewer does root cause analysis, implementor applies TDD fix, validation, and hotfix path for critical issues
- **Refactoring** -- architect defines target architecture, incremental refactoring with TDD, staged PRs
- **Security Audit** -- reviewer runs full OWASP audit, architect assesses architecture-level findings, parallel fixes across team
- **Data Migration** -- architect plans strategy and rollback, backend writes scripts, devops handles staging/backup, reviewer validates
- **Performance Optimization** -- reviewer profiles bottlenecks, architect proposes optimizations, parallel implementation, benchmark validation
- **New Project Setup** -- full architecture design, scaffolding, CI/CD, initial implementation, repo configuration
- **Database Tasks** -- schema design, migrations, query optimization, deployment with Docker

## Key Features

### Skill vs MCP Awareness
Every agent understands when to use Skills (process/workflow guidance) versus MCP tools (external data and actions). Skills are invoked for planning, TDD, code review, and verification workflows. MCP tools are called for documentation lookup (context7), code pattern search (grep-github), diagram creation (mermaid-mcp), and conversation history (episodic-memory). Agents reference MCPs by short natural name — they degrade gracefully when an MCP isn't installed instead of failing on hardcoded tool IDs.

### Cross-Agent Communication
Agents use a dual-mode communication protocol:
- **P0-P1 (Critical/High)**: Direct agent-to-agent messaging with coordinator CC'd
- **P2-P3 (Medium/Low)**: Mediated through coordinator

### Security Lead with Veto Power
The reviewer agent owns security end-to-end. It has veto power on P0-P1 security issues and can directly message any agent for urgent security fixes without coordinator mediation. Every PR goes through OWASP Top 10 checks, dependency auditing, and threat modeling.

### Phase 3.5 DESIGN Gate (Anti-AI-Slop)
The most common failure mode for AI-built UIs is the "AI-slop" pattern: default shadcn slate palette, purple-to-blue gradient hero, emoji-as-icon, skipped responsive, no motion, generic centered hero + 3-col features grid. The dedicated **designer agent** (sonnet with `think_harder`) runs Phase 3.5 between scaffold and implement, producing 4 BLOCKING artifacts in `.dev-squad/design/`:

1. **`design-tokens.md`** — concrete color palette, typography ladder, spacing scale, radius, motion timings + easings, shadow tokens (no TBD placeholders)
2. **`visual-spec.md`** — ≥3 reference URLs with playwright-captured screenshots, brand vibe (concrete adjectives, not "modern minimal"), project-specific anti-pattern list
3. **`component-inventory.md`** — every component × variants × states (loading/error/empty/focus/hover/active/disabled)
4. **`responsive-spec.md`** — mermaid wireframes per page × mobile/tablet/desktop breakpoints

Frontend cannot start UI work until all 4 artifacts exist. Inline arbitrary values (`text-[#abc]`), emoji-as-icon, missing responsive, and missing motion are all explicitly P0/P1 violations enforced by reviewer's static lane (Pass 5: design compliance) and qa-engineer's runtime Visual Gate. An `--mvp-mode` flag exists for rapid prototyping (slim deliverable: tokens + slim visual-spec only).

### Workflow Mapping (Runtime Contract)
Workflows are defined as **machine-readable JSON** in `.claude-plugin/workflows/` — the coordinator reads these as dispatch source-of-truth at workflow start. Each phase declares: lead agent, parallel agents, inputs/outputs (with blocking flag), skip conditions, verification command, and external companion skills. The `_schema.json` validates structure; `hooks/validate-workflow-schema.sh` detects drift between JSON and agent prompts at session start.

See [docs/workflow-mapping.md](docs/workflow-mapping.md) for the human-readable view (master tables + mermaid diagrams + skip-condition decision tree).

### Companion Plugins (On-Demand)
Dev-squad reaches maximum capability with optional companion plugins + MCP servers. All companions are **graceful-degrade** — agents fall back to native methodology if not installed.

**Run `/dev-squad bootstrap`** to auto-install MCPs and get plugin install commands.

| Companion | Tier | Used by | Phase |
|---|---|---|---|
| **superpowers** | required | all agents | all phases |
| **ui-ux-pro-max** | recommended | designer | Phase 3.5 UI DESIGN |
| **gsd** (get-shit-done) | recommended | coordinator, architect, auditor, reviewer, git-ops | Phase 0/1/2/4/5/6 |
| **frontend-design**, **code-review**, **playwright-skill**, **superpowers-chrome**, **episodic-memory**, **claude-md-management** | recommended | various | various |
| **MCPs**: context7, sequential-thinking, mermaid-mcp, grep-github | recommended | all | all |

See [docs/companion-plugins.md](docs/companion-plugins.md) for full integration guide and [.claude-plugin/companions.json](.claude-plugin/companions.json) for the declarative manifest.

### 3-Way Phase 5 Review (static + runtime + automated)
Phase 5 of zero-to-ship dispatches three agents in parallel: **reviewer** does static code review on the diff, **qa-engineer** boots the app and drives the golden path through a real browser via playwright, and **auditor** runs real analyzer tools (slow query log, connection leak detector, jscpd, golangci-lint, ts-prune, etc.) against the codebase. Each has veto in their domain. Reviewer synthesizes a single Phase 5 Metrics Report from all three lanes for the PDCA Check artifact.

### Multi-Language Code Quality (JS/TS, Go, Python)
The auditor agent auto-detects project language via `package.json` / `go.mod` / `pyproject.toml` and runs the appropriate analyzer set. Polyglot projects (e.g., Go backend + TypeScript frontend) get parallel tool runs per language directory with merged findings. Tools are installed on demand at devDependencies / `go install` / `pip install --user` scope.

### Fresh-Eyes Debugger via 3-Tier Self-Healing
When the self-healing loop hits iteration 3 after the author has thrashed for 2 iterations on the same bug, coordinator hands off to qa-engineer in **Investigation Mode**. qa-engineer does fresh LOOKUP, cross-boundary trace, browser-state inspection (playwright/chrome-devtools), git history analysis, and produces an Investigation Report with recommended fix. The author then applies the fix in their context (separation of diagnosis from ownership prevents author bias).

### Failure Injection with Hard Guard
The auditor's failure injection bucket (kill DB, drop network, delete config, SIGTERM workers) refuses to run without a `.dev-squad/staging-env` flag file. This guard prevents accidental chaos testing against shared or production-like environments.

### Enterprise Patterns
Built-in support for Architecture Decision Records (ADRs), conventional commits, semantic versioning, trunk-based development, feature flags, blue/green deployments, circuit breakers, health check endpoints, structured logging, and distributed tracing.

### Autonomous Tool Usage
All agents are configured to use their assigned Skills and MCP tools autonomously -- no user confirmation needed. Agents look up documentation, search for patterns, run tests, and verify work independently.

## Installation

### From Marketplace

```bash
# Add the marketplace
claude plugins marketplace add dev-squad-marketplace https://github.com/sadewadee/dev-squad-plugin

# Install the plugin
claude plugins install dev-squad
```

### Manual Installation

Copy the plugin contents to your Claude plugins directory:

```bash
cp -r dev-squad-plugin/ ~/.claude/plugins/dev-squad/
```

Ensure `skills/dev-squad/`, `agents/dev-squad/`, and `hooks/` are placed under your `~/.claude/` directory (or wherever your Claude configuration lives).

## Usage

```bash
# Zero-to-ship: build a full project from scratch
/dev-squad build <description>

# Start the coordinator for a new task
/dev-squad
/dev-squad start

# Database workflows
/dev-squad db <description>        # General database task
/dev-squad schema <description>    # Schema design
/dev-squad migrate <description>   # Database migration
/dev-squad optimize <description>  # Query optimization
/dev-squad deploy-db <description> # Database deployment

# Status and help
/dev-squad status                  # Check swarm progress
/dev-squad help                    # Show available commands
```

### Zero-to-Ship Workflow

The `build` command takes a project description and builds it through 9 automated PDCA phases. Only one user checkpoint exists -- after PRD generation in Phase 1.

```
/dev-squad build A real-time collaborative task manager with team workspaces

Phase 0:   ULTRAPLAN  --> Coordinator deep-thinks scope, entities, tech stack, risks
Phase 1:   DISCOVER   --> Architect brainstorms, researches, generates PRD
                          >>> You approve the PRD <<<
Phase 2:   DESIGN     --> Architect creates full architecture + C4 diagrams + ADRs
Phase 3:   SCAFFOLD   --> DevOps creates project structure, Docker, CI/CD; Git-Ops inits repo
Phase 3.5: UI DESIGN  --> Designer produces design-tokens + visual-spec + component-inventory + responsive-spec (BLOCKING)
Phase 4:   IMPLEMENT  --> Backend + Frontend build in parallel; Frontend reads designer's 4 artifacts before UI
Phase 5:   REVIEW     --> 3-way parallel: reviewer (static + design lint) + qa-engineer (runtime + Visual Gate) + auditor (stability + quality metrics)
Phase 6:   SHIP       --> Staging deploy, PR creation, final sign-off
Phase 7:   LEARN      --> PDCA Act retrospective: playbook + fix-it backlog + CLAUDE.md updates
```

### Examples

```bash
# Zero-to-ship: build a complete project
/dev-squad build A real-time collaborative task manager with team workspaces and Kanban boards

# Zero-to-ship: build an API service
/dev-squad build REST API for inventory management with barcode scanning and warehouse tracking

# Build a user management system
/dev-squad schema Create user management system with profiles, roles, and permissions

# Optimize slow queries
/dev-squad optimize The dashboard query is taking over 3 seconds

# Start a new feature
/dev-squad start Implement payment processing with Stripe integration

# Fix a production bug
/dev-squad start Fix: users can't reset their password when using SSO

# Check progress of an active build
/dev-squad status
```

## Dependencies

This plugin works best with the following plugins and MCP servers installed:

All companions are **graceful-degrade**: agents fall back to native methodology if a companion isn't installed. Only `superpowers` is truly required because several agents depend on its workflow skills directly.

### Required Plugins
| Plugin | Purpose |
|--------|---------|
| **superpowers** | Core workflow skills -- brainstorming, writing-plans, TDD, systematic-debugging, verification, dispatching-parallel-agents, finishing branches, git worktrees, code review |

### Strongly Recommended
| Plugin | Purpose |
|--------|---------|
| **episodic-memory** | Cross-session memory -- search and read past conversations for context recovery |
| **context7** | Library documentation lookup -- resolve library IDs and query up-to-date docs |

### Recommended Plugins
| Plugin | Purpose |
|--------|---------|
| **code-review** | Structured code review checklist for reviewer agent |
| **simplify** | Code simplification and refinement |
| **frontend-design** | UI/UX design direction for frontend agent |
| **playwright-skill** | Browser E2E test script generation |
| **superpowers-chrome** | Chrome DevTools Protocol browser control |
| **issuetracker** | Bug detection and issue tracking |
| **find-skills** | Discover and install new skills from marketplaces |
| **claude-md-management** | CLAUDE.md project knowledge management |

### MCP Servers
| Server | Purpose |
|--------|---------|
| **grep-github** / **grep** | Search GitHub for production code patterns |
| **mermaid-mcp** | Architecture diagram rendering (ERD, sequence, flow) |
| **ide** | Language server diagnostics (compile errors, type issues) |
| **playwright** | Browser automation for E2E testing |

## Directory Structure

```
dev-squad-plugin/
├── .claude-plugin/
│   ├── plugin.json          # Plugin metadata (version, author, repo)
│   └── marketplace.json     # Marketplace configuration
├── commands/
│   ├── build.md             # /dev-squad build -- zero-to-ship workflow
│   └── status.md            # /dev-squad status -- swarm progress
├── hooks/
│   ├── hooks.json                # All hook event wiring (SessionStart, SubagentStart/Stop, PreToolUse, PostToolUse, etc.)
│   └── *.sh                      # Hook scripts (auto-update, lint, dangerous-ops guard, workflow state, etc.)
├── skills/
│   ├── dev-squad/
│   │   ├── SKILL.md              # Main skill entrypoint and invocation logic
│   │   └── config.json           # Team configuration, workflows, guardrails
│   ├── backend-patterns/         # Backend pattern reference (loaded by backend agent)
│   ├── frontend-patterns/        # Frontend pattern reference (loaded by frontend agent)
│   ├── golang-patterns/          # Go idioms and patterns
│   ├── golang-testing/           # Go test patterns
│   ├── postgres-patterns/        # PostgreSQL patterns
│   ├── security-review/          # Security review checklist
│   └── tdd-workflow/             # TDD workflow definition
├── agents/
│   └── dev-squad/
│       ├── coordinator.md        # Coordinator agent (opus)
│       ├── architect.md          # System Architect agent (opus)
│       ├── designer.md           # UI/UX Designer agent — Phase 3.5 anti-AI-slop gate (sonnet, think_harder)
│       ├── backend.md            # Backend Developer agent (sonnet)
│       ├── frontend.md           # Frontend Developer agent — implements designer's spec (sonnet)
│       ├── reviewer.md           # Security Lead + Static Code Reviewer agent (sonnet)
│       ├── qa-engineer.md        # Runtime QA + Visual Gate + Investigation Mode agent (sonnet)
│       ├── auditor.md            # Stability + Quality Metrics agent (sonnet)
│       ├── devops.md             # DevOps Engineer agent (sonnet)
│       ├── git-ops.md            # Git Operations Manager agent (sonnet)
│       └── writer.md             # Content Writer agent (sonnet)
├── rules/                        # Reference rules (common, golang, typescript)
├── CHANGELOG.md
├── CLAUDE.md
└── README.md
```

## Guardrails

- Maximum 21 parallel agents (3-5 preferred for focused work)
- Review required before every merge -- no exceptions
- Tests required before every PR -- no exceptions
- Security check required for auth/data/API changes
- ADR required for architecture changes
- Maximum PR size: 500 lines (larger PRs must be split)
- Maximum task duration: 120 minutes per agent
- Rollback plan required for migrations
- All migrations must be reversible

## License

MIT
