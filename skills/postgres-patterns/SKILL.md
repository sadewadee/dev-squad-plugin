---
name: postgres-patterns
description: PostgreSQL patterns for dev-squad agents. Covers index types and strategies, data type reference, common query patterns (UPSERT, cursor pagination, queue processing), anti-pattern detection queries, RLS, and configuration tuning. SQL examples throughout.
---

# PostgreSQL Patterns - Database Reference for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Load these patterns when any dev-squad agent is designing schemas, writing queries, optimizing performance, or configuring PostgreSQL. Use as a reference for index selection, query patterns, and anti-pattern detection.

---

## 1. Index Cheat Sheet

### Index Types

| Type | Best For | Example |
|---|---|---|
| **B-tree** (default) | Equality, range, sorting, LIKE 'prefix%' | `CREATE INDEX idx_users_email ON users (email)` |
| **GIN** | Full-text search, JSONB, arrays, tsvector | `CREATE INDEX idx_posts_tags ON posts USING GIN (tags)` |
| **BRIN** | Large tables with naturally ordered data (timestamps, sequences) | `CREATE INDEX idx_events_created ON events USING BRIN (created_at)` |
| **Hash** | Equality only (rare; B-tree is usually better) | `CREATE INDEX idx_sessions_token ON sessions USING HASH (token)` |
| **GiST** | Geometric, range types, full-text (alternative to GIN) | `CREATE INDEX idx_locations_geo ON locations USING GIST (point)` |

### Composite Index

Column order matters: most selective column first for equality, range columns last.

```sql
-- For queries: WHERE status = 'active' AND created_at > '2024-01-01' ORDER BY created_at
CREATE INDEX idx_orders_status_created ON orders (status, created_at);

-- Rule: Equality columns first, then range/sort columns
-- WHERE a = ? AND b = ? AND c > ? ORDER BY c
CREATE INDEX idx_example ON table (a, b, c);
```

### Covering Index (INCLUDE)

Include non-indexed columns to enable index-only scans:

```sql
-- Query: SELECT email, name FROM users WHERE email = ?
-- Without INCLUDE: index lookup + heap fetch
-- With INCLUDE: index-only scan (no heap fetch)
CREATE INDEX idx_users_email_covering ON users (email) INCLUDE (name);

-- Verify with EXPLAIN: look for "Index Only Scan"
EXPLAIN SELECT email, name FROM users WHERE email = 'alice@example.com';
```

### Partial Index

Index only the rows that matter:

```sql
-- Only index active users (skip 90% of rows if most are inactive)
CREATE INDEX idx_users_active_email ON users (email) WHERE active = true;

-- Only index unprocessed jobs
CREATE INDEX idx_jobs_pending ON jobs (created_at) WHERE status = 'pending';

-- Only index non-null values
CREATE INDEX idx_users_phone ON users (phone) WHERE phone IS NOT NULL;
```

### When to Use Each

```
Need to search JSONB fields?          → GIN
Need full-text search?                → GIN on tsvector column
Table has 100M+ rows, time-ordered?   → BRIN on timestamp
Query filters on equality + range?    → Composite B-tree
Query selects extra cols after filter? → Covering index (INCLUDE)
Only some rows matter?                → Partial index
Geospatial queries?                   → GiST with PostGIS
```

---

## 2. Data Type Reference

| Use Case | Type | Notes |
|---|---|---|
| Primary key | `UUID` or `BIGSERIAL` | UUID for distributed systems; BIGSERIAL for simplicity |
| Text (variable) | `TEXT` | Prefer over VARCHAR -- no performance difference in Postgres |
| Text (bounded) | `VARCHAR(n)` | Only when you need a hard length constraint |
| Boolean | `BOOLEAN` | Use `NOT NULL DEFAULT false` -- avoid nullable booleans |
| Integer | `INTEGER` / `BIGINT` | BIGINT for IDs and counts that may exceed 2B |
| Money | `NUMERIC(12,2)` or `INTEGER` (cents) | Never use `MONEY` type -- locale-dependent |
| Timestamps | `TIMESTAMPTZ` | Always with timezone. Never use `TIMESTAMP` without TZ |
| Date only | `DATE` | Calendar dates without time |
| Duration | `INTERVAL` | Native interval arithmetic |
| JSON data | `JSONB` | Always JSONB, never JSON (binary, indexable, deduplicated keys) |
| Arrays | `TEXT[]`, `INTEGER[]` | Use for small, fixed sets. For variable/large: use join table |
| Enum-like | `TEXT` with CHECK | `CHECK (status IN ('draft','published','archived'))` |
| IP address | `INET` | Supports IPv4 and IPv6, comparison operators |
| UUID | `UUID` | Use `gen_random_uuid()` (PG 13+) for generation |

