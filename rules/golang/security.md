---
description: Go-specific security rules
paths:
  - "**/*.go"
  - "**/go.mod"
---

# Go Security

## Secret Management

- **Always use environment variables** for secrets -- never hardcode
- Use `os.Getenv` or a config library (Viper, envconfig) to load secrets
- Fail fast at startup if required secrets are missing

```go
// GOOD
apiKey := os.Getenv("API_KEY")
if apiKey == "" {
    log.Fatal("API_KEY environment variable is required")
}

// BAD
apiKey := "sk-hardcoded-secret-key"
```

## Gosec Scanning

Run `gosec ./...` before every commit involving Go code.

### Common Gosec Findings

| Rule | Issue | Fix |
|------|-------|-----|
| G101 | Hardcoded credentials | Move to env vars |
| G104 | Unhandled error | Check every error |
| G107 | URL from variable in HTTP request | Validate/allowlist URLs |
| G201 | SQL string concatenation | Use parameterized queries |
| G304 | File path from variable | Validate and sanitize paths |
| G401 | Weak crypto (MD5/SHA1) | Use SHA-256 or better |

### Integration

Add gosec to CI pipeline:

```bash
gosec -fmt=json -out=results.json ./...
```

Treat any HIGH-confidence finding as a blocker.

## Context Timeouts

Every outbound call MUST have a context with a timeout:

```go
// GOOD: bounded context
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()

resp, err := client.Do(req.WithContext(ctx))
```

```go
// BAD: unbounded context -- can hang forever
resp, err := client.Do(req.WithContext(context.Background()))
```

### Timeout Guidelines

| Operation | Recommended Timeout |
|-----------|-------------------|
| Database query | 5-10 seconds |
| External API call | 10-30 seconds |
| File I/O | 5 seconds |
| Full request lifecycle | 30-60 seconds |

## Input Validation

- Validate all HTTP request inputs before processing
- Use struct tags with a validator library (`go-playground/validator`)
- Sanitize file paths to prevent directory traversal
- Limit request body size with `http.MaxBytesReader`

## SQL Injection Prevention

Always use parameterized queries:

```go
// GOOD
row := db.QueryRowContext(ctx, "SELECT * FROM users WHERE id = $1", id)

// BAD
row := db.QueryRowContext(ctx, "SELECT * FROM users WHERE id = " + id)
```
