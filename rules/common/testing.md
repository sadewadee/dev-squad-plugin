---
description: Testing rules, coverage requirements, and TDD workflow
globs: "*"
---

# Testing Rules

## Coverage Requirements

- **Minimum 80% code coverage** for all projects
- Critical paths (auth, payments, data mutations) require **95%+ coverage**
- Coverage is measured on merge -- PRs that drop coverage below threshold are blocked

## Three Test Types

### Unit Tests

- Test individual functions and modules in isolation
- Mock external dependencies (databases, APIs, file system)
- Should run in milliseconds
- Naming: `describe what it does, not how`

### Integration Tests

- Test interactions between components (API + database, service + service)
- Use real dependencies where practical (test databases, in-memory stores)
- Should run in seconds
- Cover the critical user journeys

### End-to-End (E2E) Tests

- Test the full system from the user's perspective
- Run against a deployed or locally running application
- Cover the happy path and top error scenarios
- Keep the E2E suite small and fast -- defer edge cases to unit tests

## Red-Green-Refactor (TDD)

1. **Red**: Write a test that fails because the feature does not exist yet
2. **Green**: Write the simplest code that makes the test pass
3. **Refactor**: Clean up the implementation while keeping the test green

### TDD Rules

- Never write production code without a failing test first
- Each test covers exactly one behavior
- Tests are independent -- no shared mutable state between tests
- Tests read like documentation of the expected behavior

## Quality Assurance Process

1. Run the full test suite locally before pushing
2. CI runs all tests on every push
3. Reviewer verifies test quality during code review
4. Coverage report is generated and checked automatically

## Agent Support

- Use the **tdd-guide** agent/skill for guidance on test structure and strategy
- Use the **reviewer** agent to verify test quality and coverage
- Use the **e2e-runner** agent for end-to-end test execution and reporting
