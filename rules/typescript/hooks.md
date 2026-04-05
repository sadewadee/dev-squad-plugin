---
description: TypeScript-specific hooks for formatting and validation
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Hooks

## PostToolUse Hooks

Run these automatically after any TypeScript file is written or modified:

### Prettier Formatting

```bash
npx prettier --write <file>
```

Runs on every `.ts` and `.tsx` file write. Ensures consistent formatting across the project.

### TypeScript Compilation Check

```bash
npx tsc --noEmit
```

Runs after implementation changes. Catches type errors immediately rather than at build time.

### Console.log Detection

```bash
grep -rn "console\.log" <file>
```

Flags any `console.log` statements in non-test, non-script files. These must be removed or replaced with a structured logger before commit.

### ESLint Check

```bash
npx eslint <file>
```

Runs after file writes. Catches style violations, unused imports, and potential bugs.

## Hook Execution Order

1. `prettier --write <file>` -- format first
2. `eslint <file>` -- lint the formatted code
3. `tsc --noEmit` -- type check the full project
4. Console.log detection -- flag debug statements

## Stop Hook: Console Audit

Before completing any implementation task, run a final audit:

```bash
grep -rn "console\.\(log\|debug\|info\)" src/ --include="*.ts" --include="*.tsx" \
  --exclude-dir=node_modules --exclude-dir=__tests__ --exclude-dir=scripts
```

If any matches are found:

1. Report them as **HIGH** severity findings
2. Replace with structured logger calls or remove entirely
3. Only `console.error` is acceptable in production code, and only for fatal startup errors

## Failure Handling

- Prettier failure: likely a syntax error -- fix the syntax first
- tsc failure: type error -- fix before proceeding with any other work
- ESLint failure: auto-fix what you can (`--fix`), manually fix the rest
- Console.log found: replace with logger or remove -- do not commit with debug logging

## Pre-Commit Verification

Before any commit involving TypeScript files:

```bash
npx prettier --check "src/**/*.{ts,tsx}" && npx tsc --noEmit && npx eslint src/ && npm test
```

All must pass. Do not commit with known failures.
