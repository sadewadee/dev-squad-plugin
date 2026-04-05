---
name: golang-testing
description: Go testing patterns for dev-squad agents. Covers TDD red-green-refactor, table-driven tests, subtests, parallel testing, test helpers, golden files, interface-based mocking, benchmarks, fuzzing, HTTP handler testing, coverage targets, and CI/CD integration.
---

# Go Testing - Test Patterns for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Load these patterns when any dev-squad agent is writing tests, reviewing test code, or setting up CI/CD for Go projects. Enforce TDD discipline: tests first, implementation second.

---

## 1. TDD Red-Green-Refactor in Go

### The Cycle

1. **RED**: Write a failing test that describes the desired behavior
2. **GREEN**: Write the minimum code to make the test pass
3. **REFACTOR**: Clean up without changing behavior, tests still pass

```go
// Step 1 - RED: Write the test first
func TestAdd(t *testing.T) {
    got := Add(2, 3)
    want := 5
    if got != want {
        t.Errorf("Add(2, 3) = %d, want %d", got, want)
    }
}

// Step 2 - GREEN: Minimal implementation
func Add(a, b int) int {
    return a + b
}

// Step 3 - REFACTOR: (nothing to refactor here, move to next test)
```

---

## 2. Table-Driven Tests

The standard Go pattern for testing multiple cases:

```go
func TestParseAmount(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int64
        wantErr bool
    }{
        {name: "valid dollars", input: "$10.50", want: 1050, wantErr: false},
        {name: "valid no cents", input: "$10", want: 1000, wantErr: false},
        {name: "zero", input: "$0.00", want: 0, wantErr: false},
        {name: "negative", input: "-$5.00", want: -500, wantErr: false},
        {name: "invalid format", input: "abc", want: 0, wantErr: true},
        {name: "empty string", input: "", want: 0, wantErr: true},
        {name: "overflow", input: "$99999999999999", want: 0, wantErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseAmount(tt.input)
            if (err != nil) != tt.wantErr {
                t.Fatalf("ParseAmount(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
            }
            if got != tt.want {
                t.Errorf("ParseAmount(%q) = %d, want %d", tt.input, got, tt.want)
            }
        })
    }
}
```

---

## 3. Subtests and Parallel Subtests

### Grouped Subtests

```go
func TestUserService(t *testing.T) {
    t.Run("Create", func(t *testing.T) {
        t.Run("valid user", func(t *testing.T) {
            t.Parallel()
            // test valid creation
        })
        t.Run("duplicate email", func(t *testing.T) {
            t.Parallel()
            // test duplicate handling
        })
    })

    t.Run("Delete", func(t *testing.T) {
        t.Run("existing user", func(t *testing.T) {
            t.Parallel()
            // test deletion
        })
        t.Run("nonexistent user", func(t *testing.T) {
            t.Parallel()
            // test not found case
        })
    })
}
```

### Parallel Table-Driven Tests

```go
func TestSlugify(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  string
    }{
        {"simple", "Hello World", "hello-world"},
        {"special chars", "Go 1.21!", "go-121"},
        {"unicode", "cafe\u0301", "cafe"},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // safe because each tt is captured by value in Go 1.22+
            got := Slugify(tt.input)
            if got != tt.want {
                t.Errorf("Slugify(%q) = %q, want %q", tt.input, got, tt.want)
            }
        })
    }
}
```

---

## 4. Test Helpers with t.Helper()

```go
func assertNoError(t *testing.T, err error) {
    t.Helper() // marks this as helper: errors report caller's line number
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}

func assertEqual[T comparable](t *testing.T, got, want T) {
    t.Helper()
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}

func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()
    db, err := sql.Open("postgres", testDSN)
    if err != nil {
        t.Fatalf("failed to connect to test DB: %v", err)
    }
    t.Cleanup(func() {
        db.Close()
    })
    return db
}

// Usage
func TestCreateUser(t *testing.T) {
    db := setupTestDB(t)
    svc := NewUserService(db)
    user, err := svc.Create(ctx, "alice@example.com")
    assertNoError(t, err)
    assertEqual(t, user.Email, "alice@example.com")
}
```

---

## 5. Golden Files

Store expected output in files, update with `-update` flag:

