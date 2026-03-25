# dev-squad

A full-stack development team agent swarm plugin for Claude Code. Seven specialized AI agents collaborate in a hierarchical coordination model to handle feature development, database tasks, bug fixes, architecture changes, security audits, and infrastructure work.

## Team Composition

| Agent | Role | Model | Key Responsibilities |
|-------|------|-------|---------------------|
| **coordinator** | Lead/Coordinator + Memory Manager | opus | Task decomposition, agent orchestration, conflict resolution, project knowledge management |
| **architect** | System Architect | opus | System design, tech stack decisions, database schema, ADRs, infrastructure planning |
| **backend** | Backend Developer | sonnet | API development, database operations, business logic, migrations, auth implementation |
| **frontend** | Frontend Developer | sonnet | UI implementation, React/Next.js, state management, responsive/accessible design |
| **reviewer** | Security Lead + Code Reviewer/QA | sonnet | End-to-end security ownership, threat modeling, OWASP enforcement, code review, performance profiling |
| **devops** | DevOps Engineer | sonnet | Docker/Compose, Traefik, CI/CD, monitoring, secrets management, deployment strategies |
| **git-ops** | Git Operations Manager | sonnet | Branch management, PR workflows, merge strategies, release management, changelog generation |

## Supported Workflows

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
Every agent understands when to use Skills (process/workflow guidance) versus MCP tools (external data and actions). Skills are invoked for planning, TDD, code review, and verification workflows. MCP tools are called directly for documentation lookup (Context7), code pattern search (grep-github), diagram creation (mermaid-mcp), and conversation history (episodic-memory).

### Cross-Agent Communication
Agents use a dual-mode communication protocol:
- **P0-P1 (Critical/High)**: Direct agent-to-agent messaging with coordinator CC'd
- **P2-P3 (Medium/Low)**: Mediated through coordinator

### Security Lead with Veto Power
The reviewer agent owns security end-to-end. It has veto power on P0-P1 security issues and can directly message any agent for urgent security fixes without coordinator mediation. Every PR goes through OWASP Top 10 checks, dependency auditing, and threat modeling.

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

Ensure the `skills/dev-squad/SKILL.md` and `agents/dev-squad/` files are placed under your `~/.claude/` directory (or wherever your Claude configuration lives).

## Usage

```bash
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
/dev-squad status                  # Check swarm status
/dev-squad help                    # Show available commands
```

### Examples

```bash
# Build a user management system
/dev-squad schema Create user management system with profiles, roles, and permissions

# Optimize slow queries
/dev-squad optimize The dashboard query is taking over 3 seconds

# Start a new feature
/dev-squad start Implement payment processing with Stripe integration

# Fix a production bug
/dev-squad start Fix: users can't reset their password when using SSO
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
│   ├── plugin.json          # Plugin metadata
│   └── marketplace.json     # Marketplace configuration
├── skills/
│   └── dev-squad/
│       └── SKILL.md         # Skill definition and invocation instructions
├── agents/
│   └── dev-squad/
│       ├── config.json      # Team configuration, workflows, guardrails
│       ├── coordinator.md   # Coordinator agent (opus)
│       ├── architect.md     # System Architect agent (opus)
│       ├── backend.md       # Backend Developer agent (sonnet)
│       ├── frontend.md      # Frontend Developer agent (sonnet)
│       ├── reviewer.md      # Security Lead + Code Reviewer agent (sonnet)
│       ├── devops.md        # DevOps Engineer agent (sonnet)
│       └── git-ops.md       # Git Operations Manager agent (sonnet)
└── README.md
```

## Guardrails

- Maximum 12 parallel agents (3-5 preferred for focused work)
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
