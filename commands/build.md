---
name: build
description: Zero-to-Ship workflow. Takes a project description and builds it from scratch through 9 automated phases (0-7 + 3.5 design gate).
---

# /dev-squad build <description>

> **Canonical workflow definition:** `.claude-plugin/workflows/zero-to-ship.json` — coordinator reads this JSON at workflow start as dispatch source-of-truth (phase list, lead agents, parallel agents, blocking gates, skip conditions, external skills). This file is the descriptive prompt; JSON is canonical.
> Human-readable mapping: [docs/workflow-mapping.md](../docs/workflow-mapping.md). Companion plugins: [docs/companion-plugins.md](../docs/companion-plugins.md).

## Auto Mode (`--auto`)

If the argument string contains `--auto`, this run is UNATTENDED after kickoff. The coordinator MUST:

1. **Write mode + budget to state.** At workflow start, write `.dev-squad/workflow-active` with `"mode": "auto"` and copy the `auto_defaults` block from `.claude-plugin/workflows/zero-to-ship.json` into an `"auto"` object, adding `"started_at"` (current UTC ISO timestamp). Example:
   `{"workflow":"zero-to-ship","mode":"auto","auto":{"started_at":"<ISO>","wall_clock_cap_min":480,"max_total_dispatches":300,"max_iterations_per_phase":5,"on_floor_miss":"fail_loud"},"phases":{...}}`
2. **Never ask the user.** Do NOT call `AskUserQuestion`. Do NOT end any turn with a question. Every decision that would normally be a question is INFERRED from the project description + defaults and recorded in `.dev-squad/assumption-ledger.md`.
3. **Skip the Phase 1 PRD checkpoint.** The Phase 1 scored evaluator (Phase 1 PRD rubric, sonnet) substitutes for human approval. Record "PRD auto-approved by Phase 1 gate" in the ledger.

(Without `--auto`, mode is `interactive`; behavior is unchanged and all auto hooks no-op.)

### Assumption ledger format (`.dev-squad/assumption-ledger.md`)

| # | Phase | Decision point | Inferred value | Confidence | Source | Risk if wrong |
|---|-------|----------------|----------------|-----------|--------|---------------|

- Confidence: `high` / `med` / `low`; Source: `description-derived` / `default` / `heuristic`.
- Mark LOW-confidence rows clearly; the Phase 7 report surfaces them.

### Conservative defaults for IRREVERSIBLE decisions (auto mode)

When inference confidence is not high, the 4 irreversible dimensions use these conservative defaults and are logged as `confidence: low`:

| Dimension | Conservative default | Rationale |
|-----------|---------------------|-----------|
| Tenancy strategy (ADR-001) | shared-DB + RLS | standard B2B SaaS default; flag for review |
| Identity hierarchy (Intake Q2) | 3-tier (Platform / Tenant / User-in-tenant) | dev-squad's documented default |
| Billing + payment provider (ADR-002) | Stripe | most common; widest pattern coverage |
| Compliance scope (Intake Q10) | none, UNLESS a regulation is explicitly named in the description | do not impose GDPR/SOC2/etc. speculatively |

