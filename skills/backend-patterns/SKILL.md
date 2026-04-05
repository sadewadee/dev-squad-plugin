---
name: backend-patterns
description: Backend architecture patterns for dev-squad agents. Covers RESTful API structure, repository and service layer patterns, middleware, database optimization, caching, error handling, JWT auth with RBAC, rate limiting, background jobs, and structured logging. TypeScript/Node.js examples.
---

# Backend Patterns - Server Architecture for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Load these patterns when any dev-squad agent is building, reviewing, or architecting backend services. Use as a reference for API design, data layer implementation, and infrastructure patterns.

---

## 1. RESTful API Structure

### Route Organization

```typescript
// src/routes/index.ts
import { Router } from "express";
import { userRoutes } from "./users";
import { orderRoutes } from "./orders";

const router = Router();
router.use("/api/v1/users", userRoutes);
router.use("/api/v1/orders", orderRoutes);
export default router;
```

### Resource Routes

```typescript
// src/routes/users.ts
import { Router } from "express";
import { UserController } from "../controllers/user.controller";
import { authenticate, authorize } from "../middleware/auth";
import { validate } from "../middleware/validate";
import { createUserSchema, updateUserSchema } from "../schemas/user.schema";

const router = Router();
const controller = new UserController();

router.get("/", authenticate, controller.list);
router.get("/:id", authenticate, controller.getById);
router.post("/", authenticate, authorize("admin"), validate(createUserSchema), controller.create);
router.patch("/:id", authenticate, authorize("admin", "owner"), validate(updateUserSchema), controller.update);
router.delete("/:id", authenticate, authorize("admin"), controller.delete);

export { router as userRoutes };
```

### RESTful Conventions

| Action | Method | Path | Status |
|---|---|---|---|
| List | GET | /resources | 200 |
| Get one | GET | /resources/:id | 200 / 404 |
| Create | POST | /resources | 201 |
| Update (partial) | PATCH | /resources/:id | 200 / 404 |
| Replace | PUT | /resources/:id | 200 / 404 |
| Delete | DELETE | /resources/:id | 204 / 404 |

---

## 2. Repository Pattern

Abstracts data access behind an interface:

```typescript
// src/repositories/user.repository.ts
export interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  findAll(filter: UserFilter, pagination: Pagination): Promise<PaginatedResult<User>>;
  create(data: CreateUserDTO): Promise<User>;
  update(id: string, data: UpdateUserDTO): Promise<User>;
  delete(id: string): Promise<void>;
}

export class PostgresUserRepository implements IUserRepository {
  constructor(private db: Pool) {}

  async findById(id: string): Promise<User | null> {
    const result = await this.db.query(
      "SELECT id, email, name, role, created_at FROM users WHERE id = $1",
      [id]
    );
    return result.rows[0] ?? null;
  }

  async findAll(filter: UserFilter, pagination: Pagination): Promise<PaginatedResult<User>> {
    const { page, limit } = pagination;
    const offset = (page - 1) * limit;

    const conditions: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    if (filter.role) {
      conditions.push(`role = $${paramIndex++}`);
      params.push(filter.role);
    }
    if (filter.search) {
      conditions.push(`(name ILIKE $${paramIndex} OR email ILIKE $${paramIndex})`);
      params.push(`%${filter.search}%`);
      paramIndex++;
    }

    const where = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

    const [dataResult, countResult] = await Promise.all([
      this.db.query(
        `SELECT id, email, name, role, created_at FROM users ${where} ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
        [...params, limit, offset]
      ),
      this.db.query(`SELECT COUNT(*) FROM users ${where}`, params),
    ]);

    return {
      data: dataResult.rows,
      total: parseInt(countResult.rows[0].count, 10),
      page,
      limit,
      totalPages: Math.ceil(parseInt(countResult.rows[0].count, 10) / limit),
    };
  }

  async create(data: CreateUserDTO): Promise<User> {
    const result = await this.db.query(
      "INSERT INTO users (email, name, password_hash, role) VALUES ($1, $2, $3, $4) RETURNING *",
      [data.email, data.name, data.passwordHash, data.role ?? "user"]
    );
    return result.rows[0];
  }

  // ... update, delete similar
}
```

---

## 3. Service Layer Pattern

Business logic lives in services, not controllers or repositories:

```typescript
// src/services/user.service.ts
export class UserService {
  constructor(
    private userRepo: IUserRepository,
    private emailService: IEmailService,
    private cache: ICacheService,
    private logger: ILogger
  ) {}

