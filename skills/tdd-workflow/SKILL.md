---
name: tdd-workflow
description: Test-Driven Development workflow for dev-squad agents. Defines a 7-step TDD process from user journey documentation through test creation, red-green-refactor cycles, and coverage verification. Includes unit, integration, and E2E test types with git checkpoint integration.
---

# TDD Workflow - Test-Driven Development for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Follow this workflow strictly when implementing any feature or fix. Every dev-squad agent writing code MUST use this process. No code is written before a failing test exists.

---

## The 7-Step TDD Process

### Step 1: Document User Journeys

Before writing any test, understand what the user needs.

**Actions:**
- Identify the primary user journey (happy path)
- Identify edge cases and error paths
- Document expected inputs and outputs
- Note acceptance criteria

**Output format:**
```
## User Journey: [Feature Name]

### Happy Path
1. User does X
2. System responds with Y
3. User sees Z

### Edge Cases
- Empty input -> validation error
- Duplicate entry -> conflict error
- Unauthorized -> 401 response

### Acceptance Criteria
- [ ] Feature works for happy path
- [ ] All edge cases handled
- [ ] Error messages are clear
- [ ] Performance within thresholds
```

**Git checkpoint:**
```bash
git add docs/ && git commit -m "docs: user journey for [feature]"
```

---

### Step 2: Create Test Cases

Translate user journeys into concrete test cases. Do not write test code yet -- just list the cases.

**Actions:**
- Map each journey step to one or more test cases
- Categorize by type: unit, integration, E2E
- Prioritize: critical path first, edge cases second

**Output format:**
```
## Test Cases: [Feature Name]

### Unit Tests
- [ ] createUser: valid input returns user object
- [ ] createUser: missing email throws validation error
- [ ] createUser: duplicate email throws conflict error
- [ ] hashPassword: produces correct bcrypt hash
- [ ] hashPassword: different inputs produce different hashes

### Integration Tests
- [ ] POST /users: creates user and returns 201
- [ ] POST /users: duplicate email returns 409
- [ ] POST /users: missing fields returns 400 with details
- [ ] GET /users/:id: returns user after creation

### E2E Tests
- [ ] Signup flow: fill form, submit, see dashboard
- [ ] Signup flow: duplicate email shows error message
```

---

### Step 3: RED -- Write Failing Tests

Write the test code. Run it. It MUST fail. If it passes, the test is not testing new behavior.

**Rules:**
- Write ONE test at a time
- Test must fail for the RIGHT reason (not a syntax error or import error)
- Test name describes the expected behavior
- Use descriptive assertion messages

**Example (TypeScript/Jest):**
```typescript
describe("UserService.create", () => {
  it("should create a user with valid input", async () => {
    const result = await userService.create({
      email: "alice@example.com",
      name: "Alice",
      password: "securePassword123",
    });

    expect(result).toMatchObject({
      email: "alice@example.com",
      name: "Alice",
    });
    expect(result.id).toBeDefined();
    expect(result.passwordHash).toBeUndefined(); // not exposed
  });

  it("should throw ConflictError for duplicate email", async () => {
    await userService.create({ email: "alice@example.com", name: "Alice", password: "pass123" });

    await expect(
      userService.create({ email: "alice@example.com", name: "Alice 2", password: "pass456" })
    ).rejects.toThrow(ConflictError);
  });
});
```

**Example (Go):**
```go
func TestUserService_Create(t *testing.T) {
    t.Run("valid input returns user", func(t *testing.T) {
        svc := NewUserService(mockRepo)
        user, err := svc.Create(ctx, CreateUserDTO{
            Email: "alice@example.com",
            Name:  "Alice",
        })
        if err != nil {
            t.Fatalf("unexpected error: %v", err)
        }
        if user.Email != "alice@example.com" {
            t.Errorf("email = %q, want %q", user.Email, "alice@example.com")
        }
    })
}
```

**Git checkpoint:**
```bash
git add -A && git commit -m "test(red): failing tests for [feature]"
```

---

### Step 4: Implement Minimal Code (GREEN Target)

Write the MINIMUM code to make the failing test pass. No more.

**Rules:**
- Only write code that is required to pass the current failing test
- Do not add features, optimizations, or "nice to haves"
- Hardcode values if that makes the test pass (you will generalize in refactor)
- Do not write code for tests that do not exist yet

**Anti-patterns to avoid:**
- Writing the entire feature before running tests
- Adding error handling for cases not yet tested
- Optimizing before correctness is established
- Adding logging, metrics, or caching before tests pass

---

### Step 5: GREEN -- Verify Tests Pass

Run the tests. ALL tests must pass (not just the new one).

**Commands:**
```bash
# TypeScript
npm test -- --watchAll=false

# Go
go test ./...

# Python
pytest
```

**If tests fail:**
- Fix the implementation (not the test) unless the test has a bug
- Do not change test expectations to match wrong behavior
- Run the full test suite, not just the new test

**Git checkpoint:**
```bash
git add -A && git commit -m "feat(green): [feature] passing"
```

---

### Step 6: Refactor

Clean up the code while keeping all tests green.

**Refactoring checklist:**
- [ ] Remove duplication (DRY)
- [ ] Extract functions/methods for clarity
- [ ] Improve naming (variables, functions, types)
- [ ] Simplify conditionals
- [ ] Extract constants and configuration
- [ ] Ensure single responsibility per function
- [ ] Add error context where missing
- [ ] Run tests after EVERY change

**Rules:**
- Tests must pass after every refactoring step
- Do not add new behavior during refactoring
- If you want to add behavior, go back to Step 3 (RED)
- Refactoring changes structure, not behavior

