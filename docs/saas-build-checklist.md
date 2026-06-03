# SaaS Build Checklist — Canonical Reference

**Purpose:** single end-to-end checklist for users invoking `/dev-squad build` with SaaS scope. Maps every required item to: (1) which dev-squad phase covers it, (2) which agent owns it, (3) which skill section has the pattern.

**Use this doc:**
- **Before starting:** evaluate scope — is your project actually SaaS-class? See "What is SaaS-class?" below
- **During Phase 0 ULTRAPLAN:** coordinator references this to detect SaaS mode + lock decisions in master-plan.md
- **During Phase 6 SHIP:** readiness gate runs every item in "Pre-Launch Readiness" section
- **For pre-existing SaaS extension:** invoke `/dev-squad readiness` workflow which audits against this checklist

**Skill references:**
- `dev-squad:saas-patterns` — architectural code-write patterns (Part 1 backend + Part 2 frontend admin/drill-down)
- `dev-squad:saas-readiness` — pre-launch readiness + sprint execution + product-surface audit + provider abstraction + regional + case studies
- `dev-squad:postgres-patterns`, `dev-squad:backend-patterns`, `dev-squad:frontend-patterns`, `dev-squad:security-review` — pattern depth references

---

## What is "SaaS-class"?

A project is SaaS-class if it has **all 4** of these properties. If only 1-2 apply, you might be building a multi-user web app — not a SaaS. Don't take on SaaS-class operational/compliance discipline if you don't need it.

| Property | Description | If missing... |
|---|---|---|
| **Multi-tenancy** | Multiple customer organizations share infrastructure with isolated data | It's a single-tenant app — different deployment model |
| **Subscription billing** | Recurring revenue with plans, trials, dunning | It's one-time purchase or freeware |
| **Plan-based access** | Different feature/quota access per plan tier | It's a single-feature-set app |
| **Self-service onboarding** | New customers sign up + provision tenant + start using without manual setup | It's enterprise-managed software |

Plus typically:
- Customer success lifecycle (welcome → activation → trial → conversion → retention)
- Operational discipline (uptime SLAs, backups, monitoring, incident response)
- Compliance posture (regional regulations applicable to customer data)

If your project meets all 4 + most of "typically" — proceed with this checklist.

---

## Phase Map (where each item gets covered)

| Phase | Owner | dev-squad reference | Checklist sections (this doc) |
|---|---|---|---|
| **0 ULTRAPLAN** | Coordinator | `commands/build.md` Phase 0 + Step 2.5 | "Phase 0 — SaaS Mode Detection" + "Architectural Decisions" |
| **1 DISCOVER** | Architect | `agents/architect.md` | "Phase 1 — PRD with SaaS Specifics" |
| **2 DESIGN** | Architect (+ Reviewer threat model) | ADR-001..006 + saas-patterns Part 1 design | "Phase 2 — ADRs + Architectural Foundations" |
| **3 SCAFFOLD** | DevOps + Git-Ops | saas-patterns Part 1 module list | "Phase 3 — Backend Module Scaffold" |
| **3.5 DESIGN UI/UX** | Designer | saas-patterns Part 2 | "Phase 3.5 — Design Tokens + Drill-Down Spec" |
| **4 IMPLEMENT** | Backend + Frontend + Writer | saas-patterns Parts 1+2 | "Phase 4 — Implementation Per Module" |
| **5 REVIEW** | Reviewer + QA + Auditor | 3-way parallel | "Phase 5 — 3-Way Review" |
| **6 SHIP** | DevOps + Git-Ops + readiness gate | saas-readiness Sections 1-8 + Part 3 | "Phase 6 — Pre-Launch Readiness Gate" + "Product-Surface 10 Domains" |
| **7 LEARN** | Reviewer + Coordinator | retrospective | "Phase 7 — Retrospective + Playbook" |

If any item is unclear about which phase covers it, default to Phase 0 (architect documents in master-plan).

---

## Phase 0 — SaaS Mode Detection + Intake (BETA)

Two-step process: detection + intake. Both run during ULTRAPLAN, locked in `.dev-squad/master-plan.md`.

