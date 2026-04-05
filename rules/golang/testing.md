---
description: Go-specific testing rules and commands
paths:
  - "**/*.go"
  - "**/go.mod"
---

# Go Testing

## Standard Test Commands

### Run all tests

```bash
go test ./...
```

### Run with race detection

```bash
go test -race ./...
```

**Always run with `-race` in CI.** Race conditions are silent bugs that cause intermittent failures in production.

### Run with coverage

```bash
go test -cover ./...
```

### Generate coverage report

```bash
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

### Run specific test

```bash
go test -run TestFunctionName ./path/to/package
```

### Run with verbose output

```bash
go test -v ./...
```

## Testing Rules

- Every exported function has at least one test
- Use table-driven tests for functions with multiple cases
- Test file lives next to the code: `user.go` -> `user_test.go`
- Use `testdata/` directory for test fixtures
- Use `t.Helper()` in test helper functions for accurate line reporting
- Use `t.Parallel()` where tests have no shared state

## Test Organization

```go
func TestUserService_Create(t *testing.T) {
    t.Parallel()
    
    tests := []struct {
        name    string
        input   CreateUserInput
        wantErr bool
    }{
        {
            name:    "valid user",
            input:   CreateUserInput{Name: "Alice", Email: "alice@example.com"},
            wantErr: false,
        },
        {
            name:    "missing email",
            input:   CreateUserInput{Name: "Bob"},
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            svc := NewUserService(newMockRepo())
            _, err := svc.Create(context.Background(), tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Create() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

## Mocking

- Use interfaces for dependencies, then implement test doubles
- Prefer hand-written mocks over generated mocks for small interfaces
- Use `gomock` or `mockery` only for interfaces with many methods
- Test doubles go in the test file, not a separate mock package

## CI Integration

```bash
# Full CI test command
go test -race -coverprofile=coverage.out -covermode=atomic ./...
```

- Fail CI if coverage drops below 80%
- Fail CI if race detector finds any issues
- Cache test results with `go test -count=1` to disable caching when needed

## Skills Reference

Use the **golang-testing** skill for advanced testing patterns, integration test setup, and test database management.
