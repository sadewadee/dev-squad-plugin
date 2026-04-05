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

## useDebounce Hook

Reusable debounce hook for React:

```typescript
import { useState, useEffect } from "react";

function useDebounce<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);

  return debounced;
}
```

### Usage

```typescript
function SearchInput() {
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebounce(query, 300);

  useEffect(() => {
    if (debouncedQuery) {
      fetchResults(debouncedQuery);
    }
  }, [debouncedQuery]);

  return <input value={query} onChange={(e) => setQuery(e.target.value)} />;
}
```

## Repository Pattern

Generic CRUD repository with TypeScript:

```typescript
interface Repository<T, CreateInput, UpdateInput> {
  findById(id: string): Promise<T | null>;
  findAll(filter?: Partial<T>): Promise<T[]>;
  create(data: CreateInput): Promise<T>;
  update(id: string, data: UpdateInput): Promise<T>;
  delete(id: string): Promise<void>;
}
```

### Implementation Example

```typescript
class UserRepository implements Repository<User, CreateUserInput, UpdateUserInput> {
  constructor(private db: Database) {}

  async findById(id: string): Promise<User | null> {
    return this.db.query<User>("SELECT * FROM users WHERE id = $1", [id]);
  }

  async findAll(filter?: Partial<User>): Promise<User[]> {
    // Build query from filter
    return this.db.queryAll<User>(query, params);
  }

  async create(data: CreateUserInput): Promise<User> {
    return this.db.query<User>(
      "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *",
      [data.name, data.email]
    );
  }

  async update(id: string, data: UpdateUserInput): Promise<User> {
    // Build SET clause from data
    return this.db.query<User>(query, params);
  }

  async delete(id: string): Promise<void> {
    await this.db.query("DELETE FROM users WHERE id = $1", [id]);
  }
}
```

### Rules

- One repository per domain entity
- Repositories are injected into services, never instantiated inline
- All database queries live inside repositories, not in route handlers or services
- Use transactions at the service level when coordinating multiple repositories
