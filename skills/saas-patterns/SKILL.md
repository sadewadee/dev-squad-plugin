---
name: saas-patterns
description: SaaS-class architecture reference (code-write patterns) for dev-squad agents — 2 parts. PART 1 BACKEND (multi-tenancy with RLS + isolation testing, Stripe billing, entitlements, API keys, signed outbound webhooks with retry+DLQ, audit logs, notifications, transactional email, hybrid validation, admin scope, usage metering, runtime config, SSO, white-label). PART 2 FRONTEND admin dashboard with drill-down (URL state, breadcrumb, time-series brush+zoom, virtualized tables, cross-filter, permission-aware items). Load during Phase 4 IMPLEMENT for code-write patterns. For pre-launch readiness + execution discipline (operational + compliance + lifecycle + sprint decomposition + product-surface gap audit + provider abstraction + regional + case studies), see SIBLING skill `dev-squad:saas-readiness`. TypeScript/Node.js + Go examples.
---

# SaaS Patterns — Production-Class SaaS Reference for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Load these patterns when dev-squad agents are building, reviewing, or architecting a **SaaS-class** application — multi-tenant, subscription-billed, with admin/customer scope separation. Coordinator activates this skill when the workflow is in SaaS mode (auto-detected from PRD or set explicitly via `--saas`).

**Critical rule:** Multi-tenancy is an architectural decision, not a feature. Retrofit later = cross-tenant data leak (P0 security incident). Architect MUST decide tenancy strategy in Phase 2 ADR before any data model is written.

This skill is in TWO parts:
- **Part 1 (sections 1–15):** Backend patterns — data model, billing, auth, validation, isolation
- **Part 2 (sections 16–26):** Frontend admin dashboard with drill-down

This skill covers WHAT to build (architectural patterns for code). For HOW to ship + harden + audit (pre-launch readiness, operational discipline, compliance lifecycle, sprint decomposition, provider abstraction, regional patterns, case studies), see sibling skill **`dev-squad:saas-readiness`**.

**Distinct load contexts:**
- saas-patterns: load during Phase 4 IMPLEMENT (writing SaaS code)
- saas-readiness: load during Phase 5+ audit, Phase 6 SHIP gate, pre-existing project extension

---

# Part 1: Backend Patterns

---

## 1. Multi-Tenancy

### 1.1 Tenancy strategies (architect picks ONE in ADR-001)

| Strategy | Isolation level | Pros | Cons | Pick when |
|---|---|---|---|---|
| **Shared DB, tenant_id column** | Logical (RLS) | Simple, cheap, fast queries | Mistake = data leak; harder per-tenant scaling | Most B2B SaaS, <10k tenants |
| **Schema per tenant** | Schema-level | Stronger isolation, easier per-tenant migrations | Connection pool fragmentation, schema explosion | Compliance-heavy (HIPAA, finance) |
| **DB per tenant** | Physical | Strongest isolation, dedicated resources | Operational overhead, expensive | Enterprise tier only, <100 tenants |
| **Hybrid** | Mixed | Free/pro on shared, enterprise dedicated | Complex routing | Multi-tier pricing with isolation tier |

Default for dev-squad: **Shared DB + tenant_id + Postgres RLS**. Document the choice in `docs/adr/ADR-001-tenancy.md`.

### 1.2 Core data model

```typescript
// packages/shared-types/src/tenant.ts
export interface Tenant {
  id: string;              // UUID
  slug: string;            // URL-safe unique identifier
  name: string;
  status: 'active' | 'suspended' | 'cancelled';
  planId: string;          // FK -> plans
  trialEndsAt?: Date;
  stripeCustomerId?: string;
  stripeSubscriptionId?: string;
  ownerId: string;         // FK -> users (the user who created it)
  createdAt: Date;
  updatedAt: Date;
}

export interface TenantMembership {
  id: string;
  tenantId: string;        // FK -> tenants
  userId: string;          // FK -> users
  role: 'owner' | 'admin' | 'member' | 'viewer';
  status: 'active' | 'invited' | 'removed';
  invitedBy?: string;      // FK -> users
  invitedAt?: Date;
  acceptedAt?: Date;
}

export interface Invitation {
  id: string;
  tenantId: string;
  email: string;
  role: TenantMembership['role'];
  token: string;           // hashed before storage
  expiresAt: Date;         // 7 days default
  acceptedAt?: Date;
  invitedBy: string;
}
```

### 1.3 Postgres RLS (Row-Level Security)

```sql
-- Migration: enable RLS on tenant-scoped tables
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- Policy: users can only see rows from their active tenant memberships
CREATE POLICY tenant_isolation ON projects
  USING (
    tenant_id IN (
      SELECT tm.tenant_id
      FROM tenant_memberships tm
      WHERE tm.user_id = (SELECT current_setting('app.current_user_id'))::uuid
        AND tm.status = 'active'
    )
  );

-- Critical: wrap auth.uid() in subquery (Supabase pattern) for index usage
-- Query planner optimization — see postgres-patterns skill section on RLS
```

### 1.4 Tenant context middleware (Node.js / Express)

```typescript
// apps/backend/src/middleware/tenantContext.ts
export async function tenantContext(req: Request, res: Response, next: NextFunction) {
  // tenant resolution: subdomain | path | header
  // pick ONE strategy and stick with it
  const tenantSlug = req.subdomains[0]              // acme.app.com → "acme"
    || req.params.tenantSlug                         // /t/acme/...
    || req.headers['x-tenant-slug'] as string;       // header

  if (!tenantSlug) {
    throw new ApiError(400, 'TENANT_MISSING', 'Tenant context required');
  }

  const tenant = await tenantRepo.findBySlug(tenantSlug);
  if (!tenant || tenant.status !== 'active') {
    throw new ApiError(404, 'TENANT_NOT_FOUND', 'Tenant not found or suspended');
  }

  // Verify user has membership in this tenant
  const membership = await membershipRepo.findByUserAndTenant(req.user.id, tenant.id);
  if (!membership || membership.status !== 'active') {
    throw new ApiError(403, 'TENANT_ACCESS_DENIED', 'No access to this tenant');
  }

  req.tenant = tenant;
  req.membership = membership;

  // Set Postgres session var for RLS (if using shared DB strategy)
  await db.query(`SET LOCAL app.current_user_id = '${req.user.id}'`);
  await db.query(`SET LOCAL app.current_tenant_id = '${tenant.id}'`);

  next();
}
```

**Critical:** every data-access query must run through this context. Direct `SELECT * FROM projects` without tenant filter = data leak. Audit pattern: grep all queries that don't include `tenant_id` predicate.

### 1.5 Cross-tenant isolation testing (mandatory)

```typescript
// apps/backend/tests/integration/tenant-isolation.test.ts
describe('Tenant isolation', () => {
  let tenantA: Tenant, tenantB: Tenant;
  let userA: User, userB: User;

  beforeAll(async () => {
    tenantA = await createTenant({ slug: 'a' });
    tenantB = await createTenant({ slug: 'b' });
    userA = await createUserWithMembership(tenantA, 'owner');
    userB = await createUserWithMembership(tenantB, 'owner');
  });

  it('user A cannot read tenant B projects', async () => {
    const projectB = await createProject({ tenantId: tenantB.id, name: 'secret' });

    const res = await request(app)
      .get(`/api/v1/projects/${projectB.id}`)
      .set('Authorization', `Bearer ${tokenFor(userA)}`)
      .set('Host', 'a.app.com');

    expect(res.status).toBe(404); // NOT 403 — don't reveal existence
  });

  it('user A cannot list tenant B projects', async () => {
    await createProject({ tenantId: tenantB.id });

    const res = await request(app)
      .get('/api/v1/projects')
      .set('Authorization', `Bearer ${tokenFor(userA)}`)
      .set('Host', 'a.app.com');

    expect(res.body.data).toHaveLength(0);
  });

  it('user A cannot mutate tenant B resources', async () => {
    const projectB = await createProject({ tenantId: tenantB.id });

    const res = await request(app)
      .patch(`/api/v1/projects/${projectB.id}`)
      .set('Authorization', `Bearer ${tokenFor(userA)}`)
      .set('Host', 'a.app.com')
      .send({ name: 'pwned' });

    expect(res.status).toBe(404);
    const stillIntact = await projectRepo.findById(projectB.id);
    expect(stillIntact.name).not.toBe('pwned');
  });

  it('cross-tenant pagination cursor leak', async () => {
    // Cursor from tenant B should be invalid in tenant A context
    const cursorB = await getNextPageCursor({ tenantId: tenantB.id });
    const res = await request(app)
      .get(`/api/v1/projects?cursor=${cursorB}`)
      .set('Authorization', `Bearer ${tokenFor(userA)}`)
      .set('Host', 'a.app.com');

    expect(res.body.data).toHaveLength(0); // never tenant B data
  });
});
```

