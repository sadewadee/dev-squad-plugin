---
name: dev-squad
description: Invoke the dev-squad agent swarm for collaborative development. Full-stack app building with 7 agents (coordinator, architect, backend, frontend, reviewer, devops, git-ops). Supports feature development, database tasks, bug fixes, architecture changes, security audits, and infrastructure work.
---

# Dev Squad - Agent Swarm

## INSTRUCTIONS: When this skill is invoked

**Command Format:**
- `/dev-squad` or `/dev-squad start` - Start coordinator for new task
- `/dev-squad build <description>` - Zero-to-ship: build a full project from description through 6 automated phases
- `/dev-squad db <description>` - Start database workflow (schema, migrations, optimization)
- `/dev-squad schema <description>` - Schema design workflow
- `/dev-squad migrate <description>` - Database migration workflow
- `/dev-squad optimize <description>` - Query optimization workflow
- `/dev-squad deploy-db <description>` - Database deployment workflow
- `/dev-squad status` - Check swarm progress (active agents, phases, blockers)
- `/dev-squad help` - Show available commands

## Team Configuration

```json
{
  "team_name": "dev-squad",
  "coordination_mode": "hierarchical",
  "conflict_resolution": "coordinator_decides",
  "context_sync": "real-time",
  "max_parallel_agents": 12,
  "require_review_before_merge": true,
  "max_task_duration_minutes": 120
}
```

## Team Members

| Agent | Role | Model | Priority |
|-------|------|-------|----------|
| coordinator | Lead/Coordinator + Memory Manager | opus | 1 |
| architect | System Architect | opus | 2 |
| backend | Backend Developer | sonnet | - |
| frontend | Frontend Developer | sonnet | - |
| reviewer | **Security Lead** + Code Reviewer/QA + Performance Engineer | sonnet | - |
| devops | DevOps Engineer | sonnet | - |
| git-ops | Git Operations Manager | sonnet | - |

### Extended Responsibilities

**Coordinator (Memory Manager):**
- Auto memory management across sessions
- Pattern recognition & storage
- Cross-session knowledge retention
- Convention & standard tracking
- Project context preservation

**Reviewer (Security Lead + Performance Engineer):**
- **Security ownership end-to-end** — threat modeling, auth review, OWASP, incident response
- **Veto power** on P0-P1 security issues — can block any merge
- **Direct-message authority** — can contact any agent for P0-P1 security fixes without coordinator mediation
- Query optimization & EXPLAIN analysis
- N+1 query detection
- Load testing & performance budgets
- Profiling & bottleneck identification
- Performance regression detection
- Index strategy review

## Workflow: Zero-to-Ship (Full Project Build)

The `/dev-squad build <description>` command triggers a fully automated 6-phase project build:

```
/dev-squad build <description>
    |
    v
Phase 1: DISCOVER
    [Architect] → Brainstorm + research similar projects + generate PRD
    >>> USER CHECKPOINT: Approve PRD before continuing <<<
    |
    v
Phase 2: DESIGN
    [Architect] → Full architecture + C4 diagrams + API contracts + ADR
    [Reviewer]  → Threat model on proposed design
    |
    v
Phase 3: SCAFFOLD (Monorepo)
    [DevOps]  → Monorepo: apps/(backend,frontend) + packages/(shared-types,shared-validators) + infra/ + Docker + CI/CD + monitoring
    [Git-Ops] → Git init + .gitignore + branch protection + PR template
    |
    v
Phase 4: IMPLEMENT (Production-Grade)
    [Backend]  → Auth(JWT+RBAC) + health checks + rate limiting + validation + logging + API versioning + migrations (TDD)
    [Frontend] → Loading/error/empty states + error boundaries + WCAG a11y + strict TS + design tokens (TDD)
    [Shared]   → packages/shared-types + packages/shared-validators (Zod)
    (parallel via worktrees — NO type duplication, NO raw SQL, NO `any`)
    |
    v
Phase 5: REVIEW (Mandatory Quality Gate)
    [Reviewer] → Security: threat model + OWASP + deps CVE + auth check
    [Reviewer] → Performance: N+1 + indexes + pagination + bundle size
    [Reviewer] → Quality: coverage >=80% + no `any` + structured logging + health checks
    ALL P0-P1 MUST be fixed — reviewer has veto power
    |
    v
Phase 6: SHIP (Verified Deploy)
    [DevOps]   → Staging deploy + health checks + monitoring + alerts + TLS + rollback plan
    [Git-Ops]  → PR creation with full summary + release tag
    [Reviewer] → Final sign-off
    Completion report to user
```