```go
var update = flag.Bool("update", false, "update golden files")

func TestRenderTemplate(t *testing.T) {
    got := RenderTemplate(testData)
    golden := filepath.Join("testdata", t.Name()+".golden")

    if *update {
        os.MkdirAll("testdata", 0o755)
        os.WriteFile(golden, []byte(got), 0o644)
        return
    }

    want, err := os.ReadFile(golden)
    if err != nil {
        t.Fatalf("failed to read golden file (run with -update to create): %v", err)
    }

    if diff := cmp.Diff(string(want), got); diff != "" {
        t.Errorf("output mismatch (-want +got):\n%s", diff)
    }
}
```

Run `go test -update ./...` to regenerate golden files.

---

## 6. Interface-Based Mocking

Define interfaces at the consumer side and create test doubles:

```go
// Production interface (in service package)
type OrderRepository interface {
    FindByID(ctx context.Context, id string) (*Order, error)
    Save(ctx context.Context, order *Order) error
}

// Mock implementation (in test file)
type mockOrderRepo struct {
    findByIDFn func(ctx context.Context, id string) (*Order, error)
    saveFn     func(ctx context.Context, order *Order) error
}

func (m *mockOrderRepo) FindByID(ctx context.Context, id string) (*Order, error) {
    return m.findByIDFn(ctx, id)
}

func (m *mockOrderRepo) Save(ctx context.Context, order *Order) error {
    return m.saveFn(ctx, order)
}

// Usage in test
func TestCancelOrder(t *testing.T) {
    repo := &mockOrderRepo{
        findByIDFn: func(ctx context.Context, id string) (*Order, error) {
            return &Order{ID: id, Status: "active"}, nil
        },
        saveFn: func(ctx context.Context, order *Order) error {
            assertEqual(t, order.Status, "cancelled")
            return nil
        },
    }

    svc := NewOrderService(repo)
    err := svc.Cancel(context.Background(), "order-1")
    assertNoError(t, err)
}
```

---

## 7. Benchmarks

### Basic Benchmark

```go
func BenchmarkSlugify(b *testing.B) {
    input := "Hello World This Is A Test String"
    for b.Loop() {
        Slugify(input)
    }
}
```

### Benchmark with Different Sizes

```go
func BenchmarkProcessItems(b *testing.B) {
    sizes := []int{10, 100, 1000, 10000}
    for _, size := range sizes {
        items := generateItems(size)
        b.Run(fmt.Sprintf("size=%d", size), func(b *testing.B) {
            for b.Loop() {
                ProcessItems(items)
            }
        })
    }
}
```

### Memory Benchmarks

```go
func BenchmarkStringConcat(b *testing.B) {
    b.Run("plus_operator", func(b *testing.B) {
        b.ReportAllocs()
        for b.Loop() {
            s := ""
            for i := 0; i < 100; i++ {
                s += "x"
            }
        }
    })

    b.Run("strings_builder", func(b *testing.B) {
        b.ReportAllocs()
        for b.Loop() {
            var sb strings.Builder
            for i := 0; i < 100; i++ {
                sb.WriteString("x")
            }
            _ = sb.String()
        }
    })
}
```

Run: `go test -bench=. -benchmem ./...`

---

## 8. Fuzzing (Go 1.18+)

```go
func FuzzParseAmount(f *testing.F) {
    // Seed corpus
    f.Add("$10.50")
    f.Add("$0.00")
    f.Add("-$5.00")
    f.Add("")
    f.Add("$999999999999")

    f.Fuzz(func(t *testing.T, input string) {
        result, err := ParseAmount(input)
        if err != nil {
            return // expected: invalid inputs should error
        }
        // Property: round-trip - format and re-parse should match
        formatted := FormatAmount(result)
        reparsed, err := ParseAmount(formatted)
        if err != nil {
            t.Fatalf("round-trip failed: ParseAmount(%q) -> %d -> FormatAmount -> %q -> error: %v",
                input, result, formatted, err)
        }
        if reparsed != result {
            t.Fatalf("round-trip mismatch: %d != %d", reparsed, result)
        }
    })
}
```

Run: `go test -fuzz=FuzzParseAmount -fuzztime=30s ./...`

---

## 9. HTTP Handler Testing with httptest

### Testing Individual Handlers