This test suite is **mandatory** for every tenant-scoped resource. dev-squad's auditor agent runs this as part of Phase 5.6 stability execution.

---

## 2. Subscription Billing (Stripe)

### 2.1 Lifecycle overview

```
checkout.session.completed → subscription.created → invoice.payment_succeeded
                                                  ↘ invoice.payment_failed → grace_period
subscription.updated (plan change, qty change)
subscription.deleted (cancellation at period end OR immediate)
```

### 2.2 Plan model

```typescript
export interface Plan {
  id: string;
  slug: string;                    // 'free', 'pro', 'business', 'enterprise'
  name: string;
  description: string;
  status: 'active' | 'archived';
  isPublic: boolean;               // hidden plans for grandfathered/custom
  pricing: {
    monthlyAmountCents: number;
    yearlyAmountCents: number;
    currency: string;              // 'USD', 'EUR', etc.
    stripePriceIdMonthly?: string;
    stripePriceIdYearly?: string;
  };
  seatLimit?: number;              // null = unlimited
  trialDays?: number;
  entitlements: Record<string, EntitlementValue>;
  sortOrder: number;
}

export type EntitlementValue =
  | { type: 'boolean'; value: boolean }
  | { type: 'number'; value: number }
  | { type: 'unlimited' };
```

### 2.3 Stripe webhook handler

```typescript
// apps/backend/src/api/billing/stripeWebhook.ts
export async function handleStripeWebhook(req: Request, res: Response) {
  const sig = req.headers['stripe-signature'];
  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,                            // MUST be raw body, not parsed
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    return res.status(400).send(`Webhook signature verification failed: ${err.message}`);
  }

  // Idempotency: check if event already processed
  const existing = await processedEventRepo.findByEventId(event.id);
  if (existing) {
    return res.status(200).send({ received: true, deduped: true });
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed':
        await handleCheckoutCompleted(event.data.object as Stripe.Checkout.Session);
        break;
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
        await handleSubscriptionChange(event.data.object as Stripe.Subscription);
        break;
      case 'customer.subscription.deleted':
        await handleSubscriptionDeleted(event.data.object as Stripe.Subscription);
        break;
      case 'invoice.payment_succeeded':
        await handlePaymentSucceeded(event.data.object as Stripe.Invoice);
        break;
      case 'invoice.payment_failed':
        await handlePaymentFailed(event.data.object as Stripe.Invoice);
        break;
      default:
        // log and ignore
        logger.info({ eventType: event.type }, 'Unhandled Stripe event');
    }

    await processedEventRepo.markProcessed(event.id);
    res.status(200).send({ received: true });
  } catch (err) {
    logger.error({ err, eventId: event.id }, 'Webhook handler failed');
    // return 500 → Stripe will retry (exponential backoff up to 3 days)
    res.status(500).send({ error: 'processing_failed' });
  }
}
```

### 2.4 Plan change with proration

```typescript
export async function changePlan(tenantId: string, newPlanId: string, prorationBehavior: 'create_prorations' | 'none' = 'create_prorations') {
  const tenant = await tenantRepo.findById(tenantId);
  if (!tenant.stripeSubscriptionId) {
    throw new ApiError(400, 'NO_SUBSCRIPTION', 'Tenant has no active subscription');
  }
  const newPlan = await planRepo.findById(newPlanId);
  const subscription = await stripe.subscriptions.retrieve(tenant.stripeSubscriptionId);

  await stripe.subscriptions.update(tenant.stripeSubscriptionId, {
    items: [{
      id: subscription.items.data[0].id,
      price: newPlan.pricing.stripePriceIdMonthly,
    }],
    proration_behavior: prorationBehavior,
  });

  // tenant.planId updated by webhook; no direct mutation here
  return { status: 'pending_webhook' };
}
```

### 2.5 Promo codes & coupons

```typescript
// Use Stripe-managed promo codes — don't roll your own
export async function createCheckoutSession(tenantId: string, planId: string, promoCode?: string) {
  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    customer: tenant.stripeCustomerId,
    line_items: [{ price: plan.pricing.stripePriceIdMonthly, quantity: 1 }],
    discounts: promoCode ? [{ coupon: await resolvePromoCode(promoCode) }] : undefined,
    success_url: `${process.env.APP_URL}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.APP_URL}/billing/cancel`,
    metadata: { tenantId, planId },     // ← critical for webhook to know which tenant/plan
  });
  return session;
}
```

---

## 3. Plan-Based Access Control / Entitlements

### 3.1 Entitlement check pattern

```typescript
// packages/shared/src/entitlements.ts
export async function hasEntitlement(tenant: Tenant, key: string): Promise<boolean> {
  const plan = await planRepo.findById(tenant.planId);
  const entitlement = plan.entitlements[key];
  if (!entitlement) return false;
  if (entitlement.type === 'boolean') return entitlement.value;
  if (entitlement.type === 'unlimited') return true;
  return false; // number type needs separate quota check
}

export async function checkQuota(tenant: Tenant, key: string, currentUsage: number): Promise<{ allowed: boolean; limit: number | 'unlimited'; remaining: number | 'unlimited' }> {
  const plan = await planRepo.findById(tenant.planId);
  const entitlement = plan.entitlements[key];
  if (!entitlement) return { allowed: false, limit: 0, remaining: 0 };
  if (entitlement.type === 'unlimited') return { allowed: true, limit: 'unlimited', remaining: 'unlimited' };
  if (entitlement.type === 'number') {
    const remaining = entitlement.value - currentUsage;
    return { allowed: remaining > 0, limit: entitlement.value, remaining };
  }
  return { allowed: false, limit: 0, remaining: 0 };
}
```

### 3.2 Middleware-based gating

```typescript
// apps/backend/src/middleware/requireEntitlement.ts
export function requireEntitlement(key: string) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (!await hasEntitlement(req.tenant, key)) {
      throw new ApiError(402, 'ENTITLEMENT_REQUIRED', `Plan upgrade needed for: ${key}`, {
        requiredFeature: key,
        currentPlan: req.tenant.planId,
      });
    }
    next();
  };
}

// usage:
router.post('/api/v1/exports', requireEntitlement('feature.bulk_export'), exportController);
```

### 3.3 Seat counting

```typescript
export async function canAddMember(tenant: Tenant): Promise<{ allowed: boolean; current: number; limit: number | 'unlimited' }> {
  const plan = await planRepo.findById(tenant.planId);
  if (!plan.seatLimit) return { allowed: true, current: 0, limit: 'unlimited' };
  const current = await membershipRepo.countActive(tenant.id);
  return { allowed: current < plan.seatLimit, current, limit: plan.seatLimit };
}
```

---

## 4. API Key Management