**Git checkpoint:**
```bash
git add -A && git commit -m "refactor: clean up [feature] implementation"
```

---

### Step 7: Verify Coverage

Check that test coverage meets the project thresholds.

**Commands:**
```bash
# TypeScript (Jest)
npx jest --coverage

# Go
go test -cover -coverprofile=coverage.out ./...
go tool cover -func=coverage.out

# Python
pytest --cov=src --cov-report=term-missing
```

**Coverage Targets:**

| Category | Minimum | Stretch |
|---|---|---|
| General application code | 80% | 90% |
| Public APIs / SDK packages | 90% | 95% |
| Critical paths (auth, payments, data integrity) | 100% | 100% |
| UI components (logic, not markup) | 70% | 80% |

**If coverage is below target:**
- Go back to Step 3: write more tests for uncovered paths
- Focus on: error branches, edge cases, boundary conditions
- Do NOT write meaningless tests just to hit the number

---

## Three Test Types

### Unit Tests

Test individual functions, methods, or classes in isolation.

**Characteristics:**
- Fast (< 10ms per test)
- No I/O (no database, no network, no filesystem)
- Mock external dependencies
- Test one behavior per test

**When to write:** For all business logic, data transformations, validation, calculations.

```typescript
// Unit test: pure business logic
describe("calculateDiscount", () => {
  it("applies 10% for orders over $100", () => {
    expect(calculateDiscount(150)).toBe(15);
  });
  it("no discount for orders under $100", () => {
    expect(calculateDiscount(50)).toBe(0);
  });
});
```

### Integration Tests

Test how components work together with real dependencies.

**Characteristics:**
- Slower (100ms - 5s per test)
- Use real database (test instance), real HTTP stack
- Test the boundary between layers
- Seed and clean up test data

**When to write:** For API endpoints, database queries, service interactions.

```typescript
// Integration test: real HTTP + real DB
describe("POST /api/v1/users", () => {
  beforeEach(async () => {
    await db.query("TRUNCATE users CASCADE");
  });

  it("creates a user and returns 201", async () => {
    const res = await request(app)
      .post("/api/v1/users")
      .send({ email: "alice@test.com", name: "Alice", password: "secure123" });

    expect(res.status).toBe(201);
    expect(res.body.email).toBe("alice@test.com");

    const dbUser = await db.query("SELECT * FROM users WHERE email = $1", ["alice@test.com"]);
    expect(dbUser.rows).toHaveLength(1);
  });
});
```

### E2E Tests (Playwright)

Test complete user flows through the browser.

**Characteristics:**
- Slowest (5s - 30s per test)
- Run against deployed application (staging or local)
- Test real user interactions
- Catch integration issues between frontend and backend

**When to write:** For critical user journeys (signup, login, checkout, onboarding).

```typescript
// E2E test: full user flow
import { test, expect } from "@playwright/test";

test("user can sign up and reach dashboard", async ({ page }) => {
  await page.goto("/signup");

  await page.fill('[name="email"]', "alice@test.com");
  await page.fill('[name="name"]', "Alice");
  await page.fill('[name="password"]', "securePassword123");
  await page.fill('[name="confirmPassword"]', "securePassword123");
  await page.click('button[type="submit"]');

  // Should redirect to dashboard
  await expect(page).toHaveURL("/dashboard");
  await expect(page.getByText("Welcome, Alice")).toBeVisible();
});

test("signup shows error for duplicate email", async ({ page }) => {
  // Seed: create user first via API
  await page.request.post("/api/v1/users", {
    data: { email: "alice@test.com", name: "Alice", password: "pass123" },
  });

  await page.goto("/signup");
  await page.fill('[name="email"]', "alice@test.com");
  await page.fill('[name="name"]', "Alice");
  await page.fill('[name="password"]', "securePassword123");
  await page.fill('[name="confirmPassword"]', "securePassword123");
  await page.click('button[type="submit"]');

  await expect(page.getByText("Email is already registered")).toBeVisible();
});
```

---

## Git Integration

### Commit Strategy

TDD produces natural commit checkpoints. Use them:

| Stage | Commit Prefix | Example |
|---|---|---|
| User journey docs | `docs:` | `docs: user journey for signup flow` |
| Failing tests | `test(red):` | `test(red): failing tests for user creation` |
| Passing tests | `feat(green):` | `feat(green): user creation passing` |
| Refactoring | `refactor:` | `refactor: extract password hashing to utility` |
| Coverage improvement | `test:` | `test: add edge case coverage for user creation` |

### Branch Strategy

```
feature/user-signup
  ├── docs: user journey for signup flow
  ├── test(red): failing tests for user creation service
  ├── feat(green): user creation service passing
  ├── refactor: extract validation to shared module
  ├── test(red): failing tests for signup API endpoint
  ├── feat(green): signup endpoint passing
  ├── refactor: centralize error handling
  ├── test(red): failing E2E tests for signup flow
  ├── feat(green): E2E signup flow passing
  └── test: coverage at 92% for signup module
```

### When to Commit

- After every RED-GREEN-REFACTOR cycle completes
- After reaching a coverage milestone
- Before switching to a different test case
- Never commit with failing tests (except RED commits, which are intentionally failing)

---

## Quick Reference Card

```
1. DOCUMENT  → Write user journeys and acceptance criteria
2. PLAN      → List test cases by type (unit/integration/E2E)
3. RED       → Write ONE failing test. Run it. Confirm it fails.
4. GREEN     → Write MINIMUM code to pass. Run tests. All green.
5. REFACTOR  → Clean up. Run tests after every change. Still green.
6. REPEAT    → Go back to step 3 for the next test case.
7. VERIFY    → Check coverage. Fill gaps. Ship.
```
