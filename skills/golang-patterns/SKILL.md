---
name: golang-patterns
description: Idiomatic Go patterns for dev-squad agents. Covers error handling, concurrency, interfaces, package layout, functional options, struct embedding, memory optimization, and anti-patterns. Reference this skill when writing or reviewing Go code.
---

# Go Patterns - Idiomatic Go for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Load these patterns into context when any dev-squad agent is writing, reviewing, or architecting Go code. Use as a reference for code generation, code review, and architecture decisions.

---

## 1. Error Handling

### Wrapping Errors with Context

Always wrap errors with `fmt.Errorf` and `%w` to preserve the error chain:

```go
func GetUser(id string) (*User, error) {
    user, err := db.FindUser(id)
    if err != nil {
        return nil, fmt.Errorf("GetUser(%s): %w", id, err)
    }
    return user, nil
}
```

### Custom Error Types

Define domain-specific errors for programmatic handling:

```go
type NotFoundError struct {
    Resource string
    ID       string
}

func (e *NotFoundError) Error() string {
    return fmt.Sprintf("%s with ID %s not found", e.Resource, e.ID)
}

// Sentinel errors for common cases
var (
    ErrUnauthorized = errors.New("unauthorized")
    ErrForbidden    = errors.New("forbidden")
)
```

### Checking Errors with errors.Is and errors.As

```go
// Check sentinel errors
if errors.Is(err, ErrUnauthorized) {
    http.Error(w, "Unauthorized", http.StatusUnauthorized)
    return
}

// Check error types
var notFound *NotFoundError
if errors.As(err, &notFound) {
    http.Error(w, notFound.Error(), http.StatusNotFound)
    return
}
```

### Error Handling Rules

- Never ignore errors: `_ = doSomething()` is almost always wrong
- Add context at each layer but avoid redundant wrapping
- Use sentinel errors for expected conditions, custom types for rich context
- Return errors; do not log-and-return (choose one)

---

## 2. Concurrency Patterns

### Worker Pool

```go
func ProcessItems(ctx context.Context, items []Item, workers int) error {
    g, ctx := errgroup.WithContext(ctx)
    itemCh := make(chan Item)

    // Producer
    g.Go(func() error {
        defer close(itemCh)
        for _, item := range items {
            select {
            case itemCh <- item:
            case <-ctx.Done():
                return ctx.Err()
            }
        }
        return nil
    })

    // Workers
    for i := 0; i < workers; i++ {
        g.Go(func() error {
            for item := range itemCh {
                if err := process(ctx, item); err != nil {
                    return fmt.Errorf("processing item %s: %w", item.ID, err)
                }
            }
            return nil
        })
    }

    return g.Wait()
}
```

### Context Cancellation

```go
func LongRunningTask(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
            // Do a unit of work
            if err := doWork(); err != nil {
                return err
            }
        }
    }
}

// Caller sets timeout
ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
err := LongRunningTask(ctx)
```

### errgroup for Parallel Tasks

```go
func FetchAll(ctx context.Context, urls []string) ([]Response, error) {
    g, ctx := errgroup.WithContext(ctx)
    results := make([]Response, len(urls))

    for i, url := range urls {
        g.Go(func() error {
            resp, err := fetch(ctx, url)
            if err != nil {
                return fmt.Errorf("fetch %s: %w", url, err)
            }
            results[i] = resp // safe: each goroutine writes to unique index
            return nil
        })
    }

    if err := g.Wait(); err != nil {
        return nil, err
    }
    return results, nil
}
```

### Graceful Shutdown

```go
func main() {
    srv := &http.Server{Addr: ":8080", Handler: router}

    // Start server
    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("server error: %v", err)
        }
    }()

    // Wait for interrupt
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("shutting down...")
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatalf("forced shutdown: %v", err)
    }
    log.Println("server stopped")
}
```

### Avoiding Goroutine Leaks

```go
// BAD: goroutine leaks if nobody reads from ch
func bad() chan int {
    ch := make(chan int)
    go func() {
        ch <- expensiveComputation()
    }()
    return ch
}

// GOOD: use context cancellation or buffered channel
func good(ctx context.Context) chan int {
    ch := make(chan int, 1) // buffered: goroutine won't block
    go func() {
        select {
        case ch <- expensiveComputation():
        case <-ctx.Done():
        }
    }()
    return ch
}
```

---

## 3. Interface Patterns

### Small, Focused Interfaces

```go
// Good: small and composable
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

type ReadWriter interface {
    Reader
    Writer
}
```

### Define Interfaces Where Used (Consumer Side)

```go
// In the service package (consumer), NOT in the repository package (producer)
package service

type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Save(ctx context.Context, user *User) error
}

type UserService struct {
    repo UserRepository // depends on interface, not concrete type
}
```

### Optional Behavior via Type Assertion

```go
type Logger interface {
    Log(msg string)
}

// Optional interface for structured logging
type StructuredLogger interface {
    Logger
    LogFields(msg string, fields map[string]any)
}

func logMessage(l Logger, msg string, fields map[string]any) {
    if sl, ok := l.(StructuredLogger); ok {
        sl.LogFields(msg, fields)
    } else {
        l.Log(msg)
    }
}
```

---

## 4. Package Layout