```typescript
export interface ApiKey {
  id: string;
  tenantId: string;
  name: string;                   // user-given label
  keyHash: string;                // sha256 hash of full key
  keyPreview: string;             // first 8 + last 4 chars only
  scopes: string[];               // ['read:projects', 'write:tasks']
  lastUsedAt?: Date;
  expiresAt?: Date;
  createdBy: string;
  revokedAt?: Date;
}

export async function createApiKey(tenantId: string, name: string, scopes: string[], userId: string) {
  const fullKey = `sk_${crypto.randomBytes(32).toString('hex')}`;     // never stored
  const keyHash = crypto.createHash('sha256').update(fullKey).digest('hex');
  const keyPreview = fullKey.slice(0, 8) + '...' + fullKey.slice(-4);

  await apiKeyRepo.create({
    tenantId, name, keyHash, keyPreview, scopes, createdBy: userId,
  });

  // Return full key ONLY on creation. After this, it's lost forever.
  return { fullKey, keyPreview };
}

export async function authenticateApiKey(rawKey: string): Promise<{ tenant: Tenant; scopes: string[] } | null> {
  const keyHash = crypto.createHash('sha256').update(rawKey).digest('hex');
  const apiKey = await apiKeyRepo.findByHash(keyHash);
  if (!apiKey || apiKey.revokedAt) return null;
  if (apiKey.expiresAt && apiKey.expiresAt < new Date()) return null;

  // Update lastUsedAt asynchronously (don't block request)
  apiKeyRepo.touchLastUsed(apiKey.id).catch(err => logger.warn({ err }, 'lastUsedAt update failed'));

  const tenant = await tenantRepo.findById(apiKey.tenantId);
  return { tenant, scopes: apiKey.scopes };
}
```

**Security rules:**
- Full key shown ONCE at creation, then only `keyPreview` displayed in UI
- Hash with SHA-256 minimum (or HMAC if key is short)
- Constant-time comparison when verifying — but hash lookup avoids timing attacks
- Scope-based authorization: every endpoint declares required scope
- Revocation: soft delete (set `revokedAt`), don't hard-delete (audit trail)

---

## 5. Outbound Webhooks

### 5.1 Event definition + delivery

```typescript
export interface WebhookEndpoint {
  id: string;
  tenantId: string;
  url: string;
  secret: string;                 // for HMAC signing
  enabledEvents: string[];        // ['user.created', 'project.deleted', '*']
  status: 'active' | 'disabled' | 'failed';
  failureCount: number;
  lastSuccessAt?: Date;
  lastFailureAt?: Date;
  createdAt: Date;
}

export interface WebhookDelivery {
  id: string;
  webhookId: string;
  eventType: string;
  eventId: string;
  payload: object;
  status: 'pending' | 'success' | 'failed' | 'dlq';
  attemptCount: number;
  nextAttemptAt?: Date;
  responseStatus?: number;
  responseBody?: string;
  durationMs?: number;
  createdAt: Date;
}
```

### 5.2 Signed delivery

```typescript
export async function deliverWebhook(delivery: WebhookDelivery, endpoint: WebhookEndpoint) {
  const body = JSON.stringify({
    id: delivery.eventId,
    type: delivery.eventType,
    created: Math.floor(Date.now() / 1000),
    data: delivery.payload,
  });

  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signedPayload = `${timestamp}.${body}`;
  const signature = crypto.createHmac('sha256', endpoint.secret).update(signedPayload).digest('hex');

  const start = Date.now();
  try {
    const res = await fetch(endpoint.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Timestamp': timestamp,
        'X-Webhook-Signature': `t=${timestamp},v1=${signature}`,
        'X-Webhook-Id': delivery.id,
      },
      body,
      signal: AbortSignal.timeout(15_000),     // 15s hard timeout
    });

    const success = res.status >= 200 && res.status < 300;
    await deliveryRepo.update(delivery.id, {
      status: success ? 'success' : 'failed',
      responseStatus: res.status,
      responseBody: (await res.text()).slice(0, 1000),     // cap at 1KB
      durationMs: Date.now() - start,
    });

    if (!success) await scheduleRetry(delivery);
  } catch (err) {
    await deliveryRepo.update(delivery.id, {
      status: 'failed',
      responseBody: err.message.slice(0, 1000),
      durationMs: Date.now() - start,
    });
    await scheduleRetry(delivery);
  }
}
```

### 5.3 Retry with exponential backoff + DLQ

```typescript
const MAX_ATTEMPTS = 8;
const RETRY_DELAYS_MS = [
  60_000,        // 1 min
  300_000,       // 5 min
  900_000,       // 15 min
  3_600_000,     // 1 hour
  14_400_000,    // 4 hours
  43_200_000,    // 12 hours
  86_400_000,    // 24 hours
];

async function scheduleRetry(delivery: WebhookDelivery) {
  if (delivery.attemptCount >= MAX_ATTEMPTS) {
    // Dead letter queue — manual intervention required
    await deliveryRepo.update(delivery.id, { status: 'dlq' });
    await notifyAdmin('Webhook DLQ', { deliveryId: delivery.id, webhookId: delivery.webhookId });

    // Disable the webhook if 3+ deliveries hit DLQ in 24h
    const recentDLQ = await deliveryRepo.countDLQInWindow(delivery.webhookId, '24h');
    if (recentDLQ >= 3) {
      await webhookRepo.disable(delivery.webhookId, 'too many DLQ');
    }
    return;
  }

  const delay = RETRY_DELAYS_MS[delivery.attemptCount];
  const nextAttemptAt = new Date(Date.now() + delay);
  await deliveryRepo.update(delivery.id, {
    attemptCount: delivery.attemptCount + 1,
    nextAttemptAt,
    status: 'pending',
  });
}
```

### 5.4 Customer verification snippet (provide in docs)

```typescript
// Customer-side verification — provide in your /docs/webhooks page
function verifyWebhook(payload: string, signature: string, timestamp: string, secret: string) {
  // Reject if timestamp older than 5 minutes (replay protection)
  if (Math.abs(Date.now() / 1000 - parseInt(timestamp)) > 300) return false;

  const expected = crypto
    .createHmac('sha256', secret)
    .update(`${timestamp}.${payload}`)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signature.replace('v1=', '')),
    Buffer.from(expected)
  );
}
```

---

## 6. Audit Logs

Audit log ≠ system log. Audit log answers "who did what to which resource when, from where". Immutable, searchable, regulatory-compliance-ready.

```typescript
export interface AuditLogEntry {
  id: string;
  tenantId: string;
  actorType: 'user' | 'api_key' | 'system' | 'admin';
  actorId: string;
  actorIpAddress?: string;
  actorUserAgent?: string;
  action: string;                    // 'project.created', 'member.role_changed'
  resourceType: string;
  resourceId: string;
  before?: object;                   // state before mutation
  after?: object;                    // state after mutation
  metadata?: object;                 // arbitrary context
  createdAt: Date;
}
```

### Helper

```typescript
export async function audit(req: Request, action: string, resource: { type: string; id: string }, before?: object, after?: object) {
  await auditRepo.append({
    tenantId: req.tenant?.id,
    actorType: req.apiKey ? 'api_key' : 'user',
    actorId: req.apiKey?.id ?? req.user?.id,
    actorIpAddress: req.ip,
    actorUserAgent: req.headers['user-agent'],
    action,
    resourceType: resource.type,
    resourceId: resource.id,
    before,
    after,
  });
}

// usage in controller:
const before = await projectRepo.findById(id);
await projectRepo.update(id, { name: req.body.name });
const after = await projectRepo.findById(id);
await audit(req, 'project.updated', { type: 'project', id }, before, after);
```

