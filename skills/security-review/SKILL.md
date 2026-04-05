---
name: security-review
description: Security review checklist for dev-squad agents. Covers 10 security areas including secrets management, input validation, SQL injection, auth/authz, XSS, CSRF, rate limiting, sensitive data exposure, dependency security, and blockchain considerations. Includes pre-deployment checklist.
---

# Security Review - Security Audit for Dev Squad

## INSTRUCTIONS: When this skill is invoked

The reviewer agent (security lead) MUST run through all 10 security areas when reviewing code. Other agents should reference this when building features that touch auth, user input, or data handling. Any P0-P1 finding blocks the merge.

---

## Security Review Process

For each area below:
1. **Scan** the codebase for relevant patterns
2. **Assess** severity: P0 (critical), P1 (high), P2 (medium), P3 (low)
3. **Document** findings with file path, line number, and remediation
4. **Block** merge for any P0 or P1 finding

### Severity Definitions

| Level | Definition | Response Time | Examples |
|---|---|---|---|
| P0 | Active exploitation possible, data breach imminent | Immediate fix, block all merges | Exposed secrets, SQL injection, auth bypass |
| P1 | High risk, exploitable with moderate effort | Fix before merge | Broken access control, XSS, missing rate limit on auth |
| P2 | Medium risk, defense-in-depth gap | Fix within sprint | Missing CSRF token, verbose error messages |
| P3 | Low risk, best practice gap | Track in backlog | Missing security headers, suboptimal password policy |

---

## Area 1: Secrets Management

### What to Check

- Hardcoded secrets, API keys, passwords, tokens in source code
- Secrets in configuration files committed to git
- Secrets in environment variable defaults
- Secrets in Docker images or build artifacts
- Secrets in log output

### Detection Patterns

Search for these patterns in the codebase:

```
# High-signal patterns
password\s*=\s*["'][^"']+["']
api[_-]?key\s*=\s*["'][^"']+["']
secret\s*=\s*["'][^"']+["']
token\s*=\s*["'][^"']+["']
-----BEGIN (RSA |EC )?PRIVATE KEY-----
AWS_ACCESS_KEY_ID
STRIPE_SECRET_KEY
DATABASE_URL.*password

# Check .env files are gitignored
.env
.env.local
.env.production
```

### Correct Pattern

```typescript
// GOOD: Load from environment, fail loudly if missing
const config = {
  dbUrl: requireEnv("DATABASE_URL"),
  jwtSecret: requireEnv("JWT_SECRET"),
  stripeKey: requireEnv("STRIPE_SECRET_KEY"),
};

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}
```

### Remediation

- Move all secrets to environment variables or a secrets manager (Vault, AWS Secrets Manager)
- Add `.env*` to `.gitignore`
- Rotate any secrets that were ever committed to git (even if removed later)
- Use `git-secrets` or `trufflehog` in CI to prevent future leaks
- Redact secrets from log output

---

## Area 2: Input Validation

### What to Check

- All user inputs validated before processing (query params, body, headers, file uploads)
- Validation happens on the server side (client-side validation is UX, not security)
- Input length limits enforced
- File upload type and size restrictions
- JSON schema validation on API endpoints

### Correct Pattern

```typescript
import { z } from "zod";

// Strict schema with constraints
const createUserSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(100).trim(),
  password: z.string().min(8).max(128),
  role: z.enum(["user", "admin"]).optional().default("user"),
});

// Validate at the boundary (middleware)
function validate(schema: z.ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      throw new BadRequestError(
        result.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ")
      );
    }
    req.body = result.data; // use parsed/sanitized data
    next();
  };
}

// File upload validation
const uploadSchema = z.object({
  mimetype: z.enum(["image/jpeg", "image/png", "image/webp"]),
  size: z.number().max(5 * 1024 * 1024), // 5MB
});
```

### Common Pitfalls

- Trusting `Content-Type` header without validating actual file contents
- Not limiting array/object depth in JSON parsing
- Not sanitizing filenames in uploads (path traversal: `../../etc/passwd`)
- Allowing unbounded string lengths (memory exhaustion)

---

## Area 3: SQL Injection Prevention

### What to Check

- All database queries use parameterized queries or prepared statements
- No string concatenation or template literals in SQL
- ORM usage does not bypass parameterization
- Raw queries (if any) use parameter binding

### Detection Patterns

