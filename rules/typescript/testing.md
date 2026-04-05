---
description: TypeScript-specific testing rules and E2E patterns
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Testing

## Unit and Integration Tests

Use Vitest or Jest for unit and integration testing:

```bash
# Run all tests
npx vitest run

# Run with coverage
npx vitest run --coverage

# Run in watch mode during development
npx vitest
```

### Test File Convention

- Test files live next to the source: `user.service.ts` -> `user.service.test.ts`
- Or in a `__tests__/` directory at the same level
- Use `.test.ts` suffix, not `.spec.ts` (pick one and be consistent)

### Test Structure

```typescript
describe("UserService", () => {
  describe("create", () => {
    it("should create a user with valid input", async () => {
      const repo = createMockRepo();
      const service = new UserService(repo);

      const user = await service.create({ name: "Alice", email: "alice@example.com" });

      expect(user.name).toBe("Alice");
      expect(repo.create).toHaveBeenCalledOnce();
    });

    it("should throw on duplicate email", async () => {
      const repo = createMockRepo({ createThrows: new ConflictError() });
      const service = new UserService(repo);

      await expect(
        service.create({ name: "Alice", email: "taken@example.com" })
      ).rejects.toThrow(ConflictError);
    });
  });
});
```

## End-to-End Tests with Playwright

Use Playwright for all E2E testing:

```bash
# Run E2E tests
npx playwright test

# Run with UI mode
npx playwright test --ui

# Run specific test file
npx playwright test tests/auth.spec.ts
```

### E2E Test Structure

```typescript
import { test, expect } from "@playwright/test";

test.describe("Authentication", () => {
  test("should allow user to log in", async ({ page }) => {
    await page.goto("/login");
    await page.fill('[name="email"]', "alice@example.com");
    await page.fill('[name="password"]', "password123");
    await page.click('button[type="submit"]');

    await expect(page).toHaveURL("/dashboard");
    await expect(page.locator("h1")).toContainText("Welcome");
  });

  test("should show error on invalid credentials", async ({ page }) => {
    await page.goto("/login");
    await page.fill('[name="email"]', "wrong@example.com");
    await page.fill('[name="password"]', "wrong");
    await page.click('button[type="submit"]');

    await expect(page.locator('[role="alert"]')).toBeVisible();
  });
});
```

### E2E Rules

- Cover the critical happy paths: signup, login, core workflow, logout
- Cover the top 3-5 error scenarios
- Keep E2E tests fast -- defer edge cases to unit tests
- Use `data-testid` attributes for stable selectors
- Never depend on CSS classes or DOM structure for selectors

## E2E Runner Agent

Use the **e2e-runner** agent for:

- Executing the full Playwright test suite against a running environment
- Generating test reports with screenshots on failure
- Retrying flaky tests and reporting instability
- Running E2E tests in CI before deployment

### Invoking the Agent

The e2e-runner agent handles:

1. Starting the dev server if not already running
2. Running the Playwright suite
3. Collecting results, screenshots, and traces
4. Reporting pass/fail summary with links to artifacts

## Coverage Requirements

- Unit + integration tests: 80% minimum coverage
- E2E tests: cover all critical user journeys
- Run coverage in CI and block merges that drop below threshold

```bash
npx vitest run --coverage --coverage.reporter=text --coverage.reporter=lcov
```
