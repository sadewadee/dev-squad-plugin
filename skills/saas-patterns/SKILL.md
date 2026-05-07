---
name: saas-patterns
description: SaaS-class backend architecture patterns for dev-squad agents. Covers multi-tenancy (tenants, memberships, isolation), subscription billing (Stripe lifecycle, plans, promo codes), entitlements + plan-based access, API key management, outbound webhooks (signed delivery, retry, DLQ), audit logs, in-app notifications, transactional email, hybrid validation (struct tags + DB schema), admin scope, usage metering, runtime config, multi-tenant isolation testing. Reference architecture inspired by production SaaS codebases. TypeScript/Node.js + Go examples.
---

# SaaS Patterns — Production-Class SaaS Reference for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Load these patterns when dev-squad agents are building, reviewing, or architecting a **SaaS-class** application — multi-tenant, subscription-billed, with admin/customer scope separation. Coordinator activates this skill when the workflow is in SaaS mode (auto-detected from PRD or set explicitly via `--saas`).

**Critical rule:** Multi-tenancy is an architectural decision, not a feature. Retrofit later = cross-tenant data leak (P0 security incident). Architect MUST decide tenancy strategy in Phase 2 ADR before any data model is written.

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

## 15. Admin Drill-Down Endpoints (pair with drill-down-patterns frontend skill)

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

## Anti-patterns (NEVER do these in SaaS)

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

---

## Companion skills

When this skill is loaded, also reference:
- `dev-squad:postgres-patterns` for RLS, index design, partition strategy
- `dev-squad:backend-patterns` for general API/service layer
- `dev-squad:security-review` for auth/authz review
- `dev-squad:drill-down-patterns` for the frontend side of admin dashboards

## Bootstrap Context

Architect MUST decide and document in ADRs (Phase 2) before backend codes:
- ADR-001 Tenancy strategy (shared/schema/db/hybrid)
- ADR-002 Billing model (per-seat, per-usage, hybrid)
- ADR-003 Plan structure (free trial? plan tiers? entitlement keys?)
- ADR-004 Admin scope (root-tenant key vs dedicated admin_users table)

Without these ADRs, backend will retrofit multi-tenancy = data leak risk.