```
# Dangerous patterns to search for
query(`SELECT.*\$\{        # Template literal in SQL
query("SELECT.*" +         # String concatenation in SQL
query(`.*${req.           # User input directly in SQL
.where(`.*\$\{             # Template literal in WHERE clause
.raw(`.*\$\{               # Raw query with interpolation
```

### Correct Pattern

```typescript
// GOOD: Parameterized queries
const user = await db.query("SELECT * FROM users WHERE email = $1", [email]);

// GOOD: ORM with parameter binding
const user = await prisma.user.findUnique({ where: { email } });

// GOOD: Query builder with binding
const users = await knex("users").where("role", role).andWhere("active", true);

// BAD: String interpolation -- SQL INJECTION
const user = await db.query(`SELECT * FROM users WHERE email = '${email}'`); // NEVER DO THIS
```

### Go Example

```go
// GOOD: Parameterized
row := db.QueryRow("SELECT id, name FROM users WHERE email = $1", email)

// BAD: String formatting -- SQL INJECTION
row := db.QueryRow(fmt.Sprintf("SELECT id, name FROM users WHERE email = '%s'", email)) // NEVER
```

---

## Area 4: Authentication and Authorization

### What to Check

- All non-public endpoints require authentication
- Authorization checks exist for every protected resource
- JWT tokens have reasonable expiry (15m access, 7d refresh)
- Password hashing uses bcrypt/argon2 with appropriate cost factor
- Account lockout after failed attempts
- Session invalidation on password change
- No broken object-level authorization (IDOR)

### Correct Pattern

```typescript
// Auth middleware on every protected route
router.use("/api/v1", authenticate);

// Authorization check: user can only access own resources
async function getOrder(req: Request, res: Response) {
  const order = await orderRepo.findById(req.params.id);
  if (!order) throw new NotFoundError("Order", req.params.id);

  // CRITICAL: verify ownership or admin role
  if (order.userId !== req.user.id && req.user.role !== "admin") {
    throw new ForbiddenError("You do not have access to this order");
  }

  res.json(order);
}

// Password hashing
const BCRYPT_ROUNDS = 12; // minimum 10, prefer 12
const hash = await bcrypt.hash(password, BCRYPT_ROUNDS);

// JWT with short expiry
const accessToken = jwt.sign(
  { sub: user.id, role: user.role },
  jwtSecret,
  { expiresIn: "15m" }
);
```

### IDOR (Insecure Direct Object Reference) Check

For every endpoint that accepts an ID parameter, verify:
1. The authenticated user has permission to access that resource
2. The check cannot be bypassed by changing the ID
3. UUIDs are used (not sequential integers) to prevent enumeration

---

## Area 5: XSS (Cross-Site Scripting) Prevention

### What to Check

- All user-generated content is escaped/sanitized before rendering
- React/Vue/Angular auto-escaping is not bypassed
- `dangerouslySetInnerHTML` (React) or `v-html` (Vue) usage is audited
- Content Security Policy (CSP) headers are set
- HTTP-only cookies for session tokens

### Detection Patterns

```
# Dangerous patterns
dangerouslySetInnerHTML
v-html
innerHTML\s*=
document.write
eval(
new Function(
```

### Correct Pattern

```tsx
// GOOD: React auto-escapes by default
function Comment({ text }: { text: string }) {
  return <p>{text}</p>; // safely escaped
}

// DANGEROUS: Only use with sanitized content
import DOMPurify from "dompurify";
function RichContent({ html }: { html: string }) {
  const sanitized = DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ["b", "i", "em", "strong", "a", "p", "ul", "ol", "li"],
    ALLOWED_ATTR: ["href"],
  });
  return <div dangerouslySetInnerHTML={{ __html: sanitized }} />;
}

// CSP Header
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;
```

---

## Area 6: CSRF (Cross-Site Request Forgery) Protection

### What to Check

- State-changing operations (POST, PUT, PATCH, DELETE) have CSRF protection
- CSRF tokens are validated on the server
- SameSite cookie attribute is set
- CORS configuration is restrictive

### Correct Pattern

```typescript
// Cookie configuration
app.use(session({
  cookie: {
    httpOnly: true,
    secure: true,           // HTTPS only
    sameSite: "strict",     // or "lax" for link navigation
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
  },
}));

// CORS: restrict to known origins
app.use(cors({
  origin: ["https://myapp.com", "https://admin.myapp.com"],
  credentials: true,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
}));

// For SPA with JWT: use Authorization header (not cookies) -- inherently CSRF-safe
// For cookie-based auth: use csrf middleware
import csrf from "csurf";
app.use(csrf({ cookie: { httpOnly: true, sameSite: "strict" } }));
```

---

## Area 7: Rate Limiting

### What to Check

- Authentication endpoints (login, signup, password reset) have strict rate limits
- API endpoints have general rate limits
- Rate limits are per-user/IP, not global
- Rate limit responses include retry-after information

### Correct Pattern

```typescript
// Strict limits on auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,                    // 5 attempts per window
  keyGenerator: (req) => req.ip,
  handler: (req, res) => {
    res.status(429).json({
      error: "Too many attempts. Try again in 15 minutes.",
      retryAfter: 900,
    });
  },
});
app.use("/api/v1/auth/login", authLimiter);
app.use("/api/v1/auth/signup", authLimiter);
app.use("/api/v1/auth/reset-password", authLimiter);

// General API rate limit
const apiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100,             // 100 requests per minute
  keyGenerator: (req) => req.user?.id ?? req.ip,
});
app.use("/api/v1", apiLimiter);
```

### Recommended Limits

| Endpoint | Window | Max Requests |
|---|---|---|
| Login | 15 min | 5 |
| Signup | 1 hour | 3 |
| Password reset | 1 hour | 3 |
| General API (authenticated) | 1 min | 100 |
| General API (unauthenticated) | 1 min | 20 |
| File upload | 1 hour | 10 |

---

## Area 8: Sensitive Data Exposure

### What to Check

- Passwords never returned in API responses
- PII (email, phone, address) exposure is minimized
- Error messages do not leak system internals (stack traces, SQL errors, file paths)
- Logs do not contain sensitive data
- HTTPS enforced everywhere (no mixed content)
- Sensitive headers stripped from responses

### Correct Pattern

```typescript
// Response serialization: explicitly select fields
function toUserResponse(user: User): UserResponse {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    createdAt: user.createdAt,
    // passwordHash: NEVER included
    // internalNotes: NEVER included
  };
}

// Error responses: generic in production
function errorHandler(err: Error, req: Request, res: Response, next: NextFunction) {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ error: { code: err.code, message: err.message } });
  } else {
    // NEVER expose stack trace or internal error details to client
    logger.error({ err, requestId: req.requestId }, "unhandled error");
    res.status(500).json({ error: { code: "INTERNAL_ERROR", message: "An unexpected error occurred" } });
  }
}

// Log redaction
const logger = pino({
  redact: [
    "req.headers.authorization",
    "req.headers.cookie",
    "password",
    "passwordHash",
    "token",
    "creditCard",
    "ssn",
  ],
});

// Security headers
app.use(helmet({
  hsts: { maxAge: 31536000, includeSubDomains: true },
  contentSecurityPolicy: true,
  referrerPolicy: { policy: "strict-origin-when-cross-origin" },
}));
```

---

## Area 9: Dependency Security

### What to Check

- No known vulnerabilities in dependencies
- Dependencies are pinned to specific versions (lockfile exists)
- No unnecessary dependencies (attack surface)
- Automated vulnerability scanning in CI

### Commands

```bash
# Node.js
npm audit
npm audit --production  # only production deps

# Go
govulncheck ./...

# Python
pip-audit
safety check

# General
trivy fs .
snyk test
```

### CI Integration

```yaml
# GitHub Actions: automated dependency audit
- name: Audit dependencies
  run: npm audit --production --audit-level=high

# Renovate or Dependabot for automated updates
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

### Policy

- P0: Any dependency with a known critical/high CVE that affects the application
- P1: Dependencies with moderate CVEs in production code
- P2: Dependencies with low CVEs or dev-only vulnerabilities
- Block merge for P0-P1 until resolved (update, patch, or mitigate)

---

## Area 10: Blockchain Security (If Applicable)

### What to Check (Skip if not applicable)

- Smart contract reentrancy protection
- Integer overflow/underflow guards
- Access control on privileged functions
- Oracle manipulation risks
- Front-running vulnerabilities
- Private key management
- Transaction signing verification

### Correct Pattern (Solidity)

```solidity
// Reentrancy guard
contract Vault is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // Update state BEFORE external call (checks-effects-interactions)
        balances[msg.sender] -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
```

### Correct Pattern (Key Management)

```typescript
// NEVER hardcode private keys
// NEVER store private keys in environment variables on shared servers
// Use HSM, AWS KMS, or hardware wallets for signing

const signer = new ethers.Wallet(
  await kmsClient.getPrivateKey("signing-key-id")
);
```

---

## Pre-Deployment Security Checklist

Run through this checklist before any deployment. Every item must be checked.

### Secrets and Configuration
- [ ] No secrets in source code or config files
- [ ] All secrets loaded from environment/secrets manager
- [ ] `.env` files are in `.gitignore`
- [ ] Default passwords changed
- [ ] Debug mode disabled in production

### Authentication and Authorization
- [ ] All endpoints require appropriate authentication
- [ ] Authorization checks on every protected resource
- [ ] JWT access tokens expire within 15 minutes
- [ ] Password hashing uses bcrypt (cost 12+) or argon2
- [ ] Account lockout after 5 failed attempts
- [ ] Session invalidation on password change

### Input and Output
- [ ] All inputs validated on server side with strict schemas
- [ ] File upload type and size restricted
- [ ] SQL queries use parameterized statements (zero string interpolation)
- [ ] API responses exclude sensitive fields (passwordHash, internal IDs)
- [ ] Error responses do not leak system internals

### Transport and Headers
- [ ] HTTPS enforced (HSTS header set)
- [ ] Cookies set with HttpOnly, Secure, SameSite
- [ ] CORS restricted to known origins
- [ ] CSP header configured
- [ ] X-Content-Type-Options: nosniff
- [ ] X-Frame-Options: DENY

### Rate Limiting and Abuse Prevention
- [ ] Auth endpoints rate limited (5/15min)
- [ ] API endpoints rate limited (100/min)
- [ ] File upload rate limited
- [ ] Rate limit responses include Retry-After

### Dependencies and Infrastructure
- [ ] `npm audit` / `govulncheck` shows no high/critical issues
- [ ] Lockfile committed and up to date
- [ ] Automated dependency scanning in CI
- [ ] Database connections use TLS
- [ ] Logging does not include sensitive data

### Monitoring
- [ ] Security events logged (failed logins, permission denied, rate limits)
- [ ] Alerting configured for security anomalies
- [ ] Health check endpoint exists
- [ ] Error tracking configured (Sentry or equivalent)