### Column Defaults

```sql
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    role        TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'manager')),
    active      BOOLEAN NOT NULL DEFAULT true,
    metadata    JSONB NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## 3. Common Patterns

### UPSERT (INSERT ... ON CONFLICT)

```sql
-- Insert or update on conflict
INSERT INTO user_preferences (user_id, key, value)
VALUES ($1, $2, $3)
ON CONFLICT (user_id, key)
DO UPDATE SET
    value = EXCLUDED.value,
    updated_at = now();

-- Insert or ignore (do nothing on conflict)
INSERT INTO tags (name)
VALUES ($1)
ON CONFLICT (name) DO NOTHING
RETURNING id;
```

### Cursor-Based Pagination

More efficient than OFFSET for large datasets:

```sql
-- First page
SELECT id, name, created_at
FROM products
WHERE category = $1
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- Next page: use last row's values as cursor
SELECT id, name, created_at
FROM products
WHERE category = $1
  AND (created_at, id) < ($2, $3)  -- $2=last_created_at, $3=last_id
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- Index to support this:
CREATE INDEX idx_products_category_cursor ON products (category, created_at DESC, id DESC);
```

### Queue Processing with FOR UPDATE SKIP LOCKED

```sql
-- Worker picks up next available job without blocking other workers
WITH next_job AS (
    SELECT id
    FROM jobs
    WHERE status = 'pending'
      AND scheduled_at <= now()
    ORDER BY priority DESC, scheduled_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
)
UPDATE jobs
SET status = 'processing',
    started_at = now(),
    worker_id = $1
FROM next_job
WHERE jobs.id = next_job.id
RETURNING jobs.*;
```

### Row-Level Security (RLS)

```sql
-- Enable RLS on the table
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Policy: users can only see their own documents
CREATE POLICY documents_select ON documents
    FOR SELECT
    USING (owner_id = current_setting('app.current_user_id')::UUID);

-- Policy: users can only insert documents they own
CREATE POLICY documents_insert ON documents
    FOR INSERT
    WITH CHECK (owner_id = current_setting('app.current_user_id')::UUID);

-- Policy: admins can see everything
CREATE POLICY documents_admin ON documents
    FOR ALL
    USING (current_setting('app.current_role') = 'admin');

-- Set user context before queries (in application code)
-- SET LOCAL app.current_user_id = 'uuid-here';
-- SET LOCAL app.current_role = 'user';
```

### Soft Delete with Filtered Index

```sql
-- Add soft delete column
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;

-- Partial index: only index non-deleted rows
CREATE INDEX idx_users_email_active ON users (email) WHERE deleted_at IS NULL;

-- Create a view for convenience
CREATE VIEW active_users AS
SELECT * FROM users WHERE deleted_at IS NULL;

-- Soft delete
UPDATE users SET deleted_at = now() WHERE id = $1;
```

### Updated_at Trigger

```sql
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Apply to all tables that have updated_at
CREATE TRIGGER set_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

### Full-Text Search

```sql
-- Add tsvector column
ALTER TABLE posts ADD COLUMN search_vector TSVECTOR;

-- Populate it
UPDATE posts SET search_vector =
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(body, '')), 'B');

-- Keep it updated with trigger
CREATE FUNCTION posts_search_update() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.body, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER posts_search_trigger
    BEFORE INSERT OR UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION posts_search_update();

-- GIN index
CREATE INDEX idx_posts_search ON posts USING GIN (search_vector);

-- Query with ranking
SELECT id, title, ts_rank(search_vector, query) AS rank
FROM posts, plainto_tsquery('english', $1) query
WHERE search_vector @@ query
ORDER BY rank DESC
LIMIT 20;
```

