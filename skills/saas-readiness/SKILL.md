---
name: saas-readiness
description: Pre-launch readiness + execution discipline for SaaS. Sibling to saas-patterns (architectural). 4 parts. PART 1 readiness checklist + operational discipline (P0/P1/P2 categorized, backup+DR, CI/CD requirements, compliance lifecycle GDPR/PDP/CCPA/LGPD with data export+erasure+cookie+DPA, customer onboarding email lifecycle welcome→activation→trial-warn→drip, status page+incident, payment compliance Stripe Tax+tax invoice+annual+dunning, pre-existing project audit pattern). PART 2 sprint execution (6-A→6-H domain decomposition: billing/user-mgmt/invoicing/plan/api/compliance/operational/customer-success — domain-parallel sprint decomposition extracted from real-world wacrm pivot). PART 3 product-surface gap audit (10 domains A-J for completeness check beyond architecture: user-mgmt/plan/payment/invoicing/api+integrations/customization/notifications/customer-analytics/workspace/compliance). PART 4 real-world patterns (provider abstraction interface+registry+per-org, regional Indonesia+EU+US, re-platform graceful deprecation, wacrm case study). Load when SaaS readiness audit / pre-launch hardening / existing-project SaaS extension / Phase 6 SHIP gate — distinct from saas-patterns which loads during Phase 4 IMPLEMENT for code-write patterns.
---

# saas-readiness — Pre-Launch Readiness & Execution Discipline

## INSTRUCTIONS: When this skill is invoked

Load this skill when work is about **shipping a SaaS** — not building one. saas-patterns (sibling skill) covers WHAT to build (architectural patterns for code). saas-readiness covers HOW to ship it without P0 readiness blockers + HOW to harden existing SaaS toward launch.

**Distinct load contexts:**
- saas-patterns: load during Phase 4 IMPLEMENT (writing SaaS code)
- saas-readiness: load during Phase 5+ (audit), Phase 6 SHIP (readiness gate), pre-existing project extension

**Critical rule:** A multi-tenant SaaS with perfect tenancy isolation but no backup automation, no Stripe Tax, no GDPR data export, no welcome email — that's a launch-blocker. Or worse: a customer-trust failure mode within the first month. Patterns here are derived from real-world readiness audits of dev-squad-built SaaS apps.

This skill is in **4 parts**:
- **Part 1 (sections 1–8):** Pre-launch readiness checklist + operational discipline
- **Part 2 (sections 9–10):** Sprint execution (6-A → 6-H domain decomposition)
- **Part 3 (sections 11–20):** Product-surface gap audit (10 domains for completeness check beyond architecture)
- **Part 4 (sections 21–24):** Real-world patterns (provider abstraction, regional, re-platform, case study)

---

# Part 1: Pre-Launch Readiness Checklist + Operational Discipline

---

## 1. Pre-Launch Readiness Checklist

Before Phase 6 SHIP, verify every item below. Categorize remaining gaps as P0 (ship-blocker), P1 (launch-risk), P2 (post-launch backlog).

### 1.1 P0 — Ship-blockers (cannot launch with even 1 customer until resolved)

**Security:**
- [ ] Password reset flow exists end-to-end (UI + API + DB model + email)
- [ ] Per-account lockout after N failed logins (default: 5 → 15 min lock)
- [ ] No `LOG_LEVEL=debug` default in production (PII leak via Prisma query logs)
- [ ] All payment webhook receivers verify signatures (Stripe / PayPal / Xendit / etc.)
- [ ] Multi-tenant isolation runtime test passes (saas-patterns Section 1.5)
- [ ] No hardcoded secrets in repo / Docker images / compose files
- [ ] HSTS + CSP strict + helmet wired

**Operational:**
- [ ] Database backup automation (cron + S3 + restore drill verified) — Section 2
- [ ] CI/CD pipeline blocking PRs on tsc/test/lint — Section 3
- [ ] `/health` + `/ready` endpoints respond 200
- [ ] Migrations run on container start (`prisma migrate deploy`)
- [ ] Status page exists (even static) — Section 6

**Business:**
- [ ] Trial expiry enforcement cron — Section 5
- [ ] Tax engine enabled (Stripe Tax, Xendit native, or per-region custom) — Section 7
- [ ] Welcome email sent after email verification — Section 5
- [ ] Tax invoice / kwitansi generation works for completed payments — Section 7

### 1.2 P1 — Launch-risks (should fix before public marketing launch)

**Security:**
- [ ] Refresh token rotation endpoint
- [ ] CORS production guard (reject localhost when `NODE_ENV=production`)
- [ ] GDPR/PDP data export + erasure endpoints — Section 4
- [ ] Cookie consent banner (ePrivacy + PDP requirement)
- [ ] 2FA/TOTP for tenant admins
- [ ] Plan downgrade contact + seat enforcement (saas-patterns Section 3)

**Operational:**
- [ ] Pino redact PII paths (email, phone, address, SSN, JWT, etc.)
- [ ] Prometheus `/metrics` endpoint
- [ ] Sentry / error tracking (frontend + backend)
- [ ] Backup automation for ALL stateful services (Postgres + Redis + ClickHouse + ...)
- [ ] Payment provider placeholder rejection in staging (not just production)

**Business:**
- [ ] Annual billing pricing tier (15-20% discount vs monthly) — Section 7
- [ ] Help center / docs site exists at advertised URL
- [ ] Database connection pool sized for expected workers
- [ ] Multi-region or DB failover plan
- [ ] Signup funnel + activation milestone tracking

### 1.3 P2 — Post-launch backlog (acceptable to defer beyond launch but track)

- [ ] Drip cadence emails (re-engagement at 30/60/90 day dormancy) — Section 5
- [ ] IP/domain warmup logic (for transactional email senders)
- [ ] DMARC rua aggregation pipeline
- [ ] Email-to-ticket gateway for support
- [ ] Test coverage instrumentation (c8 / coverage thresholds in CI)
- [ ] Code quality tools install (jscpd, madge, ts-prune)
- [ ] BullMQ worker for queued operations (when sync hits scale)

### 1.4 Phase 6 SHIP gate

**Coordinator MUST run this checklist before approving Phase 6 SHIP.** Block if any P0 unresolved. Allow with explicit user override if P1 unresolved (with documented exception in `.dev-squad/ship-exceptions.md`). P2 always allowed (track in `docs/next-iteration.md`).

---

## 2. Backup & Disaster Recovery

Architecture without backup automation = ship-blocker. First DB corruption = total data loss.

### 2.1 Postgres backup

```yaml
# docker-compose.yml — add pg-backup service
services:
  pg-backup:
    image: prodrigestivill/postgres-backup-local:16
    restart: always
    volumes:
      - ./backups:/backups
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_EXTRA_OPTS: '-Z 9 --schema=public --blobs'
      SCHEDULE: '@daily'
      BACKUP_KEEP_DAYS: 7
      BACKUP_KEEP_WEEKS: 4
      BACKUP_KEEP_MONTHS: 12
    depends_on:
      - postgres
```

Plus S3 upload via sidecar or cron:

```bash
# scripts/backup-to-s3.sh
aws s3 cp backups/daily/$(ls -t backups/daily/ | head -1) \
  s3://my-app-backups/postgres/$(date +%Y%m%d)/
# Lifecycle policy on bucket: glacier after 30d, delete after 365d
```

### 2.2 Redis backup

For BullMQ queue state or sessions:

```yaml
redis:
  image: redis:7-alpine
  command: redis-server --save 60 1000 --appendonly yes
  volumes:
    - redis_data:/data
```

For ClickHouse / other stateful: each has its own backup pattern. Don't assume "Postgres backup covers everything".