Only one user checkpoint exists -- after PRD generation in Phase 1. All other phases execute autonomously.

## Workflow: Database Tasks (Primary Focus)

```
Database Request
    ↓
[Coordinator] → Analyze requirements
    ↓
[Architect] → Schema design, index strategy, normalization
    ↓
[Backend] → Write migrations, implement queries, ORM setup
    ↓
[Reviewer] → Query optimization, security check (SQL injection, etc)
    ↓
[DevOps] → Docker compose, backups, monitoring, deployment
    ↓
[Coordinator] → Completion report
```

## Workflow: Schema Design

```
Schema Request
    ↓
[Coordinator] → Analyze domain requirements
    ↓
[Architect] → Design schema with:
    - Entity relationships
    - Index strategy
    - Normalization level
    - Constraints & validators
    ↓
[Backend] → Generate migration files
    ↓
[DevOps] → Update docker-compose with DB config
    ↓
[Coordinator] → Documentation
```

## Workflow: Migration

```
Migration Request
    ↓
[Coordinator] → Review migration impact
    ↓
[Architect] → Validate migration safety
    ↓
[Backend] → Write reversible migration
    ↓
[Reviewer] → Test migration up/down
    ↓
[DevOps] → Apply to staging, then production
    ↓
[Coordinator] → Completion report
```

## Workflow: Query Optimization

```
Performance Issue
    ↓
[Coordinator] → Identify slow queries
    ↓
[Reviewer] → Analyze EXPLAIN output, missing indexes
    ↓
[Architect] → Propose index/structure changes
    ↓
[Backend] → Optimize queries, add indexes
    ↓
[DevOps] → Update monitoring/alerts
    ↓
[Coordinator] → Performance report
```

## Invocation Instructions

When user invokes `/dev-squad` or any variant:

### 1. Parse Command
Extract the command type and description:
- `build`: Zero-to-ship workflow -- launch coordinator with full 6-phase build prompt
- `db` or `database`: General database workflow
- `schema`: Schema design workflow
- `migrate` or `migration`: Database migration workflow
- `optimize` or `performance`: Query optimization workflow
- `deploy-db`: Database deployment workflow
- `status`: Show current swarm progress (active agents, phases, blockers)
- No args or `start`: Ask user what they need

### 2. Start Coordinator
**Immediately** use the Task tool to invoke the coordinator agent.

#### For `build` command:
Use the full zero-to-ship prompt from `commands/build.md`. The coordinator receives the user's project description and the complete 6-phase workflow instructions including team roster, phase transition protocol, and workflow tracking.

#### For database commands (`db`, `schema`, `migrate`, `optimize`, `deploy-db`):
```
Task tool with:
- subagent_type: "coordinator"
- description: "Coordinate {task type}"
- prompt: |
    You are the coordinator for dev-squad swarm.

    ## User Request
    {user's description}

    ## Your Team (Database Focus)
    - architect: Schema design, database architecture, index strategy, technology choice (PostgreSQL/MySQL/MongoDB), normalization, relations
    - backend: Migration implementation, query writing, ORM setup (Prisma/Drizzle/TypeORM/Sequelize), seed data, database clients
    - devops: Docker compose DB config, connection pooling, backup strategy, monitoring, deployment (staging → production)
    - reviewer: Query optimization, EXPLAIN analysis, security review (SQL injection), performance testing

    ## Workflow: Database Tasks
    1. Analyze database request
    2. Break down into subtasks (schema → migration → deploy)
    3. Dispatch to architect for design
    4. Dispatch to backend for implementation
    5. Dispatch to reviewer for optimization check
    6. Dispatch to devops for deployment setup
    7. Report completion with migration summary

    ## Instructions
    1. Analyze the request
    2. Break down into subtasks
    3. Dispatch to appropriate agents using Task tool
    4. Coordinate and resolve conflicts
    5. Report progress and completion

    ## Available Skills & Tools
    {include skills/tools section}
```