---

## 4. Anti-Pattern Detection Queries

### Find Unindexed Foreign Keys

```sql
SELECT
    tc.table_name,
    kcu.column_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND NOT EXISTS (
      SELECT 1
      FROM pg_indexes
      WHERE tablename = tc.table_name
        AND indexdef LIKE '%' || kcu.column_name || '%'
  )
ORDER BY tc.table_name, kcu.column_name;
```

### Find Slow Queries

```sql
-- Top 10 slowest queries by total time
SELECT
    calls,
    round(total_exec_time::numeric, 2) AS total_time_ms,
    round(mean_exec_time::numeric, 2) AS avg_time_ms,
    round(max_exec_time::numeric, 2) AS max_time_ms,
    rows,
    query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Queries with high average time
SELECT
    calls,
    round(mean_exec_time::numeric, 2) AS avg_time_ms,
    query
FROM pg_stat_statements
WHERE calls > 10
  AND mean_exec_time > 100  -- over 100ms average
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Detect Table Bloat

```sql
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname || '.' || tablename::regclass)) AS index_size,
    n_dead_tup,
    n_live_tup,
    CASE WHEN n_live_tup > 0
        THEN round(100.0 * n_dead_tup / n_live_tup, 1)
        ELSE 0
    END AS dead_pct
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

### Find Unused Indexes

```sql
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS times_used
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Find Missing Indexes (Seq Scans on Large Tables)

```sql
SELECT
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    n_live_tup AS estimated_rows,
    pg_size_pretty(pg_relation_size(relid)) AS table_size
FROM pg_stat_user_tables
WHERE seq_scan > 100
  AND n_live_tup > 10000
  AND (idx_scan IS NULL OR idx_scan < seq_scan)
ORDER BY seq_tup_read DESC
LIMIT 20;
```

### Lock Monitoring

```sql
-- Current locks and what's blocking what
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_query,
    blocking_activity.query AS blocking_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

---

## 5. Configuration Template

Tuning for a server with 16 GB RAM, 4 CPU cores, SSD storage:

```ini
# Memory
shared_buffers = 4GB                   # 25% of RAM
effective_cache_size = 12GB            # 75% of RAM
work_mem = 64MB                        # Per-sort/hash operation
maintenance_work_mem = 1GB             # For VACUUM, CREATE INDEX

# WAL
wal_buffers = 64MB
max_wal_size = 2GB
min_wal_size = 1GB
checkpoint_completion_target = 0.9

# Query Planner
random_page_cost = 1.1                 # SSD (use 4.0 for HDD)
effective_io_concurrency = 200         # SSD (use 2 for HDD)
default_statistics_target = 100        # Increase to 500 for complex queries

# Connections
max_connections = 100                  # Use connection pooler for more
# Consider PgBouncer for 100+ concurrent connections

# Parallelism
max_worker_processes = 4
max_parallel_workers_per_gather = 2
max_parallel_workers = 4
max_parallel_maintenance_workers = 2

# Logging
log_min_duration_statement = 200       # Log queries over 200ms
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0                     # Log all temp file usage

# Autovacuum (aggressive for OLTP)
autovacuum_max_workers = 4
autovacuum_naptime = 30s
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.05  # 5% dead rows triggers vacuum
autovacuum_analyze_scale_factor = 0.05

# Extensions (enable as needed)
# shared_preload_libraries = 'pg_stat_statements,pgaudit'
```

### Scaling Guidelines

| RAM | shared_buffers | effective_cache_size | work_mem |
|---|---|---|---|
| 4 GB | 1 GB | 3 GB | 16 MB |
| 8 GB | 2 GB | 6 GB | 32 MB |
| 16 GB | 4 GB | 12 GB | 64 MB |
| 32 GB | 8 GB | 24 GB | 128 MB |
| 64 GB | 16 GB | 48 GB | 256 MB |