### 2.3 Restore drill (mandatory quarterly)

**Backups you've never restored ARE NOT BACKUPS.**

```bash
# scripts/restore-drill.sh
docker run -d --name drill-db postgres:16
gunzip -c latest.sql.gz | docker exec -i drill-db psql -U postgres
docker exec drill-db psql -U postgres -c "
  SELECT count(*) FROM users;
  SELECT count(*) FROM organizations;
"
# Document drill in docs/ops-runbook.md with date + result
docker rm -f drill-db
```

Restore failure or row counts unexpected → P0 incident — investigate immediately.

---

## 3. CI/CD Pipeline Requirements for SaaS

Watchtower-style hot-deploys without test gates = broken builds reach prod silently.

### 3.1 Required gates per PR

```yaml
# .github/workflows/ci.yml
name: CI
on:
  pull_request:
    branches: [main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: 'pnpm' }
      - run: pnpm install --frozen-lockfile
      - name: Type check
        run: pnpm tsc --noEmit
      - name: Lint
        run: pnpm lint
      - name: Test
        run: pnpm test
      - name: Build
        run: pnpm build
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pnpm audit --audit-level=high
      - name: Secret scan
        uses: gitleaks/gitleaks-action@v2
```

### 3.2 Migration safety gate

Block PR merge if migration is unsafe:
- Adding NOT NULL column without default on table > 1M rows
- DROP COLUMN / DROP TABLE without staging verification
- CREATE INDEX without CONCURRENTLY on hot table
- ACCESS EXCLUSIVE locks during long transactions

Custom migration linter or manual review checklist enforced in CI.

### 3.3 Deploy gates

Production deploy ONLY on:
- Green CI on `main`
- Tagged release (semantic version)
- Migration deployed to staging first + verified
- Manual approval if changing breaking interfaces

Deploy script reads `prisma migrate status` to ensure DB is up-to-date before swapping containers.

---

## 4. Compliance Lifecycle (Data Subject Rights)

Multi-tenant SaaS handling user data must comply with regional law. Architect MUST decide ADR-005 (compliance scope) alongside ADR-001..004 (saas-patterns Bootstrap Context).

| Regulation | Region | Key obligations |
|---|---|---|
| **GDPR** | EU | Right to access, erasure, portability, rectification; cookie consent (ePrivacy); DPA contract with subprocessors |
| **PDP** (UU PDP) | Indonesia | Right to access, erasure, withdrawal of consent; data localization for some sectors |
| **CCPA / CPRA** | California | Right to know, delete, opt-out of sale; verifiable consumer requests |
| **LGPD** | Brazil | Similar to GDPR — access, erasure, portability |

### 4.1 Data export endpoint (Right to access)

```typescript
// apps/api/src/modules/compliance/exportData.ts
export async function exportUserData(userId: string): Promise<Buffer> {
  const user = await userRepo.findById(userId);
  const data = {
    user: omit(user, ['passwordHash', 'refreshTokenHash']),
    organizations: await orgRepo.findByUser(userId),
    contacts: await contactRepo.findByUser(userId),
    auditTrail: await auditRepo.findByUser(userId),
    apiKeys: (await apiKeyRepo.findByUser(userId)).map(k => ({ ...k, keyHash: undefined })),
  };
  return Buffer.from(JSON.stringify(data, null, 2));
}

router.post('/api/v1/me/data-export', authenticate, async (req, res) => {
  await emailQueue.enqueue('data-export', { userId: req.user.id });
  res.status(202).json({ status: 'queued', notify_via: 'email' });
});
```

Format: machine-readable (JSON or NDJSON). Time bound: deliver within 30 days (GDPR requirement).

### 4.2 Data erasure endpoint (Right to be forgotten)

```typescript
export async function eraseUser(userId: string): Promise<void> {
  await userRepo.update(userId, {
    email: `erased-${userId}@deleted.local`,
    name: '[ERASED]',
    phone: null,
    avatarUrl: null,
    passwordHash: null,
    erasedAt: new Date(),
  });
  await auditRepo.anonymizeUser(userId);
  await apiKeyRepo.revokeAll(userId);
  await refreshTokenRepo.deleteAll(userId);
}
```

**Critical:** retain financial records (invoices, transactions) for legally-mandated period (7 years US/EU). Anonymize PII in them, keep the record. Document in privacy policy.

### 4.3 Cookie consent banner

```tsx
// apps/web/src/components/CookieConsent.tsx
'use client';
export function CookieConsent() {
  const [shown, setShown] = useState(true);
  useEffect(() => setShown(!localStorage.getItem('cookie-consent')), []);
  if (!shown) return null;
  return (
    <div className="fixed bottom-0 inset-x-0 bg-background border-t p-4 flex items-center gap-4">
      <p className="text-sm">We use essential cookies. Analytics with consent. <Link href="/privacy">Privacy</Link>.</p>
      <Button onClick={() => { localStorage.setItem('cookie-consent', 'all'); setShown(false); }}>Accept all</Button>
      <Button variant="outline" onClick={() => { localStorage.setItem('cookie-consent', 'essential'); setShown(false); }}>Essential only</Button>
    </div>
  );
}
```

Don't load analytics scripts until consent is "all". For "essential only", limit to auth + CSRF cookies.

### 4.4 DPA (Data Processing Agreement)

When processing B2B customer data, customers can ask for a DPA. Template at `docs/legal/data-processing-agreement.md` covering: subprocessors list, data locations, security measures, breach notification SLA, sub-processor change notice period.

---

## 5. Customer Onboarding Email Lifecycle

Welcome silence after signup = customer thinks app is broken. First impression = lifelong impression.

### 5.1 Standard email lifecycle for SaaS

```
Day 0  signup       → email-verify (immediate, transactional)
Day 0  verify       → welcome (immediate, friendly intro + 1 CTA)
Day 1-3            → onboarding tip 1 (only if user has NOT completed first key action)
Day 5-7            → activation milestone (sent ONLY when user reaches first value moment)
Day -3 to expiry   → trial-warning (3 days before trial ends, with upgrade CTA)
Day 0  expiry      → trial-expired (immediate, with grace + upgrade option)
Day 30 dormant     → re-engagement drip 1
Day 60 dormant     → re-engagement drip 2 (with offer)
Day 90 dormant     → win-back / cancel
```

### 5.2 Implementation pattern

```typescript
export async function onUserSignup(userId: string) {
  await emailQueue.enqueue('verify-email', { userId, delay: 0 });
}

export async function onEmailVerified(userId: string) {
  await emailQueue.enqueue('welcome', { userId, delay: 0 });
  await emailQueue.enqueue('check-activation', { userId, delay: 24 * 3600 * 1000 });
}

export async function checkActivationMilestone(userId: string) {
  const milestone = await activationRepo.find(userId);
  if (milestone?.firstKeyAction && !milestone?.activationEmailSent) {
    await emailQueue.enqueue('activation-milestone', { userId });
    await activationRepo.mark(userId, { activationEmailSent: true });
  }
}

// Daily cron:
export async function trialExpiryCheck() {
  const expiringSoon = await tenantRepo.findExpiringTrials({ within: '3d' });
  for (const tenant of expiringSoon) {
    if (!tenant.trialWarningSent) {
      await emailQueue.enqueue('trial-warning', { tenantId: tenant.id });
      await tenantRepo.markWarned(tenant.id);
    }
  }
  const expired = await tenantRepo.findExpiredTrials();
  for (const tenant of expired) {
    await tenantRepo.update(tenant.id, { planStatus: 'TRIAL_EXPIRED' });
    await emailQueue.enqueue('trial-expired', { tenantId: tenant.id });
  }
}
```

