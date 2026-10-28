-- ============================================================================
-- Part 14: Database Architecture & Scaling - Hands-on Lab
-- File: 14_partitioning_and_maintenance.sql
-- Goal: Implement declarative range partitioning, observe partition pruning,
--       and execute maintenance operations (VACUUM, ANALYZE, table statistics).
-- ============================================================================

DROP TABLE IF EXISTS scaled_events CASCADE;

-- ----------------------------------------------------------------------------
-- 1. Declarative Range Partitioning
-- ----------------------------------------------------------------------------
-- Define the logical master table partitioned by the log_date column:

CREATE TABLE scaled_events (
    event_id    BIGSERIAL,
    event_name  VARCHAR(50) NOT NULL,
    user_id     INTEGER NOT NULL,
    log_date    DATE NOT NULL,
    metadata    TEXT,
    -- In partitioned tables, the partition key must be included in the primary key!
    PRIMARY KEY (event_id, log_date)
) PARTITION BY RANGE (log_date);

-- ----------------------------------------------------------------------------
-- 2. Creating Discrete Physical Partitions
-- ----------------------------------------------------------------------------

-- Partition for 2024:
CREATE TABLE scaled_events_2024 PARTITION OF scaled_events
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

-- Partition for 2025:
CREATE TABLE scaled_events_2025 PARTITION OF scaled_events
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Partition for 2026:
CREATE TABLE scaled_events_2026 PARTITION OF scaled_events
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- Default partition for any unexpected dates:
CREATE TABLE scaled_events_default PARTITION OF scaled_events DEFAULT;

-- Create indexes on partitions (can also be created on parent table in modern Postgres):
CREATE INDEX idx_scaled_events_2024_user ON scaled_events_2024 (user_id);
CREATE INDEX idx_scaled_events_2025_user ON scaled_events_2025 (user_id);
CREATE INDEX idx_scaled_events_2026_user ON scaled_events_2026 (user_id);

-- ----------------------------------------------------------------------------
-- 3. Automatic Row Routing in Action
-- ----------------------------------------------------------------------------
-- Insert rows into the PARENT table. The DBMS routes each row to its correct physical partition:

INSERT INTO scaled_events (event_name, user_id, log_date, metadata)
VALUES
    ('legacy_import', 101, '2024-06-15', 'Historical log entry from 2024'),
    ('system_upgrade', 102, '2025-08-20', 'Middleware upgrade in 2025'),
    ('new_checkout',   103, '2026-03-10', 'Active customer order in 2026'),
    ('new_signup',     104, '2026-04-01', 'New registration in 2026');

-- Verify that the parent table shows all 4 rows:
SELECT event_id, event_name, log_date FROM scaled_events ORDER BY log_date;

-- Query the individual physical partitions directly:
SELECT event_id, event_name, log_date FROM scaled_events_2024;
SELECT event_id, event_name, log_date FROM scaled_events_2026;

-- ----------------------------------------------------------------------------
-- 4. Witnessing Partition Pruning
-- ----------------------------------------------------------------------------
-- When querying a specific date range, the query planner completely prunes (skips)
-- the partitions for 2024, 2025, and default:

EXPLAIN ANALYZE
SELECT *
FROM scaled_events
WHERE log_date >= '2026-01-01' AND log_date < '2026-12-31';
-- In the output plan, notice that only scaled_events_2026 was scanned!

-- ----------------------------------------------------------------------------
-- 5. Operational Maintenance: VACUUM and Database Statistics
-- ----------------------------------------------------------------------------

-- Check live vs dead tuples in user tables:
SELECT
    relname AS table_name,
    n_live_tup AS active_rows,
    n_dead_tup AS dead_tuples_to_reclaim,
    last_vacuum,
    last_autovacuum,
    last_analyze
FROM pg_stat_user_tables
WHERE relname LIKE 'scaled_events%'
ORDER BY relname;

-- Run standard VACUUM and ANALYZE to reclaim space and update query planner stats:
VACUUM ANALYZE scaled_events;

-- Note on table bloat:
-- In production, autovacuum runs in the background.
-- For zero-downtime table repacking when physical bloat occurs, tools like
-- 'pg_repack' are used instead of VACUUM FULL.