**Storage strategy:**
- Hot tier: last 90 days in primary DB, indexed on (tenant_id, created_at desc)
- Cold tier: archive to S3/GCS as compressed JSON Lines, queryable via Athena/BigQuery
- Never delete — soft-delete the resource, audit log persists
- Mask PII fields in `before`/`after` for compliance (redact email/SSN/etc. based on field tags)

---

## 7. In-App Notifications & Messages

```typescript
export interface Notification {
  id: string;
  tenantId: string;
  recipientUserId: string;
  category: 'mention' | 'invitation' | 'billing' | 'system' | 'comment';
  title: string;
  body: string;
  link?: string;                    // app-internal URL
  payload?: object;                 // structured data for action
  readAt?: Date;
  archivedAt?: Date;
  createdAt: Date;
}
```

### Multi-channel delivery

```typescript
export async function notify(notification: Omit<Notification, 'id' | 'readAt' | 'archivedAt' | 'createdAt'>) {
  const created = await notificationRepo.create(notification);

  // Realtime push to in-app (websocket / SSE / polling)
  await realtime.publish(`user:${notification.recipientUserId}:notifications`, created);

  // Check user preferences for additional channels
  const prefs = await prefsRepo.findByUser(notification.recipientUserId);
  if (prefs.email_for[notification.category]) {
    await emailQueue.enqueue('notification', { notificationId: created.id });
  }
  if (prefs.push_for[notification.category]) {
    await pushQueue.enqueue('notification', { notificationId: created.id });
  }

  return created;
}
```

---

## 8. Transactional Email

Categories every SaaS needs:
- Verify email (signup)
- Reset password
- Invitation to tenant
- Payment receipt / failure
- Trial expiring soon
- Subscription cancelled

```typescript
// apps/backend/src/email/templates.ts
export const emailTemplates = {
  'verify-email': {
    subject: 'Verify your {productName} email',
    react: VerifyEmailTemplate,           // React Email or MJML component
  },
  'reset-password': {
    subject: 'Reset your {productName} password',
    react: ResetPasswordTemplate,
  },
  // ...
};

export async function sendEmail<T extends keyof typeof emailTemplates>(
  template: T,
  to: string,
  data: TemplateData<T>
) {
  const tpl = emailTemplates[template];
  const html = await render(tpl.react(data));
  const subject = interpolate(tpl.subject, { productName: process.env.PRODUCT_NAME });

  // Single provider abstraction — swap Resend/SendGrid/SES without changing call sites
  await emailProvider.send({ to, subject, html });

  await emailLogRepo.append({ template, to, sentAt: new Date() });
}
```

**Anti-patterns:**
- Never embed plaintext API keys / tokens in email body
- Always include unsubscribe link for non-transactional categories (compliance)
- Rate-limit per recipient (max 5 emails / hour) to prevent abuse
- DKIM + SPF + DMARC configured at DNS layer (devops responsibility)

---

## 9. Hybrid Validation (Two-Layer Defense)

Lesson from production SaaS: **Go struct tags or Zod alone is not enough.** A bug in the app layer can write malformed data to the DB. Add a second layer at the DB.

### 9.1 Node.js + Zod + Postgres CHECK constraints

```typescript
// Layer 1: app-level validation
export const createProjectSchema = z.object({
  name: z.string().min(1).max(120),
  visibility: z.enum(['private', 'team', 'public']),
  budget: z.number().int().min(0).optional(),
});

// Layer 2: DB-level CHECK
// migrations/001_projects.sql
// CREATE TABLE projects (
//   ...
//   name VARCHAR(120) NOT NULL CHECK (length(name) >= 1),
//   visibility VARCHAR(20) NOT NULL CHECK (visibility IN ('private', 'team', 'public')),
//   budget INTEGER CHECK (budget >= 0)
// );
```

### 9.2 Go struct tags + MongoDB JSON Schema (lastsaas pattern)

```go
// Layer 1: Go struct tags via go-playground/validator
type Tenant struct {
    ID       string `bson:"_id"        validate:"required,uuid4"`
    Slug     string `bson:"slug"       validate:"required,min=3,max=40,alphanum"`
    Name     string `bson:"name"       validate:"required,min=1,max=120"`
    PlanID   string `bson:"plan_id"    validate:"required,uuid4"`
    Status   string `bson:"status"     validate:"required,oneof=active suspended cancelled"`
}

// Layer 2: MongoDB JSON Schema (db/schema.go)
func tenantsSchema() CollectionSchema {
    return CollectionSchema{
        Collection: "tenants",
        Schema: bson.M{
            "$jsonSchema": bson.M{
                "bsonType": "object",
                "required": []string{"_id", "slug", "name", "plan_id", "status"},
                "properties": bson.M{
                    "slug":   bson.M{"bsonType": "string", "minLength": 3, "maxLength": 40, "pattern": "^[a-zA-Z0-9]+$"},
                    "name":   bson.M{"bsonType": "string", "minLength": 1, "maxLength": 120},
                    "status": bson.M{"enum": []string{"active", "suspended", "cancelled"}},
                },
            },
        },
    }
}
```

**Sync rule:** When changing the struct, also change the schema function. Test:

```go
func TestTenantValidationSync(t *testing.T) {
    tenant := Tenant{Status: "invalid"}                     // App-level fail
    err := validate.Struct(tenant)
    assert.Error(t, err)

    _, dbErr := coll.InsertOne(ctx, bson.M{"status": "invalid"})    // DB-level fail
    assert.ErrorContains(t, dbErr, "Document failed validation")
}
```

If both layers reject the same input, sync is good. If only one rejects, you have drift.

---

## 10. Admin Scope (Separate from Customer Scope)

```typescript
// Admin uses a "root tenant" — a special tenant with id = '00000000-0000-0000-0000-000000000000'
// or a dedicated admin_users table

// apps/backend/src/middleware/requireAdmin.ts
export async function requireAdmin(req: Request, res: Response, next: NextFunction) {
  // Option A: root-tenant API key (lastsaas pattern)
  if (req.apiKey?.tenantId !== ROOT_TENANT_ID) {
    throw new ApiError(403, 'ADMIN_REQUIRED', 'Admin authority required');
  }

  // Option B: dedicated admin_users table with role check
  // const adminUser = await adminUserRepo.findById(req.user.id);
  // if (!adminUser) throw new ApiError(403, 'ADMIN_REQUIRED');

  next();
}

// Admin routes mounted under /admin/api/v1/*
app.use('/admin/api/v1', requireAdmin, adminRouter);
```

**Admin endpoints typically include:**
- list/get all tenants
- list/get all users (across tenants)
- financial metrics (revenue, ARR, MRR, DAU, MAU)
- system logs search
- health metrics across nodes
- runtime config mutation
- announcement publish/draft
- promo code management

These should NEVER be exposed to customer-scope tokens, even with admin role within their tenant.

---

## 11. Usage Events / Metering

For usage-based billing or quota enforcement:

```typescript
export interface UsageEvent {
  id: string;
  tenantId: string;
  meterId: string;                  // 'api_calls', 'storage_bytes', 'compute_seconds'
  amount: number;                   // 1 for count, N for bytes/seconds
  occurredAt: Date;
  idempotencyKey?: string;          // dedupe duplicate emissions
  metadata?: object;
}
```

```typescript
export async function meter(tenantId: string, meterId: string, amount: number, metadata?: object) {
  await usageEventRepo.append({
    tenantId, meterId, amount, occurredAt: new Date(), metadata,
  });

  // For billing: aggregate hourly into materialized view
  // For quota check: compare against plan limit
}

// Aggregation query (run hourly via cron):
// INSERT INTO usage_aggregates (tenant_id, meter_id, period_start, period_end, total)
// SELECT tenant_id, meter_id, date_trunc('hour', occurred_at), date_trunc('hour', occurred_at) + interval '1 hour', sum(amount)
// FROM usage_events
// WHERE occurred_at >= now() - interval '1 hour'
// GROUP BY tenant_id, meter_id, date_trunc('hour', occurred_at);
```