### 5.3 Anti-patterns

- Email verification but no welcome → customer assumes broken
- Trial expires silently → customer surprise + trust loss
- Generic re-engagement template → looks like spam
- Re-engagement drip without unsubscribe link → CAN-SPAM / GDPR violation
- Mixing transactional (verify, reset) and marketing (drip) on same domain → deliverability tanks

---

## 6. Status Page & Incident Communication

When app is down, customers blame YOU regardless of cause. Public status page = first line of defense.

### 6.1 Tooling options

| Tool | Pros | Cons | Cost |
|---|---|---|---|
| BetterStack | Polished, good SLA tracking | Subscription | $29+/mo |
| Atlassian Statuspage | Industry standard | Pricier | $79+/mo |
| Cachet (self-host) | Free, full control | Operational overhead | Free + hosting |
| Static page | Pre-launch placeholder | No real-time | Free |

Pre-launch: even a static "All systems operational" page on `status.yourapp.com` is better than nothing.

### 6.2 Incident severity classification

| Sev | Definition | Response |
|---|---|---|
| **Sev 0** | Critical — full outage, data loss, security breach | Page oncall in 5min; status page UPDATE in 15min; customer email in 1h |
| **Sev 1** | Major — feature broken for many users | Page oncall in 15min; status page UPDATE in 30min |
| **Sev 2** | Minor — degraded perf, single feature flaky | Investigate business hours; status page note if customer-impacting |
| **Sev 3** | Cosmetic — UI bug, edge case | Backlog ticket |

### 6.3 Postmortem template (for Sev 0/1)

```markdown
docs/postmortems/{YYYY-MM-DD}-{slug}.md

# Postmortem: {title}
**Status:** Resolved
**Severity:** Sev 0 / 1
**Duration:** {start} → {end}

## Timeline (UTC)
- HH:MM — Alert fired
- HH:MM — Oncall paged
- HH:MM — Investigation began
- HH:MM — Root cause identified
- HH:MM — Mitigation applied
- HH:MM — Verified resolved

## Root cause
{Be technical and honest}

## Impact
{Customer-facing: what didn't work, how long, how many}

## What went well / What went poorly
## Action items
- [ ] {Specific fix} — owner, due date
```

Publish externally if customer-impacting (transparency builds trust).

---

## 7. Payment Compliance & Pricing Tiers

Provider abstraction (Section 21) gives flexibility, but tax + invoicing + pricing strategy are launch-blockers regardless of provider.

### 7.1 Tax engine (mandatory)

**Stripe Tax** (if Stripe is provider):
```typescript
await stripe.checkout.sessions.create({
  mode: 'subscription',
  customer: tenant.stripeCustomerId,
  line_items: [{ price: plan.pricing.stripePriceIdMonthly, quantity: 1 }],
  // MANDATORY for compliance:
  automatic_tax: { enabled: true },
  customer_update: { address: 'auto', name: 'auto' },
  tax_id_collection: { enabled: true },
  metadata: { tenantId, planId },
});
```

**Xendit** (Indonesian provider): tax handled per-product. Faktur Pajak generation is separate (Section 22).

**Stripe Tax dashboard config:**
- Tax registrations (Indonesia PPN 11%, EU VAT, US states sales tax)
- Tax codes per product (digital service vs SaaS vs services)
- Reverse charge for B2B EU customers

Without tax engine = compliance violation in many jurisdictions on day 1.

### 7.2 Tax invoice / receipt generation (per-region)

**Indonesia (e-Faktur PPN):**
- Tax ID (NPWP) collected at checkout for B2B
- Invoice in IDR
- Format compatible with Coretax (DJP)
- B2B: tax invoice (Faktur Pajak); B2C: receipt (kwitansi)
- Optional: bank-stamped proof of transfer (manual provider — Section 22)

**EU (VAT invoice):**
- VAT number on invoice for B2B (reverse charge)
- VAT amount itemized

**US:**
- State sales tax based on customer address (Stripe Tax computes)
- 1099-K reporting for high-volume merchants

```typescript
export async function generateLocalizedInvoice(invoiceId: string) {
  const inv = await stripe.invoices.retrieve(invoiceId, { expand: ['customer'] });
  const tenant = await tenantRepo.findByStripeCustomer(inv.customer);
  const region = tenant.billingAddress?.country;
  if (region === 'ID') return generateIndonesianInvoice(inv, tenant);
  if (['DE', 'FR', 'NL', 'IT', 'ES'].includes(region)) return generateEUVATInvoice(inv, tenant);
  return generateDefaultInvoice(inv, tenant);
}
```

Store generated invoices in S3, link in billing portal.

### 7.3 Pricing — annual + monthly

Annual = 15-20% discount = 30-50% potential ARR uplift. Most SaaS offer both.

```typescript
export interface Plan {
  pricing: {
    monthlyAmountCents: number;
    yearlyAmountCents: number;          // typically monthly * 10 (15-17% discount)
    currency: string;
    stripePriceIdMonthly?: string;
    stripePriceIdYearly?: string;
  };
}
```

UI:
```tsx
<RadioGroup value={cycle} onChange={setCycle}>
  <Radio value="monthly">$29/mo</Radio>
  <Radio value="yearly">
    $290/year
    <Badge variant="success">Save 17% — 2 months free</Badge>
  </Radio>
</RadioGroup>
```

### 7.4 Failed payment retry / dunning

```typescript
async function handlePaymentFailed(invoice: Stripe.Invoice) {
  const tenant = await tenantRepo.findByStripeCustomer(invoice.customer);
  const attempt = invoice.attempt_count;
  if (attempt === 1) await emailQueue.enqueue('payment-failed-1st', { tenantId: tenant.id });
  else if (attempt === 2) await emailQueue.enqueue('payment-failed-2nd', { tenantId: tenant.id });
  else if (attempt >= 3) {
    await emailQueue.enqueue('payment-failed-final', { tenantId: tenant.id });
    await tenantRepo.update(tenant.id, { planStatus: 'PAST_DUE' });
  }
}
```

Provider handles retries (smart retries config). Your job: notify + update status. Don't reinvent.

### 7.5 Refund policy

- Document publicly (legal page)
- Refund via dashboard or API
- Update internal records: revoke entitlements, audit log, email confirmation
- Don't reverse usage events (they happened)

---

## 8. Pre-Existing Project Audit Pattern

When extending an EXISTING SaaS (not building zero-to-ship), run readiness audit first.

### 8.1 Run readiness audit BEFORE adding features

If project hasn't done a SaaS readiness audit, do it first:

1. Dispatch reviewer + auditor + architect in parallel for 3 readiness reports:
   - `docs/saas-readiness-security.md` (reviewer)
   - `docs/saas-readiness-operational.md` (auditor)
   - `docs/saas-readiness-business.md` (architect)
2. Synthesize into `docs/saas-readiness-master-report.md` with:
   - Combined P0 / P1 / P2 categorized
   - Day-by-day pre-launch hardening sprint plan (or 6-A → 6-H decomposition — Section 9)
   - Phase 7 / v2 backlog
3. **Block new feature work until P0 items resolved.** Adding features to a leaky foundation = compounding tech debt.

### 8.2 Audit categories (each agent owns)

**Reviewer (Security/Compliance):** auth flow gaps, compliance gaps, CVE exposure, CSP/HSTS/secrets scan

**Auditor (Operational/Tooling):** backup automation, CI/CD existence + gates, observability, migration safety, connection pool

**Architect (Business/Scalability):** trial enforcement, tax engine + tax invoice, plan downgrade enforcement, customer onboarding lifecycle, status page, annual billing, help center, signup funnel + product-surface gap (Part 3 — 10 domains)

