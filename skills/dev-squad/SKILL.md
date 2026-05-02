---
name: dev-squad
description: Invoke the dev-squad agent swarm for collaborative development. Full-stack app building with 11 agents (coordinator, architect, designer, backend, frontend, reviewer, qa-engineer, auditor, devops, git-ops, writer). Phase 3.5 DESIGN gate (designer) prevents AI-slop UI by producing design tokens + visual spec + component inventory + responsive spec BEFORE frontend codes. Supports feature development, database tasks, bug fixes, architecture changes, security audits, infrastructure work, and runtime/stability/quality auditing.
---

# Dev Squad - Agent Swarm

## INSTRUCTIONS: When this skill is invoked

**Command Format:**
- `/dev-squad` or `/dev-squad start` - Start coordinator for new task
- `/dev-squad build <description>` - Zero-to-ship: build a full project through 8 automated PDCA phases (Plan → Do → Check → Act)
- `/dev-squad retrospective [scope]` - Run a PDCA Act-phase retrospective on completed work (feature, sprint, post-incident)
- `/dev-squad db <description>` - Start database workflow (schema, migrations, optimization)
- `/dev-squad schema <description>` - Schema design workflow
- `/dev-squad migrate <description>` - Database migration workflow
- `/dev-squad optimize <description>` - Query optimization workflow
- `/dev-squad deploy-db <description>` - Database deployment workflow
- `/dev-squad status` - Check swarm progress (active agents, phases, blockers)
- `/dev-squad help` - Show available commands

## Orchestration Modes

dev-squad supports two orchestration modes. The coordinator auto-detects which to use.

### Mode A: Agent Teams (Recommended)

Requires the experimental flag. Enables real parallel execution with shared task list.