For Stripe usage-based pricing, push aggregates to Stripe via `subscriptionItems.createUsageRecord()`.

---

## 12. Runtime Config / Feature Flags

```typescript
export interface ConfigVar {
  key: string;                      // 'feature.new_dashboard', 'limit.max_uploads'
  value: any;                       // typed via zod at read time
  type: 'boolean' | 'number' | 'string' | 'json';
  scope: 'global' | 'per_tenant' | 'per_user';
  scopeId?: string;                 // tenant_id or user_id for non-global
  description: string;
  updatedAt: Date;
  updatedBy: string;
}

export async function getConfig<T>(key: string, defaultValue: T, ctx?: { tenantId?: string; userId?: string }): Promise<T> {
  // Resolution order: per_user > per_tenant > global > default
  if (ctx?.userId) {
    const userScoped = await configRepo.find(key, 'per_user', ctx.userId);
    if (userScoped) return userScoped.value;
  }
  if (ctx?.tenantId) {
    const tenantScoped = await configRepo.find(key, 'per_tenant', ctx.tenantId);
    if (tenantScoped) return tenantScoped.value;
  }
  const global = await configRepo.find(key, 'global');
  return global?.value ?? defaultValue;
}
```

**Cache layer:** in-process LRU with 60s TTL. Mutation invalidates cache via Redis pub/sub.

---

## 13. SSO / Multi-IdP

```typescript
export interface SsoConnection {
  id: string;
  tenantId: string;
  provider: 'google' | 'microsoft' | 'okta' | 'saml' | 'oidc';
  status: 'active' | 'pending_verification' | 'disabled';
  config: SsoConfig;                // provider-specific (clientId, tenantId, etc.)
  domains: string[];                // email domains routed to this connection
  enforced: boolean;                // if true, password login disabled for these domains
  createdAt: Date;
}
```

Login flow:
1. User enters email
2. Lookup `domains` table — if match found, redirect to that SSO provider
3. If no match + `enforced` for the domain, reject ("contact your admin")
4. Otherwise allow password / regular auth

Use battle-tested libraries (Auth.js / Lucia / WorkOS / Auth0) — don't roll SAML by hand.

---

## 14. White-label / Tenant Branding

```typescript
export interface TenantBranding {
  tenantId: string;
  logoUrl?: string;
  faviconUrl?: string;
  primaryColor?: string;            // CSS color
  customDomain?: string;            // for paid tiers only
  emailFromName?: string;
  emailFromAddress?: string;        // requires verification
  sigil?: { text: string; bg: string; fg: string };  // fallback when no logo
  customCss?: string;               // sandboxed, scope-prefixed
}
```

**Critical:** custom CSS = XSS surface. Sandbox via:
- `<style>` element with scoped selector prefix (e.g., `.tenant-{id}-scope ...`)
- CSS-only properties (no `expression()`, no JS URLs)
- Length limit (~10KB)
- CSP header restricts inline style usage

---

## 15. Admin Drill-Down Endpoints (backend side — frontend in Part 2)

For backend supporting drill-down dashboards, expose endpoints in this hierarchy:

```
GET  /admin/api/v1/dashboard/summary                   ← KPI cards (level 1)
GET  /admin/api/v1/financials/metrics?range=30d        ← time-series (level 2)
GET  /admin/api/v1/financials/transactions?           ← row table (level 3)
       cursor=...&filter[plan]=pro&filter[status]=paid
GET  /admin/api/v1/tenants/:id                         ← entity detail (level 4)
GET  /admin/api/v1/tenants/:id/usage-events           ← event log (level 5)
```

Standard pagination:
```typescript
{
  data: Item[],
  pagination: {
    cursor: string | null,         // null = no more pages
    hasMore: boolean,
    totalCount?: number,           // optional, expensive
  }
}
```

Standard time-series response:
```typescript
{
  series: [{
    metric: 'mrr' | 'arr' | 'dau' | 'mau' | 'churn_rate',
    points: [{ timestamp: ISO8601, value: number }]
  }],
  range: { from: ISO8601, to: ISO8601, granularity: 'hour' | 'day' | 'week' | 'month' }
}
```

---

# Part 2: Frontend Admin Dashboard & Drill-Down

A drill-down is not just nested pages. It's a **stateful exploration session** where every step must be:
1. Deep-linkable (sharing a URL re-creates the exact view)
2. Reversible (back button works correctly)
3. Filterable in composition (multiple filters across levels remain coherent)
4. Permission-aware (drill items hidden if user lacks entitlement)

If any of these breaks, drill-down becomes "click around and pray" — the worst kind of dashboard.

---

## 16. The Five Drill Levels

```
Level 1: KPI cards               (what's happening)
   ↓ click a metric
Level 2: Time-series chart        (when did it change)
   ↓ brush/zoom date range OR click a segment
Level 3: Segment table            (who/which contributes)
   ↓ click a row
Level 4: Entity detail            (what's the full picture for this row)
   ↓ click an activity
Level 5: Event detail              (what happened in this moment)
```

Not every dashboard needs all 5. But the pattern is consistent — each level narrows the dimension while preserving the previous filters.

### Example: SaaS revenue drill

| Level | View | Example URL |
|---|---|---|
| 1 | KPI: MRR $42k, ARR $504k, Churn 2.1% | `/admin/dashboard` |
| 2 | MRR over last 90 days, line chart | `/admin/dashboard/mrr?range=90d` |
| 3 | Top tenants contributing to MRR | `/admin/dashboard/mrr/tenants?range=90d&sort=mrr_desc` |
| 4 | Tenant "Acme Corp" detail page | `/admin/tenants/acme?range=90d&from_view=mrr` |
| 5 | Specific subscription change event | `/admin/tenants/acme/events/sub_chg_42?range=90d` |

The breadcrumb at level 5 reads: `Dashboard > MRR > Tenants > Acme > Subscription change`.

---

## 17. URL State Architecture

URL is the source of truth. Component state mirrors URL.

### 17.1 Search params schema (Zod-typed)

```typescript
// app/admin/dashboard/searchParams.ts
import { z } from 'zod';
import { useSearchParams } from 'next/navigation';

export const dashboardSearchSchema = z.object({
  range: z.enum(['7d', '30d', '90d', 'ytd', 'custom']).default('30d'),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  metric: z.enum(['mrr', 'arr', 'dau', 'mau', 'churn']).optional(),
  filter_plan: z.array(z.string()).default([]),
  filter_status: z.enum(['active', 'trial', 'cancelled', 'all']).default('all'),
  segment: z.string().optional(),
  sort: z.enum(['mrr_desc', 'mrr_asc', 'name_asc', 'created_desc']).default('mrr_desc'),
  cursor: z.string().optional(),
});

export type DashboardSearch = z.infer<typeof dashboardSearchSchema>;

export function useDashboardSearch(): [DashboardSearch, (next: Partial<DashboardSearch>) => void] {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  const current = useMemo(() => {
    const obj = Object.fromEntries(params);
    obj.filter_plan = params.getAll('filter_plan');
    return dashboardSearchSchema.parse(obj);
  }, [params]);

  const setSearch = useCallback((next: Partial<DashboardSearch>) => {
    const merged = { ...current, ...next };
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(merged)) {
      if (v == null || v === '' || (Array.isArray(v) && v.length === 0)) continue;
      if (Array.isArray(v)) v.forEach(item => sp.append(k, item));
      else sp.set(k, String(v));
    }
    router.push(`${pathname}?${sp.toString()}`);
  }, [current, pathname, router]);

  return [current, setSearch];
}
```