### 8.3 Synthesize report format

```markdown
# {Project} — SaaS-Readiness Master Report

Date: {YYYY-MM-DD}

## Executive Verdict
{🟢 READY / 🟡 NOT YET / 🔴 SIGNIFICANT GAPS}

| Stage | Status | Items remaining |
|---|---|---|
| Internal demo | {✅/⚠/❌} | {n} |
| Soft-launch (1-10 invited) | {✅/⚠/❌} | {n} |
| Public marketing launch | {✅/⚠/❌} | {n} |
| Scale beyond 50 customers | {✅/⚠/❌} | {n} |

## Combined P0 — Ship-Blockers ({n})
### Security/Compliance
### Operational/Tooling
### Business/Scalability

## Combined P1 — Launch-Risk ({n})
[Same categorization]

## Notable PASS items (verified during audit)

## Recommended Pre-Launch Hardening Sprint
### Day 1 — Critical P0s
### Day 2 — Remaining P0s + critical P1s
### Day 3 — High-impact P1s

OR for larger scope:

### Phase 6 Sub-Phase Decomposition (Section 9 pattern)
6-A through 6-H — see Part 2

## Phase 7 / v2 Backlog (P2 + nice-to-haves)

## Final Verdict
{Action with timeline}
```

### 8.4 Block-ship rule

Coordinator MUST NOT advance to Phase 6 SHIP if combined P0 count > 0. User can override with explicit "ship with documented exception" — each exception logged in `.dev-squad/ship-exceptions.md` with sign-off + remediation deadline.

---

# Part 2: Sprint Execution (6-A → 6-H Domain Decomposition)

When pre-launch readiness audit reveals 20+ P0+P1 items, a 3-day sprint may not be enough. Decompose into 8 domain-specific sub-phases (extracted from real-world wacrm Indonesia-first pivot — see Section 24 case study).

---

## 9. Sprint Decomposition Pattern (8 sub-phases)

```
6-A Billing replatform           — payment provider work
6-B User management hardening    — self-service profile, password, account deletion, 2FA, bulk invite
6-C Invoicing + tax              — Faktur Pajak / VAT invoice / receipt generation
6-D Plan management              — trial cron, annual billing, coupons, downgrade enforcement
6-E API & integrations           — customer-facing API, OpenAPI doc, customer webhooks, Zapier/Make
6-F Compliance lifecycle         — GDPR/PDP data export+erasure, cookie consent, DPA, sub-processors
6-G Operational hardening        — backup automation, CI/CD, status page, observability (Sentry/Prometheus)
6-H Customer success             — onboarding email lifecycle, activation milestone, drip, help center
```

### 9.1 Properties of this decomposition

- **Domain-bounded:** each sub-phase has clear scope (no overlap)
- **Parallelizable when independent:** 6-B + 6-C + 6-D can run concurrently if different agents
- **Sequenced when dependent:** 6-A (billing) before 6-C (invoicing) — invoicing needs payment data; 6-G (operational) often last as it needs final config
- **Each sub-phase ships incrementally:** each gets its own commit/PR, doesn't wait for whole sprint
- **Each sub-phase has clear exit criteria:** P0 items in that domain resolved + tests pass + reviewer sign-off

### 9.2 When to use this pattern (vs 3-day sprint)

| Situation | Recommended pattern |
|---|---|
| < 10 P0 items, 1 domain dominates | 3-day sprint (Section 8.3) |
| 10-30 P0+P1 items across 4+ domains | 6-A → 6-H decomposition |
| > 30 items + multiple market pivots | 6-A → 6-H + multi-week timeline |
| 1 P0 critical (security incident) | Hotfix workflow (single-day) |

### 9.3 Dependency graph

```
6-A Billing ──┬──→ 6-C Invoicing (needs payment data shape)
              └──→ 6-D Plan mgmt (needs billing provider for trial cron)

6-B User mgmt ─→ 6-F Compliance (account deletion = compliance feature)

(6-E API integrations independent — can run anytime)

6-A 6-B 6-C 6-D 6-E 6-F ──→ 6-G Operational (final hardening, needs all features stable)
                          ──→ 6-H Customer success (final UX layer, needs all features done)
```

### 9.4 Coordinator dispatch template

For each sub-phase 6-X, coordinator dispatches:

```
Phase 6-X: {Domain Name}
- Lead: {primary agent — usually backend or frontend}
- Parallel: {writer for copy, designer for new UI, devops for infra config}
- Inputs: readiness master report (P0+P1 items in this domain), saas-patterns sections referenced
- Outputs: code commits + tests + updated readiness report (this domain's P0 → resolved)
- Exit criteria: all P0 in domain resolved; tests pass; iteration loop max 5 if regression
- Reviewer + qa-engineer + auditor verify before marking sub-phase complete
```

---

## 10. Per-Sub-Phase Execution Templates

### 10.1 Sub-phase 6-A — Billing replatform

**When triggered:** payment provider mismatch (e.g., Stripe-only when target market is Indonesia), provider lock-in concerns, or P0 billing gaps.

**Lead:** backend
**Parallel:** writer (copy + email templates), frontend (billing UI + admin queue page if manual provider)
**Pattern:** Section 21 provider abstraction
**Outputs:**
- `apps/api/src/modules/billing/payment-provider.interface.ts` — interface
- `apps/api/src/modules/billing/payment-provider-registry.ts` — registry
- `apps/api/src/modules/billing/{provider-name}/` — per-provider implementation
- Schema migration: replace provider-specific columns with provider-neutral
- Webhook routes split per provider (`/webhooks/billing/{provider}`)
- Plan catalog: `Plan.providerPriceIds[providerName]`
- Legacy provider code moved to `apps/api/src/modules/billing/legacy-{provider}/` (Section 23)

**Blockers:** KYC + sandbox accounts (e.g., Xendit 1-2 weeks). Document blocked items in `.dev-squad/blockers.md`.

### 10.2 Sub-phase 6-B — User management hardening

**Lead:** backend
**Parallel:** frontend (profile UI, settings page, bulk invite UI), writer (email templates), designer (avatar upload UI)
**Pattern:** saas-patterns Section 1 (multi-tenancy) + Section 4 (API keys for force-logout endpoint) + Section 11 product-surface gap (this skill)
**Outputs:**
- `PATCH /api/v1/me` — self-service profile edit
- `PATCH /api/v1/me/password` — password change with current password verify
- `POST /api/v1/me/email-change` + `POST /api/v1/me/email-change/verify` — email change with verification
- `DELETE /api/v1/me` — account deletion (GDPR / PDP — Section 4.2)
- `POST /api/v1/me/avatar` — avatar upload (S3)
- Per-user tenant audit log (separate from platform audit log)
- 2FA/TOTP enrollment flow + recovery codes
- Force logout endpoint (admin-side: revoke user sessions immediately)
- Bulk user import (CSV upload)
- Account lockout after N failed logins (P0 from readiness checklist)

### 10.3 Sub-phase 6-C — Invoicing + tax

**Lead:** backend
**Parallel:** writer (tax invoice copy, NPWP capture form copy)
**Dependencies:** 6-A complete (need payment data)
**Pattern:** Section 7 + Section 22 (regional)
**Outputs:**
- Tax engine enabled (Stripe Tax / Xendit native)
- NPWP capture at checkout for Indonesian customers
- Faktur Pajak generation (e-Faktur PPN format) for Indonesian B2B
- VAT invoice for EU B2B (reverse charge)
- Receipt template for B2C
- S3 storage of generated invoices
- Customer billing portal lists invoices

### 10.4 Sub-phase 6-D — Plan management