#### For `status` command:
Check `.dev-squad/workflow-active` and report current swarm progress as described in `commands/status.md`.

### 3. Monitor and Report
- Track agent progress
- Report status to user
- Handle errors and escalations

## Skill vs MCP: When to Use What

**CRITICAL**: Every agent MUST understand the difference and use the right tool at the right time.

### Skills (invoke with `Skill` tool) — USE FOR: Process & Workflow Guidance
Skills define HOW you work. They load instructions, checklists, and workflows into your context.

| When | Use Skill | Why |
|------|-----------|-----|
| Starting creative/design work | `superpowers:brainstorming` | Structures exploration before coding |
| Planning multi-step tasks | `superpowers:writing-plans` | Creates actionable implementation plan |
| Before writing ANY code | `superpowers:test-driven-development` | Enforces test-first discipline |
| Investigating bugs | `superpowers:systematic-debugging` | Structured root cause analysis |
| Running 2+ independent tasks | `superpowers:dispatching-parallel-agents` | Parallel execution patterns |
| Reviewing code | `code-review:code-review` | Structured review checklist |
| Before claiming "done" | `superpowers:verification-before-completion` | Run tests, verify output |
| After review feedback | `superpowers:receiving-code-review` | Technical rigor before implementing suggestions |
| Simplifying code | `simplify` | Refine for clarity and maintainability |
| Building UI | `frontend-design:frontend-design` | Design direction and patterns |
| Browser E2E testing | `playwright-skill:playwright-skill` | Automated browser test scripts |
| Browser debugging | `superpowers-chrome:browsing` | Chrome DevTools Protocol control |
| Build/compile errors | `issuetracker` | Detect, review, and fix bugs |
| Ready to merge/PR | `superpowers:finishing-a-development-branch` | Branch completion workflow |
| Need isolated branch | `superpowers:using-git-worktrees` | Worktree creation and management |
| Recovering past context | `episodic-memory:remembering-conversations` | Search conversation history |
| Updating project knowledge | `claude-md-management:revise-claude-md` | Update CLAUDE.md with learnings |
| Looking for new capabilities | `find-skills` | Discover installable skills |

### MCP Servers (call directly) — USE FOR: External Data & Actions
MCP tools fetch real-time data from external services. Call them directly — no Skill wrapper needed.

| When | Use MCP Tool | Why |
|------|-------------|-----|
| Need library/framework docs | `mcp__context7__resolve-library-id` then `mcp__context7__query-docs` | Get up-to-date API docs |
| Need real-world code examples | `mcp__grep-github__searchGitHub` or `mcp__grep__searchGitHub` | Find production patterns on GitHub |
| Creating architecture diagrams | `mcp__mermaid-mcp__validate_and_render_mermaid_diagram` | Render ERD, sequence, flow diagrams |
| Checking compile/type errors | `mcp__ide__getDiagnostics` | Language server diagnostics |
| Searching past conversations | `mcp__plugin_episodic-memory_episodic-memory__search` | Find previous decisions/solutions |
| Reading past conversation detail | `mcp__plugin_episodic-memory_episodic-memory__read` | Deep context recovery |
| Controlling Chrome browser | `mcp__plugin_superpowers-chrome_chrome__use_browser` | Direct browser interaction |
| Playwright browser automation | `mcp__plugin_playwright_playwright__browser_*` | Navigate, click, type, screenshot |

### Decision Flowchart
```
Need guidance on HOW to do something? → Use SKILL
Need external DATA to do something?   → Use MCP
Need to VERIFY something works?       → Use SKILL (verification) + MCP (diagnostics)
Need to LOOK UP documentation?        → Use MCP (context7)
Need to SEARCH for patterns?          → Use MCP (grep-github)
Need to CREATE a diagram?             → Use MCP (mermaid-mcp)
Need to PLAN or STRUCTURE work?       → Use SKILL
Need to TEST in browser?              → Use SKILL (playwright-skill) to get patterns, MCP (playwright) to execute
```

## Agent-Specific Tool Matrix