### Step 2.5: SaaS Mode Detection (default-deny per v4.14.4)

- [ ] Auto-detect: keywords "subscription", "tenant", "billing", "plans", "multi-tenant", "team workspace", "billing/Stripe", "usage-based", "admin panel", "drill down", "analytics dashboard", "white-label" — **3+ matches** (raised from 2+ to reduce false-positives) OR explicit `--saas` flag
- [ ] If fewer than 3 keywords AND no `--saas` flag: skip confirmation, lock `SaaS Mode: disabled (standard app)`, proceed
- [ ] User confirmation via AskUserQuestion — **"No, build a standard app" is recommended default** (first option). User must actively choose "Yes, full SaaS scope" or "Yes, but skip admin dashboard"
- [ ] Dismiss/cancel = DEFAULT to disabled (never silent-enable)
- [ ] Decision locked in master-plan.md `## SaaS Mode` section with explicit value (`enabled` / `disabled`)

### Step 2.5b: SaaS Scope Intake (v4.15.0 — NEW, BETA)

If SaaS Mode locked enabled, run **3 AskUserQuestion blocks (10 questions total)** capturing scope dimensions. Each answer is written to master-plan.md `## SaaS Intake` section and read by architect / backend / frontend / devops / writer at their phases.

**Block 1 — Foundation (4Q):**
- [ ] Q1 Target Market — Indonesia (IDR+Faktur Pajak+Xendit+PDP) / EU (EUR+VAT+Stripe+GDPR+AI Act+DORA) / US (USD+Stripe Tax+CCPA+SOC 2) / Multi-region (provider abstraction)
- [ ] Q2 Admin Hierarchy — 3-tier (Platform+Tenant+User+impersonation+audit log split) / Tenant-only (no platform layer)
- [ ] Q3 Per-Tenant Role Model — Owner-only / Owner+Member / Owner+Admin+Editor+Viewer / Custom RBAC
- [ ] Q4 Trial + Plan — no trial / freemium / time-limited trial / freemium + trial-of-higher

**Block 2 — Customer-facing (4Q):**
- [ ] Q5 Self-Service Auth Flows (multi) — password-reset / password-change / email-change / account-deletion / 2FA / lockout
- [ ] Q6 Customer-Facing API — None / API-keys / +webhooks / +OpenAPI
- [ ] Q7 Email Lifecycle (multi) — verify / welcome / trial-warn / trial-expired / payment-failed-dunning / re-engagement / win-back
- [ ] Q8 Invoice Surface — Stripe-portal / in-app+PDF / +resend-notes

**Block 3 — Ops + Compliance (2Q):**
- [ ] Q9 Operational Readiness (multi) — backup-cron / CI-CD-gate / Sentry / status-page / PII-redact / rate-limit
- [ ] Q10 Compliance Jurisdiction (multi) — GDPR / PDP UU 27 / CCPA / LGPD / SOC2 Type1 / EU AI Act / none

Cancellation handling: any block cancelled mid-way → remaining dimensions marked `UNANSWERED — REQUIRE Phase 1 clarification`. Architect's Phase 1 brainstorming must close them before PRD generation.

**Once locked, do not retrofit.** Multi-tenancy retrofit = cross-tenant data leak risk. Identity hierarchy retrofit = full re-scaffold. Payment provider retrofit = full billing replatform.

**BETA notice:** SaaS Intake is functional but not exhaustive. Phase 5+ readiness audit may still surface edge-case gaps. Treat intake as foundation, not guarantee. Empirical baseline: tested on wacrm CRM migration.

---

## Phase 1 — PRD with SaaS Specifics

Architect's PRD MUST answer (in addition to standard PRD questions):