**Lead:** backend
**Parallel:** frontend (annual/monthly toggle UI, coupon input)
**Dependencies:** 6-A complete
**Pattern:** saas-patterns Section 2 (billing) + Section 3 (entitlements)
**Outputs:**
- Trial expiry enforcement cron (daily check `trialEndsAt`)
- Annual billing pricing tier (15-20% discount)
- Coupon / promo code at checkout (`allow_promotion_codes: true`)
- Plan downgrade contact + seat enforcement (block if over-quota or auto-suspend over-quota items)
- Plan history audit trail (when did org upgrade/downgrade)

### 10.5 Sub-phase 6-E — API & integrations

**Lead:** backend
**Parallel:** writer (API docs)
**Outputs:**
- OpenAPI spec auto-generated from route definitions
- Customer-facing API key management UI (saas-patterns Section 4 — exists, but customer-facing UI may not)
- Customer webhook subscriptions (saas-patterns Section 5 has architecture; this is the customer config UI)
- API rate limiting per tenant
- API docs site (Swagger UI / Redoc / Stoplight)
- Optional: Zapier app, Make.com module

### 10.6 Sub-phase 6-F — Compliance lifecycle

**Lead:** backend
**Parallel:** frontend (cookie banner, data export download UI), writer (privacy policy, DPA template)
**Pattern:** Section 4
**Outputs:**
- Data export endpoint (async via queue, JSON/NDJSON)
- Data erasure endpoint (anonymize PII, retain financial 7y)
- Cookie consent banner
- DPA template at `docs/legal/data-processing-agreement.md`
- Sub-processors list page (public)
- Privacy policy + Terms of Service updated

### 10.7 Sub-phase 6-G — Operational hardening

**Lead:** devops
**Parallel:** auditor (verifies post-implementation)
**Pattern:** Sections 2 + 3 + 6
**Outputs:**
- Postgres backup automation (pg-backup service + S3 + restore drill done)
- Redis backup
- ClickHouse backup (if used)
- CI/CD pipeline blocking PRs on tsc/test/lint + security scan
- Status page setup (BetterStack / Cachet / static)
- Sentry error tracking (frontend + backend)
- Prometheus `/metrics` endpoint + Grafana dashboards
- Pino redact PII paths
- ADMIN_IP_ALLOWLIST (if applicable)

### 10.8 Sub-phase 6-H — Customer success

**Lead:** writer
**Parallel:** backend (lifecycle cron), frontend (in-app onboarding tooltips)
**Pattern:** Section 5
**Outputs:**
- Welcome email (after email verify)
- Activation milestone email (after first key action)
- Trial-warning email (3 days before expiry)
- Trial-expired email + reactivation drip
- Re-engagement drip 30/60/90 day dormancy
- Help center / docs site at advertised URL
- Signup funnel + activation milestone tracking (PostHog / Plausible / custom events)

---

# Part 3: Product-Surface Gap Audit (10 domains)

Architectural readiness (Part 1+2) is necessary but not sufficient. SaaS buyers expect specific **product-surface features** beyond architecture. Use this as a completeness checklist when auditing existing SaaS or planning Phase 6 sprint.

The 10 domains (A-J) extracted from real-world wacrm gap audit. Each domain has features common to mature B2B SaaS — missing items are blockers vs nice-to-haves vs enterprise-only.

---

## 11. A. User Management

| Feature | Tier | Notes |
|---|---|---|
| Org member list | Core | Required from day 1 |
| Invite by email | Core | Required from day 1 |
| Accept invitation | Core | Required from day 1 |
| Role change (admin/member/viewer) | Core | Required from day 1 |
| Remove member | Core | Required from day 1 |
| Plan-gate seat count on invite | Core | Required for plan-based access |
| **Self-service profile edit (PATCH /me)** | **P0** | User can't update own name/email/avatar = launch-blocker UX gap |
| **Self-service password change** | **P0** | No `/auth/password/change` route = security UX gap |
| **Self-service email change with verification** | **P0** | High-risk security feature, often needs email re-verify |
| **Self-service account deletion (GDPR/PDP)** | **P1** | Required for EU + Indonesian compliance |
| **Avatar upload** | P1 | S3 upload route + UI |
| **Account lockout after failed logins** | **P0** | Credential stuffing surface |
| **2FA/TOTP** | P1 | Tenant admins should be able to enable |
| Bulk user import (CSV) | P1 | Customers w/ existing teams expect to migrate |
| Custom roles / permissions | P2 (Enterprise) | Only fixed OWNER/ADMIN/MEMBER common |
| **Per-record audit ("who deleted this?")** | P1 | Tenant admin needs to know who did what within their org |
| **User activity log (per-tenant)** | P1 | Distinct from platform audit (admin-scope) |
| Force logout / session management | P1 | Can't kick a compromised user without this |
| Last sign-in tracking | P1 | `User.lastLoginAt` |
| **SSO (Google / Microsoft / SAML)** | P2 (Enterprise) | Blocker for >$1k/mo deals |
| **SCIM provisioning** | P2 (Enterprise) | Enterprise IT requirement |

---

## 12. B. Plan Management

| Feature | Tier | Notes |
|---|---|---|
| Multi-tier pricing (FREE/STARTER/GROWTH/SCALE) | Core | Required from day 1 |
| Plan comparison page | Core | Required for marketing |
| Current plan card in tenant billing | Core | Required from day 1 |
| Upgrade flow → checkout | Core | Required from day 1 |
| Customer billing portal link | Core | Required from day 1 |
| Plan-gate runtime enforcement | Core | Block over-quota new resources |
| **Trial enforcement** | **P0** | Set `trialEndsAt`, no cron reads = orgs trial-priced indefinitely |
| **Coupon / promo code at checkout** | P1 | `allow_promotion_codes: true` (1-line fix often) |
| **Annual billing (15-20% discount)** | P1 | Missing 30-50% potential ARR uplift |
| **Plan downgrade with over-quota handling** | P1 | Over-cap contacts/seats not enforced post-downgrade |
| **Custom enterprise pricing flow** | P2 | "Contact sales" form + manual plan assignment |
| Plan grandfathering | P2 | If tier prices change, existing customers locked into old terms |
| Usage-based overage billing | P2 | "You sent 105k emails on a 100k plan, $10 overage" |
| Add-ons (extra seats, extra domain) | P2 (Enterprise) | A la carte expectation |
| **Multi-currency pricing** | P1 (regional) | Indonesian customers expect IDR; EU EUR; etc. |
| Plan history / change audit | P1 | "We were on STARTER from Jan-Mar" |

---

## 13. C. Payment

| Feature | Tier | Notes |
|---|---|---|
| **Tax engine enabled** | **P0** | Stripe Tax / Xendit / per-region custom — compliance violation without |
| Stripe Checkout / equivalent | Core | Standard SaaS pattern |
| Customer billing portal | Core | Standard pattern |
| Webhook signature verification | **P0** | Security blocker |
| Failed payment retry / dunning | Core | Provider-handled, plus customer notify |
| Refund flow | Core | Manual via dashboard OK; document policy |
| **Multi-provider support** (regional) | P1 (regional) | Stripe doesn't fully operate in Indonesia → need Xendit + PayPal + Manual (Section 21) |
| **Manual bank transfer + admin verify** | P1 (regional Indonesia/Asia) | B2B preference, lower transfer limits, internal approval workflows |
| **QRIS / VA / e-wallet** | P1 (regional Indonesia) | Indonesian payment ecosystem |
| Invoice in customer's currency | P1 | Multi-currency display |

---

## 14. D. Invoicing