**Setup:**
```json
// Add to ~/.claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Visual agent tracking (optional):**
```json
// Add to ~/.claude.json
{
  "teammateMode": "auto"
}
```
- `"auto"` — auto-detects tmux/iTerm2
- `"tmux"` — each agent in separate tmux pane
- `"in-process"` — all in single terminal (Shift+Down to cycle)

**Share task list across sessions (optional):**
```bash
export CLAUDE_CODE_TASK_LIST_ID=dev-squad-project
```

### Mode B: Subagent Fan-Out (Default Fallback)

Works without any setup. Coordinator dispatches agents sequentially via Agent tool.

## Team Configuration

```json
{
  "team_name": "dev-squad",
  "coordination_mode": "hierarchical",
  "conflict_resolution": "coordinator_decides",
  "context_sync": "real-time",
  "max_parallel_agents": 21,
  "require_review_before_merge": true,
  "max_task_duration_minutes": 120
}
```

## Team Members

| Agent | Role | Model | Priority |
|-------|------|-------|----------|
| coordinator | Lead/Coordinator + Memory Manager | opus | 1 |
| architect | System Architect | opus | 2 |
| designer | UI/UX Designer (Phase 3.5 anti-AI-slop gate) | sonnet (think_harder) | 3 |
| backend | Backend Developer | sonnet | - |
| frontend | Frontend Developer (implements designer's spec) | sonnet | - |
| reviewer | **Security Lead** + Static Code Reviewer + Phase 5 metrics synthesizer | sonnet | - |
| qa-engineer | Runtime QA (Phase 5.5 functional verification + Visual Gate) + Investigation Mode debugger | sonnet | - |
| auditor | Stability execution (Phase 5.6) + multi-language code quality metrics (Phase 5.7) | sonnet | - |
| devops | DevOps Engineer | sonnet | - |
| git-ops | Git Operations Manager | sonnet | - |
| writer | Content Writer | sonnet | - |

### Extended Responsibilities

**Coordinator (Memory Manager):**
- Auto memory management across sessions
- Pattern recognition & storage
- Cross-session knowledge retention
- Convention & standard tracking
- Project context preservation

**Designer (UI/UX — Phase 3.5 Anti-AI-Slop Gate):**
- **Phase 3.5 DESIGN ownership** — produces 4 BLOCKING artifacts before frontend codes: `design-tokens.md`, `visual-spec.md`, `component-inventory.md`, `responsive-spec.md`
- **Anti-AI-slop authority** — rejects emoji-as-icon, default shadcn slate, AI-cliché gradients, missing responsive, missing motion, "modern minimal" boilerplate
- **Reference-grounded design** — uses WebSearch + grep-github + playwright (screenshots) + chrome-devtools (style inspection) on ≥3 reference sites before locking palette/type/layout
- **Veto power** on UI PRs that violate anti-pattern list (emoji-as-icon = P0, inline arbitrary values = P1, missing responsive = P0)
- **`--mvp-mode` escape hatch** — slimmed deliverable for rapid prototyping (tokens + slim visual spec only)

**Reviewer (Security Lead + Static Code Reviewer + Phase 5 Synthesizer):**
- **Security ownership end-to-end** — threat modeling, auth review, OWASP, incident response
- **Veto power** on P0-P1 security issues — can block any merge
- **Direct-message authority** — can contact any agent for P0-P1 security fixes without coordinator mediation
- Static code review (diff-based) — multi-angle: security, performance, spec compliance, architecture
- **Phase 5 Metrics Report synthesis** — combines static review findings + qa-engineer functional verification + auditor stability/quality reports into single PDCA Check artifact

**QA Engineer (Runtime Verification + Visual Gate + Investigation Mode):**
- **Phase 5.5 FUNCTIONAL VERIFICATION** — boots the app, drives golden path via playwright, audits every interactive element, smoke-tests every API endpoint, captures browser console/network
- **Visual Gate (anti-AI-slop runtime check)** — runs designer's anti-pattern list against shipped UI: emoji-as-icon regex scan, inline arbitrary value scan, responsive presence check (3 breakpoints), motion presence check, default shadcn palette check
- **Investigation Mode** — fresh-eyes debugger when self-healing iter 3 triggers (author has thrashed for 2 iterations); produces Investigation Report with root cause + recommended fix; author applies the fix
- **Veto power** on P0 functional findings (runtime crash, missing endpoint, broken auth, button without onClick, emoji-as-icon, missing responsive) and P1 in golden path

**Auditor (Stability + Code Quality Metrics):**
- **Phase 5.6 STABILITY EXECUTION** — config drift detection, DB performance (slow queries, missing indexes, connection leaks, migration safety, pool sanity), endpoint hammering for 500-leak detection, failure injection (with `.dev-squad/staging-env` hard guard), API pattern compliance (REST/GraphQL/gRPC anti-patterns)
- **Phase 5.7 CODE QUALITY METRICS** — multi-language tool runner (auto-detects via package.json / go.mod / pyproject.toml). JS/TS: eslint --max-complexity, jscpd, ts-prune, madge. Go: gocyclo, dupl, staticcheck, errcheck, golangci-lint, go test -race. Python: radon, vulture, ruff.
- **Tool installation on demand** — installs missing analyzers at devDependencies / `go install` / `pip install --user`
- **Veto power** on P0 stability/quality findings (race condition, P1 metric exceed by >20%)

## v3.0 Orchestration Patterns

These patterns are adopted from proven plugins (superpowers, code-review, double-shot-latte) and applied throughout all workflows:

| Pattern | Where Applied | What It Does |
|---------|--------------|--------------|
| **Phase 3.5 DESIGN gate** | Phase 3.5 (zero-to-ship) | Designer produces 4 BLOCKING artifacts before frontend codes UI; anti-AI-slop authority |
| **Two-Stage Review** | Phase 4 (per task) | Spec compliance → Code quality, loop until both pass; agents chosen via Diff-Scope Heuristic |
| **3-Way Phase 5 Review** | Phase 5 (full feature) | reviewer (static, incl. design lint) + qa-engineer (runtime + Visual Gate) + auditor (automated) dispatched in parallel; reviewer synthesizes single Metrics Report. Designer added as light pass for new UI surfaces. |
| **Diff-Scope Dispatch Heuristic** | Every review dispatch | Coordinator picks reviewer / qa-engineer / auditor combo per diff scope; logs decision to .dev-squad/dispatch-log.md |
| **Phase Gate Judge** | Between all phases | Cheap haiku agent validates deliverables before transition |
| **Confidence Scoring** | Phase 5 review | Score 0-100 per finding, filter < 80 as non-actionable |
| **Multi-Angle Review** | Phase 5 reviewer lane | 4 review passes within reviewer's static lane: security, performance, spec, architecture |
| **Systematic Debugging** | All agents | 4-phase: investigate → analyze → hypothesize → implement |
| **Plan Review Loop** | Phase 2 design | Dispatch reviewer for plan, max 3 iterations |
| **Verification-Before-Completion** | Phase 6 + all tasks | Evidence before claims, run commands fresh |
| **Agent Memory** | All agents | `memory: project` — persistent knowledge across sessions |
| **CronCreate Monitoring** | Phase 6 post-deploy | Automated health checks, lighthouse, CVE scans |
| **Smart Model Routing** | All dispatches | opus for complex/integration, sonnet for simple, haiku for gates |
| **Self-Healing Loop** | Phase 3-6 | Run → error → diagnose → fix → retry (max 5, then escalate) |
| **UltraPlan** | Phase 0 (before any dispatch) | Coordinator thinks deeply: scope, entities, tech stack, risks → master-plan.md |
| **Continuous Learning** | All agents | Write learnings to agent-memory + gotchas.md before reporting done |

## Workflow: Zero-to-Ship (Full Project Build)

The `/dev-squad build <description>` command triggers a fully automated 7-phase project build:

```
/dev-squad build <description>
    |
    v