**Why this matters:**
- Refresh = same view (no state lost)
- Share URL = same view for recipient
- Back button = previous filter state
- Browser history = exploration trail

### 17.2 Don't store transient UI in URL

URL is for **shareable state**: filters, sort, segment, cursor.
URL is NOT for: hover state, modal open/close, scroll position, ephemeral form input.

Rule of thumb: would you want this state in a Slack-shared screenshot URL? If yes → URL. If no → component state.

---

## 18. Breadcrumb with State Preservation

```typescript
// components/Breadcrumb.tsx
interface BreadcrumbStep {
  label: string;
  href: string;          // includes preserved search params
}

export function Breadcrumb({ steps }: { steps: BreadcrumbStep[] }) {
  return (
    <nav aria-label="Breadcrumb" className="flex items-center text-sm text-muted-foreground">
      {steps.map((step, i) => (
        <Fragment key={step.href}>
          {i > 0 && <ChevronRight className="mx-2 h-4 w-4" aria-hidden />}
          {i === steps.length - 1 ? (
            <span aria-current="page" className="text-foreground font-medium">{step.label}</span>
          ) : (
            <Link href={step.href} className="hover:text-foreground transition-colors">
              {step.label}
            </Link>
          )}
        </Fragment>
      ))}
    </nav>
  );
}
```

Build the trail in each route:

```typescript
// app/admin/dashboard/mrr/tenants/page.tsx
export default function MrrTenantsPage() {
  const [search] = useDashboardSearch();
  const range = search.range;

  const trail: BreadcrumbStep[] = [
    { label: 'Dashboard', href: '/admin/dashboard' },
    { label: 'MRR', href: `/admin/dashboard/mrr?range=${range}` },
    { label: 'Tenants', href: `/admin/dashboard/mrr/tenants?range=${range}&sort=${search.sort}` },
  ];

  return (
    <>
      <Breadcrumb steps={trail} />
      {/* ... */}
    </>
  );
}
```

**Critical:** every breadcrumb link must carry the relevant filters. Going back to "MRR" from level 3 should preserve the `range` so the user doesn't lose context.

---

## 19. Time-Series Charts with Brush + Zoom

Use a charting library that supports brush. Recommendations:
- **recharts** (good defaults, simple) — `<Brush>` component
- **visx** (composable, low-level) — full control, steeper learning
- **nivo** (opinionated, good for non-interactive)

### 19.1 Brush-driven date range update

```tsx
import { LineChart, Line, XAxis, YAxis, Tooltip, Brush, ResponsiveContainer } from 'recharts';

export function MrrChart({ data, onRangeChange }: { data: TimeSeriesPoint[]; onRangeChange: (from: Date, to: Date) => void }) {
  return (
    <ResponsiveContainer width="100%" height={400}>
      <LineChart data={data} margin={{ top: 20, right: 16, bottom: 20, left: 0 }}>
        <XAxis dataKey="timestamp" tickFormatter={(ts) => format(new Date(ts), 'MMM d')} />
        <YAxis tickFormatter={(v) => `$${(v / 1000).toFixed(0)}k`} />
        <Tooltip formatter={(v: number) => `$${v.toLocaleString()}`} />
        <Line type="monotone" dataKey="value" stroke="hsl(var(--primary))" strokeWidth={2} dot={false} />
        <Brush
          dataKey="timestamp"
          height={30}
          stroke="hsl(var(--primary))"
          tickFormatter={(ts) => format(new Date(ts), 'MMM')}
          onChange={(range) => {
            if (range?.startIndex != null && range?.endIndex != null) {
              const from = new Date(data[range.startIndex].timestamp);
              const to = new Date(data[range.endIndex].timestamp);
              onRangeChange(from, to);
            }
          }}
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
```

`onRangeChange` updates URL state which re-fetches data at the new range. Debounce by 300ms to avoid hammering the API while user is dragging.

### 19.2 Granularity auto-selection

Backend response (per Section 15) should include `granularity` chosen for the requested range:

| Range | Granularity | Points |
|---|---|---|
| < 24h | 5min | ~288 |
| 1-7 days | hour | 24-168 |
| 7-90 days | day | 7-90 |
| > 90 days | week | 13+ |
| > 1 year | month | 12+ |

Aim for 50-300 points per chart — fewer = blurry, more = noisy.

---

## 20. Virtualized Tables (Large Datasets)

Default `<table>` choke at ~500 rows. Virtualization renders only visible rows.

### 20.1 TanStack Virtual + TanStack Table

```bash
pnpm add @tanstack/react-table @tanstack/react-virtual
```

```tsx
import { useVirtualizer } from '@tanstack/react-virtual';
import { useReactTable, getCoreRowModel, flexRender, type ColumnDef } from '@tanstack/react-table';

export function VirtualTable<T>({ data, columns }: { data: T[]; columns: ColumnDef<T>[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const table = useReactTable({ data, columns, getCoreRowModel: getCoreRowModel() });
  const { rows } = table.getRowModel();

  const rowVirtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 48,
    overscan: 8,
  });

  return (
    <div ref={parentRef} className="h-[600px] overflow-auto rounded-md border">
      <table className="w-full">
        <thead className="sticky top-0 bg-background z-10">
          {table.getHeaderGroups().map(hg => (
            <tr key={hg.id}>
              {hg.headers.map(h => (
                <th key={h.id} className="px-4 py-2 text-left">
                  {flexRender(h.column.columnDef.header, h.getContext())}
                </th>
              ))}
            </tr>
          ))}
        </thead>
        <tbody style={{ height: `${rowVirtualizer.getTotalSize()}px`, position: 'relative' }}>
          {rowVirtualizer.getVirtualItems().map(vRow => {
            const row = rows[vRow.index];
            return (
              <tr
                key={row.id}
                style={{
                  position: 'absolute', top: 0, left: 0, width: '100%',
                  height: `${vRow.size}px`, transform: `translateY(${vRow.start}px)`,
                }}
                className="hover:bg-muted/50 cursor-pointer"
              >
                {row.getVisibleCells().map(cell => (
                  <td key={cell.id} className="px-4 py-2">
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </td>
                ))}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
```

### 20.2 Server-side pagination + infinite scroll

For 10k+ rows, virtualization isn't enough — you can't load everything client-side. Use cursor-based pagination + auto-fetch on scroll:

```tsx
const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
  queryKey: ['tenants', filters],
  queryFn: ({ pageParam }) => api.getTenants({ ...filters, cursor: pageParam }),
  getNextPageParam: (last) => last.pagination.cursor,
  initialPageParam: undefined,
});

const allRows = data?.pages.flatMap(p => p.data) ?? [];

useEffect(() => {
  const lastItem = [...rowVirtualizer.getVirtualItems()].at(-1);
  if (!lastItem) return;
  if (lastItem.index >= allRows.length - 1 && hasNextPage && !isFetchingNextPage) {
    fetchNextPage();
  }
}, [rowVirtualizer.getVirtualItems(), allRows.length, hasNextPage, isFetchingNextPage]);
```

---

## 21. Cross-Filter Coordination

When filters span multiple components (date range affects chart AND table AND KPI cards), centralize the filter state.

### 21.1 Filter store (Zustand)