| Feature | Tier | Notes |
|---|---|---|
| Stripe-generated invoice / equivalent | Core | Provider provides basic |
| **Tax invoice (Faktur Pajak / VAT / e-Faktur)** | **P0** (per-region) | Indonesia compliance via Coretax (DJP); EU VAT invoice for B2B |
| **NPWP / VAT number capture at checkout** | **P0** (per-region) | B2B requirement |
| **Localized invoice format** (per-region) | P1 | Indonesian e-Faktur PPN format; EU VAT format |
| Invoice in customer's currency | P1 | Multi-currency |
| Invoice S3 storage + permanent URL | P1 | Customer download from billing portal |
| Payment receipt for B2C | Core | Distinct from tax invoice |
| Refund invoice / credit memo | P1 | When refund issued |
| Bank-stamped proof attachment (manual provider) | P1 (regional) | Indonesian B2B expectation |

---

## 15. E. API & Integrations

| Feature | Tier | Notes |
|---|---|---|
| Customer-facing API key management UI | P1 | If exposing API to customers — saas-patterns Section 4 architecture |
| OpenAPI spec / Swagger docs | P1 | Auto-generated from routes |
| API rate limiting per tenant | P1 | Per-plan limits |
| Customer webhook subscriptions | P1 | If exposing webhooks to customers — saas-patterns Section 5 |
| API docs site (Swagger UI / Redoc) | P1 | Public docs.yourapp.com |
| Zapier app | P2 | Reach into Zapier ecosystem |
| Make.com / n8n module | P2 | Alternative integrators |
| Webhook event replay | P2 | "Resend webhook" for failed delivery |
| API usage analytics per tenant | P2 | Customer-facing API usage |
| API versioning strategy | Core | `/api/v1/` from day 1 |

---

## 16. F. Customization & White-label

| Feature | Tier | Notes |
|---|---|---|
| Per-tenant logo upload | P1 | Branded experience |
| Per-tenant primary color / theme | P1 | Brand consistency |
| Email-from address customization | P1 (Enterprise) | Requires DNS verification + DKIM |
| Custom domain (CNAME to your app) | P2 (Enterprise) | Customer's branded URL |
| Custom CSS (sandboxed) | P2 (Enterprise) | XSS surface — careful sandboxing |
| Custom email templates | P2 (Enterprise) | Override default lifecycle emails |
| Sigil / favicon | P1 | Quick win for branding |
| Embedded widget mode | P2 | If customer wants to embed feature in their site |

See saas-patterns Section 14 for white-label architectural pattern.

---

## 17. G. Notifications & Comms

| Feature | Tier | Notes |
|---|---|---|
| In-app notifications | Core | saas-patterns Section 7 architecture |
| Notification preferences per user | P1 | Email vs push vs in-app channel selection |
| Push notifications (mobile / web push) | P2 | Requires service worker + provider |
| Status updates from us to customer | P1 | "Your export is ready", "Your campaign sent" |
| Announcements (publish-broadcast) | P1 | Admin posts, all tenants see |
| Per-tenant maintenance window notice | P2 | Schedule + notify before downtime |
| Webhook for customer to subscribe | P1 | Customer-side notification (Section 15) |

---

## 18. H. Customer-facing Analytics / Reporting

| Feature | Tier | Notes |
|---|---|---|
| Per-tenant dashboard | Core | Drill-down (saas-patterns Part 2) |
| Export to CSV / Excel | P1 | Customer-driven export |
| Scheduled reports (email weekly/monthly) | P2 | Auto-generated reports |
| Custom report builder | P2 (Enterprise) | Drag-drop column builder |
| Goal/KPI tracking per tenant | P2 | "Your goal: 100 contacts; current: 47" |
| Comparison vs previous period | P1 | "Up 15% vs last month" |
| Per-user activity within tenant | P1 | "Who was most active in your team" |
| Audit export (compliance) | P1 | Customer pulls own audit log |

---

## 19. I. Workspace / Sub-tenancy

| Feature | Tier | Notes |
|---|---|---|
| Single workspace per org | Core | Default — most B2B SaaS |
| Multi-workspace (org → workspace → user) | P2 (Enterprise) | Larger orgs want sub-tenancy |
| Workspace switching UI | P2 | If multi-workspace |
| Workspace-level permissions | P2 | Distinct from org-level |
| Workspace-level billing | P2 (Enterprise) | Larger orgs want per-workspace billing |
| Cross-workspace search | P2 | Find resources across all workspaces |

Most projects don't need this. Only enterprise tier customers ask for it.

---

## 20. J. Compliance / Legal

| Feature | Tier | Notes |
|---|---|---|
| Privacy policy page | Core | Required for any data collection |
| Terms of service page | Core | Required for any contract |
| Cookie consent banner | **P0** (regional) | EU + Indonesia |
| Data export endpoint | **P0** (regional) | GDPR/PDP/CCPA |
| Data erasure endpoint | **P0** (regional) | GDPR/PDP "right to be forgotten" |
| DPA (data processing agreement) | P1 (B2B) | B2B customers will ask |
| Sub-processors list (public) | P1 | DPA addendum |
| Acceptable use policy | P2 | If user-generated content |
| SOC 2 readiness | P2 (Enterprise) | Enterprise blocker for $10k+/mo deals |
| PCI DSS scope (if storing card) | Core IF storing cards | Use Stripe / provider tokenization to STAY OUT of scope |
| GDPR breach notification SLA (72h) | P1 (regional) | Document procedure |
| Data residency (region selection) | P2 (Enterprise) | EU customers want EU data |

---

# Part 4: Real-World Patterns

Concrete patterns extracted from real wacrm pivot. These are too specific for general saas-patterns architectural reference but proven valuable in practice.

---

## 21. Provider Abstraction Pattern

When primary vendor doesn't fit all customer markets (e.g., Stripe doesn't operate in Indonesia for local methods), abstract provider behind interface. Apply same pattern to OTHER vendor categories you might pivot (WhatsApp providers, email providers, SMS providers, etc.).

### 21.1 Pattern structure

```
PaymentProvider interface
  ├── PaymentProviderRegistry  (per-org selection)
  │
  ├── StripeProvider     ─── webhooks at /webhooks/billing/stripe
  ├── XenditProvider     ─── webhooks at /webhooks/billing/xendit
  ├── PayPalProvider     ─── webhooks at /webhooks/billing/paypal
  └── ManualProvider     ─── admin verification queue (no webhook)
```

### 21.2 Interface contract (TypeScript)

```typescript
export type PaymentProviderName = 'STRIPE' | 'XENDIT' | 'PAYPAL' | 'MANUAL';

export interface PaymentProvider {
  readonly name: PaymentProviderName;

  // Checkout: create session, return redirect URL or admin-action info
  createCheckoutSession(params: {
    tenantId: string;
    planSlug: string;
    cycle: 'monthly' | 'yearly';
    customerEmail: string;
    metadata?: Record<string, string>;
  }): Promise<{ redirectUrl?: string; adminInstructions?: string }>;

  // Subscription lifecycle
  cancelSubscription(subscriptionId: string): Promise<void>;
  changePlan(subscriptionId: string, newPlanSlug: string): Promise<void>;

  // Customer portal (or null if provider doesn't have one)
  createPortalSession(tenantId: string): Promise<{ portalUrl: string } | null>;

  // Webhook handling — provider-specific verification + normalization
  verifyAndParseWebhook(req: Request): Promise<NormalizedBillingEvent | null>;

  // For manual providers: admin verification interface
  listPendingVerifications?(): Promise<PendingVerification[]>;
  approveVerification?(id: string, adminId: string): Promise<void>;
  rejectVerification?(id: string, adminId: string, reason: string): Promise<void>;
}

export interface NormalizedBillingEvent {
  type: 'subscription.created' | 'subscription.updated' | 'subscription.deleted'
      | 'invoice.payment_succeeded' | 'invoice.payment_failed';
  tenantId: string;
  data: { planSlug: string; cycle?: 'monthly' | 'yearly'; amountCents?: number; ... };
}
```

