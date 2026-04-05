---
description: Go-specific hooks for auto-formatting and static analysis
paths:
  - "**/*.go"
  - "**/go.mod"
---

# Go Hooks

## PostToolUse Hooks

Run these automatically after any Go file is written or modified:

### Auto-Format with gofmt

```bash
gofmt -w <file>
```

Runs on every `.go` file write. Non-negotiable -- all Go code must be gofmt-compliant.

### Auto-Format with goimports

```bash
goimports -w <file>
```

Runs after gofmt. Organizes imports into three groups: stdlib, external, internal. Also removes unused imports.

### Go Vet

```bash
go vet ./...
```

Runs after implementation changes. Catches common mistakes like Printf format string mismatches, unreachable code, and suspicious constructs.

### Staticcheck

```bash
staticcheck ./...
```

Runs after implementation changes. Catches a broader set of issues than go vet including deprecated API usage, unnecessary conversions, and inefficient code patterns.

## Hook Execution Order

1. `gofmt -w <file>` -- format first
2. `goimports -w <file>` -- fix imports
3. `go vet ./...` -- check for mistakes
4. `staticcheck ./...` -- deeper analysis

## Failure Handling

- If gofmt or goimports fails, the file has a syntax error -- fix before proceeding
- If go vet reports issues, treat them as **HIGH** severity -- fix immediately
- If staticcheck reports issues, triage by severity:
  - SA-category (bugs): fix immediately
  - ST-category (style): fix before review
  - S-category (simplifications): fix when convenient

## Pre-Commit Verification

Before any commit involving Go files, run:

```bash
go build ./... && go vet ./... && staticcheck ./... && go test ./...
```

All four must pass. Do not commit with known failures.