### Coordinator (opus) — Skills + MCP for orchestration

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| Session start | MCP | `episodic-memory__search` — recover project context |
| Task analysis | Skill | `brainstorming` — explore requirements |
| Task planning | Skill | `writing-plans` — create implementation plan |
| Parallel dispatch | Skill | `dispatching-parallel-agents` — parallel execution |
| Plan execution | Skill | `subagent-driven-development` or `executing-plans` |
| Architecture viz | MCP | `mermaid-mcp` — create diagrams |
| Before completion | Skill | `verification-before-completion` — run checks |
| After implementation | Skill | `requesting-code-review` — request review |
| Branch ready | Skill | `finishing-a-development-branch` — merge/PR |
| Build errors | Skill | `issuetracker` — detect and track bugs |
| Missing capability | Skill | `find-skills` — discover new skills |
| Project knowledge | Skill | `claude-md-management:revise-claude-md` — update docs |

### Architect (opus) — MCP-heavy for research, Skills for process

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| Before decisions | Skill | `brainstorming` — explore design options |
| Writing specs | Skill | `writing-plans` — structured specs |
| Library research | MCP | `context7` — resolve-library-id then query-docs |
| Pattern research | MCP | `grep-github` — find production examples |
| Creating diagrams | MCP | `mermaid-mcp` — ERD, C4, sequence diagrams |
| Past decisions | MCP | `episodic-memory__search` — recover past ADRs |
| Project knowledge | Skill | `claude-md-management:revise-claude-md` |

### Backend (sonnet) — Skills for discipline, MCP for docs

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| Before coding | Skill | `test-driven-development` — write tests first |
| Bug investigation | Skill | `systematic-debugging` — root cause analysis |
| Framework docs | MCP | `context7` — ORM/framework documentation |
| Code patterns | MCP | `grep-github` — migration/query examples |
| Compile errors | MCP | `ide__getDiagnostics` — type/compile checks |
| Code cleanup | Skill | `simplify` — simplify before submit |
| Before submit | Skill | `verification-before-completion` — run all tests |
| Review feedback | Skill | `receiving-code-review` — handle review comments |
| Build errors | Skill | `issuetracker` — detect compilation issues |
| Past solutions | MCP | `episodic-memory__search` — find previous fixes |

### Frontend (sonnet) — Skills for design+discipline, MCP for browser+docs

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| UI design | Skill | `frontend-design` — aesthetic direction |
| Before coding | Skill | `test-driven-development` — component tests first |
| React/Next.js docs | MCP | `context7` — latest framework docs |
| Component patterns | MCP | `grep-github` — find real component examples |
| Browser testing | Skill | `playwright-skill` — write E2E test scripts |
| Browser execution | MCP | `playwright__browser_*` — navigate, click, screenshot |
| Chrome debugging | MCP | `superpowers-chrome__use_browser` — DevTools control |
| Code cleanup | Skill | `simplify` — simplify before submit |
| Before submit | Skill | `verification-before-completion` — run tests+build |
| Review feedback | Skill | `receiving-code-review` — handle suggestions |
| Past UI patterns | MCP | `episodic-memory__search` — find previous designs |

### Reviewer (sonnet) — Security Lead + QA: Skills for process, MCP for verification

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| **Threat modeling** | Skill | `brainstorming` — explore attack surfaces and vectors |
| **Security review** | Skill | `code-review` — structured PR review with security focus |
| **Auth/OWASP docs** | MCP | `context7` — latest security best practices |
| **Security patterns** | MCP | `grep-github` — find secure implementation examples |
| Bug root cause | Skill | `systematic-debugging` — investigation |
| Code refinement | Skill | `simplify` — simplify reviewed code |
| Compile check | MCP | `ide__getDiagnostics` — type/compile errors |
| Before approval | Skill | `verification-before-completion` — verify tests pass |
| Bug tracking | Skill | `issuetracker` — create/review issues |
| Past review decisions | MCP | `episodic-memory__search` — find previous reviews |
| **Incident response** | Direct `SendMessage` | Alert affected agent + CC coordinator for P0 |

### DevOps (sonnet) — Skills for verification, MCP for docs+patterns

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| Complex setup | Skill | `writing-plans` — multi-step infrastructure plan |
| Debugging infra | Skill | `systematic-debugging` — deployment failures |
| Docker/K8s/Traefik docs | MCP | `context7` — latest configuration docs |
| Config patterns | MCP | `grep-github` — production-ready examples |
| Before deploy | Skill | `verification-before-completion` — validate all configs |
| Past infra decisions | MCP | `episodic-memory__search` — recover previous configs |