### 21.3 Per-org selection

Add `paymentProvider` column to `Organization` table. Default at signup based on country (Indonesian → Xendit; international → Stripe; some customers might explicitly choose Manual).

```typescript
// On signup:
const provider = inferProviderFromCountry(signupAddress.country) || 'STRIPE';
await orgRepo.create({ ...orgData, paymentProvider: provider });

// On checkout:
const org = await orgRepo.findById(tenantId);
const provider = providerRegistry.get(org.paymentProvider);
const session = await provider.createCheckoutSession({ ... });
```

Allow tenant admin to switch provider in billing settings (with subscription cancel + re-subscribe via new provider).

### 21.4 Plan catalog (provider-neutral)

```typescript
model Plan {
  slug                String  @id          // 'free' | 'starter' | 'growth' | 'scale'
  name                String
  monthlyAmountCents  Int
  yearlyAmountCents   Int
  currency            String                // 'USD' or 'IDR' per market
  // Provider-specific external IDs:
  stripePriceIdMonthly  String?
  stripePriceIdYearly   String?
  xenditPlanIdMonthly   String?
  xenditPlanIdYearly    String?
  paypalPlanIdMonthly   String?
  paypalPlanIdYearly    String?
  // No paypal/xendit ID for Manual — manual is "send invoice, customer transfers, admin approves"
}
```

### 21.5 When pattern applies

- **Multi-region market expansion** (Indonesia + global)
- **Vendor lock-in concerns** (avoid "all-in on Stripe")
- **B2B reality** (some customers want manual / non-automated path)
- **Compliance segregation** (EU customer data must stay in EU provider)

This pattern in dev-squad codebases was first applied in wacrm for **WhatsApp provider** (Meta Cloud + GOWA) before being applied to **payment** (PayPal + Xendit + Manual). It's a reusable abstraction template.

### 21.6 Cross-provider testing

```typescript
// __tests__/payment-providers.test.ts
const providers: PaymentProviderName[] = ['STRIPE', 'XENDIT', 'PAYPAL', 'MANUAL'];

for (const name of providers) {
  describe(`PaymentProvider: ${name}`, () => {
    it('createCheckoutSession returns valid output', async () => { ... });
    it('handles webhook verification correctly', async () => { ... });
    it('normalizes events to common shape', async () => { ... });
  });
}
```

Cross-provider conformance tests catch interface drift.

---

## 22. Regional Considerations

### 22.1 Indonesia

- **Faktur Pajak (e-Faktur PPN):** Tax invoice for B2B; format compatible with Coretax (DJP). NPWP capture mandatory at checkout.
- **PPN 11%** standard rate (some sectors different)
- **QRIS** (QR Indonesian Standard) — major Indonesian payment method
- **Virtual Account (VA)** — bank-issued payment numbers (BCA / BNI / BRI / Mandiri / Permata)
- **E-wallets:** OVO / DANA / ShopeePay / LinkAja / GoPay
- **Retail outlets:** Indomaret / Alfamart for cash payment
- **Manual bank transfer + admin verify:** B2B preference, especially for SMBs:
  - Internet banking trust > new payment gateways
  - Bank-stamped proof needed for Faktur Pajak
  - Internal approval workflows (PIC must approve via internet banking)
  - Lower transfer limits on QRIS/VA than direct bank transfer for higher-value subscriptions
- **Provider:** Xendit (Indonesian-purpose, good SaaS subscription API). Midtrans rejected (weaker subscription docs). Stripe doesn't fully operate.
- **PDP (UU PDP):** data subject rights similar to GDPR; some sectors require data localization
- **KYC timeline for payment providers:** Xendit business KYC ~1-2 weeks (factor into Phase 6-A)

### 22.2 EU

- **GDPR:** data subject rights (access / erasure / portability / rectification)
- **ePrivacy Directive:** cookie consent (active opt-in required)
- **VAT invoice for B2B:** reverse charge mechanism — VAT number on invoice
- **Multi-language requirement** for some markets (DE / FR / IT / ES)
- **Data residency:** some customers require EU-only data (use AWS eu-west-1 / GCP europe / Hetzner)

### 22.3 US

- **State sales tax** based on customer address (Stripe Tax computes per-state)
- **CCPA / CPRA** (California): right to know / delete / opt-out of sale
- **1099-K reporting** for high-volume merchants (Stripe handles)
- **PCI DSS scope:** use Stripe / provider tokenization to stay OUT of scope (don't store cards)

### 22.4 Region detection at signup

```typescript
const region = inferRegionFromCountry(signupAddress.country);
const compliancePack = getComplianceObligations(region);
// → ['gdpr', 'epp']  for EU
// → ['pdp']  for ID
// → ['ccpa']  for CA-US
// Drives which features are required (cookie banner / data export / VAT invoice / etc.)
```

---

## 23. Re-Platform Discipline (Graceful Provider Deprecation)

When pivoting from one provider to another (e.g., Stripe → Xendit + PayPal + Manual), don't rip-and-replace. Use graceful deprecation:

### 23.1 Steps

1. **Implement new providers behind interface** (Section 21) without removing old
2. **Move legacy provider code to `legacy-{provider}/` directory**:
   ```
   apps/api/src/modules/billing/
   ├── payment-provider.interface.ts
   ├── payment-provider-registry.ts
   ├── stripe/                      ← Active (or moved to legacy if pivoting)
   ├── xendit/                      ← New active
   ├── paypal/                      ← New active
   ├── manual/                      ← New active
   └── legacy-stripe/               ← OLD code, marked deprecated
   ```
3. **Mark legacy code with deprecation comment + removal timer:**
   ```typescript
   /**
    * @deprecated Stripe demoted in ADR-006. Will be removed YYYY-MM-DD if no production
    * customers migrated to it. See docs/migration/stripe-to-xendit.md.
    */
   export class LegacyStripeProvider { ... }
   ```
4. **Keep webhook receivers active** for legacy provider in case existing customers' subscriptions still pass through (until migration complete)
5. **Schedule removal:** 6-month timer is reasonable. Track in `docs/next-iteration.md`.

### 23.2 Migration discipline

- Don't migrate existing customers automatically; let them choose at next billing cycle
- Provide clear migration UI: "Switch your billing provider — current Stripe → new Xendit"
- Audit log every provider switch
- Keep both providers' invoices accessible (don't lose history)

### 23.3 Schema migration

Replace provider-specific columns with provider-neutral:

```diff
model Organization {
- stripeCustomerId      String?
- stripeSubscriptionId  String?
- stripePriceId         String?
+ paymentProvider       String?    // 'STRIPE' | 'XENDIT' | 'PAYPAL' | 'MANUAL'
+ providerCustomerId    String?    // provider-specific customer ID
+ providerSubscriptionId String?
+ providerPriceId       String?
}
```

Migration script: copy old `stripeCustomerId` → new `providerCustomerId` with `paymentProvider = 'STRIPE'`. Keep both columns during transition (write to both, read from new).

---

## 24. Case Study: WaCRM Indonesia-First Pivot

### 24.1 Background

WaCRM started as multi-tenant SaaS CRM with Stripe-only billing (ADR-002). Architecture solid: multi-tenancy verified, Stripe sig + bcrypt + CSP hardened, etc. Phase 5 review passed with all P0+P1 closed.

### 24.2 Pivot trigger