```typescript
// stores/dashboardFilters.ts
import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';

interface FilterState {
  range: '7d' | '30d' | '90d' | 'custom';
  customFrom?: Date;
  customTo?: Date;
  plans: string[];
  status: 'all' | 'active' | 'trial' | 'cancelled';
  segment?: string;

  setRange: (range: FilterState['range']) => void;
  setCustomDates: (from: Date, to: Date) => void;
  togglePlan: (slug: string) => void;
  setStatus: (status: FilterState['status']) => void;
  setSegment: (segment: string | undefined) => void;
  reset: () => void;
}

export const useDashboardFilters = create<FilterState>()(
  subscribeWithSelector((set) => ({
    range: '30d',
    plans: [],
    status: 'all',
    setRange: (range) => set({ range, customFrom: undefined, customTo: undefined }),
    setCustomDates: (from, to) => set({ range: 'custom', customFrom: from, customTo: to }),
    togglePlan: (slug) => set((s) => ({
      plans: s.plans.includes(slug) ? s.plans.filter(p => p !== slug) : [...s.plans, slug],
    })),
    setStatus: (status) => set({ status }),
    setSegment: (segment) => set({ segment }),
    reset: () => set({ range: '30d', plans: [], status: 'all', segment: undefined, customFrom: undefined, customTo: undefined }),
  }))
);
```

### 21.2 Bridge filter store ↔ URL

```typescript
export function useDashboardFiltersUrl() {
  const filters = useDashboardFilters();
  const [urlSearch, setUrlSearch] = useDashboardSearch();

  // URL → store
  useEffect(() => {
    useDashboardFilters.setState({
      range: urlSearch.range,
      plans: urlSearch.filter_plan,
      status: urlSearch.filter_status,
      segment: urlSearch.segment,
    });
  }, [urlSearch.range, urlSearch.filter_plan, urlSearch.filter_status, urlSearch.segment]);

  // store → URL
  useEffect(() => {
    return useDashboardFilters.subscribe(
      (s) => ({ range: s.range, plans: s.plans, status: s.status, segment: s.segment }),
      (next) => setUrlSearch({
        range: next.range,
        filter_plan: next.plans,
        filter_status: next.status,
        segment: next.segment,
      }),
      { equalityFn: (a, b) => JSON.stringify(a) === JSON.stringify(b) }
    );
  }, [setUrlSearch]);
}
```

When user changes filter → store updates → URL updates → query refetches with new key.

---

## 22. Empty / Loading / Error States Per Drill Level

Each level needs all 4 states:

| State | Treatment |
|---|---|
| **Loading** | Skeleton shaped like the real content, NOT a spinner |
| **Empty** | Friendly copy + suggested next action |
| **Error** | Specific error class + recovery action |
| **Loaded** | Data render + cache invalidation hooks |

### 22.1 Skeleton matching layout

```tsx
function KpiCardsSkeleton() {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {[1, 2, 3, 4].map(i => (
        <div key={i} className="rounded-lg border p-4">
          <div className="h-4 w-24 bg-muted animate-pulse rounded" />
          <div className="mt-2 h-8 w-32 bg-muted animate-pulse rounded" />
          <div className="mt-1 h-3 w-20 bg-muted animate-pulse rounded" />
        </div>
      ))}
    </div>
  );
}
```

The skeleton matches dimensions and grid of the loaded version. No layout shift on transition.

### 22.2 Empty with action

```tsx
function EmptyState({ icon: Icon, title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <Icon className="h-12 w-12 text-muted-foreground mb-4" />
      <h3 className="text-lg font-medium">{title}</h3>
      <p className="text-sm text-muted-foreground mt-1 max-w-md">{description}</p>
      {action && <div className="mt-6">{action}</div>}
    </div>
  );
}

<EmptyState
  icon={SearchX}
  title="No tenants match these filters"
  description="Try widening the date range or removing plan filters."
  action={<Button variant="outline" onClick={resetFilters}>Reset filters</Button>}
/>
```

### 22.3 Error with class-specific copy

```tsx
function ErrorState({ error, retry }: { error: ApiError; retry: () => void }) {
  if (error.code === 'ENTITLEMENT_REQUIRED') {
    return <UpgradePrompt feature={error.requiredFeature} currentPlan={error.currentPlan} />;
  }
  if (error.code === 'TENANT_ACCESS_DENIED') {
    return <EmptyState icon={Lock} title="Access denied" description="Contact your tenant admin." />;
  }
  return (
    <EmptyState icon={AlertTriangle} title="Couldn't load data" description={error.message}
      action={<Button onClick={retry}>Try again</Button>} />
  );
}
```

---

## 23. Permission-Aware Drill Items

Some drill targets require entitlement (see Section 3). Hide rather than show-then-block.

```tsx
function PermissionGate({ feature, fallback, children }: {
  feature: string;
  fallback?: ReactNode;
  children: ReactNode;
}) {
  const tenant = useCurrentTenant();
  const allowed = useEntitlement(tenant, feature);
  if (!allowed) return fallback ?? null;
  return <>{children}</>;
}

// usage:
<KpiCard label="MRR" value={mrr.value} change={mrr.change} />
<PermissionGate feature="metrics.advanced">
  <KpiCard label="LTV/CAC" value={ltv.cacRatio} change={ltv.change} />
</PermissionGate>
```

For drill links — show locked state for discoverability:

```tsx
<PermissionGate
  feature="metrics.export"
  fallback={
    <Tooltip content="Upgrade to Pro to export">
      <Button variant="outline" disabled>
        <Download /> Export <Lock className="ml-2 h-3 w-3" />
      </Button>
    </Tooltip>
  }
>
  <Button onClick={handleExport}>
    <Download /> Export
  </Button>
</PermissionGate>
```

---

## 24. Real-Time Updates

For dashboards that update without refresh:

### 24.1 Polling (simplest, fits most cases)

```tsx
const { data } = useQuery({
  queryKey: ['dashboard-summary'],
  queryFn: api.getDashboardSummary,
  refetchInterval: 30_000,
  refetchOnWindowFocus: true,
});
```

### 24.2 Server-Sent Events (efficient one-way)

```tsx
useEffect(() => {
  const es = new EventSource(`/api/v1/dashboard/stream?token=${token}`);
  es.onmessage = (e) => {
    const update = JSON.parse(e.data);
    queryClient.setQueryData(['dashboard-summary'], (old) => ({ ...old, ...update }));
  };
  return () => es.close();
}, []);
```

### 24.3 WebSocket (bidirectional, for collab dashboards)

Use only when you need bidirectional events (live cursor, comments, multi-user filter sync). Otherwise polling/SSE is simpler.

**Indicator pattern:** show "last updated 12s ago" timestamp. Users trust freshness signals more than implicit "real-time" claims.

---

## 25. Performance Considerations

### 25.1 Bundle splitting per drill level

Each drill level is a separate route → automatic code splitting in Next.js App Router. Keep level-specific heavy deps (charts, virtualization) in level components, not in the layout.

### 25.2 Memoize derived data

```tsx
const sortedRows = useMemo(
  () => [...rows].sort((a, b) => sortKey === 'mrr_desc' ? b.mrr - a.mrr : a.mrr - b.mrr),
  [rows, sortKey]
);
```

For 10k+ rows, sort/filter on the server (Section 15 endpoints support cursor + filters). Client-side derivations are for ≤1k rows.

### 25.3 React Query stale time per level

```tsx
const { data } = useQuery({
  queryKey: ['mrr-chart', filters],
  queryFn: () => api.getMrrChart(filters),
  staleTime: 60_000,
  gcTime: 5 * 60_000,
});
```

| Level type | staleTime | Reason |
|---|---|---|
| Real-time KPIs | 0-30s | freshness matters |
| Time-series charts | 60s-5min | smooth interaction |
| Historical detail | 5min-1h | rarely changes |
| Audit log | 0 | should NOT be cached aggressively (compliance — Section 6) |

### 25.4 Suspense boundaries per level

```tsx
<Suspense fallback={<KpiCardsSkeleton />}>
  <KpiCards />
</Suspense>
<Suspense fallback={<ChartSkeleton />}>
  <MrrChart />
</Suspense>
<Suspense fallback={<TableSkeleton />}>
  <TenantsTable />
</Suspense>
```

Each section streams independently. Slow chart doesn't block fast KPI cards.

### 25.5 Optimistic UI for mutations

