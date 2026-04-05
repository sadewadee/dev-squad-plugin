---
description: Development workflow - research, plan, implement, review
globs: "*"
---

# Development Workflow

## Phase 1: Research and Reuse

Before writing any code, follow this order:

1. **Search GitHub** for existing solutions, libraries, or skeleton projects
2. **Read library documentation** for the chosen tools and frameworks
3. **Evaluate candidates** -- check stars, maintenance activity, license, bundle size
4. **Only then implement** what cannot be found or reused

Never reinvent what already exists. Prefer battle-tested libraries over custom implementations.

## Phase 2: Plan First

- Use the **planner** or architect agent before touching code
- Write a short plan covering:
  - What will be built
  - Which files will be created or modified
  - Data flow and key interfaces
  - Dependencies needed
  - Risks or unknowns
- Get plan approved before proceeding

## Phase 3: Test-Driven Development

1. **Red** -- Write a failing test that describes the desired behavior
2. **Green** -- Write the minimum code to make the test pass
3. **Refactor** -- Clean up while keeping tests green

Follow this cycle for every unit of functionality.

## Phase 4: Implementation

- Work in small, incremental steps
- Commit after each meaningful unit of work
- Keep the build green at all times
- Follow the coding style and security rules

## Phase 5: Code Review

- Run the reviewer agent or request human review
- Address all CRITICAL and HIGH findings
- Verify all automated checks pass

## Phase 6: Commit and Push

- Use conventional commit messages
- Ensure the PR has a clear summary and test plan
- Squash fixup commits before merge

## Pre-Review Checks

Before requesting any review, verify:

- [ ] `npm test` / `go test ./...` passes
- [ ] Linter reports zero errors
- [ ] No secrets in the codebase
- [ ] Documentation updated if behavior changed
- [ ] Coverage meets the 80% threshold
