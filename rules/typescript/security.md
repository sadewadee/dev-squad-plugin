---
description: TypeScript-specific security rules
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Security

## Never Hardcode Secrets

No API keys, tokens, passwords, or connection strings in source code. Ever.

```typescript
// BAD -- secret in source code
const apiKey = "sk-1234567890abcdef";
const dbUrl = "postgres://admin:password@prod-db:5432/myapp";

// GOOD -- loaded from environment
const apiKey = process.env.API_KEY;
const dbUrl = process.env.DATABASE_URL;
```

## Always Use Environment Variables

### Loading

Use a validated config module at application startup:

```typescript
import { z } from "zod";

const EnvSchema = z.object({
  API_KEY: z.string().min(1),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  NODE_ENV: z.enum(["development", "staging", "production"]),
  PORT: z.coerce.number().default(3000),
});

export const env = EnvSchema.parse(process.env);
```

### Rules

- Validate all environment variables at startup with Zod -- fail fast if missing
- Use `.env.example` to document required variables (with placeholder values only)
- Never commit `.env` files -- ensure `.gitignore` includes them
- Use different secrets for each environment (dev, staging, production)
- Access environment variables through the validated config object, not `process.env` directly

## Security Reviewer Agent

Use the **security-reviewer** agent for:

- Pre-merge security review of authentication and authorization changes
- Audit of new dependencies for known vulnerabilities
- Review of API endpoint exposure and access control
- Verification that secrets are not leaked in logs, errors, or responses

### When to Invoke

- Any PR that touches auth logic
- Any PR that adds new API endpoints
- Any PR that adds new dependencies
- Any PR that modifies error handling or logging
- Before any production deployment

## Additional TypeScript Security Rules

### XSS Prevention

- Never use `dangerouslySetInnerHTML` without sanitization
- Use DOMPurify or similar library for any user-generated HTML
- Escape all dynamic content rendered in templates

### Dependency Safety

```bash
npm audit
```

- Run before every commit that adds or updates dependencies
- Zero critical or high vulnerabilities allowed
- Pin exact versions in `package.json` for production dependencies

### JWT Handling

- Never store JWTs in localStorage (use httpOnly cookies)
- Always verify JWT signature and expiration server-side
- Use short-lived access tokens with refresh token rotation

### SQL Injection

- Always use parameterized queries or an ORM
- Never concatenate user input into query strings

```typescript
// BAD
const result = await db.query(`SELECT * FROM users WHERE id = '${userId}'`);

// GOOD
const result = await db.query("SELECT * FROM users WHERE id = $1", [userId]);
```