```
project/
  cmd/
    api/              # main.go for API server
    worker/           # main.go for background worker
    migrate/          # main.go for migrations CLI
  internal/
    user/             # domain: user service, repo interface, models
    order/            # domain: order service, repo interface, models
    platform/
      postgres/       # postgres implementations of repo interfaces
      redis/          # redis cache implementations
      http/           # HTTP handlers, middleware, router
  pkg/
    validate/         # reusable validation utilities (public API)
    money/            # reusable money type (public API)
  api/
    openapi.yaml      # API specification
  migrations/         # SQL migration files
  go.mod
  go.sum
```

**Rules:**
- `cmd/`: Each binary gets its own directory with `main.go`
- `internal/`: Private application code. Cannot be imported by other modules
- `pkg/`: Public libraries safe for external import
- Domain packages (`internal/user`) own their models, service logic, and repository interface
- Infrastructure packages (`internal/platform/postgres`) implement interfaces

---

## 5. Functional Options Pattern

```go
type Server struct {
    addr         string
    readTimeout  time.Duration
    writeTimeout time.Duration
    logger       Logger
}

type Option func(*Server)

func WithAddr(addr string) Option {
    return func(s *Server) { s.addr = addr }
}

func WithReadTimeout(d time.Duration) Option {
    return func(s *Server) { s.readTimeout = d }
}

func WithLogger(l Logger) Option {
    return func(s *Server) { s.logger = l }
}

func NewServer(opts ...Option) *Server {
    s := &Server{
        addr:         ":8080",       // sensible defaults
        readTimeout:  5 * time.Second,
        writeTimeout: 10 * time.Second,
    }
    for _, opt := range opts {
        opt(s)
    }
    return s
}

// Usage
srv := NewServer(
    WithAddr(":3000"),
    WithReadTimeout(10*time.Second),
    WithLogger(myLogger),
)
```

---

## 6. Struct Embedding

```go
// Embed for composition, not inheritance
type BaseModel struct {
    ID        uuid.UUID  `json:"id" db:"id"`
    CreatedAt time.Time  `json:"created_at" db:"created_at"`
    UpdatedAt time.Time  `json:"updated_at" db:"updated_at"`
}

type User struct {
    BaseModel               // embedded: User gets ID, CreatedAt, UpdatedAt
    Email     string        `json:"email" db:"email"`
    Name      string        `json:"name" db:"name"`
}

// Embed interfaces for partial implementation
type ReadOnlyStore struct {
    UserRepository // only override Read methods; Write methods panic by default
}

func (s *ReadOnlyStore) Save(ctx context.Context, u *User) error {
    return errors.New("read-only store: writes not permitted")
}
```

---

## 7. Memory Optimization

### Preallocate Slices

```go
// BAD: grows dynamically, causes multiple allocations
var results []Result
for _, item := range items {
    results = append(results, process(item))
}

// GOOD: preallocate with known capacity
results := make([]Result, 0, len(items))
for _, item := range items {
    results = append(results, process(item))
}
```

### sync.Pool for Temporary Objects

```go
var bufPool = sync.Pool{
    New: func() any {
        return new(bytes.Buffer)
    },
}

func ProcessRequest(data []byte) string {
    buf := bufPool.Get().(*bytes.Buffer)
    defer func() {
        buf.Reset()
        bufPool.Put(buf)
    }()

    buf.Write(data)
    // ... process ...
    return buf.String()
}
```

### strings.Builder for String Concatenation

```go
// BAD: creates new string each iteration
result := ""
for _, s := range parts {
    result += s + ","
}

// GOOD: efficient string building
var b strings.Builder
b.Grow(estimatedSize) // optional: preallocate
for i, s := range parts {
    if i > 0 {
        b.WriteByte(',')
    }
    b.WriteString(s)
}
result := b.String()
```

### Struct Field Ordering (Reduce Padding)

```go
// BAD: 32 bytes (padding waste)
type Bad struct {
    a bool    // 1 byte + 7 padding
    b int64   // 8 bytes
    c bool    // 1 byte + 7 padding
    d int64   // 8 bytes
}

// GOOD: 24 bytes (minimal padding)
type Good struct {
    b int64   // 8 bytes
    d int64   // 8 bytes
    a bool    // 1 byte
    c bool    // 1 byte + 6 padding
}
```

---

## 8. Anti-Patterns to Avoid

| Anti-Pattern | Why It's Bad | Do This Instead |
|---|---|---|
| `interface{}` / `any` everywhere | Loses type safety | Use generics (Go 1.18+) or concrete types |
| Giant interfaces (10+ methods) | Hard to mock, tight coupling | Split into small focused interfaces |
| `init()` functions | Hidden side effects, test difficulties | Explicit initialization in `main()` |
| Bare `go func()` without tracking | Goroutine leaks, lost errors | Use `errgroup` or `sync.WaitGroup` |
| Global mutable state | Race conditions, test pollution | Dependency injection via struct fields |
| `panic` for control flow | Crashes the program | Return errors |
| Premature channel usage | Channels add complexity | Use mutexes for simple shared state |
| Returning concrete types from constructors | Prevents testing with mocks | Return interfaces when polymorphism is needed |
| Deep package nesting (`a/b/c/d/e`) | Hard to navigate | Flat-ish structure, max 2-3 levels |
| `time.Sleep` in production code | Unreliable, slows tests | Use tickers, timers, or context deadlines |