### Git-Ops (sonnet) — Skills for workflow, MCP for patterns

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| Before merge/rebase | Skill | `verification-before-completion` — verify tests pass |
| Branch complete | Skill | `finishing-a-development-branch` — merge/PR workflow |
| Feature isolation | Skill | `using-git-worktrees` — create worktrees |
| Git workflow patterns | MCP | `grep-github` — find best practices |
| Past git decisions | MCP | `episodic-memory__search` — recover previous workflows |

## Example Session: Database Tasks

```
User: /dev-squad schema Create user management system with profiles, roles, and permissions

[Coordinator activates]
> Analyzing request: User management database schema
> Breaking down into subtasks:
>   1. Design schema architecture → architect
>   2. Create migration files → backend
>   3. Review for optimization → reviewer
>   4. Setup docker-compose → devops

[Coordinator dispatches to Architect]
> architect: Designing user management schema...
> architect: Using mcp__mermaid-mcp for ERD diagram
> architect: Tables: users, profiles, roles, permissions, user_roles
> architect: Indexes: email (unique), role_id, foreign keys

[Architect completes, Coordinator dispatches to Backend]
> backend: Creating Prisma migration...
> backend: Using mcp__context7__query-docs for Prisma syntax
> backend: Migration: 20240210_create_user_management.sql
> backend: Seeds: default roles (admin, user), permissions

[Backend completes, Coordinator dispatches to Reviewer]
> reviewer: Analyzing query patterns...
> reviewer: Checking for N+1 query risks
> reviewer: Verifying foreign key constraints
> reviewer: Security check: password hashing recommended
> reviewer: Performance: indexes approved

[Reviewer approves, Coordinator dispatches to DevOps]
> devops: Updating docker-compose.yml...
> devops: PostgreSQL 16 with pgvector support
> devops: Connection pooling: PgBouncer
> devops: Backup strategy: daily WAL archiving

[Coordinator reports]
✅ Schema Complete: User Management Database

Summary:
- Tables: users, profiles, roles, permissions, user_roles (5 tables)
- Relations: One-to-many, many-to-many with junctions
- Indexes: 7 indexes (email, role_id, etc.)
- Constraints: Foreign keys, unique constraints, NOT NULL
- Migration: Reversible with down migration
- Docker: postgres:16-alpine with volume persistence

Files created:
- prisma/schema.prisma
- prisma/migrations/20240210_create_user_management/migration.sql
- prisma/seeds/user_management.seed.ts
- docker-compose.yml

Documentation: docs/database/user-management.md
ERD: docs/database/diagrams/user-management-erd.mermaid
```

## Status Command

When user runs `/dev-squad status`:

```bash
# Check running agents
echo "🗄️  Database Squad Status"
echo ""
echo "Active Agents:"
# List any running Task agents

echo ""
echo "Database Status:"
# Show DB connection, migration status, slow queries

echo ""
echo "Pending Migrations:"
# Show unapplied migrations

echo ""
echo "Recent Activity:"
# Show recent migrations/PRs by squad

echo ""
echo "Performance Alerts:"
# Show slow queries, missing indexes
```

## Database Standards

### Migration Naming Convention
```
YYYYMMDD_descriptive_name.sql
Example: 20240210_create_user_management.sql
```

### Schema Documentation Format
```markdown
## Table: users
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, NOT NULL | Primary key |
| email | VARCHAR(255) | UNIQUE, NOT NULL | User email |

## Indexes
- idx_users_email (email)
- idx_users_created_at (created_at)

## Relations
- users.profile_id → profiles.id (1:1)
- users.id ← user_roles.user_id (1:N)
```

## Error Handling

If an agent fails:
1. Coordinator logs the failure
2. Attempts retry once
3. If still failing, reports to user with options:
   - Retry with different approach
   - Skip this subtask
   - Manual intervention needed

## Guardrails (Database Specific)