- [ ] Target market region(s) — drives compliance scope (Section 22 saas-readiness) + payment provider choice (Section 21 provider abstraction)
- [ ] B2B / B2C / Hybrid — drives tax invoicing + onboarding flows + SOC 2 readiness expectation
- [ ] Plan tiers — names, monthly/annual pricing, feature gates, seat limits
- [ ] Trial policy — duration, opt-in/out, downgrade behavior
- [ ] Usage metering — what to track for billing/quota (saas-patterns Section 11)
- [ ] Compliance scope — GDPR / PDP / CCPA / LGPD / AI Act / CRA / DORA / sectoral (HIPAA, PCI-DSS)
- [ ] Goals & Success Criteria — numeric: LTV/CAC > 3:1, payback < 12 months, target ARR

---

## Phase 2 — ADRs + Architectural Foundations

Architect MUST produce **ADR-001 to ADR-006** in `docs/adr/` BEFORE backend codes (retrofit = data leak risk). Each ADR informed by Phase 0 Step 2.5b Intake answers:

- [ ] **ADR-001 Tenancy strategy** — shared DB+RLS / schema-per-tenant / DB-per-tenant / hybrid (saas-patterns §1.1). Informed by: project scale + Q1 target market data residency requirements.
- [ ] **ADR-002 Billing model** — per-seat / per-usage / hybrid; **provider choice**. Informed by: Q1 target market (Indonesia → Xendit + manual; EU/US → Stripe; Multi-region → provider abstraction). Q4 trial+plan model. (saas-patterns §2 + saas-readiness §21 if multi-region)
- [ ] **ADR-003 Plan structure** — tiers, free trial, entitlement keys, grandfathering policy. Informed by: Q4 trial+plan model.
- [ ] **ADR-004 Admin scope** — root-tenant API key vs dedicated `admin_users` table vs PlatformRole enum. Informed by: Q2 admin hierarchy answer.
- [ ] **ADR-005 Compliance scope** — which regulations apply (drives saas-readiness §4 obligations). Informed by: Q10 compliance jurisdiction multiselect.
- [ ] **ADR-006 Identity Hierarchy** (NEW v4.15.0) — 3-tier Platform/Tenant/User-in-tenant model: PlatformRole enum design, per-tenant role enum (Q3), impersonation flow design, audit log split (PlatformAuditLog vs TenantAuditLog). Informed by: Q2 + Q3. **Mandatory if Q2 = 3-tier.** If Q2 = Tenant-only, ADR-006 documents the simpler 2-tier model.
- [ ] **ADR-007+ Provider abstraction** (conditional, if multi-region or multi-provider) — `PaymentProvider` interface + registry pattern (saas-readiness §21). Renumbered from ADR-006 in v4.15.0 to make room for ADR-006 Identity Hierarchy.

Threat model (`docs/threat-model.md`) parallel from reviewer.

C4 architecture diagrams (mermaid via `mermaid-mcp`).

API contracts (OpenAPI spec, `/api/v1/` versioning from day 1).

---

## Phase 3 — Backend Module Scaffold

DevOps scaffolds these modules (when SaaS mode active) per saas-patterns Part 1:

```
apps/backend/src/
├── auth/                       # JWT + refresh + RBAC + 2FA + lockout (Section 1, Section 4)
├── tenants/                    # tenant model, memberships, invitations (Section 1)
├── plans/                      # plan catalog (DATA-driven, not enum) (Section 2)
├── billing/                    # provider abstraction (Section 2 + saas-readiness Section 21)
│   ├── payment-provider.interface.ts
│   ├── payment-provider-registry.ts
│   └── {stripe|xendit|paypal|manual}/   # per-provider impl
├── webhooks/                   # outbound: signed delivery + retry + DLQ (Section 5)
├── api-keys/                   # SHA-256 hashed, preview-only, scoped (Section 4)
├── audit-log/                  # tenant-level + platform-level (Section 6)
├── notifications/              # in-app messages (Section 7)
├── email/                      # transactional + lifecycle templates (Section 8)
├── compliance/                 # data export + erasure (saas-readiness Section 4)
├── usage-events/               # metering for billing/quota (Section 11)
├── config-store/               # runtime config / feature flags (Section 12)
├── sso/                        # multi-IdP (Section 13)
├── branding/                   # white-label per tenant (Section 14)
└── admin/                      # platform-admin endpoints (Section 10 + Section 15)
```

