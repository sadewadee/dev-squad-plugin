---
description: Universal coding style rules enforced across all languages
globs: "*"
---

# Coding Style Rules

## Immutability

- Prefer immutable data structures by default
- Use `const` over `let` (TypeScript/JavaScript)
- Avoid mutation of function arguments
- Return new objects/arrays instead of mutating existing ones
- Only use mutable state when performance requires it, with a comment explaining why

## File Size Limits

| Category | Lines |
|----------|-------|
| Typical file | 200-400 |
| Maximum file | 800 |
| Action when exceeding max | Split into modules |

If a file approaches 800 lines, decompose it before adding more code.

## Function Limits

- Maximum 50 lines per function
- If a function exceeds 50 lines, extract helper functions
- Each function does exactly one thing
- Function name describes what it does, not how

## Nesting Limits

- Maximum 4 levels of nesting
- Use early returns (guard clauses) to reduce nesting
- Extract nested logic into named functions

```
// BAD: deep nesting
if (user) {
  if (user.active) {
    if (user.hasPermission) {
      // do work
    }
  }
}

// GOOD: guard clauses
if (!user) return;
if (!user.active) return;
if (!user.hasPermission) return;
// do work
```

## Error Handling

- Handle errors at every level -- never swallow exceptions
- Include context in error messages (what failed, with what input)
- Use typed errors where the language supports it
- Log errors with structured data, not string concatenation

## Input Validation

- Validate all inputs at system boundaries (API handlers, CLI args, config loading)
- Fail fast with clear error messages
- Use schema validation libraries (Zod, joi, JSON Schema) over manual checks

## Code Quality Checklist

Before considering code complete:

- [ ] No magic numbers -- use named constants
- [ ] No string literals repeated more than once -- use constants
- [ ] All public APIs have documentation
- [ ] No TODO comments without a linked issue
- [ ] Consistent naming convention within the project
- [ ] Imports are organized and unused imports removed