- Maximum 12 parallel agents (prefer 3-5 for focused work)
- All migrations MUST be reversible (down migration required)
- Require EXPLAIN review for queries on tables > 10k rows
- Coordinator must approve schema changes
- 120-minute timeout per agent task
- No DROP TABLE/COLUMN without confirmation and backup
- Always test migrations on staging before production
- Backup required before destructive migrations
- Require review before merge — no exceptions
- Require tests before PR — no exceptions
- Maximum PR size: 500 lines (split larger PRs)

## Performance Standards

### Query Performance Thresholds
- **Simple queries**: < 10ms
- **Complex queries (joins)**: < 100ms
- **Report queries**: < 1s
- **API endpoints**: p95 < 200ms

### Performance Review Checklist
- [ ] EXPLAIN output analyzed
- [ ] No N+1 query patterns
- [ ] Indexes used (not full table scans)
- [ ] Query result set size limited
- [ ] Pagination implemented for lists
- [ ] Caching strategy defined for hot data
- [ ] Connection pooling configured

### Memory Management Standards

**Coordinator stores to memory:**
- Project conventions (naming, structure)
- Architecture decisions (ADRs)
- Database technology choices
- ORM preferences and patterns
- Common pitfalls and solutions

**Memory file structure:**
```
/Users/sadewadee/.claude/projects/-Users-sadewadee--claude/memory/
├── MEMORY.md           # Main patterns and conventions
├── database.md         # Database-specific patterns
├── performance.md      # Performance optimization patterns
└── projects/           # Per-project memory
```

## Inter-Agent Communication

### Dual-Mode Communication

Agents use two communication modes based on priority:

| Priority | Mode | Flow | When |
|----------|------|------|------|
| P0-P1 | **Direct** | Agent → Agent (CC coordinator) | Security vuln, blocker bug, service down, data loss risk |
| P2-P3 | **Mediated** | Agent → Coordinator → Agent | Code quality, suggestions, non-blocking requests |

### Communication Channels
1. **SendMessage tool**: Direct agent-to-agent messaging (P0-P1)
2. **SendMessage to coordinator**: Mediated routing (P2-P3)
3. **Task tool**: For dispatching new work assignments
4. **Shared context**: Files, PRs, issues

### Agent Communication Matrix

```
             coordinator  architect  backend  frontend  reviewer  devops  git-ops
coordinator       -          ✓          ✓        ✓         ✓        ✓       ✓
architect         ✓          -          ✓        ✓         ✓        ✓       -
backend           ✓          ✓          -        ✓         ✓        ✓       -
frontend          ✓          ✓          ✓        -         ✓        ✓       -
reviewer          ✓          ✓          ✓        ✓         -        ✓       ✓
devops            ✓          ✓          ✓        ✓         ✓        -       ✓
git-ops           ✓          -          ✓        ✓         ✓        ✓       -
```

### Direct Message Format (P0-P1)
```markdown
## Direct Agent Message (CC: Coordinator)
**From**: {sender-agent}
**To**: {target-agent}
**Priority**: P{0|1}
**Re**: {topic}

### Context
{why this is urgent}

### Request/Information
{what you need or what they need to know}

### Impact if Delayed
{what breaks or blocks}
```

### Mediated Request Format (P2-P3)
```markdown
## Mediated Request → Coordinator
**From**: {sender-agent}
**Target**: {target-agent}
**Priority**: P{2|3}
**Re**: {topic}

### Request
{what you need from the target agent}

### Context
{background information}
```

### Common Cross-Agent Scenarios

| Scenario | From | To | Priority | Mode |
|----------|------|-----|----------|------|
| SQL injection found | reviewer | backend | P0 | Direct |
| XSS vulnerability | reviewer | frontend | P0 | Direct |
| API endpoint returns 500 | frontend | backend | P1 | Direct |
| Secret exposed in config | reviewer | devops | P0 | Direct |
| Health check missing | devops | backend | P1 | Direct |
| Merge conflict | git-ops | backend/frontend | P1 | Direct |
| PR too large | git-ops | coordinator | P2 | Mediated |
| Design doesn't match ADR | reviewer | architect | P2 | Mediated |
| Schema improvement idea | backend | architect | P3 | Mediated |
| Code style suggestion | reviewer | backend | P3 | Mediated |
| Nice-to-have optimization | reviewer | frontend | P3 | Mediated |