Phase 0: ULTRAPLAN (Coordinator only — deep thinking, no dispatch)
    [Coordinator] → ultrathink: analyze scope, entities, tech stack, risks
    [Coordinator] → Write .dev-squad/master-plan.md
    |
    v
Phase 1: DISCOVER
    [Architect] → Brainstorm + research (with master-plan.md as context) + generate PRD
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
Phase 3.5: DESIGN (BLOCKING anti-AI-slop gate; skip ONLY with --mvp-mode)
    [Designer] → design-tokens.md + visual-spec.md (≥3 refs + screenshots) + component-inventory.md + responsive-spec.md
    [Designer] → uses WebSearch + grep-github + playwright + chrome-devtools to ground design in real references
    [Designer] → anti-pattern list: emoji-as-icon, default shadcn slate, AI-cliché gradients, missing responsive, missing motion (project-specific)
    Frontend cannot start UI work until all 4 artifacts exist.
    |
    v
Phase 4: IMPLEMENT (Production-Grade)
    [Backend]  → Auth(JWT+RBAC) + health checks + rate limiting + validation + logging + API versioning + migrations (TDD)
    [Frontend] → Read all 4 design artifacts → translate tokens → implement components per inventory → wire motion → respect responsive (TDD)
    [Frontend] → SVG icons only (NO emoji), design tokens only (NO inline arbitrary values)
    [Shared]   → packages/shared-types + packages/shared-validators (Zod)
    (parallel via worktrees — NO type duplication, NO raw SQL, NO `any`, NO AI-slop)
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
[Auditor] → Migration safety scan (Bucket B): NOT NULL on big tables, CONCURRENTLY on indexes, lock duration estimate
    ↓
[Reviewer] → Security check (SQL injection paths, RLS policies, sensitive columns)
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
[Architect] → Validate migration strategy + rollback plan
    ↓
[Backend] → Write reversible migration (up + down)
    ↓
[Auditor] → Migration safety scan: lock duration, CONCURRENTLY usage, NOT NULL on large tables, ACCESS EXCLUSIVE detection
    ↓
[Reviewer] → Test migration up/down + security check on new permissions
    ↓
[DevOps] → Apply to staging + backup verification, then production
    ↓
[QA Engineer] → Hit endpoints during/after staging migration, verify zero downtime
    ↓
[Auditor] → Post-migration: re-run pool/leak/slow-query check, confirm no regression
    ↓
[Coordinator] → Completion report (auditor's safety scan + qa-engineer's runtime verification = go/no-go evidence)
```

## Workflow: Query Optimization

```
Performance Issue
    ↓
[Coordinator] → Identify slow queries
    ↓
[Auditor] → Slow query log capture, EXPLAIN analysis, missing indexes, connection leak check, pool sanity
    ↓
[Architect] → Propose index/structure changes
    ↓
[Backend] → Optimize queries, add indexes
    ↓
[Auditor] → Re-run benchmark, before/after metrics
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
**Immediately** use the Agent tool to invoke the coordinator agent.

#### For `build` command:
Use the full zero-to-ship prompt from `commands/build.md`. The coordinator receives the user's project description and the complete 6-phase workflow instructions including team roster, phase transition protocol, and workflow tracking.