Plus monorepo standard:
- [ ] `apps/backend/` + `apps/frontend/` (or `apps/api/` + `apps/web/`)
- [ ] `packages/shared-types/` + `packages/shared-validators/` + `packages/shared-config/` — **prevents type duplication between backend + frontend**
- [ ] `infra/docker-compose.yml` with all services + health checks + resource limits
- [ ] `Dockerfile` per app (multi-stage, non-root, pinned versions, health check)
- [ ] `.env.template` (no real secrets)
- [ ] `Makefile` (dev / test / build / lint / migrate / seed)

---

## Phase 3.5 — Design Tokens + Drill-Down Spec

Designer produces 4 BLOCKING artifacts in `.dev-squad/design/` BEFORE frontend codes UI:

- [ ] `design-tokens.md` — concrete color palette / typography / spacing / motion / shadow / radius (no TBD)
- [ ] `visual-spec.md` — ≥3 reference URLs + screenshots, brand vibe, project-specific anti-pattern list
- [ ] `component-inventory.md` — every component × variants × states (loading/error/empty/focus)
- [ ] `responsive-spec.md` — mermaid wireframes per page × mobile/tablet/desktop

If SaaS + admin/analytics dashboard:
- [ ] `drill-down-spec.md` — drill hierarchy (mermaid) + per-level spec (KPI cards / time-series / segment table / entity detail / event detail) + filter model + anti-patterns (saas-patterns Part 2 §26 template)

---

## Phase 4 — Implementation Per Module

### Backend (saas-patterns Part 1)

Per architecture Section reference. Common items:

- [ ] **Multi-tenancy isolation** — every query has `tenant_id` filter OR Postgres RLS. Cross-tenant isolation test suite mandatory (Section 1.5)
- [ ] **Auth flow** — signup with email verify, JWT + refresh rotation, password reset, account lockout after 5 failed logins (15 min)
- [ ] **Plan-gate middleware** — block over-quota new resources; check entitlement keys (Section 3)
- [ ] **API key management** — SHA-256 hashed, full key shown once at creation, scope-based authorization, revocation (Section 4)
- [ ] **Outbound webhooks** — HMAC-SHA256 signed delivery + 8-attempt retry (1m/5m/15m/1h/4h/12h/24h) + DLQ + auto-disable after 3 DLQ in 24h (Section 5)
- [ ] **Audit log** — separate from system log, immutable, hot/cold tier, PII redacted (Section 6)
- [ ] **Notifications** — multi-channel delivery (realtime + email + push), per-user preferences (Section 7)
- [ ] **Transactional email** — verify, reset, invite, billing receipts via provider abstraction (Section 8)
- [ ] **Hybrid validation** — app-level (Zod / struct tags) + DB-level CHECK constraints / JSON Schema (Section 9)
- [ ] **Admin scope** — separate `/admin/api/v1/*` namespace; root-tenant API key OR dedicated admin_users (Section 10)
- [ ] **Usage events** — append-only event table; hourly aggregation for billing (Section 11)
- [ ] **Runtime config** — per-user > per-tenant > global resolution; cached with pub/sub invalidation (Section 12)
- [ ] **SSO multi-IdP** (P2 if not enterprise tier) — domain-routed login + enforcement flag (Section 13)
- [ ] **Branding per tenant** (P2) — logo + color + custom CSS (sandboxed) + custom domain (Section 14)

### Frontend (saas-patterns Part 2 — admin dashboard with drill-down)

If admin/analytics dashboard:
- [ ] URL state architecture — Zod-typed search params, deep-linkable filters (§17)
- [ ] Breadcrumb with state preservation — every breadcrumb link carries relevant filters (§18)
- [ ] Time-series with brush+zoom — date range driven, debounced URL update (§19)
- [ ] Virtualized tables — TanStack Virtual + cursor-based infinite scroll for 10k+ rows (§20)
- [ ] Cross-filter coordination — Zustand store + URL bridge (§21)
- [ ] Per-level empty/loading/error states — skeleton matching layout, action-driven empty, class-specific error (§22)
- [ ] Permission-aware drill items — `PermissionGate` hides or shows locked state (§23)
- [ ] Real-time updates (polling / SSE / WebSocket) — with "last updated" indicator (§24)
- [ ] Performance — bundle splitting per drill level, Suspense boundaries, optimistic UI (§25)

