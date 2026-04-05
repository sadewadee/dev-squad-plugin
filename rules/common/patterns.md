---
description: Common development patterns and project scaffolding
globs: "*"
---

# Common Patterns

## Skeleton Projects

When starting a new project, follow this workflow:

1. **Search** GitHub for skeleton/template repositories matching your stack
2. **Evaluate** candidates by stars, recent activity, and code quality
3. **Clone** the best match as your starting point
4. **Iterate** -- remove what you don't need, add what you do

Never start from a blank directory when a quality skeleton exists.

## Repository Pattern

Separate data access from business logic using the repository pattern:

```
interface Repository<T> {
  findById(id: string): Promise<T | null>
  findAll(filter?: Partial<T>): Promise<T[]>
  create(data: CreateInput<T>): Promise<T>
  update(id: string, data: UpdateInput<T>): Promise<T>
  delete(id: string): Promise<void>
}
```

### Benefits

- Business logic does not depend on the database
- Easy to swap storage backends
- Simple to mock in tests
- Consistent CRUD interface across all entities

### Rules

- One repository per entity/aggregate
- Repositories return domain objects, not database rows
- Keep query logic inside the repository, not in services
- Use transactions at the service layer, not the repository layer

## API Response Format

Use a consistent envelope for all API responses:

```json
{
  "success": true,
  "data": { ... },
  "error": null,
  "meta": {
    "requestId": "abc-123",
    "timestamp": "2025-01-01T00:00:00Z",
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "total": 100
    }
  }
}
```

### Error Response

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email is required",
    "details": [
      { "field": "email", "message": "must not be empty" }
    ]
  },
  "meta": {
    "requestId": "abc-124",
    "timestamp": "2025-01-01T00:00:01Z"
  }
}
```

### Rules

- Always include `success` boolean at the top level
- Always include `meta.requestId` for traceability
- Error `code` is machine-readable (UPPER_SNAKE_CASE)
- Error `message` is human-readable
- Never expose stack traces or internal details in production errors