User feedback identified: "target market is Indonesian SMB, but billing assumes Stripe global. Stripe doesn't fully operate in Indonesia." Strategic re-platform decision, not a feature add.

### 24.3 Pivot decisions

**ADR-006 (PayPal + Xendit dual-provider):**
- Xendit for Indonesia (purpose-built, QRIS/VA/e-wallet/retail support)
- PayPal for international (works in 200+ countries including Indonesia for foreign cards)
- Stripe demoted to legacy reference (6-month removal timer)
- Midtrans rejected (weaker SaaS subscription docs)

**ADR-006a (Manual Bank Transfer addendum):**
- Added MANUAL as third provider after user feedback identifying B2B reality:
  - Customers prefer internet banking + bank-stamped proof for Faktur Pajak
  - Internal approval workflows (PIC via internet banking, not gateway)
  - Higher transfer limits via direct bank transfer
- MANUAL provider has no automated webhook — admin queue for verification

### 24.4 Phase 6 sub-phase decomposition

WaCRM decomposed Phase 6 into 8 sub-phases (Section 9 pattern):
- 6-A Billing replatform (in progress, blocked on Xendit KYC ~1-2 weeks)
- 6-B User mgmt (mostly complete: refresh rotation, profile/email/password, account deletion, 2FA, bulk invite, audit log)
- 6-C Invoicing + tax (complete: Faktur Pajak + NPWP capture)
- 6-D Plan management (complete: annual + downgrade + trial cron + coupons)
- 6-E API integrations (pending)
- 6-F Compliance (complete: cookie consent + data export + sub-processors)
- 6-G Operational (pending: backup automation, CI/CD, status page)
- 6-H Customer success (pending)

### 24.5 Lessons extracted

1. **Provider abstraction pattern is reusable** — applied first to WhatsApp (ADR-004), then payment (ADR-006). The same interface + registry + per-org selection + normalized webhook events shape works.

2. **Regional context drives architectural decisions** — Indonesia-first SMB market doesn't tolerate Stripe-only because of payment ecosystem mismatch. Architecture must be informed by target market, not vendor defaults.

3. **B2B preferences differ from B2C** — Indonesian SMB B2B: manual bank transfer with proof upload + admin verify often beats Xendit Virtual Account for higher-value subscriptions. Don't assume "all SaaS = automated billing".

4. **Phase 6 decomposition (6-A→6-H) is more granular than 3-day sprint** — when readiness audit reveals 27+ items across 8 domains, 3-day sprint is unrealistic. 8 sub-phases parallelizable + ship-incremental.

5. **Re-platform discipline matters** — Stripe didn't get ripped out, it got moved to `legacy-stripe/` with 6-month removal timer. Existing infrastructure preserved during transition.

6. **Some patterns are NOT general** — Manual provider with admin verify is Indonesian/Asian B2B-specific. Worth documenting as regional pattern (Section 22.1), not promoting as general SaaS pattern.

### 24.6 Replicable for other regional pivots

The pattern (`provider-abstraction → regional providers → graceful deprecation → sub-phase decomposition`) replicates for:
- LATAM markets (e.g., MercadoPago + PayU + Local Wire)
- India (e.g., Razorpay + UPI + Bank transfer)
- China (e.g., WeChat Pay + Alipay + Bank transfer)
- Africa (e.g., Flutterwave + M-Pesa + bank)

Each region has its own payment ecosystem mismatch with global Stripe-only assumption.

---

## Anti-patterns (NEVER do these in SaaS readiness work)

| Anti-pattern | Why it's wrong | Right way |
|---|---|---|
| Backup script that's never restored | Backup that doesn't restore = no backup | Quarterly restore drill with documented row counts |
| `LOG_LEVEL=debug` in production | PII leak via Prisma query logs | LOG_LEVEL=info default; Zod refine reject debug when prod |
| Tax engine `automatic_tax: false` (Stripe) | PPN/VAT/sales tax compliance violation | enabled: true + dashboard config |
| No welcome email after email verify | Customer thinks app is broken | Enqueue welcome email immediately on verify |
| Trial expires silently | Customer surprise + trust loss | Trial-warning 3d before + trial-expired immediately |
| Hot-deploy without CI gates | Broken builds reach prod silently | Min: tsc/test/lint blocking PRs |
| Hardcoded plan IDs in code | Plan change = code deploy | Plan as table, queried by slug |
| Manual GDPR data export ("we'll do it manually") | Doesn't scale; legal exposure (30d SLA) | Implement /me/data-export + erasure endpoints |
| Cookie banner that loads analytics on dismiss | ePrivacy / PDP violation | Don't load analytics until consent="all" |
| Drip email without unsubscribe link | CAN-SPAM / GDPR violation | Every marketing email has visible unsubscribe |
| Mixing transactional + marketing on same domain | Deliverability tanks | Separate domains (mail.app.com vs marketing.app.com) |
| No status page | Customer blames YOU for cloud outages | Even static page beats nothing |
| Adding features over unresolved P0 | Compounding tech debt | Audit-first, block features until P0 cleared (Section 8.4) |
| Refund without revoking entitlements | Customer keeps paid features | After refund: revoke + audit log + email confirmation |
| Erasure that deletes financial records | 7-year retention violation | Anonymize PII in financials, keep records |
| Stripe-only billing for Indonesian market | Foundational market mismatch | Provider abstraction + Xendit/PayPal/Manual (Section 21) |
| Rip-and-replace provider migration | Disrupts existing customers | Graceful deprecation: legacy directory + removal timer (Section 23) |
| Single sprint for 30+ readiness items | Unrealistic timeline | 6-A → 6-H sub-phase decomposition (Section 9) |

---

## Companion skills

When this skill is loaded, also reference:
- **`dev-squad:saas-patterns`** — sibling skill covering WHAT to build (Part 1 backend architectural patterns + Part 2 frontend admin/drill-down). saas-readiness covers HOW to ship + harden. Distinct load contexts.
- `dev-squad:postgres-patterns` for index design, RLS, partition strategy
- `dev-squad:backend-patterns` for general API/service layer
- `dev-squad:security-review` for auth/authz review
- `frontend-design:frontend-design` (if installed) for visual aesthetic
- `superpowers:brainstorming` for compliance scope decisions (ADR-005)

## Bootstrap Context

**Coordinator + Reviewer + Auditor + Architect MUST run readiness checklist (Section 1) BEFORE Phase 6 SHIP.** P0 items block ship. P1 documented as pre-launch hardening sprint plan (Section 8.3 template OR Section 9 sub-phase decomposition for larger scope). P2 to `docs/next-iteration.md`.

For pre-existing SaaS projects (not zero-to-ship): coordinator MUST run readiness audit (Section 8) BEFORE adding features. Adding features to project with unresolved P0 = compounding tech debt anti-pattern.

**DevOps owns:** Section 2 (backup), Section 3 (CI/CD), Section 6 (status page), Section 10.7 (6-G operational hardening).

**Architect owns:** Section 4 ADR-005 compliance scope decision, Section 8 (audit synthesis), Section 21 (provider abstraction architecture decision when pivoting), Section 22 (regional context).

**Backend owns:** Section 4 implementation (data export/erasure), Section 7 (payment compliance), Section 10.1-10.6 (sub-phase implementation).

**Writer owns:** Section 5 (email lifecycle templates), Section 7.5 (refund policy doc), Section 4.4 (DPA template), Section 10.8 (6-H customer success copy).

**For SaaS pivots / re-platforms:** Architect produces ADR-006 (or successor numbering) for provider abstraction decision. Section 23 graceful deprecation discipline mandatory — no rip-and-replace.

For specific regional context (Indonesia / EU / US / etc.), reference Section 22 alongside ADR-005 compliance scope.