  async createUser(dto: CreateUserDTO): Promise<User> {
    // Business rule: check uniqueness
    const existing = await this.userRepo.findByEmail(dto.email);
    if (existing) {
      throw new ConflictError(`Email ${dto.email} is already registered`);
    }

    // Business rule: hash password
    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.userRepo.create({
      ...dto,
      passwordHash,
    });

    // Side effects
    await this.emailService.sendWelcome(user.email, user.name);
    this.logger.info("user created", { userId: user.id, email: user.email });

    return user;
  }

  async getUser(id: string): Promise<User> {
    // Check cache first
    const cached = await this.cache.get<User>(`user:${id}`);
    if (cached) return cached;

    const user = await this.userRepo.findById(id);
    if (!user) {
      throw new NotFoundError("User", id);
    }

    await this.cache.set(`user:${id}`, user, 300); // 5 min TTL
    return user;
  }
}
```

---

## 4. Middleware Pattern

### Authentication Middleware

```typescript
// src/middleware/auth.ts
export function authenticate(req: Request, res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    throw new UnauthorizedError("Missing or invalid Authorization header");
  }

  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, config.jwtSecret) as JWTPayload;
    req.user = { id: payload.sub, role: payload.role, email: payload.email };
    next();
  } catch {
    throw new UnauthorizedError("Invalid or expired token");
  }
}

export function authorize(...roles: string[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      throw new UnauthorizedError("Not authenticated");
    }
    if (roles.length > 0 && !roles.includes(req.user.role)) {
      throw new ForbiddenError("Insufficient permissions");
    }
    next();
  };
}
```

### Logging Middleware

```typescript
// src/middleware/logging.ts
export function requestLogger(logger: ILogger) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const start = performance.now();
    const requestId = crypto.randomUUID();
    req.requestId = requestId;

    res.on("finish", () => {
      const duration = Math.round(performance.now() - start);
      logger.info("request completed", {
        requestId,
        method: req.method,
        path: req.path,
        status: res.statusCode,
        durationMs: duration,
        userAgent: req.headers["user-agent"],
        userId: req.user?.id,
      });
    });

    next();
  };
}
```

### Rate Limiting Middleware

```typescript
// src/middleware/rate-limit.ts
import { RateLimiterRedis } from "rate-limiter-flexible";

export function rateLimiter(redis: Redis, opts: { points: number; duration: number }) {
  const limiter = new RateLimiterRedis({
    storeClient: redis,
    keyPrefix: "rl",
    points: opts.points,
    duration: opts.duration,
  });

  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const key = req.user?.id ?? req.ip;
    try {
      const result = await limiter.consume(key);
      res.setHeader("X-RateLimit-Remaining", result.remainingPoints);
      res.setHeader("X-RateLimit-Reset", new Date(Date.now() + result.msBeforeNext).toISOString());
      next();
    } catch {
      res.status(429).json({ error: "Too many requests" });
    }
  };
}
```

---

## 5. Database Patterns

### N+1 Prevention

```typescript
// BAD: N+1 query
async function getOrdersWithUsers(orderIds: string[]) {
  const orders = await db.query("SELECT * FROM orders WHERE id = ANY($1)", [orderIds]);
  for (const order of orders.rows) {
    order.user = await db.query("SELECT * FROM users WHERE id = $1", [order.user_id]); // N queries!
  }
}

// GOOD: Single query with JOIN
async function getOrdersWithUsers(orderIds: string[]) {
  return db.query(`
    SELECT o.*, u.name as user_name, u.email as user_email
    FROM orders o
    JOIN users u ON u.id = o.user_id
    WHERE o.id = ANY($1)
  `, [orderIds]);
}

