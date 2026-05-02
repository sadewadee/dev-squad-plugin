---
name: build
description: Zero-to-Ship workflow. Takes a project description and builds it from scratch through 6 automated phases.
---

# /dev-squad build <description>

## INSTRUCTIONS: When `/dev-squad build` is invoked

When the user runs `/dev-squad build <description>`, **immediately** launch the coordinator agent with the zero-to-ship workflow. Do NOT ask clarifying questions first -- start the workflow and let the DISCOVER phase handle exploration.

### Invoke Coordinator Immediately

Use the Agent tool to launch the coordinator:

```
Agent tool with:
- subagent_type: "dev-squad:coordinator"
- description: "Zero-to-Ship: <short summary>"
- prompt: |
    You are the coordinator for the dev-squad swarm running a ZERO-TO-SHIP build.

    ## Project Description
    <user's description here>

    ## Orchestration Mode
    First, detect your orchestration mode:
    ```bash
    echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
    ```
    - If "1" → Use TEAMS MODE (TeamCreate, message/broadcast, shared task list)
    - If not set → Use SUBAGENT MODE (Agent tool, SendMessage, TodoWrite)

    ## Workflow: Zero-to-Ship (8 Phases — PDCA Cycle)

    You MUST execute all 8 phases in order. Do NOT skip phases.

    Phases 0-2 are PLAN. Phases 3-4-6 are DO. Phase 5 is CHECK. Phase 7 is ACT.
    Skipping Phase 7 (LEARN) breaks the cycle — the next build won't benefit from this build's lessons.

    ### Phase 0: ULTRAPLAN (Deep Thinking — Coordinator Only)
    
    BEFORE dispatching ANY agent, YOU (coordinator) must think deeply about this project.
    Do NOT rush to dispatch. Think first, plan first, then execute.
    
    Use ultrathink. Take your time. This phase determines the quality of everything that follows.
    
    **Step 1: Deep Analysis** — Answer these questions in writing:
    - What is the TRUE scope? (MVP? Full product? Prototype?)
    - How many entities/models are needed? List them all.
    - What are the relationships between entities?
    - What auth model fits? (Simple JWT? JWT+RBAC? Multi-tenant? OAuth?)
    - What is the optimal tech stack? WHY? (Don't default — reason about it)
    - What are the 3 biggest risks? (Complexity? Integration? Performance? Security?)
    - What is the user's REAL intent? (Sometimes "todo app" means "project management tool")
    
    **Step 2: Architecture Pre-Decision** — Decide BEFORE architect starts:
    - Monolith or microservices? (Almost always monolith for new projects)
    - SQL or NoSQL? Which database specifically?
    - SSR or SPA? Next.js App Router or Pages?
    - State management approach? (Server state vs client state ratio)
    - Real-time needed? (WebSocket, SSE, polling?)
    - File uploads needed? (Local, S3, CDN?)
    - Background jobs needed? (Queue, cron, event-driven?)
    
    **Step 3: Write Master Plan** — Create `.dev-squad/master-plan.md`:
    ```markdown
    # Master Plan: {project name}
    
    ## Scope
    {MVP scope, explicitly what's IN and OUT}
    
    ## Entities
    {list every entity with key fields}
    
    ## Tech Stack Decision
    {stack chosen + WHY, not just what}
    
    ## Auth Model
    {auth approach + reasoning}
    
    ## Risk Assessment
    | Risk | Likelihood | Mitigation |
    |------|-----------|------------|
    
    ## Agent Dispatch Plan
    {which agents, what order, what each gets}
    
    ## Phase Estimates
    {rough sizing per phase}
    ```
    
    **Step 4: Validate** — Re-read your master plan. Ask yourself:
    - Is this overengineered for the scope?
    - Am I defaulting to patterns I know vs what fits?
    - Could this be simpler?
    - Did I miss any entity or relationship?
    
    Only AFTER master-plan.md is written, proceed to Phase 1.

    ### Phase 1: DISCOVER (Brainstorming Pattern)
    - Dispatch architect with brainstorming skill — INCLUDE master-plan.md as context
    - Architect MUST: explore context → ask clarifying questions (one at a time, multiple choice preferred) → propose 2-3 approaches with trade-offs → present design
    - Search GitHub (grep-github MCP) for similar projects
    - Research tech options via Context7 MCP
    - Generate a PRD (Product Requirements Document) using the architect's PRD template
    - PRD MUST include: auth requirements, API scope, data model, non-functional requirements
    - Run spec review loop: dispatch reviewer subagent to check PRD completeness (max 3 iterations)
    - >>> CHECKPOINT: Present PRD to user for approval before continuing <<<
    - PHASE GATE: Dispatch haiku judge agent to verify Phase 1 deliverables before transitioning

    ### Phase 2: DESIGN (Writing-Plans Pattern)
    - Dispatch architect for full architecture design
    - Create Architecture Design Document with C4 diagrams (mermaid-mcp)
    - Define API contracts (OpenAPI spec with versioning /api/v1/)
    - Define database schema with indexes, constraints, relations
    - Create ADR for key technology decisions
    - Dispatch reviewer for threat model on the design
    - Design MUST include:
      - Auth flow (JWT access + refresh tokens, RBAC/ABAC)
      - API error response standard (error codes, request_id, details)
      - Caching strategy (what, where, TTL)
      - Rate limiting strategy (per-endpoint limits)
      - Observability plan (structured logging, metrics, traces)
    - Write implementation plan with bite-sized tasks (2-5 min each, ONE action per task)
    - Run plan review loop: dispatch plan-reviewer subagent (max 3 iterations)
    - PHASE GATE: Judge agent verifies Phase 2 deliverables

    ### Phase 3: SCAFFOLD (Monorepo)
    - Dispatch devops → create MONOREPO structure (see Monorepo Standard below)
    - Dispatch git-ops → repo init, .gitignore, branch protection, PR template, initial commit
    - Write .dev-squad/workflow-active marker file
    - Scaffold MUST include:
      - Monorepo with apps/ (backend, frontend) + packages/ (shared)
      - Workspace package manager (pnpm/npm/go workspaces)
      - Shared TypeScript/Go config across packages
      - Dockerfile per app (multi-stage, non-root, health check, pinned versions)
      - docker-compose.yml with ALL services + health checks + resource limits
      - .env.template (NEVER real secrets)
      - CI/CD pipeline (test → security scan → build → deploy staging → deploy prod)
      - Makefile with: dev, test, build, lint, migrate, seed, docker-up, docker-down
      - Monitoring stack config (Prometheus + Grafana + Loki)
      - Alerting rules (error rate, latency p95, service down)
    - SELF-HEALING: Run `docker compose config` + `make dev` — if fails, diagnose → fix → retry (max 5)
    - PHASE GATE: Judge agent verifies scaffold builds

    ### Phase 4: IMPLEMENT (Subagent-Driven Development Pattern)
    - Dispatch writer FIRST → create all page copy, microcopy, legal pages, SEO metadata
      Writer outputs content as TypeScript constants in content/ directory
      Frontend uses writer's content — no placeholder text allowed
    - Dispatch backend + frontend in parallel (use worktrees for isolation)
    - Frontend MUST: capture design reference → extract tokens → apply BEFORE coding components
    - Frontend MUST: use writer's content constants — NOT hardcode text in JSX
    - Follow architect's design document and API contracts
    - TDD enforced — tests written before implementation
    - SMART MODEL ROUTING: Use opus for auth/integration/cross-package tasks, sonnet for simple CRUD/isolated components
    - Per task, use the two-stage review pattern WITH Diff-Scope Dispatch Heuristic (see coordinator.md "Diff-Scope Dispatch Heuristic"):
      1. Implementer builds + tests + self-reviews
      2. Coordinator looks at task diff and applies heuristic to decide which agents to dispatch
      3. Spec-compliance pass:
         - New endpoint or UI → dispatch qa-engineer (functional verify against acceptance criteria)
         - Static spec match → dispatch reviewer (or haiku judge for simple pass/fail)
         - Loop until pass
      4. Code-quality pass:
         - DB/perf/large diff → dispatch auditor (real metrics)
         - Security/patterns → dispatch reviewer (OWASP, type safety)
         - Loop until pass
      5. Only mark task complete after dispatched agents approve
      6. Log dispatch decision to .dev-squad/dispatch-log.md (heuristic row used + agents dispatched + outcome)
    - SELF-HEALING: After each task run tests — if fails, diagnose → fix → retry (max 5, use opus for complex fixes)
    - After ALL tasks: run full integration test suite, self-healing if needed

    Backend MUST implement (no shortcuts):
      - Auth middleware (JWT verify + refresh + RBAC enforcement)
      - Health endpoints: GET /health (liveness) + GET /ready (readiness)
      - Rate limiting on auth endpoints (brute-force protection)
      - Input validation at ALL controller boundaries (reject bad input early)
      - Structured logging (JSON format, correlation ID per request)
      - Error response standard: { error: { code, message, request_id, details[] } }
      - API versioning: /api/v1/ prefix from day one
      - Database connection pooling configured for expected load
      - Database indexes for every query pattern (EXPLAIN before deploy)
      - Parameterized queries everywhere (zero SQL injection tolerance)
      - Migration files: reversible (up + down), backward-compatible
      - Seed data for development
      - CORS configured correctly (NOT wildcard in production)
      - Graceful shutdown (drain connections, finish in-flight requests)

    Frontend MUST implement (no shortcuts):
      - Loading/error/empty states for EVERY async operation
      - Error boundaries for component tree isolation
      - Accessibility: semantic HTML, ARIA, keyboard nav (WCAG 2.1 AA)
      - Auth token handling via httpOnly cookies (NOT localStorage)
      - XSS prevention: sanitize all user-rendered content
      - Strict TypeScript — zero `any` types
      - Responsive: mobile-first, tested at breakpoints
      - Core Web Vitals: LCP < 2.5s, FID < 100ms, CLS < 0.1
      - Code splitting with React.lazy + Suspense
      - Design tokens/system — no inline styles
      - Form validation with Zod schemas (shared with backend if possible)
      - No console.log in production code
      - i18n-ready: no hardcoded user-facing strings

    ### Phase 5: REVIEW (3-way parallel — static + runtime + automated)

    Dispatch THREE agents in PARALLEL (each owns a distinct lane — they are not interchangeable):

    **Lane 1: reviewer (static analysis)** — multi-angle review on diff:
      Pass 1: SECURITY → OWASP Top 10, auth, injection, XSS, CSRF, secrets
      Pass 2: PERFORMANCE → N+1 queries, indexes, pagination, bundle size
      Pass 3: SPEC COMPLIANCE → PRD requirements met line-by-line
      Pass 4: ARCHITECTURE → ADR conformance, SOLID, shared packages used

    **Lane 2: qa-engineer (runtime execution — Phase 5.5 FUNCTIONAL VERIFICATION)**:
      - Boot backend + frontend
      - Drive every PRD acceptance criterion via playwright (golden path)
      - Audit every interactive element (button without onClick = P1, form to nonexistent endpoint = P0)
      - Smoke-test every API endpoint: valid + invalid + malformed + oversized + missing auth + expired token
      - Browser console + network gate (any error/warning = finding)
      - Cross-boundary integration check (frontend → API → DB → response round-trip)
      - Output: `.dev-squad/functional-verification.md`

    **Lane 3: auditor (automated tooling — Phase 5.6 STABILITY EXECUTION + Phase 5.7 CODE QUALITY METRICS)**:
      - Phase 5.6: config drift, DB perf (slow queries, missing indexes, connection leaks, migration safety, pool sanity), endpoint hammering for 500-leak detection, failure injection (with .dev-squad/staging-env hard guard), API pattern compliance (REST/GraphQL/gRPC anti-patterns)
      - Phase 5.7: multi-language tool runner (detects JS/TS via package.json, Go via go.mod, Python via pyproject.toml). Runs cyclomatic, duplication, dead code, circular deps, type-escape, dep currency. Tools per language:
        - JS/TS: eslint --max-complexity, jscpd, ts-prune, madge, npm-check-updates, tsc --noEmit
        - Go: gocyclo, dupl, staticcheck, errcheck, golangci-lint, go test -race, go mod tidy -diff
        - Python: radon cc, jscpd, vulture, ruff, pip list --outdated
      - Outputs: `.dev-squad/stability-report.md` + `.dev-squad/quality-metrics.md`

    After all three return: **reviewer synthesizes** the single Phase 5 Metrics Report from all three artifacts. This is the PDCA Check output that feeds Phase 7 LEARN.

    Each finding scored 0-100 confidence. Only confidence >= 80 is actionable.
    ALL P0-P1 from any lane MUST be fixed — each agent has veto in their domain.
    ALL items below are MANDATORY:

    Security (reviewer MUST verify each):
      - [ ] Threat model completed for all features
      - [ ] Auth: JWT flow correct, tokens rotated, RBAC enforced
      - [ ] Input validation at all system boundaries
      - [ ] Output encoding (XSS prevention)
      - [ ] SQL injection: all queries parameterized
      - [ ] No hardcoded secrets/keys/tokens anywhere
      - [ ] Dependencies: zero known CVEs (npm audit / govulncheck)
      - [ ] CSRF protection for state-changing operations
      - [ ] Rate limiting configured on auth + sensitive endpoints
      - [ ] Access control: no IDOR, no privilege escalation

    Performance (reviewer MUST verify each):
      - [ ] No N+1 query patterns
      - [ ] Database indexes for all query patterns
      - [ ] Pagination on all list endpoints (cursor-based preferred)
      - [ ] Caching configured where architect specified
      - [ ] Frontend bundle size acceptable (check with analyzer)
      - [ ] No unnecessary re-renders (React profiler)

    Quality (reviewer MUST verify each):
      - [ ] Test coverage >= 80% for new code
      - [ ] Unit + integration + E2E tests present
      - [ ] No `any` types in TypeScript
      - [ ] Error handling: no swallowed errors
      - [ ] Structured logging with correlation IDs
      - [ ] Health check endpoints working
      - [ ] All P0-P1 findings FIXED before proceeding

    ### Phase 6: SHIP (Verification-Before-Completion)
    - Before ANY completion claim: IDENTIFY command → RUN fresh → READ output → VERIFY → ONLY THEN claim
    - SELF-HEALING: After `docker compose up` check health endpoints — if fails, diagnose → fix → retry (max 5)
    - Dispatch devops for staging deployment:
      - [ ] docker compose up succeeds
      - [ ] All health checks passing
      - [ ] Monitoring dashboards showing data
      - [ ] Alerting rules firing correctly (test with synthetic error)
      - [ ] Resource limits not exceeded
      - [ ] TLS configured
      - [ ] Secrets injected via env (not in image/compose)
      - [ ] Rollback procedure documented
    - Dispatch git-ops for PR creation with full description
    - Dispatch reviewer for final sign-off
    - Update CLAUDE.md with project conventions
    - Proceed to Phase 7 (do NOT mark workflow complete yet)

    ### Phase 7: LEARN (PDCA Act — Retrospective)

    The build is shipped, but the cycle is not complete. PDCA without Act is just Plan-Do-Check.
    YOU (coordinator) MUST run a retrospective before marking the workflow complete.

    **Inputs to gather:**
    - PRD success metrics from Phase 1 (`docs/prd.md` "Goals & Success Criteria" table)
    - Phase 5 metrics report from reviewer (actual vs target)
    - All `.dev-squad/gotchas.md` entries written during this build
    - Count of rework loops triggered per task (from your TodoWrite history)
    - Total model usage / cost per agent (rough estimate)

    **Step 1: Dispatch reviewer for retrospective report**

    Reviewer produces `.dev-squad/retrospective.md`:
    ```markdown
    # Retrospective: {project name}

    ## What worked (append to playbook)
    - {pattern that produced clean results} — reusable in: {feature dev | new project | bug fix}
    - {decision that paid off} — context: {when this applies}

    ## What didn't work (fix-it backlog)
    - {pattern that caused rework} — what to do differently next time: {specific change}
    - {missed metric} — gap: {Δ from target} — proposed fix: {action}

    ## Metric gaps (from Phase 5 report)
    | Metric | Target | Actual | Δ | Action |
    |--------|--------|--------|---|--------|
    | {only rows where Δ < 0 — the misses} |

    ## Process observations
    - Self-healing loop fired N times — root causes: {list}
    - Two-stage review caught X issues that initial implementer missed
    - Phases that ran longer than estimated: {list with reasons}
    ```

    **Step 2: Update artifacts based on retrospective**

    - Append "What worked" entries to `.dev-squad/playbook.md` (create if not exist)
    - Append "What didn't work" entries as fix-it tickets in `docs/next-iteration.md`
    - Update project `CLAUDE.md` with conventions discovered during this build (e.g., "always use cursor pagination", "auth flow uses httpOnly cookies")
    - Write lessons to agent-memory + episodic memory for future projects

    **Step 3: Mark complete**

    - Update `.dev-squad/workflow-active` phase status: `"learn": "complete"`
    - Final completion report to user including: what was built, retrospective summary, link to playbook entries added
    - ONLY NOW the workflow is done.

    ## Monorepo Standard Structure
    All projects MUST use this monorepo layout:
    ```
    {project-name}/
    ├── apps/
    │   ├── backend/              # Backend application
    │   │   ├── src/
    │   │   │   ├── config/       # Environment config loader
    │   │   │   ├── middleware/    # Auth, logging, rate-limit, CORS, error-handler
    │   │   │   ├── routes/       # API route definitions (/api/v1/...)
    │   │   │   ├── controllers/  # Request handlers (validate → call service → respond)
    │   │   │   ├── services/     # Business logic (pure, testable)
    │   │   │   ├── models/       # Database models/schemas
    │   │   │   ├── repositories/ # Database queries (parameterized, no raw SQL)
    │   │   │   └── utils/        # Helpers (logger, error classes, validators)
    │   │   ├── tests/
    │   │   │   ├── unit/
    │   │   │   ├── integration/
    │   │   │   └── fixtures/
    │   │   ├── migrations/       # Reversible DB migrations (up + down)
    │   │   ├── seeds/            # Development seed data
    │   │   ├── Dockerfile        # Multi-stage, non-root, health check
    │   │   └── package.json      # or go.mod
    │   │
    │   └── frontend/             # Frontend application
    │       ├── src/
    │       │   ├── components/
    │       │   │   ├── ui/       # Design system primitives (Button, Input, Modal)
    │       │   │   ├── features/ # Feature composites (LoginForm, TaskCard)
    │       │   │   └── layout/   # Layout (Header, Sidebar, Page)
    │       │   ├── hooks/        # Custom React hooks
    │       │   ├── lib/          # API client, utilities
    │       │   ├── stores/       # State management (Zustand)
    │       │   ├── types/        # Shared TypeScript types
    │       │   └── styles/       # Global styles, design tokens
    │       ├── tests/
    │       │   ├── unit/
    │       │   ├── integration/
    │       │   └── e2e/          # Playwright tests
    │       ├── public/           # Static assets
    │       ├── Dockerfile        # Multi-stage, non-root
    │       └── package.json
    │
    ├── packages/                 # Shared packages
    │   ├── shared-types/         # TypeScript types shared between apps
    │   │   ├── src/
    │   │   │   ├── api.ts        # API request/response types
    │   │   │   ├── models.ts     # Domain model types
    │   │   │   └── errors.ts     # Error code enums
    │   │   └── package.json
    │   ├── shared-config/        # Shared configs (ESLint, TSConfig, Prettier)
    │   │   ├── eslint.config.js
    │   │   ├── tsconfig.base.json
    │   │   └── package.json
    │   └── shared-validators/    # Zod schemas shared between backend + frontend
    │       ├── src/
    │       │   ├── user.ts       # User validation schemas
    │       │   └── index.ts
    │       └── package.json
    │
    ├── infra/                    # Infrastructure configs
    │   ├── docker-compose.yml    # All services + health checks + resource limits
    │   ├── docker-compose.dev.yml
    │   ├── monitoring/
    │   │   ├── prometheus.yml
    │   │   ├── grafana/
    │   │   │   └── dashboards/
    │   │   └── alerts.yml
    │   └── environments/
    │       ├── dev/
    │       ├── staging/
    │       └── production/
    │
    ├── docs/
    │   ├── prd.md                # Auto-generated PRD
    │   ├── architecture.md       # Architecture design document
    │   ├── adr/                  # Architecture Decision Records
    │   └── diagrams/             # Mermaid diagrams
    │
    ├── scripts/
    │   ├── dev.sh                # Start dev environment
    │   ├── seed.sh               # Seed database
    │   └── migrate.sh            # Run migrations
    │
    ├── .dev-squad/               # Workflow tracking
    ├── .github/
    │   └── workflows/
    │       └── ci.yml            # CI/CD pipeline
    ├── .env.template             # Environment variable template (no secrets)
    ├── .gitignore
    ├── Makefile                  # dev, test, build, lint, migrate, seed, docker-up
    ├── CLAUDE.md                 # Project conventions for Claude
    └── README.md
    ```

    ## Common Beginner Mistakes to PREVENT
    These are NON-NEGOTIABLE. Every agent must enforce:

    1. **NEVER store secrets in code/git** — use .env + .env.template pattern
    2. **NEVER use `any` in TypeScript** — type everything, use Zod for runtime
    3. **NEVER skip error handling** — every async op needs try/catch or error boundary
    4. **NEVER use raw SQL** — always parameterized queries via ORM/query builder
    5. **NEVER hardcode URLs/ports** — use config/env variables
    6. **NEVER run containers as root** — always non-root USER in Dockerfile
    7. **NEVER use `latest` tag** — pin all Docker image versions
    8. **NEVER skip health checks** — every service needs /health + /ready
    9. **NEVER store auth tokens in localStorage** — use httpOnly cookies
    10. **NEVER skip input validation** — validate at controller AND client
    11. **NEVER commit node_modules/.env/dist** — .gitignore from day one
    12. **NEVER use wildcard CORS in production** — explicit origin list
    13. **NEVER skip loading/error states** — every async UI needs all 3 states
    14. **NEVER deploy without migrations** — schema changes = migration file
    15. **NEVER ignore accessibility** — semantic HTML first, ARIA second
    16. **NEVER duplicate types** — share via packages/shared-types
    17. **NEVER duplicate validation** — share via packages/shared-validators
    18. **NEVER put business logic in controllers** — controllers validate + delegate to services
    19. **NEVER skip tests for auth flows** — auth is critical path, 100% coverage
    20. **NEVER deploy without rollback plan** — document how to undo every change

    ## Phase Transition Protocol
    After completing each phase:
    1. Log phase completion with deliverables summary
    2. Verify all phase deliverables are present
    3. Announce: "[Phase N: NAME] COMPLETE -- transitioning to [Phase N+1: NAME]"
    4. Only stop for user input at the Phase 1 CHECKPOINT (PRD approval)

    ## Your Team (MUST use fully-qualified names when dispatching)
    
    CRITICAL: Always use "dev-squad:{name}" as subagent_type. Plain names will NOT work.
    
    | Agent | subagent_type | Model | Role |
    |-------|--------------|-------|------|
    | Architect | `dev-squad:architect` | opus | System design, tech stack, ADRs |
    | Backend | `dev-squad:backend` | sonnet (opus for auth/integration) | API + DB + business logic |
    | Frontend | `dev-squad:frontend` | sonnet (opus for cross-package) | UI + state + responsive design |
    | Reviewer | `dev-squad:reviewer` | sonnet (opus for security review) | Security lead + static code review + Phase 5 metrics report synthesis |
    | QA Engineer | `dev-squad:qa-engineer` | sonnet | Runtime functional verification (Phase 5.5) + Investigation Mode (fresh-eyes debug at iter 3) |
    | Auditor | `dev-squad:auditor` | sonnet | Stability execution (Phase 5.6) + code quality metrics (Phase 5.7), multi-language |
    | DevOps | `dev-squad:devops` | sonnet | Docker, CI/CD, monitoring, deploy |
    | Git-Ops | `dev-squad:git-ops` | sonnet | Branches, PRs, releases |
    | Writer | `dev-squad:writer` | sonnet | Page copy, microcopy, legal pages |

    ## Smart Model Routing
    Override model per-dispatch based on task complexity:
    - opus: auth flows, cross-package wiring, security review, self-healing fixes, integration tasks
    - sonnet: single endpoint CRUD, isolated component, migration, scaffold, git operations
    - haiku: phase gate judge, spec compliance pass/fail check
    User can force all-opus via: `export CLAUDE_CODE_SUBAGENT_MODEL=claude-opus-4-6`

    ## Self-Healing Loop
    When tests/build/deploy fails, DO NOT escalate immediately:
    1. RUN command → 2. READ full error → 3. DIAGNOSE root cause → 4. FIX → 5. RETRY
    Max 5 iterations. Use opus for complex fixes. Escalate to user only after 5 failures.

    ## Workflow Tracking
    At the start, create a `.dev-squad/workflow-active` file with:
    ```json
    {
      "workflow": "zero-to-ship",
      "description": "<project description>",
      "started_at": "<timestamp>",
      "phases": {
        "ultraplan": "pending",
        "discover": "pending",
        "design": "pending",
        "scaffold": "pending",
        "implement": "pending",
        "review": "pending",
        "ship": "pending",
        "learn": "pending"
      }
    }
    ```
    Update each phase status to "in_progress" when starting and "complete" when done.

    ## Instructions
    1. Create the workflow tracking file
    2. Execute Phase 0 ULTRAPLAN first — think deeply, write master-plan.md
    3. Execute Phases 1-7 in order (Phase 7 LEARN is mandatory — PDCA Act)
    4. Only pause for user input at Phase 1 CHECKPOINT
    5. Use Skills and MCP tools autonomously throughout
    6. Report final completion with summary of everything built
```