### Content (writer)

- [ ] All page copy (homepage, about, pricing, features, contact)
- [ ] Legal pages (privacy policy, ToS, cookie policy, DPA template)
- [ ] Microcopy (buttons, errors, empty states, tooltips, placeholder, confirmation dialogs, 404)
- [ ] SEO metadata per page (title, description, og:tags, JSON-LD)
- [ ] Email lifecycle templates (saas-readiness Section 5 — verify / welcome / activation / trial-warn / trial-expired / drip / win-back)

---

## Phase 5 — 3-Way Review

3 lanes parallel (coordinator dispatches):

### Reviewer (static)
- [ ] OWASP Top 10 audit
- [ ] Auth flow review (JWT + refresh + RBAC + 2FA + lockout)
- [ ] CVE scan (`npm audit` / `govulncheck` + WebSearch GitHub Security Advisories)
- [ ] Threat model + secrets scan
- [ ] Phase 5 Metrics Report synthesis

### QA-Engineer (runtime — Phase 5.5)
- [ ] Boot app (backend + frontend), wait for `/health` + `/ready`
- [ ] Drive golden path (signup → onboard → first key action) via `playwright`
- [ ] Audit every interactive element (buttons must have onClick, forms must POST to real endpoints)
- [ ] Smoke-test every API endpoint (valid + invalid + missing-auth + malformed)
- [ ] Browser console gate (any uncaught error / hydration mismatch / key warning = finding)
- [ ] Visual Gate runtime check (anti-AI-slop) per designer's anti-pattern list

### Auditor (automated — Phase 5.6 + 5.7)
- [ ] Config drift detection (env var diff, docker compose validate, /health response, CORS/TLS sanity)
- [ ] DB stability (connection pool, slow queries, index coverage, migration safety, idle-in-transaction)
- [ ] Endpoint hammering (500 leak detection, info disclosure on stack traces)
- [ ] Failure injection (with `.dev-squad/staging-env` hard guard)
- [ ] API pattern compliance (REST: pagination + idempotency + versioning + Retry-After; or GraphQL/gRPC equivalents)
- [ ] Code quality metrics (cyclomatic, duplication, dead code, type-escape, file/function size)

### Coordinator
- [ ] Iteration loop: while findings_p0_or_p1 AND iter ≤ 5: dispatch fix → verify → if regression, git restore + retry
- [ ] If iter > 5 unresolved: escalate to user with blast radius assessment

---

## Phase 6 — Pre-Launch Readiness Gate

If SaaS mode active, BLOCKING readiness gate (saas-readiness Section 1 + 8). Reviewer + Auditor + Architect dispatch parallel for 3 readiness reports → architect synthesizes `docs/saas-readiness-master-report.md`.

### P0 — Ship-blockers (cannot launch with even 1 customer)

**Security:**
- [ ] Password reset end-to-end (UI + API + DB model + email)
- [ ] Per-account lockout after N failed logins
- [ ] No `LOG_LEVEL=debug` default in production (PII leak via Prisma query logs)
- [ ] All payment webhook receivers verify signatures
- [ ] Multi-tenant isolation runtime test passes
- [ ] No hardcoded secrets in repo / images / compose
- [ ] HSTS + CSP strict + helmet wired
- [ ] **OAuth 2.1 with PKCE** (no static client secrets) — 2026 baseline

**Operational:**
- [ ] DB backup automation (cron + S3 + restore drill verified)
- [ ] CI/CD pipeline blocking PRs on tsc/test/lint
- [ ] `/health` + `/ready` endpoints respond 200
- [ ] Migrations run on container start (`prisma migrate deploy`)
- [ ] Status page exists (even static)

**Business:**
- [ ] Trial expiry enforcement cron
- [ ] Tax engine enabled (Stripe Tax / Xendit native / per-region custom)
- [ ] Welcome email sent after email verification
- [ ] Tax invoice / receipt generation works