```go
func TestGetUserHandler(t *testing.T) {
    repo := &mockUserRepo{
        findByIDFn: func(ctx context.Context, id string) (*User, error) {
            return &User{ID: id, Name: "Alice"}, nil
        },
    }
    handler := NewGetUserHandler(repo)

    req := httptest.NewRequest(http.MethodGet, "/users/123", nil)
    req.SetPathValue("id", "123") // Go 1.22+ routing
    rec := httptest.NewRecorder()

    handler.ServeHTTP(rec, req)

    if rec.Code != http.StatusOK {
        t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
    }

    var got User
    json.NewDecoder(rec.Body).Decode(&got)
    assertEqual(t, got.Name, "Alice")
}
```

### Testing with a Full Server

```go
func TestAPIIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test in short mode")
    }

    router := setupRouter(testDB)
    srv := httptest.NewServer(router)
    defer srv.Close()

    // Create user
    body := strings.NewReader(`{"email":"alice@test.com","name":"Alice"}`)
    resp, err := http.Post(srv.URL+"/users", "application/json", body)
    assertNoError(t, err)
    assertEqual(t, resp.StatusCode, http.StatusCreated)

    // Get user
    resp, err = http.Get(srv.URL + "/users/1")
    assertNoError(t, err)
    assertEqual(t, resp.StatusCode, http.StatusOK)
}
```

### Testing Middleware

```go
func TestAuthMiddleware(t *testing.T) {
    inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    })

    handler := AuthMiddleware(inner)

    t.Run("missing token", func(t *testing.T) {
        req := httptest.NewRequest(http.MethodGet, "/", nil)
        rec := httptest.NewRecorder()
        handler.ServeHTTP(rec, req)
        assertEqual(t, rec.Code, http.StatusUnauthorized)
    })

    t.Run("valid token", func(t *testing.T) {
        req := httptest.NewRequest(http.MethodGet, "/", nil)
        req.Header.Set("Authorization", "Bearer valid-test-token")
        rec := httptest.NewRecorder()
        handler.ServeHTTP(rec, req)
        assertEqual(t, rec.Code, http.StatusOK)
    })
}
```

---

## 10. Coverage

### Commands

```bash
# Run tests with coverage
go test -cover ./...

# Generate coverage profile
go test -coverprofile=coverage.out ./...

# View coverage in browser
go tool cover -html=coverage.out

# Check coverage percentage
go tool cover -func=coverage.out

# Coverage for specific package
go test -cover -coverprofile=coverage.out ./internal/user/...
```

### Coverage Targets

| Category | Target | Rationale |
|---|---|---|
| General application code | 80%+ | Good balance of effort vs safety |
| Public API / SDK packages (`pkg/`) | 90%+ | External consumers depend on correctness |
| Critical paths (auth, payments, data) | 100% | Zero tolerance for bugs in critical flows |
| Generated code (protobuf, mocks) | Excluded | No value in testing generated code |
| `cmd/main.go` | Excluded | Wiring only; tested via integration tests |

### Excluding Files from Coverage

```bash
# Exclude generated files
go test -coverprofile=coverage.out ./... | grep -v "_generated.go"

# Build tag approach: add to generated files
//go:build ignore
```

---

## 11. CI/CD Integration

### GitHub Actions Example

```yaml
name: Go Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: "1.22"

      - name: Run tests
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/testdb?sslmode=disable
        run: |
          go test -race -coverprofile=coverage.out -covermode=atomic ./...

      - name: Check coverage threshold
        run: |
          COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
          echo "Total coverage: ${COVERAGE}%"
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage ${COVERAGE}% is below 80% threshold"
            exit 1
          fi

      - name: Run benchmarks (no regression check)
        run: go test -bench=. -benchmem -run=^$ ./...

      - name: Run fuzzing (short)
        run: go test -fuzz=. -fuzztime=10s ./...
```

### Test Organization Rules

- **Unit tests**: Same package, `_test.go` suffix, run with `go test ./...`
- **Integration tests**: Use `testing.Short()` guard or build tags
- **Test fixtures**: Place in `testdata/` directory (ignored by `go build`)
- **Test helpers**: Place in `_test.go` files or a `testutil` internal package
- **Parallel by default**: Mark tests `t.Parallel()` unless they share state