```tsx
const mutation = useMutation({
  mutationFn: api.markAllNotificationsRead,
  onMutate: async () => {
    await queryClient.cancelQueries({ queryKey: ['notifications'] });
    const previous = queryClient.getQueryData(['notifications']);
    queryClient.setQueryData(['notifications'], (old) =>
      old.map(n => ({ ...n, readAt: new Date() }))
    );
    return { previous };
  },
  onError: (err, _, context) => {
    queryClient.setQueryData(['notifications'], context?.previous);
    toast.error('Could not mark all as read');
  },
  onSettled: () => queryClient.invalidateQueries({ queryKey: ['notifications'] }),
});
```

UI updates instantly; rollback only if API fails.

---

## 26. Designer's Drill-Down Spec (Phase 3.5 output)

Designer must produce this artifact when project has dashboard with drill-down:

```markdown
# Drill-Down Spec

## Drill Hierarchy

\`\`\`mermaid
graph TD
  L1[KPI Cards: MRR / ARR / Churn / DAU] --> L2A[MRR Chart]
  L1 --> L2B[Churn Cohort]
  L2A --> L3[Tenants Contributing to MRR]
  L3 --> L4[Tenant Detail]
  L4 --> L5[Subscription Event Detail]
\`\`\`

## Per-Level Specification

### Level 1: KPI Cards
- Layout: 4-column grid desktop / 2-col tablet / 1-col mobile
- Card content: metric name, value, % change vs previous period, sparkline
- Empty state: "Awaiting first data" + ETA
- Interaction: click → level 2

### Level 2: Time-Series Chart
- Default range: 30d
- Range presets: 7d / 30d / 90d / YTD / custom
- Brush enabled at bottom — drag to zoom
- Tooltip on hover shows exact value + date
- Interaction: click point → level 3 with that day pre-selected

### Level 3: Segment Table
- Default sort: contribution to metric, desc
- Columns: name, value, % share, change, last activity
- Sortable headers
- Filter chips above table
- Row count badge
- Pagination: cursor-based, infinite scroll
- Interaction: click row → level 4

### Level 4: Entity Detail
- Layout: 2-column — summary panel left, activity feed right
- Summary panel: key facts + actions (edit / suspend / impersonate)
- Activity feed: scrollable, grouped by date
- Tabs for sub-views (overview / billing / members / api-keys)
- Interaction: click activity item → level 5

### Level 5: Event Detail
- Modal or side sheet (don't break navigation)
- Full event payload + before/after diff
- Actions: copy as cURL / open in admin / view audit trail

## Filter Model
- range: time window
- plans: multi-select chips
- status: tab pill (all / active / trial / cancelled)
- search: text input (name / email)

All filters compose. Every level respects all active filters.

## Anti-Patterns (Visual Gate input for qa-engineer)
- Spinner instead of skeleton ❌
- Empty table with no message ❌
- Generic "error" with no recovery ❌
- Drill link that loses filter state ❌
- Modal that blocks back-button ❌
- Click target < 44px on mobile ❌
- No keyboard navigation for drill ❌
```

This spec feeds:
- frontend agent: implementation
- qa-engineer Visual Gate: verification
- writer agent: empty/loading/error copy

## Anti-patterns (NEVER do these in SaaS)

### Backend anti-patterns
| Anti-pattern | Why it's wrong | Right way |
|---|---|---|
| `SELECT * FROM projects WHERE id = ?` (no tenant filter) | Cross-tenant data leak | Always include `tenant_id = ?` in every query, or rely on RLS |
| Storing API keys in plaintext | DB breach = total compromise | Hash with SHA-256, store preview only |
| Webhook delivery in request handler | Slow webhook = customer requests time out | Always async via queue |
| `UPDATE users SET role = 'admin'` from any endpoint | Privilege escalation | Role changes must go through dedicated audit-logged path |
| Hardcoded plan IDs in code | Changing plans requires deploy | Plan model in DB, queried by slug |
| Direct Stripe API call in business logic | Test pollution, vendor lock | Wrap in `billingProvider` abstraction |
| Synchronous email send in HTTP handler | SMTP slow → request times out | Always queue email |
| Skipping idempotency on payment endpoints | Double-charge on retry | Idempotency-Key header + dedupe |
| Plain enums instead of entitlement keys | Hardcodes plan→feature mapping | Plans declare entitlements as data |
| Audit log in same table as system log | Different retention, queries, compliance | Separate table/store |

### Frontend (drill-down) anti-patterns
| Anti-pattern | Why it's wrong | Right way |
|---|---|---|
| Spinner instead of skeleton | "I have no idea what's coming" — anxiety-inducing | Skeleton matches loaded layout, no layout shift |
| Empty state without action | User stuck — what now? | Friendly copy + recovery action button |
| Generic "Something went wrong" error | No recovery path | Class-specific error + retry/upgrade/contact-admin |
| Drill link that loses filter state | User has to re-filter every time | Every link carries relevant search params |
| Modal that traps back-button | History broken, share-link broken | Use side sheet or in-flow navigation |
| Click target < 44px on mobile | iOS HIG / Material guideline violation | Minimum 44x44px tap target |
| Inline arbitrary Tailwind values (`text-[#abc]`, `mt-[17px]`) | Bypass design tokens | Use designer-specified tokens (Phase 3.5) |
| No keyboard navigation for drill | Accessibility fail | Every clickable element keyboard-reachable + focus visible |
| Storing modal/scroll/hover state in URL | URL bloat, history pollution | Component state for transient UI |
| Permission gating via 403 after click | Bad UX — discover-then-block | PermissionGate hides or shows locked state |

---

## Companion skills

When this skill is loaded, also reference:
- **`dev-squad:saas-readiness`** — sibling skill covering pre-launch readiness + execution discipline (P0/P1/P2 checklist, backup/CI/CD/compliance lifecycle, customer onboarding emails, status page, payment compliance, sprint decomposition 6-A→6-H, product-surface gap audit 10 domains, provider abstraction, regional patterns, case studies). Distinct load context: saas-patterns for code-write, saas-readiness for ship-audit/harden.
- `dev-squad:postgres-patterns` for RLS, index design, partition strategy
- `dev-squad:backend-patterns` for general API/service layer
- `dev-squad:frontend-patterns` for component composition + hooks baseline (Part 2 builds on this)
- `dev-squad:security-review` for auth/authz review
- `frontend-design:frontend-design` (if installed) for visual aesthetic of drill levels

## Bootstrap Context

Architect MUST decide and document in ADRs (Phase 2) before backend codes:
- ADR-001 Tenancy strategy (shared/schema/db/hybrid)
- ADR-002 Billing model (per-seat, per-usage, hybrid). If multi-region target: provider abstraction (see saas-readiness Section 21) — ADR-006+ for provider choices
- ADR-003 Plan structure (free trial? plan tiers? entitlement keys?)
- ADR-004 Admin scope (root-tenant key vs dedicated admin_users table)
- **ADR-005 Compliance scope** (which regulations apply: GDPR / PDP / CCPA / LGPD / sectoral) — drives saas-readiness Section 4 obligations

Without ADR-001..005, backend will retrofit = data leak risk + compliance debt.

Designer (Phase 3.5) MUST produce `drill-down-spec.md` (Part 2 Section 26 template) BEFORE frontend codes any admin dashboard. Without explicit drill spec, frontend will improvise — usually skipping breadcrumb state preservation, virtualization, or permission gating.

**For pre-launch readiness gate, sprint decomposition, product-surface audit, provider abstraction, and case studies: load sibling skill `dev-squad:saas-readiness`.** This skill (saas-patterns) intentionally stays focused on architectural code-write patterns. saas-readiness covers Phase 5+ audit, Phase 6 SHIP gate, and pre-existing project extension work.