### P1 — Launch-risks (fix before public marketing launch)

**Security:**
- [ ] Refresh token rotation endpoint
- [ ] CORS production guard
- [ ] GDPR/PDP data export + erasure endpoints
- [ ] Cookie consent banner (ePrivacy + PDP requirement)
- [ ] 2FA/TOTP for tenant admins
- [ ] Plan downgrade contact + seat enforcement

**Operational:**
- [ ] Pino redact PII paths
- [ ] Prometheus `/metrics` endpoint
- [ ] Sentry / error tracking (frontend + backend)
- [ ] Backup automation for ALL stateful services
- [ ] Payment provider placeholder rejection in staging

**Business:**
- [ ] Annual billing pricing tier (15-20% discount)
- [ ] Help center / docs site at advertised URL
- [ ] DB connection pool sized for expected workers
- [ ] Multi-region or DB failover plan
- [ ] Signup funnel + activation milestone tracking
- [ ] **LTV/CAC > 3:1 + payback < 12 months target** — sustainable growth metric (2026 industry standard)

### P2 — Post-launch backlog (acceptable to defer, track in `docs/next-iteration.md`)

- [ ] Drip cadence emails (30/60/90 dormancy)
- [ ] IP/domain warmup logic
- [ ] DMARC rua aggregation pipeline
- [ ] Email-to-ticket gateway
- [ ] Test coverage instrumentation
- [ ] BullMQ worker for queued operations

### Sprint decomposition trigger

If 10+ P0+P1 items across 4+ domains: invoke `/dev-squad readiness` workflow (saas-readiness-sprint.json) for 6-A→6-H decomposition instead of 3-day sprint.

### `.claude/` pre-seed (mandatory for generated apps)

Writer + Architect produce in user's project:
- [ ] `CLAUDE.md` — project root, auto-loaded. **STARTS with 12-rule base template** verbatim (see `docs/templates/claude-md-base.md` — think before coding / simplicity / surgical changes / goal-driven / model-for-judgment / token budgets / surface conflicts / read before write / tests verify intent / checkpoint / match conventions / fail loud). Project-specific sections (overview, tech stack, how-to-run, where things live) AFTER the 12 rules. Writer MUST NOT modify the 12 rules — append below only.
- [ ] `.claude/architecture.md` — entities, modules, flow, mermaid
- [ ] `.claude/conventions.md` — naming, error handling, testing, commits
- [ ] `.claude/gotchas.md` — known issues filtered from `.dev-squad/gotchas.md`

### Auto-reviewer wait

- [ ] PR creation followed by mandatory 180s wait for auto-reviewers (Gemini/Copilot/CodeRabbit)
- [ ] Address all unresolved review threads before merge

---

## Product-Surface 10 Domains (Completeness Audit)

Architectural readiness ≠ product completeness. SaaS buyers expect features per these 10 domains. Use during readiness audit (saas-readiness Part 3 has full matrix).

