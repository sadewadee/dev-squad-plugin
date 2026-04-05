---
description: TypeScript-specific coding style rules
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Coding Style

## Type Annotations

- **Explicit types for public APIs**: All exported functions, class methods, and module boundaries must have explicit return types
- **Infer types for locals**: Let TypeScript infer types for local variables, loop iterators, and internal helpers
- Never rely on implicit `any` -- enable `strict: true` in tsconfig

```typescript
// GOOD: explicit return type on exported function
export function calculateTotal(items: CartItem[]): number {
  const subtotal = items.reduce((sum, item) => sum + item.price, 0); // inferred
  return subtotal;
}

// BAD: no return type on exported function
export function calculateTotal(items: CartItem[]) {
  // ...
}
```

## Interface vs Type

- Use **interface** for object shapes (extendable, mergeable)
- Use **type** for unions, intersections, and computed types

```typescript
// GOOD: interface for object shape
interface User {
  id: string;
  name: string;
  email: string;
}

// GOOD: type for union
type Status = "active" | "inactive" | "pending";

// GOOD: type for intersection
type AdminUser = User & { permissions: string[] };
```

## No `any`

- Never use `any` -- use `unknown` instead and narrow with type guards
- If you must escape the type system, use `unknown` with explicit assertion and a comment

```typescript
// BAD
function parse(input: any) { ... }

// GOOD
function parse(input: unknown): ParsedResult {
  if (typeof input !== "string") {
    throw new TypeError("Expected string input");
  }
  return JSON.parse(input) as ParsedResult;
}
```

## Runtime Validation with Zod

Use Zod for all runtime validation at system boundaries:

```typescript
import { z } from "zod";

const CreateUserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  age: z.number().int().positive().optional(),
});

type CreateUserInput = z.infer<typeof CreateUserSchema>;
```

### When to Use Zod

- API request body validation
- Environment variable parsing
- External API response validation
- Configuration file parsing

## No console.log in Production

- Use a structured logger (pino, winston) instead of `console.log`
- `console.log` is acceptable only in development scripts and CLI tools
- Use `console.error` for error output in CLI tools only
- PostToolUse hooks will flag any `console.log` in non-test files

## Null Handling

- Prefer `undefined` over `null` for optional values
- Use optional chaining (`?.`) and nullish coalescing (`??`)
- Never use non-null assertion (`!`) without a preceding guard or comment
