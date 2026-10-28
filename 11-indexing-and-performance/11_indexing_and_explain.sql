-- ============================================================================
-- Part 11: Indexing & Query Performance Optimization - Hands-on Lab
-- File: 11_indexing_and_explain.sql
-- Goal: Generate 100,000 rows, compare Seq Scan vs Index Scan using
--       EXPLAIN ANALYZE, build covering/partial indexes, and measure index sizes.
-- ============================================================================

DROP TABLE IF EXISTS perf_benchmark_events CASCADE;

CREATE TABLE perf_benchmark_events (
    event_id    SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL,
    event_type  VARCHAR(50) NOT NULL,
    ip_address  VARCHAR(45) NOT NULL,
    payload     TEXT,
    is_flagged  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL
);

-- ----------------------------------------------------------------------------
-- 1. Populate 100,000 Realistic Benchmark Rows
-- ----------------------------------------------------------------------------
INSERT INTO perf_benchmark_events (user_id, event_type, ip_address, payload, is_flagged, created_at)
SELECT
    (random() * 5000)::integer + 1,
    (ARRAY['page_view', 'add_to_cart', 'purchase', 'login', 'logout'])[(random() * 4)::integer + 1],
    '192.168.' || (random() * 254)::integer || '.' || (random() * 254)::integer,
    'Synthetic audit metadata payload token ' || md5(random()::text),
    (random() < 0.02), -- Only ~2% are flagged (imbalanced data)
    TIMESTAMPTZ '2026-01-01 00:00:00Z' + (random() * 300) * INTERVAL '1 day'
FROM generate_series(1, 100000);

-- Refresh database statistics so the query optimizer has accurate row estimates:
ANALYZE perf_benchmark_events;

-- Check table physical storage size:
SELECT pg_size_pretty(pg_total_relation_size('perf_benchmark_events')) AS table_and_index_size;

-- ----------------------------------------------------------------------------
-- 2. Baseline: Querying Without an Index (Sequential Scan)
-- ----------------------------------------------------------------------------
-- Look at the output of EXPLAIN ANALYZE:
-- Notice: "Seq Scan on perf_benchmark_events" and the execution time in ms.
EXPLAIN ANALYZE
SELECT event_id, user_id, event_type, created_at
FROM perf_benchmark_events
WHERE user_id = 4242;

-- ----------------------------------------------------------------------------
-- 3. Creating a B-Tree Index & Observing the Transformation
-- ----------------------------------------------------------------------------
CREATE INDEX idx_perf_events_user_id ON perf_benchmark_events (user_id);

-- Run the exact same query again:
-- Notice: "Index Scan using idx_perf_events_user_id" and execution drops to < 0.1 ms!
EXPLAIN ANALYZE
SELECT event_id, user_id, event_type, created_at
FROM perf_benchmark_events
WHERE user_id = 4242;

-- ----------------------------------------------------------------------------
-- 4. Covering Index & Index Only Scan (Zero Heap Fetches)
-- ----------------------------------------------------------------------------
-- An Index Only Scan avoids reading the table heap pages entirely.
-- We can add extra non-search payload columns into the leaf nodes using INCLUDE:

CREATE INDEX idx_perf_events_covering
ON perf_benchmark_events (user_id) INCLUDE (event_type, created_at);

-- Notice: "Index Only Scan using idx_perf_events_covering"
EXPLAIN ANALYZE
SELECT user_id, event_type, created_at
FROM perf_benchmark_events
WHERE user_id = 4242;

-- ----------------------------------------------------------------------------
-- 5. Partial / Filtered Index (98% Disk Space Savings)
-- ----------------------------------------------------------------------------
-- Only ~2% of rows have is_flagged = TRUE.
-- A full index would waste disk space indexing 98,000 false values.

-- Partial index indexing ONLY flagged events:
CREATE INDEX idx_perf_events_flagged
ON perf_benchmark_events (created_at)
WHERE is_flagged = TRUE;

-- Compare physical index sizes:
SELECT
    c.relname AS index_name,
    pg_size_pretty(pg_relation_size(c.oid)) AS index_size
FROM pg_class c
WHERE c.relname IN ('idx_perf_events_user_id', 'idx_perf_events_flagged');

-- This query utilizes the partial index:
EXPLAIN ANALYZE
SELECT event_id, created_at
FROM perf_benchmark_events
WHERE is_flagged = TRUE
  AND created_at >= '2026-03-01';

-- ----------------------------------------------------------------------------
-- 6. Performance Pitfall: Function Wrapped Columns vs Direct Ranges
-- ----------------------------------------------------------------------------

-- SLOW ANTI-PATTERN: Wrapping created_at in a function prevents index usage!
-- The engine cannot use a standard B-Tree index on created_at for this:
EXPLAIN ANALYZE
SELECT count(*)
FROM perf_benchmark_events
WHERE EXTRACT(YEAR FROM created_at) = 2026;

-- FAST PRODUCTION PATTERN: Use explicit sargable range boundaries:
EXPLAIN ANALYZE
SELECT count(*)
FROM perf_benchmark_events
WHERE created_at >= '2026-01-01' AND created_at < '2027-01-01';
