---
description: Security rules and mandatory pre-commit checks
globs: "*"
---

# Security Rules

## Mandatory Pre-Commit Security Checks

Every commit MUST pass these checks. No exceptions.

- [ ] **No secrets**: No API keys, tokens, passwords, or private keys in code
- [ ] **Inputs validated**: All user inputs are validated and sanitized at boundaries
- [ ] **SQL parameterized**: All database queries use parameterized statements, never string concatenation
- [ ] **XSS prevented**: All user-generated content is escaped before rendering in HTML
- [ ] **CSRF enabled**: All state-changing endpoints have CSRF protection
- [ ] **Auth verified**: All protected endpoints verify authentication and authorization
- [ ] **Rate limiting**: Public-facing endpoints have rate limiting configured
- [ ] **Error messages safe**: Error responses do not leak stack traces, file paths, or internal details

## Secret Management

### Never Do

- Hardcode secrets in source code
- Commit `.env` files to version control
- Log secrets in application output
- Pass secrets as command-line arguments (visible in process lists)

### Always Do

- Store secrets in environment variables or a secrets manager (Vault, AWS Secrets Manager, etc.)
- Use `.env.example` with placeholder values as documentation
- Add `.env` and secret files to `.gitignore` before the first commit
- Rotate secrets immediately if they are accidentally exposed
- Use different secrets for each environment (dev, staging, production)

## Security Response Protocol

If a security vulnerability is discovered:

1. **Stop** -- do not push or deploy any code
2. **Assess** -- determine the severity and blast radius
3. **Contain** -- revoke compromised credentials, block attack vectors
4. **Fix** -- implement the fix with a test proving the vulnerability is closed
5. **Review** -- have the fix reviewed by the security-reviewer agent or a human
6. **Document** -- record what happened, what was fixed, and how to prevent recurrence
7. **Deploy** -- push the fix through an expedited but reviewed process

## Dependency Security

- Run `npm audit` / `go mod verify` / `pip audit` before adding new dependencies
- Do not use dependencies with known critical vulnerabilities
- Pin dependency versions -- do not use floating ranges in production
- Review new dependencies for maintenance status and community trust