// GOOD: DataLoader pattern for GraphQL / batch access
const userLoader = new DataLoader<string, User>(async (ids) => {
  const users = await db.query("SELECT * FROM users WHERE id = ANY($1)", [ids]);
  const userMap = new Map(users.rows.map((u) => [u.id, u]));
  return ids.map((id) => userMap.get(id) ?? new Error(`User ${id} not found`));
});
```

### Transaction Pattern

```typescript
async function transferFunds(fromId: string, toId: string, amount: number): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const from = await client.query(
      "SELECT balance FROM accounts WHERE id = $1 FOR UPDATE",
      [fromId]
    );
    if (from.rows[0].balance < amount) {
      throw new BadRequestError("Insufficient funds");
    }

    await client.query("UPDATE accounts SET balance = balance - $1 WHERE id = $2", [amount, fromId]);
    await client.query("UPDATE accounts SET balance = balance + $1 WHERE id = $2", [amount, toId]);

    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}
```

### Query Optimization Rules

- Always use parameterized queries (`$1`, `$2`) -- never string interpolation
- Add indexes for columns used in WHERE, JOIN, and ORDER BY
- Use `EXPLAIN ANALYZE` to verify query plans
- Limit result sets: always paginate lists
- Use `SELECT` with explicit columns, not `SELECT *` in production

---

## 6. Caching (Redis, Cache-Aside)

```typescript
// src/services/cache.service.ts
export class RedisCacheService implements ICacheService {
  constructor(private redis: Redis) {}

  async get<T>(key: string): Promise<T | null> {
    const data = await this.redis.get(key);
    return data ? JSON.parse(data) : null;
  }

  async set<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
    await this.redis.set(key, JSON.stringify(value), "EX", ttlSeconds);
  }

  async invalidate(pattern: string): Promise<void> {
    const keys = await this.redis.keys(pattern);
    if (keys.length > 0) {
      await this.redis.del(...keys);
    }
  }
}

// Cache-aside pattern in service
async function getProduct(id: string): Promise<Product> {
  const cacheKey = `product:${id}`;

  // 1. Check cache
  const cached = await cache.get<Product>(cacheKey);
  if (cached) return cached;

  // 2. Cache miss: fetch from DB
  const product = await productRepo.findById(id);
  if (!product) throw new NotFoundError("Product", id);

  // 3. Populate cache
  await cache.set(cacheKey, product, 600); // 10 min TTL

  return product;
}

// Invalidate on mutation
async function updateProduct(id: string, data: UpdateProductDTO): Promise<Product> {
  const product = await productRepo.update(id, data);
  await cache.invalidate(`product:${id}`);
  await cache.invalidate("products:list:*"); // invalidate list caches too
  return product;
}
```

---

## 7. Error Handling

### Centralized Error Classes

```typescript
// src/errors/index.ts
export class AppError extends Error {
  constructor(
    public message: string,
    public statusCode: number,
    public code: string,
    public isOperational = true
  ) {
    super(message);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super(`${resource} with ID ${id} not found`, 404, "NOT_FOUND");
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 409, "CONFLICT");
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = "Unauthorized") {
    super(message, 401, "UNAUTHORIZED");
  }
}

export class ForbiddenError extends AppError {
  constructor(message = "Forbidden") {
    super(message, 403, "FORBIDDEN");
  }
}

export class BadRequestError extends AppError {
  constructor(message: string) {
    super(message, 400, "BAD_REQUEST");
  }
}
```

### Centralized Error Handler

```typescript
// src/middleware/error-handler.ts
export function errorHandler(logger: ILogger) {
  return (err: Error, req: Request, res: Response, _next: NextFunction): void => {
    if (err instanceof AppError) {
      logger.warn("operational error", {
        code: err.code,
        message: err.message,
        path: req.path,
        method: req.method,
      });
      res.status(err.statusCode).json({
        error: { code: err.code, message: err.message },
      });
      return;
    }

    // Unexpected errors
    logger.error("unhandled error", {
      error: err.message,
      stack: err.stack,
      path: req.path,
      method: req.method,
    });
    res.status(500).json({
      error: { code: "INTERNAL_ERROR", message: "An unexpected error occurred" },
    });
  };
}
```

### Retry with Exponential Backoff

```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  opts: { maxRetries?: number; baseDelayMs?: number; maxDelayMs?: number } = {}
): Promise<T> {
  const { maxRetries = 3, baseDelayMs = 200, maxDelayMs = 5000 } = opts;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (attempt === maxRetries) throw err;
      const delay = Math.min(baseDelayMs * 2 ** attempt + Math.random() * 100, maxDelayMs);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
  throw new Error("unreachable");
}

