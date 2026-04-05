---
description: Code review standards and checklists
globs: "*"
---

# Code Review Standards

## Mandatory Review Triggers

- Any PR targeting main/master branch
- Changes touching authentication, authorization, or payment logic
- Database schema migrations
- Public API contract changes
- Infrastructure or deployment configuration changes

## Pre-Review Requirements

Before requesting review, the author MUST:

- [ ] All tests pass locally
- [ ] No linting errors
- [ ] Self-reviewed the diff
- [ ] Updated relevant documentation
- [ ] Removed debug/temporary code

## Review Checklist

### Readability
- [ ] Code is self-documenting with clear naming
- [ ] Complex logic has explanatory comments
- [ ] No dead code or commented-out blocks

### Size Limits
- [ ] Functions are under 50 lines
- [ ] Files are under 800 lines
- [ ] PRs are under 400 lines changed (split if larger)

### Structure
- [ ] Nesting depth is 4 levels or fewer
- [ ] Single responsibility per function and module
- [ ] No code duplication (DRY)

### Error Handling
- [ ] All error paths are handled explicitly
- [ ] Errors include context for debugging
- [ ] No swallowed errors or empty catch blocks

### Security
- [ ] No hardcoded secrets, tokens, or passwords
- [ ] No `console.log` with sensitive data in production code
- [ ] Inputs are validated at boundaries

### Testing
- [ ] Tests exist for new functionality
- [ ] Coverage is at or above 80%
- [ ] Edge cases and error paths are tested

## Severity Levels

| Level | Description | Action Required |
|-------|-------------|-----------------|
| **CRITICAL** | Security vulnerability, data loss risk, breaking change | Must fix before merge |
| **HIGH** | Bug, missing error handling, no tests | Must fix before merge |
| **MEDIUM** | Code smell, missing docs, suboptimal pattern | Should fix, can negotiate |
| **LOW** | Style nit, naming suggestion, minor improvement | Optional, author decides |

## Approval Criteria

- Zero CRITICAL or HIGH issues remaining
- At least one approving review from a domain-relevant agent or human
- All automated checks (CI, linting, tests) pass
- MEDIUM issues either resolved or acknowledged with a tracking issue