#### For database commands (`db`, `schema`, `migrate`, `optimize`, `deploy-db`):
```
Agent tool with:
- subagent_type: "dev-squad:coordinator"
- description: "Coordinate {task type}"
- prompt: |
    You are the coordinator for dev-squad swarm.

    ## User Request
    {user's description}

    ## Your Team (MUST use fully-qualified subagent_type names)
    | Agent | subagent_type | Role |
    |-------|--------------|------|
    | Architect | `dev-squad:architect` | Schema design, database architecture, index strategy |
    | Backend | `dev-squad:backend` | Migration implementation, query writing, ORM setup |
    | DevOps | `dev-squad:devops` | Docker compose DB config, connection pooling, backup |
    | Reviewer | `dev-squad:reviewer` | Security review (SQL injection, auth on data endpoints), static code review |
    | Auditor | `dev-squad:auditor` | Query optimization (slow query log, EXPLAIN), connection leak detection, migration safety scan, pool sanity, index coverage |

    CRITICAL: Always dispatch using "dev-squad:{name}" — plain names will NOT resolve.

    ## Workflow: Database Tasks
    1. Analyze database request
    2. Break down into subtasks (schema → migration → deploy)
    3. Dispatch to dev-squad:architect for design
    4. Dispatch to dev-squad:backend for implementation
    5. Dispatch to dev-squad:reviewer for optimization check
    6. Dispatch to dev-squad:devops for deployment setup
    7. Report completion with migration summary

    ## Instructions
    1. Analyze the request
    2. Break down into subtasks
    3. Dispatch to appropriate agents using Agent tool with fully-qualified names
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
| Need library/framework docs | `context7` | Get up-to-date API docs |
| Need real-world code examples | `grep-github` | Find production patterns on GitHub |
| Creating architecture diagrams | `mermaid-mcp` | Render ERD, sequence, flow diagrams |
| Checking compile/type errors | `ide diagnostics` | Language server diagnostics |
| Searching/reading past conversations | `episodic-memory` | Find previous decisions/solutions, deep context recovery |
| Controlling Chrome browser | `chrome-devtools` | Direct browser interaction |
| Playwright browser automation | `playwright` | Navigate, click, type, screenshot |

### Decision Flowchart
```
Need guidance on HOW to do something? → Use SKILL
Need external DATA to do something?   → Use MCP
Need to VERIFY something works?       → Use SKILL (verification) + MCP (diagnostics)
Need to LOOK UP documentation?        → Use MCP (`context7`)
Need to SEARCH for patterns?          → Use MCP (`grep-github`)
Need to CREATE a diagram?             → Use MCP (`mermaid-mcp`)
Need to PLAN or STRUCTURE work?       → Use SKILL
Need to TEST in browser?              → Use SKILL (playwright-skill) to get patterns, MCP (`playwright`) to execute
```

## Agent-Specific Tool Matrix

### Coordinator (opus) — Skills + MCP for orchestration

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| Session start | MCP | `episodic-memory` — recover project context |
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
| Library research | MCP | `context7` — library/framework documentation lookup |
| Pattern research | MCP | `grep-github` — find production examples |
| Creating diagrams | MCP | `mermaid-mcp` — ERD, C4, sequence diagrams |
| Past decisions | MCP | `episodic-memory` — recover past ADRs |
| Project knowledge | Skill | `claude-md-management:revise-claude-md` |

### Designer (sonnet, think_harder) — Skills for design process, MCP for reference grounding

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| Visual direction | Skill | `frontend-design` — mandatory before locking palette/type |
| Design exploration | Skill | `brainstorming` — color/font/motion choices |
| Reference research | MCP | `WebSearch` — find ≥3 reference URLs (current year) |
| Reference research | MCP | `grep-github` — find production design patterns + token files |
| Reference capture | MCP | `playwright` — screenshot reference sites per breakpoint |
| Style inspection | MCP | `chrome-devtools` (use_browser) — extract real computed styles from refs |
| Library docs | MCP | `context7` — design system libs (shadcn, radix, framer-motion) |
| Wireframe creation | MCP | `mermaid-mcp` — per-page wireframes per breakpoint |
| Verification | Skill | `verification-before-completion` — all 4 artifacts present + concrete |
| Past design | MCP | `episodic-memory` — recover prior brand palettes / vocabulary |

### Backend (sonnet) — Skills for discipline, MCP for docs

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| Before coding | Skill | `test-driven-development` — write tests first |
| Bug investigation | Skill | `systematic-debugging` — root cause analysis |
| Framework docs | MCP | `context7` — ORM/framework documentation |
| Code patterns | MCP | `grep-github` — migration/query examples |
| Compile errors | MCP | `ide diagnostics` — type/compile checks |
| Code cleanup | Skill | `simplify` — simplify before submit |
| Before submit | Skill | `verification-before-completion` — run all tests |
| Review feedback | Skill | `receiving-code-review` — handle review comments |
| Build errors | Skill | `issuetracker` — detect compilation issues |
| Past solutions | MCP | `episodic-memory` — find previous fixes |

### Frontend (sonnet) — Skills for design+discipline, MCP for browser+docs

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| UI design | Skill | `frontend-design` — aesthetic direction |
| Before coding | Skill | `test-driven-development` — component tests first |
| React/Next.js docs | MCP | `context7` — latest framework docs |
| Component patterns | MCP | `grep-github` — find real component examples |
| Browser testing | Skill | `playwright-skill` — write E2E test scripts |
| Browser execution | MCP | `playwright` — navigate, click, screenshot |
| Chrome debugging | MCP | `chrome-devtools` — DevTools control |
| Code cleanup | Skill | `simplify` — simplify before submit |
| Before submit | Skill | `verification-before-completion` — run tests+build |
| Review feedback | Skill | `receiving-code-review` — handle suggestions |
| Past UI patterns | MCP | `episodic-memory` — find previous designs |

### Reviewer (sonnet) — Security Lead + QA: Skills for process, MCP for verification

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| **Threat modeling** | Skill | `brainstorming` — explore attack surfaces and vectors |
| **Security review** | Skill | `code-review` — structured PR review with security focus |
| **Auth/OWASP docs** | MCP | `context7` — latest security best practices |
| **Security patterns** | MCP | `grep-github` — find secure implementation examples |
| Bug root cause | Skill | `systematic-debugging` — investigation |
| Code refinement | Skill | `simplify` — simplify reviewed code |
| Compile check | MCP | `ide diagnostics` — type/compile errors |
| Before approval | Skill | `verification-before-completion` — verify tests pass |
| Bug tracking | Skill | `issuetracker` — create/review issues |
| Past review decisions | MCP | `episodic-memory` — find previous reviews |
| **Incident response** | Direct `SendMessage` | Alert affected agent + CC coordinator for P0 |

### DevOps (sonnet) — Skills for verification, MCP for docs+patterns

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| Complex setup | Skill | `writing-plans` — multi-step infrastructure plan |
| Debugging infra | Skill | `systematic-debugging` — deployment failures |
| Docker/K8s/Traefik docs | MCP | `context7` — latest configuration docs |
| Config patterns | MCP | `grep-github` — production-ready examples |
| Before deploy | Skill | `verification-before-completion` — validate all configs |
| Past infra decisions | MCP | `episodic-memory` — recover previous configs |

### Git-Ops (sonnet) — Skills for workflow, MCP for patterns

| Phase | Tool Type | Specific Tool |
|-------|-----------|---------------|
| Before merge/rebase | Skill | `verification-before-completion` — verify tests pass |
| Branch complete | Skill | `finishing-a-development-branch` — merge/PR workflow |
| Feature isolation | Skill | `using-git-worktrees` — create worktrees |
| Git workflow patterns | MCP | `grep-github` — find best practices |
| Past git decisions | MCP | `episodic-memory` — recover previous workflows |

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
> architect: Using mermaid-mcp for ERD diagram
> architect: Tables: users, profiles, roles, permissions, user_roles
> architect: Indexes: email (unique), role_id, foreign keys

[Architect completes, Coordinator dispatches to Backend]
> backend: Creating Prisma migration...
> backend: Using context7 for Prisma syntax
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

- Maximum 21 parallel agents (prefer 3-5 for focused work)
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
3. **Agent tool**: For dispatching new work assignments
4. **Shared context**: Files, PRs, issues

### Agent Communication Matrix

```
              coord  arch  design  backend  frontend  reviewer  qa-eng  auditor  devops  git-ops  writer
