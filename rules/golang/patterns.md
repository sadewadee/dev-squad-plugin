---
description: Go-specific design patterns and idioms
paths:
  - "**/*.go"
  - "**/go.mod"
---

# Go Patterns

## Functional Options

Use the functional options pattern for configurable constructors:

```go
type Server struct {
    host    string
    port    int
    timeout time.Duration
}

type Option func(*Server)

func WithHost(host string) Option {
    return func(s *Server) { s.host = host }
}

func WithPort(port int) Option {
    return func(s *Server) { s.port = port }
}

func WithTimeout(timeout time.Duration) Option {
    return func(s *Server) { s.timeout = timeout }
}

func NewServer(opts ...Option) *Server {
    s := &Server{
        host:    "localhost",
        port:    8080,
        timeout: 30 * time.Second,
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

### When to Use

- Structs with many optional fields
- Constructors where sensible defaults exist
- APIs that need to stay backward-compatible as options grow

## Small Interfaces

Define interfaces at the consumer, not the producer:

```go
// In the handler package (consumer), not the store package (producer)
type UserFinder interface {
    FindByID(ctx context.Context, id string) (*User, error)
}

func NewHandler(users UserFinder) *Handler {
    return &Handler{users: users}
}
```

This makes testing trivial -- implement the 1-method interface with a mock.

## Dependency Injection

Wire dependencies through constructors, not globals:

```go
// GOOD: explicit dependencies
func NewService(repo Repository, logger *slog.Logger) *Service {
    return &Service{repo: repo, logger: logger}
}

// BAD: hidden global dependencies
func NewService() *Service {
    return &Service{
        repo:   globalDB,     // hidden dependency
        logger: globalLogger, // hidden dependency
    }
}
```

### Rules

- Every dependency is a constructor parameter
- Use interfaces for external dependencies (database, HTTP clients, clocks)
- Wire everything together in `main()` or a composition root
- No `init()` functions for setting up dependencies

## Table-Driven Tests

Always use table-driven tests for functions with multiple input/output cases:

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name string
        a, b int
        want int
    }{
        {"positive", 1, 2, 3},
        {"zero", 0, 0, 0},
        {"negative", -1, -2, -3},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Add(tt.a, tt.b)
            if got != tt.want {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

## Skills Reference

Use the **golang-patterns** skill for extended examples and project-specific pattern guidance.