The other 6 SaaS intake dimensions are inferred ad hoc from the description (no fixed default).

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

    ## Workflow: Zero-to-Ship (9 Phases — PDCA Cycle)

    You MUST execute all 9 phases in order. Do NOT skip phases.

    Phases 0-2 + 3.5 are PLAN. Phases 3-4-6 are DO. Phase 5 is CHECK. Phase 7 is ACT.
    Phase 3.5 (DESIGN) is the anti-AI-slop gate — designer produces 4 BLOCKING artifacts before frontend can write UI. Skip ONLY if `--mvp-mode` flag is set by user.
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

    **Step 2.5: SaaS Mode Detection** — Detect if this is SaaS-class scope. **DEFAULT POSTURE: NON-SAAS unless user explicitly confirms.**
    - Auto-detect from PRD/description keywords: "subscription", "tenant", "billing", "plans", "multi-tenant", "team workspace", "billing/Stripe", "usage-based", "admin panel", "drill down", "analytics dashboard", "white-label"
    - Trigger SaaS confirmation question ONLY when: **3+ keywords match** OR user passed `--saas` flag explicitly
    - If fewer than 3 keywords match AND no `--saas` flag: skip confirmation, lock master-plan.md to `SaaS Mode: disabled (standard app)`, proceed to Step 3
    - SaaS confirmation (use AskUserQuestion) — "No" is the recommended/safe default:
      ```
      Question: "I detected possible SaaS-class scope. Multi-tenancy, billing, RLS, and audit logs are heavy patterns — they modify your data model and add 8 backend modules (tenants, plans, billing, webhooks, api-keys, audit-log, notifications, admin). Enable SaaS scope?"
      Options (in order):
        - "No, build a standard app" → DEFAULT/RECOMMENDED. Lock SaaS Mode: disabled. No multi-tenancy, no billing module, no audit logs. Standard zero-to-ship.
        - "Yes, full SaaS scope" → Lock SaaS Mode: enabled. Load saas-patterns + saas-readiness. Scaffold extends to 8 SaaS modules. Architect produces ADR-001..006 (006 = identity hierarchy NEW v4.15.0).
        - "Yes, but skip admin dashboard" → Lock SaaS Mode: enabled, drill-down disabled. Load saas-patterns Part 1 only.
      ```
    - **If user dismisses/cancels the question OR returns no answer**: DEFAULT TO "No, standard app". Lock master-plan.md to `SaaS Mode: disabled`. Never apply SaaS patterns silently.
    - Record decision in `.dev-squad/master-plan.md` under section "SaaS Mode" with explicit value (`enabled` or `disabled`) — once locked, do NOT retrofit (multi-tenancy retrofit = data leak risk; removing it = wasted code)
    - If SaaS mode is `enabled` ONLY, proceed to Step 2.5b SaaS Scope Intake (below) BEFORE writing master-plan. Architect later produces ADR-001 to **ADR-006** in Phase 2 BEFORE backend codes: tenancy strategy, billing model, plan structure, admin scope, **compliance scope** (regulations apply per Intake Block 3 Q10), and **identity hierarchy** (3-tier Platform/Tenant/User-in-tenant per Intake Block 1 Q2). If SaaS mode is `disabled`, skip Step 2.5b AND skip ADR-001..006 entirely.

    **Auto mode:** skip the confirmation `AskUserQuestion`. Apply the keyword heuristic deterministically (3+ keywords OR `--saas` → SaaS enabled; else standard). Log the decision + matched keywords + confidence to the assumption ledger.

    **Step 2.5b: SaaS Scope Intake** — RUN ONLY IF Step 2.5 locked `SaaS Mode: enabled`. Skip entirely for standard apps.

    Many SaaS projects fail at kick-start because Phase 0 captures only "Enable SaaS yes/no" — leaving 50+ implementation decisions made silently. The post-launch readiness audit then surfaces P0/P1 gaps that should have been planned upfront. Empirical evidence (wacrm project audit, 2026-05): single-question Phase 0 caused 8 retrofit phases — billing replatform, user management hardening, invoicing/tax, plan management, customer API, compliance lifecycle, operational, customer success.

    To prevent this, run **3 AskUserQuestion blocks in sequence** to lock 10 SaaS dimensions before architect codes. Each answer is recorded in master-plan.md `## SaaS Intake` section. Architect, backend, frontend, devops, writer READ this section at their respective phases.

    **Block 1: Foundation (4 questions, 1 AskUserQuestion call)**

    | # | Question | Options |
    |---|----------|---------|
    | Q1 | "Primary target market? (drives currency + payment provider + tax + legal compliance)" | Indonesia (IDR + Faktur Pajak + Xendit/QRIS + manual bank + PDP UU 27/2022) / EU (EUR + VAT + Stripe + GDPR + AI Act + DORA) / United States (USD + Stripe Tax + Stripe + CCPA + SOC 2 path) / Multi-region (regional provider abstraction per saas-readiness §21) |
    | Q2 | "3-tier admin hierarchy? (drives identity model + impersonation)" | Yes — Platform admin + Tenant admin + User-in-tenant (PlatformRole enum + /(platform-admin) routes + impersonation + PlatformAuditLog) / Tenant-only — no platform layer (simpler, limits operator visibility) |
    | Q3 | "Per-tenant role model? (drives RBAC complexity)" | Owner-only (single user per tenant) / Owner + Member (binary) / Owner + Admin + Editor + Viewer (standard 3-role) / Custom RBAC with permission matrix |
    | Q4 | "Trial + plan model?" | No trial — paid only / Free tier + paid plans (freemium) / Time-limited trial (e.g., 14-day) → automatic downgrade cron on expiry / Free tier + time-limited trial of higher plan |

    **Block 2: Customer-facing features (4 questions, 1 AskUserQuestion call)**

    | # | Question | Options |
    |---|----------|---------|
    | Q5 | "Self-service auth flows required? (multiSelect)" | Password reset / Password change / Email change with re-verification / Account deletion / 2FA TOTP / Account lockout after N failed |
    | Q6 | "Customer-facing API surface?" | None — internal use only / API keys (X-API-Key) / API keys + customer-facing webhooks / Full OpenAPI/Swagger + API keys + webhooks |
    | Q7 | "Transactional email lifecycle? (multiSelect)" | Email verification / Welcome / Trial-ending warning / Trial-expired / Payment-failed dunning (1st/2nd/final) / Re-engagement drip (30/60/90 day) / Win-back / cancel survey |
    | Q8 | "Invoice surface?" | Stripe-hosted portal only / In-app invoice list + PDF download / In-app + PDF + customer resend/notes |

    **Block 3: Operational + Compliance (2 questions, 1 AskUserQuestion call)**

    | # | Question | Options |
    |---|----------|---------|
    | Q9 | "Operational readiness baseline? (multiSelect — all checked = production-ready)" | Postgres backup cron (pg_dump → S3 + restore drill) / CI/CD pipeline (typecheck + test + lint + security scan blocking) / Error tracking (Sentry) / Status page (BetterStack/Cachet/static) / PII log redaction (Pino redact) / Rate limiting per endpoint + per API key |
    | Q10 | "Compliance jurisdiction? (multiSelect — drives data export + erasure + consent UI)" | GDPR (any EU user triggers Art. 15/17) / PDP UU 27/2022 (Indonesian user) / CCPA (California opt-out + delete) / LGPD (Brazilian) / SOC 2 Type 1 path / EU AI Act 2026 / None (US domestic, no special compliance) |

    **After all 10 answers captured**: write to `.dev-squad/master-plan.md` under new `## SaaS Intake` section. This becomes source-of-truth that architect/backend/frontend/devops/writer READ during their phases. Master-plan.md cannot be modified retroactively without explicit ADR (multi-tenancy retrofits = data leak risk; identity hierarchy retrofits = full re-scaffold; payment provider retrofits = full billing replatform).

    **Decline / cancel handling**: if user cancels any block mid-intake, lock the answers obtained so far + mark remaining dimensions as `UNANSWERED — REQUIRE Phase 1 clarification` in master-plan.md. Phase 1 architect brainstorming MUST re-surface unanswered dimensions before PRD generation (architect uses brainstorming skill with `clarifying_questions` mode for these specific gaps).

    **BETA notice**: SaaS Intake is beta. The 10-question matrix captures most SaaS scope but is not exhaustive. Phase 5+ readiness audit will likely still surface edge-case P1/P2 gaps. Treat Intake as foundation, not guarantee.

    **Auto mode:** do NOT run the 3 AskUserQuestion blocks. Infer all 10 dimensions: the 4 irreversible ones use the conservative-defaults table above (logged `confidence: low`); the other 6 are inferred from the description. Write every inference to the assumption ledger. Do not require Phase 1 clarification for unanswered dimensions (there is no human) — record them as low-confidence assumptions instead.

    **Step 3: Write Master Plan** — Create `.dev-squad/master-plan.md`:
    ```markdown
    # Master Plan: {project name}
    
    ## SaaS Mode
    `enabled` | `disabled`   ← set explicitly in Step 2.5
    
    ## SaaS Intake
    (Include this section ONLY when SaaS Mode = enabled. Captured during Step 2.5b. UNANSWERED = require Phase 1 clarification.)
    
    ### Block 1: Foundation
    - **Q1 Target Market**: {Indonesia | EU | United States | Multi-region}
    - **Q2 Admin Hierarchy**: {3-tier (Platform + Tenant + User-in-tenant) | Tenant-only}
    - **Q3 Per-Tenant Role Model**: {Owner-only | Owner+Member | Owner+Admin+Editor+Viewer | Custom RBAC}
    - **Q4 Trial + Plan Model**: {No trial | Freemium | Time-limited trial | Free tier + time-limited trial of higher plan}
    
    ### Block 2: Customer-facing features
    - **Q5 Self-Service Auth Flows**: [password-reset, password-change, email-change, account-deletion, 2FA, lockout]
    - **Q6 Customer-Facing API Surface**: {None | API-keys | API-keys+webhooks | OpenAPI+keys+webhooks}
    - **Q7 Email Lifecycle**: [verify, welcome, trial-warn, trial-expired, payment-failed-dunning, re-engagement, win-back]
    - **Q8 Invoice Surface**: {Stripe-portal | In-app + PDF | In-app + PDF + resend/notes}
    
    ### Block 3: Operational + Compliance
    - **Q9 Operational Readiness**: [backup-cron, ci-cd-gate, sentry, status-page, pii-redact, rate-limit]
    - **Q10 Compliance Jurisdiction**: [GDPR, PDP-UU-27, CCPA, LGPD, SOC2-Type1, EU-AI-Act, none]
    
    ## Scope
    {MVP scope, explicitly what's IN and OUT}
    
    ## Entities
    {list every entity with key fields. If Q2 = 3-tier: include `Platform.{Admin,Support}` + `Organization` + `User(with platformRole?, role)` + `PlatformAuditLog` + `TenantAuditLog`. If Q2 = Tenant-only: include `Organization` + `User(role)` only.}
    
    ## Tech Stack Decision
    {stack chosen + WHY, not just what. Payment provider derived from Q1 (Indonesia → Xendit + manual; EU/US → Stripe; Multi-region → provider abstraction per saas-readiness §21).}
    
    ## Auth Model
    {auth approach + reasoning. Self-service flows derived from Q5 — explicitly list each flow's endpoint.}
    
    ## Risk Assessment
    | Risk | Likelihood | Mitigation |
    |------|-----------|------------|
    
    ## Agent Dispatch Plan
    {which agents, what order, what each gets. Architect produces ADR-001..006 if SaaS=enabled (006 = identity hierarchy from Q2/Q3).}
    
    ## Phase Estimates
    {rough sizing per phase. SaaS-mode-enabled adds Phase 6 sub-phase decomposition 6-A..6-H per saas-readiness §9 if Intake reveals 10+ P0+P1 across 4+ domains.}
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
    - Run spec review loop: dispatch `subagent_type: "dev-squad:reviewer"` to check PRD completeness (max 3 iterations). Reviewer applies spec-document-reviewer check matrix from saas-readiness Section 8 (if SaaS) or general spec review (otherwise).
    - >>> CHECKPOINT: Present PRD to user for approval before continuing <<<
      (Auto mode: SKIP this checkpoint — the Phase 1 scored evaluator (Phase 1 PRD rubric, sonnet) approves the PRD; log "PRD auto-approved by Phase 1 gate" to the assumption ledger.)
    - PHASE GATE: Dispatch `subagent_type: "general-purpose"` with `model: "sonnet"` to run the scored evaluator against the Phase 1 PRD rubric before transitioning. (See "Phase Gate Decision (Scored Evaluator)" in coordinator.md — there is NO `dev-squad:judge` agent type; use general-purpose + sonnet for Phase 1 PRD + Phase 3.5 Design gates, haiku for other structural gates.)

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
    - Run plan review loop: dispatch `subagent_type: "general-purpose"` with `model: "haiku"` (cost-efficient plan completeness check) OR `subagent_type: "dev-squad:reviewer"` (codebase-aware, when plan touches security/SaaS subsystems). Max 3 iterations. NO `dev-squad:plan-reviewer` agent type exists — use one of the two patterns above.
    - PHASE GATE: Dispatch scored evaluator (`general-purpose`, model: `haiku`, Generic rubric) to verify Phase 2 deliverables; loop on feedback until score >= threshold or max_iters/plateau.

    ### Phase 3: SCAFFOLD (Monorepo)
    - Dispatch devops → create MONOREPO structure (see Monorepo Standard below)
    - Dispatch git-ops → repo init, .gitignore, branch protection, PR template, initial commit
    - Write .dev-squad/workflow-active marker file (now includes `ui_design` phase between scaffold and implement)
    - **If SaaS mode active** (per Phase 0 Step 2.5): devops scaffolds additional backend modules — `apps/backend/src/{tenants,plans,billing,webhooks,api-keys,audit-log,notifications,admin}/` (or Go-equivalent `internal/...`). Reference `dev-squad:saas-patterns` skill for module contracts.
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
    - PHASE GATE: Dispatch scored evaluator (`general-purpose`, model: `haiku`, Generic rubric) to verify scaffold builds; loop on feedback until score >= threshold or max_iters/plateau

    ### Phase 3.5: DESIGN (BLOCKING anti-AI-slop gate — skip ONLY with `--mvp-mode`)
    - Dispatch **designer** → produce 4 BLOCKING artifacts in `.dev-squad/design/`:
      - `design-tokens.md` (color palette, typography ladder, spacing scale, radius, motion timings/easings, shadow — concrete values, no TBD)
      - `visual-spec.md` (≥3 reference URLs with screenshots in `.dev-squad/design/refs/`, brand vibe, project-specific anti-pattern list)
      - `component-inventory.md` (every component × variants × states including loading/error/empty/focus)
      - `responsive-spec.md` (mermaid wireframes per page × mobile/tablet/desktop)
    - **If SaaS mode active AND PRD has dashboard/analytics/admin scope:** designer ALSO produces `drill-down-spec.md` (drill hierarchy mermaid + per-level spec for KPI cards, time-series, segment table, entity detail, event detail + filter model + anti-patterns). Reference `dev-squad:saas-patterns` Part 2 Section 26 (drill-down spec template lives in same skill, not separate).
    - Designer uses WebSearch + grep-github + playwright (screenshot references) + chrome-devtools (study real reference styles)
    - Designer's anti-pattern list is project-specific (NOT generic) — must explicitly reject: emoji-as-icon, default shadcn slate primary, AI-cliché purple-to-blue gradients, missing responsive, missing motion
    - SELF-HEALING: If artifacts incomplete (missing concrete values, no reference screenshots, generic anti-pattern list) → re-dispatch designer with specific gap call-out
    - PHASE GATE: Dispatch scored evaluator (`general-purpose`, model: `sonnet`, Phase 3.5 Design rubric) to verify all 4 artifacts present + designer's self-check passed; loop on feedback until score >= threshold or max_iters/plateau before transitioning to Phase 4
    - `--mvp-mode` escape: produce only design-tokens.md + slim visual-spec.md (1 ref + anti-pattern list); skip component-inventory + responsive-spec

    ### Phase 4: IMPLEMENT (Subagent-Driven Development Pattern)
    - Dispatch writer FIRST → create all page copy, microcopy, legal pages, SEO metadata
      Writer outputs content as TypeScript constants in content/ directory
      Frontend uses writer's content — no placeholder text allowed
    - Dispatch backend + frontend in parallel (use worktrees for isolation)
    - Frontend MUST: Read all 4 designer artifacts in `.dev-squad/design/` BEFORE coding any UI. No improvising.
    - Frontend MUST: copy design-tokens.md values into `src/styles/design-tokens.ts` and `tailwind.config.ts`. Inline arbitrary values like `text-[#abc]` are P1 violations.
    - Frontend MUST: implement every component variant + state per `component-inventory.md`
    - Frontend MUST: wire motion per `design-tokens.md` motion section, with reduced-motion fallback
    - Frontend MUST: implement responsive per `responsive-spec.md` mermaid wireframes (mobile/tablet/desktop)
    - Frontend MUST: use SVG icons (lucide-react / heroicons / custom) — NEVER emoji as icon
    - Frontend MUST: use writer's content constants — NOT hardcode text in JSX
    - Follow architect's design document and API contracts
    - TDD enforced — tests written before implementation
    - SMART MODEL ROUTING: Use opus for auth/integration/cross-package tasks, sonnet for simple CRUD/isolated components
    - Per task, use the two-stage review pattern WITH Diff-Scope Dispatch Heuristic (see coordinator.md "Diff-Scope Dispatch Heuristic"):
      1. Implementer builds + tests + self-reviews
      2. Coordinator looks at task diff and applies heuristic to decide which agents to dispatch
      3. Spec-compliance pass:
         - New endpoint or UI → dispatch `dev-squad:qa-engineer` (functional verify against acceptance criteria)
         - Static spec match → dispatch `dev-squad:reviewer` (full review) OR `general-purpose` + `model: "haiku"` (scored gate, Generic rubric — there is NO `dev-squad:judge` agent type)
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
      - Loading/error/empty states for EVERY async operation (per component-inventory.md)
      - Error boundaries for component tree isolation
      - Accessibility: semantic HTML, ARIA, keyboard nav (WCAG 2.1 AA)
      - Auth token handling via httpOnly cookies (NOT localStorage)
      - XSS prevention: sanitize all user-rendered content
      - Strict TypeScript — zero `any` types
      - Responsive: mobile-first, per `.dev-squad/design/responsive-spec.md` wireframes (375 / 768 / 1280 minimum)
      - Core Web Vitals: LCP < 2.5s, FID < 100ms, CLS < 0.1
      - Code splitting with React.lazy + Suspense
      - Design tokens from `.dev-squad/design/design-tokens.md` — NO inline arbitrary values, NO inline styles
      - Motion wired per design-tokens motion section, with `prefers-reduced-motion` fallback
      - Icons: SVG only (lucide-react / heroicons / custom) — emoji-as-icon is P0 violation
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

    **Lane 2: qa-engineer (runtime execution — Phase 5.5 FUNCTIONAL VERIFICATION + Visual Gate)**:
      - Boot backend + frontend
      - Drive every PRD acceptance criterion via playwright (golden path)
      - Audit every interactive element (button without onClick = P1, form to nonexistent endpoint = P0)
      - Smoke-test every API endpoint: valid + invalid + malformed + oversized + missing auth + expired token
      - Browser console + network gate (any error/warning = finding)
      - Cross-boundary integration check (frontend → API → DB → response round-trip)
      - **Visual Gate (anti-AI-slop)**: emoji-as-icon regex scan, inline arbitrary value scan, responsive presence check (3 breakpoints via playwright), motion presence check, default shadcn palette check, anti-pattern list scan from designer's `visual-spec.md`
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
    - **If SaaS mode active: BLOCKING readiness gate** (saas-readiness Section 1 + Section 8)
      - Dispatch reviewer + auditor + architect in parallel to produce 3 readiness reports:
        - `docs/saas-readiness-security.md` (reviewer)
        - `docs/saas-readiness-operational.md` (auditor)
        - `docs/saas-readiness-business.md` (architect)
      - Architect synthesizes `docs/saas-readiness-master-report.md` per saas-readiness Section 8.3 template
      - **BLOCK Phase 6 if combined P0 count > 0.** User can override with explicit "ship with documented exception" — log to `.dev-squad/ship-exceptions.md` with sign-off + remediation deadline
      - **If 10+ P0+P1 items across 4+ domains:** invoke `/dev-squad readiness` workflow (6-A→6-H sub-phase decomposition per saas-readiness Section 9) instead of 3-day sprint. Coordinator orchestrates 8 sub-phases parallelizable when independent.
      - P1 items captured as Day 1-3 pre-launch hardening sprint OR sub-phase plan (in master report)
      - P2 items appended to `docs/next-iteration.md`
    - Dispatch devops for staging deployment:
      - [ ] docker compose up succeeds
      - [ ] All health checks passing
      - [ ] Monitoring dashboards showing data
      - [ ] Alerting rules firing correctly (test with synthetic error)
      - [ ] Resource limits not exceeded
      - [ ] TLS configured
      - [ ] Secrets injected via env (not in image/compose)
      - [ ] Rollback procedure documented
      - [ ] **If SaaS: backup automation verified (pg_dump cron + S3 + restore drill done)** — saas-readiness Section 2
      - [ ] **If SaaS: CI/CD pipeline blocking PRs on tsc/test/lint** — saas-readiness Section 3
      - [ ] **If SaaS: status page exists (even static)** — saas-readiness Section 6
    - Dispatch git-ops for PR creation with full description
    - Dispatch reviewer for final sign-off
    - **Pre-seed self-documenting context for future Claude sessions** (mandatory): writer + architect collaborate to produce in user's project root:
      - `CLAUDE.md` — START with **12-rule base template** (verbatim from `docs/templates/claude-md-base.md` in dev-squad plugin) covering: think before coding, simplicity, surgical changes, goal-driven execution, model-for-judgment-only, token budgets, surface conflicts, read before write, tests verify intent, checkpoint, match conventions, fail loud. THEN append project-specific: overview (1 paragraph), tech stack, how-to-run, where things live, references to `.claude/` detail docs. Auto-loaded by Claude Code at session start. **Do NOT modify the 12 rules** — only append project-specific BELOW.
      - `.claude/architecture.md` — entities + relationships, key modules + responsibilities, data flow, auth flow (with mermaid). Sourced from architect's Phase 2 design doc.
      - `.claude/conventions.md` — naming, file organization, error handling, validation, testing, commit format. Sourced from reviewer's Phase 5 notes + ADRs.
      - `.claude/gotchas.md` — known issues, footguns, things to be careful about. Sourced from `.dev-squad/gotchas.md` (filter to project-relevant only — drop dev-squad-internal entries).
      - **Why this matters:** every future Claude session on this project loads `CLAUDE.md` automatically and discovers detail docs in `.claude/`. No re-discovery, no re-reading source from scratch. Compound productivity gain.
      - Keep each doc tight (under 200 LOC). They're context, not exhaustive reference — link to source code for details.
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
    - Update project `CLAUDE.md` with conventions discovered during this build (e.g., "always use cursor pagination", "auth flow uses httpOnly cookies"). **Preserve the 12 rules at top of CLAUDE.md unchanged** — append new conventions as a "Project Conventions Discovered During Build" section BELOW. Do NOT inline conventions inside the 12 rules.
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
       (Auto mode: SKIP this checkpoint — the Phase 1 scored evaluator (Phase 1 PRD rubric, sonnet) approves the PRD; log "PRD auto-approved by Phase 1 gate" to the assumption ledger.)

    ## Your Team (MUST use fully-qualified names when dispatching)
    
    CRITICAL: Always use "dev-squad:{name}" as subagent_type. Plain names will NOT work.
    
    | Agent | subagent_type | Model | Role |
    |-------|--------------|-------|------|
    | Architect | `dev-squad:architect` | opus | System design, tech stack, ADRs |
    | Designer | `dev-squad:designer` | sonnet (think_harder) | Phase 3.5 design tokens + visual spec + component inventory + responsive spec; anti-AI-slop authority |
    | Backend | `dev-squad:backend` | sonnet (opus for auth/integration) | API + DB + business logic |
    | Frontend | `dev-squad:frontend` | sonnet (opus for cross-package) | UI implementation per designer's spec — translates design artifacts to code |
    | Reviewer | `dev-squad:reviewer` | sonnet (opus for security review) | Security lead + static code review (5 passes incl. design compliance) + Phase 5 metrics report synthesis |
    | QA Engineer | `dev-squad:qa-engineer` | sonnet | Runtime functional verification (Phase 5.5) + Visual Gate anti-AI-slop + Investigation Mode (fresh-eyes debug at iter 3) |
    | Auditor | `dev-squad:auditor` | sonnet | Stability execution (Phase 5.6) + code quality metrics (Phase 5.7), multi-language |
    | DevOps | `dev-squad:devops` | sonnet | Docker, CI/CD, monitoring, deploy |
    | Git-Ops | `dev-squad:git-ops` | sonnet | Branches, PRs, releases |
    | Writer | `dev-squad:writer` | sonnet | Page copy, microcopy, legal pages |

    ## Smart Model Routing
    Override model per-dispatch based on task complexity:
    - opus: auth flows, cross-package wiring, security review, self-healing fixes, integration tasks
    - sonnet: single endpoint CRUD, isolated component, migration, scaffold, git operations
    - haiku: structural/generic scored gate (Phase 2, 3, 4 deliverable checks) + spec compliance checks; sonnet: Phase 1 PRD + Phase 3.5 Design scored gates (judgment-heavy rubrics)
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
        "ui_design": "pending",
        "implement": "pending",
        "review": "pending",
        "ship": "pending",
        "learn": "pending"
      }
    }
    ```
    Update each phase status to "in_progress" when starting and "complete" when done.

    **If `--auto` was passed** (present in the build description / user request): also write `"mode": "auto"` and an `"auto"` object into this JSON — copy the `auto_defaults` block from `.claude-plugin/workflows/zero-to-ship.json` and add `"started_at": "<current UTC ISO timestamp>"`. Example:
    `"mode":"auto","auto":{"started_at":"2026-05-25T10:00:00Z","wall_clock_cap_min":480,"max_total_dispatches":300,"max_iterations_per_phase":5,"on_floor_miss":"fail_loud"}`
    Without `--auto`, omit these fields (interactive default — all auto hooks no-op).

    ## Instructions
    1. Create the workflow tracking file
    2. Execute Phase 0 ULTRAPLAN first — think deeply, write master-plan.md
    3. Execute Phases 1-7 in order (Phase 7 LEARN is mandatory — PDCA Act)
    4. Only pause for user input at Phase 1 CHECKPOINT
       In `--auto` mode there are ZERO user checkpoints; all decisions are inferred and recorded in `.dev-squad/assumption-ledger.md`.
    5. Use Skills and MCP tools autonomously throughout
    6. Report final completion with summary of everything built
```