coordinator     -     ✓     ✓        ✓         ✓         ✓        ✓       ✓        ✓       ✓       ✓
architect       ✓     -     ✓        ✓         ✓         ✓        ✓       ✓        ✓       -       ✓
designer        ✓     ✓     -        -         ✓         ✓        ✓       -        -       -       ✓
backend         ✓     ✓     -        -         ✓         ✓        ✓       ✓        ✓       -       -
frontend        ✓     ✓     ✓        ✓         -         ✓        ✓       ✓        ✓       -       ✓
reviewer        ✓     ✓     ✓        ✓         ✓         -        ✓       ✓        ✓       ✓       -
qa-engineer     ✓     ✓     ✓        ✓         ✓         ✓        -       ✓        ✓       -       -
auditor         ✓     ✓     -        ✓         ✓         ✓        ✓       -        ✓       -       -
devops          ✓     ✓     -        ✓         ✓         ✓        ✓       ✓        -       ✓       -
git-ops         ✓     -     -        ✓         ✓         ✓        ✓       ✓        ✓       -       -
writer          ✓     ✓     ✓        -         ✓         ✓        -       -        -       -       -
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
| SQL injection found (static) | reviewer | backend | P0 | Direct |
| XSS vulnerability (static) | reviewer | frontend | P0 | Direct |
| API endpoint returns 500 (runtime detection) | qa-engineer | backend | P0 | Direct |
| 500 leak under malformed payload (Bucket C) | auditor | backend | P0 | Direct |
| Stack trace in error response (info disclosure) | auditor | backend + reviewer | P0 | Direct |
| Connection leak detected (Bucket B) | auditor | backend | P0 | Direct |
| Migration safety violation (NOT NULL on big table, missing CONCURRENTLY) | auditor | backend + architect | P0 | Direct |
| Hydration mismatch / browser console error | qa-engineer | frontend | P1 | Direct |
| Button without onClick (interactive audit) | qa-engineer | frontend | P1 | Direct |
| Missing endpoint per contract | qa-engineer | backend | P0 | Direct |
| Slow query (>100ms in pg_stat_statements) | auditor | backend | P1 | Direct |
| Missing index for WHERE/ORDER BY column | auditor | backend | P1 | Direct |
| Pool size > 80% max_connections | auditor | devops | P1 | Direct |
| Config drift (missing env validator, CORS wildcard) | auditor | devops | P1 | Direct |
| Cyclomatic complexity threshold breach | auditor | backend/frontend | P2 | Direct |
| Code duplication >5% threshold | auditor | backend/frontend | P2 | Direct |
| Investigation Mode handoff (iter 3 self-healing) | coordinator | qa-engineer | P1 | Dispatch |
| Investigation Report → fix recommendation | qa-engineer | backend/frontend | P1 | Direct |
| Phase 3.5 dispatch (zero-to-ship UI gate) | coordinator | designer | P0 | Dispatch |
| Designer hands off 4 artifacts → frontend can start UI | designer | frontend | P1 | Direct |
| Architecture page list incomplete (designer blocked) | designer | architect | P1 | Direct |
| Brand vibe / domain context for designer | architect / coordinator | designer | P1 | Direct |
| Copy length affects designer's layout proportion | designer | writer | P2 | Direct |
| Emoji-as-icon detected at runtime (Visual Gate) | qa-engineer | frontend (CC designer) | P0 | Direct |
| Inline arbitrary values in JSX (token discipline) | reviewer | frontend (CC designer) | P1 | Direct |
| Missing responsive — page renders identical at all viewports | qa-engineer | frontend (CC designer) | P0 | Direct |
| Motion missing on speced-animated state | qa-engineer | frontend (CC designer) | P1 | Direct |
| Default shadcn slate primary used despite custom palette specced | qa-engineer | frontend (CC designer) | P1 | Direct |
| Anti-pattern from visual-spec.md detected (e.g., AI gradient hero) | qa-engineer / reviewer | frontend (CC designer) | P1 | Direct |
| Component variant needed but not in inventory | frontend | designer | P2 | Mediated |
| Designer artifacts incomplete (missing concrete value, generic anti-pattern list) | coordinator | designer | P0 | Dispatch |
| Refactoring with visual change in scope | coordinator | designer | P1 | Dispatch |
| Brand visual identity decision (across multiple projects) | designer | coordinator | P2 | Mediated |
| Secret exposed in config | reviewer | devops | P0 | Direct |
| Health check missing | devops | backend | P1 | Direct |
| Merge conflict | git-ops | backend/frontend | P1 | Direct |
| PR ready (touches new endpoint/UI) | git-ops | qa-engineer | P2 | Direct |
| PR ready (touches DB/migrations) | git-ops | auditor | P2 | Direct |
| PR too large | git-ops | coordinator | P2 | Mediated |
| Design doesn't match ADR | reviewer | architect | P2 | Mediated |
| API anti-pattern recurring across endpoints | auditor | architect | P2 | Mediated |
| Schema improvement idea | backend | architect | P3 | Mediated |
| Code style suggestion | reviewer | backend | P3 | Mediated |
| Nice-to-have optimization | reviewer | frontend | P3 | Mediated |