| Domain | Core | P0 | P1 | P2 (Enterprise) |
|---|---|---|---|---|
| **A. User Mgmt** | invite/role/remove + plan-gate seats | self-service profile/password/email/account-deletion + lockout + per-record audit | 2FA, bulk import, force logout, last-sign-in | SSO (SAML/OIDC), SCIM, custom roles, **JIT provisioning** |
| **B. Plan Mgmt** | tiers, comparison, upgrade flow, customer portal | trial enforcement, allow_promotion_codes | annual billing, downgrade enforcement, multi-currency, plan history | custom enterprise pricing, grandfathering, overage billing, add-ons |
| **C. Payment** | webhook sig verify, dunning, refund | tax engine | regional providers, manual bank transfer + admin verify, QRIS/VA/e-wallet | embedded payment widget |
| **D. Invoicing** | provider invoice, B2C receipt | Faktur Pajak / VAT, NPWP/VAT capture | localized format, multi-currency, S3 storage | refund invoice / credit memo, bank-stamped proof attachment |
| **E. API + Integrations** | API versioning | — | OpenAPI spec, customer API keys, customer webhooks, rate limit per tenant, docs site | Zapier / Make / n8n, webhook replay |
| **F. Customization / White-label** | — | — | logo, color, sigil, favicon | custom domain, custom CSS sandboxed, email-from custom, custom email templates |
| **G. Notifications + Comms** | in-app | — | per-user preferences, status updates from us, announcements | push notifications, scheduled maintenance notice |
| **H. Customer Analytics** | per-tenant dashboard | — | export CSV, comparison vs prev period, per-user activity, audit export | scheduled reports, custom report builder, KPI tracking |
| **I. Workspace / Sub-tenancy** | single workspace per org | — | — | multi-workspace, workspace permissions, workspace-level billing |
| **J. Compliance / Legal** | privacy, ToS | cookie consent (regional), data export (regional), data erasure (regional), CRA vulnerability reporting (if has installable component) | DPA, sub-processors page, breach notification SLA, AI Act conformity (if AI features) | SOC 2 Type 1 → Type 2, PCI DSS, data residency, **CRA full compliance Dec 11 2027** |

---

## 2026 Compliance Updates (NEW)

Recent regulations every SaaS must consider:

### EU AI Act (Aug 2026 enforceable)
- **Extraterritorial reach** — applies to US/global SaaS with EU customers, similar to GDPR
- Penalties up to **7% of global annual turnover**
- If your SaaS uses AI (LLM, recommendation engine, content moderation, etc.): conformity assessment required
- Even AI-free SaaS may need disclosures if processing EU customer data

### EU CRA (Cyber Resilience Act)
- **Vulnerability reporting to ENISA starts Sep 11 2026**
- **Full compliance Dec 11 2027**
- Penalties up to **€15M or 2.5% global turnover**
- **Pure SaaS exempt** — but most SaaS includes browser extensions / desktop apps / mobile apps / agent software / SDKs / CLI tools, which ARE in scope
- Actions: documented vulnerability handling process + reporting channel; SBOM (Software Bill of Materials) for components

### DORA (Digital Operational Resilience Act)
- **Effective Jan 2026**
- Applies to financial institutions + their IT service providers (incl. SaaS) operating in EU
- Requires: incident reporting (severe ICT incident notification within hours), threat-led penetration testing, third-party risk management
- If your SaaS serves EU financial customers — verify DORA scope

### SOC 2 distinction
- **Type 1** = snapshot of security control design (faster — weeks)
- **Type 2** = proof you followed procedures over **3-12 months**
- Enterprise customers ($10k+/mo) typically require Type 2
- Path: Type 1 first (quick win) → Type 2 readiness over 6-12 months

### OAuth 2.1 with PKCE (baseline)
- Static client secrets **not acceptable in serious enterprise environment**
- PKCE (Proof Key for Code Exchange) mandatory baseline
- If your SaaS exposes API to customers' apps: OAuth 2.1 + PKCE auth flow

### Encryption baseline
- AES-256 encryption at rest
- TLS 1.2+ in transit (TLS 1.3 preferred)
- Older SSL protocols disabled completely

---

## Region-Specific Addendum

See saas-readiness Section 22 for full coverage.

### Indonesia (most-detailed in saas-readiness based on wacrm pivot)
- Faktur Pajak (e-Faktur PPN) — NPWP capture mandatory at B2B checkout, format compatible with Coretax (DJP)
- PPN 11% standard rate
- QRIS / Virtual Account / e-wallets / retail outlet (Indomaret/Alfamart for cash)
- **Manual bank transfer + admin verify** — first-class B2B preference, not fallback
- Provider: Xendit (purpose-built); Stripe doesn't fully operate
- KYC timeline: ~1-2 weeks for Xendit
- PDP (UU PDP): data subject rights similar to GDPR; some sectors require localization

### EU
- GDPR + ePrivacy + AI Act + CRA + DORA (region/sector-conditional)
- VAT invoice for B2B (reverse charge); VAT number capture at checkout
- Multi-language for some markets (DE/FR/IT/ES)
- Data residency: AWS eu-west-1 / GCP europe / Hetzner / OVH for EU-only customers

