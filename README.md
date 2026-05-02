# dev-squad

A full-stack development team agent swarm plugin for Claude Code. **Ten specialized AI agents** collaborate in a hierarchical coordination model to handle zero-to-ship project builds, feature development, database tasks, bug fixes, architecture changes, security audits, infrastructure work, runtime/stability/quality auditing, and content authoring.

Current version is in `.claude-plugin/plugin.json`.

## Team Composition

| Agent | Role | Model | Key Responsibilities |
|-------|------|-------|---------------------|
| **coordinator** | Lead/Coordinator + Memory Manager | opus | Task decomposition, agent orchestration, conflict resolution, project knowledge management |
| **architect** | System Architect | opus | System design, tech stack decisions, database schema, ADRs, infrastructure planning |
| **backend** | Backend Developer | sonnet | API development, database operations, business logic, migrations, auth implementation |
| **frontend** | Frontend Developer | sonnet | UI implementation, React/Next.js, state management, responsive/accessible design |
| **reviewer** | Security Lead + Static Code Reviewer | sonnet | End-to-end security, threat modeling, OWASP, static code review on diff, Phase 5 metrics report synthesis |
| **qa-engineer** | Runtime QA + Investigation Mode | sonnet | Phase 5.5 functional verification (boot app, drive golden path via playwright, audit interactive elements, smoke-test endpoints, browser console gate). Fresh-eyes debugger when self-healing iter 3 triggers. |
| **auditor** | Stability + Quality Metrics | sonnet | Phase 5.6 stability execution (config drift, DB perf, endpoint hammer, failure injection, API pattern compliance) + Phase 5.7 code quality metrics (multi-language: JS/TS, Go, Python). Installs analyzer tools on demand. |
| **devops** | DevOps Engineer | sonnet | Docker/Compose, Traefik, CI/CD, monitoring, secrets management, deployment strategies |
| **git-ops** | Git Operations Manager | sonnet | Branch management, PR workflows, merge strategies, release management, changelog generation |
| **writer** | Content Writer | sonnet | Page copy, microcopy, legal pages, SEO metadata, documentation — production-ready content, not placeholders |

## Supported Workflows

- **Zero-to-Ship** -- build a full project from a single description through 6 automated phases: DISCOVER, DESIGN, SCAFFOLD, IMPLEMENT, REVIEW, SHIP
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

The `build` command takes a project description and builds it through 6 automated phases. Only one user checkpoint exists -- after PRD generation in Phase 1.

```
/dev-squad build A real-time collaborative task manager with team workspaces

Phase 1: DISCOVER  --> Architect brainstorms, researches, generates PRD
                       >>> You approve the PRD <<<
Phase 2: DESIGN    --> Architect creates full architecture + C4 diagrams + ADRs
Phase 3: SCAFFOLD  --> DevOps creates project structure, Docker, CI/CD; Git-Ops inits repo
Phase 4: IMPLEMENT --> Backend + Frontend build in parallel with TDD
Phase 5: REVIEW    --> Reviewer does full code review + OWASP security audit
Phase 6: SHIP      --> Staging deploy, PR creation, final sign-off
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

### Required Plugins
| Plugin | Purpose |
|--------|---------|
| **superpowers** | Core workflow skills -- brainstorming, writing-plans, TDD, systematic-debugging, verification, dispatching-parallel-agents, finishing branches, git worktrees, code review |
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
│       ├── backend.md            # Backend Developer agent (sonnet)
│       ├── frontend.md           # Frontend Developer agent (sonnet)
│       ├── reviewer.md           # Security Lead + Static Code Reviewer agent (sonnet)
│       ├── qa-engineer.md        # Runtime QA + Investigation Mode agent (sonnet)
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
