---
description: TypeScript-specific design patterns
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Patterns

## API Response Format

Use a generic interface for consistent API responses:

```typescript
interface ApiResponse<T> {
  success: boolean;
  data: T | null;
  error: ApiError | null;
  meta: ResponseMeta;
}

interface ApiError {
  code: string;
  message: string;
  details?: FieldError[];
}

interface FieldError {
  field: string;
  message: string;
}

interface ResponseMeta {
  requestId: string;
  timestamp: string;
  pagination?: PaginationMeta;
}

interface PaginationMeta {
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}
```

### Helper Functions

```typescript
function ok<T>(data: T, meta?: Partial<ResponseMeta>): ApiResponse<T> {
  return {
    success: true,
    data,
    error: null,
    meta: { requestId: generateId(), timestamp: new Date().toISOString(), ...meta },
  };
}

function fail(code: string, message: string, details?: FieldError[]): ApiResponse<never> {
  return {
    success: false,
    data: null,
    error: { code, message, details },
    meta: { requestId: generateId(), timestamp: new Date().toISOString() },
  };
}
```

## Discriminated Unions for State

Model finite states explicitly — let TypeScript prove exhaustiveness.

```typescript
type RequestState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };

function render<T>(state: RequestState<T>) {
  switch (state.status) {
    case "idle":    return <Empty />;
    case "loading": return <Spinner />;
    case "success": return <Data value={state.data} />;
    case "error":   return <ErrorView error={state.error} />;
    // No default — exhaustiveness checked by TS
  }
}
```

## Brand Types for Domain IDs

Stop mixing `userId: string` and `orderId: string` at call sites.

```typescript
type Brand<T, B> = T & { readonly __brand: B };
type UserId  = Brand<string, "UserId">;
type OrderId = Brand<string, "OrderId">;

function asUserId(s: string): UserId { return s as UserId; }

function loadUser(id: UserId) { /* ... */ }
loadUser(orderIdFromSomewhere); // TS error — different brand
```

## `satisfies` Over Type Assertion

```typescript
// BAD: loses literal inference
const palette: Record<string, string> = { brand: "#0066ff", danger: "#ff0033" };
palette.brand; // string, not "#0066ff"

// GOOD: validates shape, keeps literal
const palette = {
  brand:  "#0066ff",
  danger: "#ff0033",
} satisfies Record<string, string>;
palette.brand; // "#0066ff"
```

## See Also

- React/JSX patterns → `skills/frontend-patterns/SKILL.md` (core) + `skills/react-stack-2026/SKILL.md` (React 19 / Next.js 15 / TanStack Query / shadcn)
- Backend API patterns (repository, service layer, middleware) → `skills/backend-patterns/SKILL.md`
- Hooks / debounce / data fetching → `skills/frontend-patterns/SKILL.md`