### US
- State sales tax based on customer address (Stripe Tax computes)
- CCPA / CPRA (California): right to know / delete / opt-out
- 1099-K for high-volume merchants
- PCI DSS scope: use Stripe / provider tokenization to STAY OUT of scope

### LATAM / India / China / Africa
- Pattern: regional payment provider abstraction (saas-readiness Section 21)
- LATAM: MercadoPago + PayU + Local Wire
- India: Razorpay + UPI + Bank transfer
- China: WeChat Pay + Alipay + Bank transfer
- Africa: Flutterwave + M-Pesa + bank

---

## Phase 7 — Retrospective + Playbook

After Phase 6 SHIP succeeded:

- [ ] `.dev-squad/retrospective.md` — what worked / what didn't / metric gaps
- [ ] `.dev-squad/playbook.md` — wins to apply by default in future builds
- [ ] `docs/next-iteration.md` — fix-it backlog (P2 items + nice-to-haves)
- [ ] CLAUDE.md updated with newly-standardized conventions
- [ ] Lessons written to agent-memory + episodic memory

---

## Sources & References

This checklist synthesizes:
- `dev-squad:saas-patterns` (architectural patterns)
- `dev-squad:saas-readiness` (operational + compliance + sprint discipline)
- WaCRM case study (Indonesia-first SaaS pivot, 2026)
- Industry standards (2026 sources):
  - [WorkOS — 10 enterprise features every B2B SaaS needs](https://workos.com/blog/enterprise-readiness-checklist-2026)
  - [Storylane — 2026 Checklist to Successfully Launch a SaaS Product](https://www.storylane.io/blog/how-to-launch-a-saas-product-checklist-included)
  - [Peiko — SaaS Security Checklist Before Launch (2026)](https://peiko.space/blog/article/saas-security-checklist-before-launch)
  - [TechExactly — Designing Multi-Tenant SaaS Applications in 2026](https://techexactly.com/blogs/multi-tenant-saas-applications)
  - [Voxturr — Go-to-Market Checklist for B2B SaaS 2026](https://voxturr.com/go-to-market-checklist-b2b-saas-2026/)
  - [Scytale — Ultimate SOC 2 Checklist for SaaS Companies](https://scytale.ai/resources/the-ultimate-soc-2-checklist-for-saas-companies/)
  - [Zylo — Essential SaaS Compliance Checklist for 2026](https://zylo.com/blog/saas-compliance-checklist)
  - [IOMETE — Data Sovereignty Compliance 2026 (DORA, AI Act)](https://iomete.com/resources/blog/data-sovereignty-compliance-2026-dora-ai-act)
  - [VinciWorks — 2026 Digital Compliance Playbook](https://vinciworks.com/blog/your-2026-digital-compliance-playbook-what-are-the-key-laws-affecting-cyber-security-and-data-protection/)
  - [European Cyber Resilience Act guide](https://www.european-cyber-resilience-act.com/)
  - [AI Act Compliance for SaaS Companies](https://aiacttools.com/blog/ai-act-saas-compliance/)

---

## How to use this doc with dev-squad

**For new SaaS build:** invoke `/dev-squad build "<description>"`. Coordinator at Phase 0 references this doc for SaaS-mode detection + Step 2.5b SaaS Intake (10-Q) + ADR-001..006 mandate (006 = identity hierarchy NEW v4.15.0). Phase 6 readiness gate runs every Phase 6 checklist item.

**For existing SaaS extension or hardening:** invoke `/dev-squad readiness`. Coordinator dispatches reviewer + auditor + architect parallel for 3 readiness reports against this checklist + product-surface 10-domain audit (saas-readiness Part 3).

**For self-audit (manual):** read this doc top-to-bottom. Categorize gaps as P0 (ship-blocker) / P1 (launch-risk) / P2 (post-launch).

**This doc is the canonical reference. saas-patterns + saas-readiness are deep references.** When in doubt, this doc tells you which Phase + which Section.
