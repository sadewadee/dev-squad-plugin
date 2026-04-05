---
description: Go-specific coding style rules
paths:
  - "**/*.go"
  - "**/go.mod"
---

# Go Coding Style

## Formatting

- **gofmt is mandatory** -- all Go code must be formatted with `gofmt` before commit
- Use `goimports` to manage import grouping (stdlib, external, internal)
- No exceptions to standard Go formatting

## Interface Design

- **Accept interfaces, return structs** -- functions should take interface parameters and return concrete types
- Keep interfaces small: **1-3 methods** maximum
- Define interfaces where they are used, not where they are implemented
- Let interfaces emerge from usage -- do not predefine them

```go
// GOOD: small, focused interface defined at point of use
type UserStore interface {
    FindByID(ctx context.Context, id string) (*User, error)
}

// BAD: large interface defined alongside implementation
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    FindAll(ctx context.Context) ([]*User, error)
    Create(ctx context.Context, u *User) error
    Update(ctx context.Context, u *User) error
    Delete(ctx context.Context, id string) error
    Count(ctx context.Context) (int, error)
    // ... too many methods
}
```

## Error Handling

- Always wrap errors with context using `fmt.Errorf("doing X: %w", err)`
- Never discard errors with `_` unless you add a comment explaining why
- Use sentinel errors (`var ErrNotFound = errors.New(...)`) for expected conditions
- Use custom error types for errors that carry additional data
- Check errors immediately -- do not defer error checking

```go
// GOOD: wrapped with context
user, err := store.FindByID(ctx, id)
if err != nil {
    return fmt.Errorf("finding user %s: %w", id, err)
}
```

## Naming

- Use short, clear variable names -- `ctx` not `context`, `err` not `error`
- Package names are lowercase, single word, no underscores
- Exported names need no package prefix: `http.Server` not `http.HTTPServer`
- Acronyms are all caps: `ID`, `HTTP`, `URL`

## Struct Design

- Group related fields together
- Use pointer receivers for methods that modify the struct
- Use value receivers for methods that only read

## Concurrency

- Always pass `context.Context` as the first parameter
- Use channels for communication, mutexes for state
- Never start goroutines without a clear shutdown path
- Use `errgroup` for managing groups of goroutines