// Usage
const result = await withRetry(() => externalApi.call(params), { maxRetries: 3 });
```

---

## 8. JWT Auth + RBAC

```typescript
// src/services/auth.service.ts
export class AuthService {
  constructor(
    private userRepo: IUserRepository,
    private jwtSecret: string,
    private tokenExpiry: string = "15m",
    private refreshExpiry: string = "7d"
  ) {}

  async login(email: string, password: string): Promise<TokenPair> {
    const user = await this.userRepo.findByEmail(email);
    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new UnauthorizedError("Invalid credentials");
    }

    return this.generateTokenPair(user);
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    const payload = jwt.verify(refreshToken, this.jwtSecret) as JWTPayload;
    if (payload.type !== "refresh") {
      throw new UnauthorizedError("Invalid refresh token");
    }
    const user = await this.userRepo.findById(payload.sub);
    if (!user) throw new UnauthorizedError("User not found");
    return this.generateTokenPair(user);
  }

  private generateTokenPair(user: User): TokenPair {
    const accessToken = jwt.sign(
      { sub: user.id, email: user.email, role: user.role, type: "access" },
      this.jwtSecret,
      { expiresIn: this.tokenExpiry }
    );
    const refreshToken = jwt.sign(
      { sub: user.id, type: "refresh" },
      this.jwtSecret,
      { expiresIn: this.refreshExpiry }
    );
    return { accessToken, refreshToken };
  }
}

// RBAC permission check
const ROLE_PERMISSIONS: Record<string, string[]> = {
  admin: ["users:read", "users:write", "users:delete", "orders:read", "orders:write", "settings:write"],
  manager: ["users:read", "orders:read", "orders:write"],
  user: ["orders:read"],
};

export function requirePermission(permission: string) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const userRole = req.user?.role;
    if (!userRole || !ROLE_PERMISSIONS[userRole]?.includes(permission)) {
      throw new ForbiddenError(`Missing permission: ${permission}`);
    }
    next();
  };
}
```

---

## 9. Background Jobs / Queues

```typescript
// src/jobs/queue.ts
import { Queue, Worker, Job } from "bullmq";

// Define queues
export const emailQueue = new Queue("email", { connection: redisConfig });
export const reportQueue = new Queue("report", { connection: redisConfig });

// Producer: enqueue jobs
async function onUserCreated(user: User): Promise<void> {
  await emailQueue.add("welcome", { userId: user.id, email: user.email }, {
    attempts: 3,
    backoff: { type: "exponential", delay: 1000 },
  });
}

// Consumer: process jobs
const emailWorker = new Worker("email", async (job: Job) => {
  switch (job.name) {
    case "welcome":
      await sendWelcomeEmail(job.data.email);
      break;
    case "password-reset":
      await sendPasswordResetEmail(job.data.email, job.data.token);
      break;
  }
}, {
  connection: redisConfig,
  concurrency: 5,
  limiter: { max: 50, duration: 60_000 }, // 50 emails per minute
});

emailWorker.on("failed", (job, err) => {
  logger.error("email job failed", { jobId: job?.id, error: err.message });
});
```

---

## 10. Structured Logging

```typescript
// src/logger.ts
import pino from "pino";

export const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
  formatters: {
    level: (label) => ({ level: label }),
  },
  serializers: {
    err: pino.stdSerializers.err,
    req: pino.stdSerializers.req,
    res: pino.stdSerializers.res,
  },
  redact: ["req.headers.authorization", "password", "passwordHash", "token"],
});

// Usage throughout the application
logger.info({ userId: user.id, action: "login" }, "user logged in");
logger.warn({ orderId, retryCount }, "payment retry");
logger.error({ err, requestId }, "unhandled exception");
```

### Logging Rules

- **Always structured**: Use key-value fields, not string interpolation
- **Redact sensitive data**: Passwords, tokens, PII
- **Include context**: requestId, userId, traceId in every log
- **Level discipline**: `error` = action needed, `warn` = unusual, `info` = business events, `debug` = developer detail
- **Never log in loops**: Log summaries, not per-iteration
