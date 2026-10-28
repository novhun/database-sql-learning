-- ============================================================================
-- Part 12: Transactions, ACID & Concurrency - Hands-on Lab
-- File: 12_transactions_and_locks.sql
-- Goal: Execute atomic multi-statement transactions, handle savepoints,
--       prevent race conditions with FOR UPDATE and SKIP LOCKED, and inspect
--       MVCC system internals (xmin, xmax, ctid).
-- ============================================================================

DROP TABLE IF EXISTS bank_accounts CASCADE;
DROP TABLE IF EXISTS job_queue CASCADE;

-- ----------------------------------------------------------------------------
-- Schema & Setup
-- ----------------------------------------------------------------------------
CREATE TABLE bank_accounts (
    account_id  SERIAL PRIMARY KEY,
    owner_name  VARCHAR(50) NOT NULL,
    balance     NUMERIC(12, 2) NOT NULL CHECK (balance >= 0.00), -- Constraint enforces no overdraft
    version     INTEGER NOT NULL DEFAULT 1 -- For Optimistic Concurrency Control (OCC)
);

INSERT INTO bank_accounts (owner_name, balance)
VALUES
    ('Alice', 1000.00),
    ('Bob',    500.00);

-- ----------------------------------------------------------------------------
-- 1. Atomic Transfer Transaction with SAVEPOINTS
-- ----------------------------------------------------------------------------
-- Transfer $200 from Alice to Bob atomically:

BEGIN;

    -- Step 1: Deduct from Alice
    UPDATE bank_accounts
    SET balance = balance - 200.00
    WHERE account_id = 1;

    -- Create an intermediate checkpoint in the transaction
    SAVEPOINT after_debit;

    -- Step 2: Credit to Bob
    UPDATE bank_accounts
    SET balance = balance + 200.00
    WHERE account_id = 2;

    -- Suppose an optional step fails (e.g. logging fee):
    -- We could do: ROLLBACK TO SAVEPOINT after_debit;
    -- Or commit the entire unit of work:
COMMIT;

-- Verify both balances transitioned cleanly:
SELECT * FROM bank_accounts;

-- ----------------------------------------------------------------------------
-- 2. Pessimistic Row Locking: SELECT ... FOR UPDATE
-- ----------------------------------------------------------------------------
-- When executing financial withdrawals or booking finite concert tickets:

BEGIN;
    -- Lock Alice's row exclusively. Any other concurrent transaction attempting
    -- to read FOR UPDATE or modify Alice will wait until this transaction completes.
    SELECT account_id, owner_name, balance
    FROM bank_accounts
    WHERE account_id = 1
    FOR UPDATE;

    -- Perform the safe update:
    UPDATE bank_accounts
    SET balance = balance - 50.00
    WHERE account_id = 1;

COMMIT;

-- ----------------------------------------------------------------------------
-- 3. SKIP LOCKED (Building High-Performance Job Queues in SQL)
-- ----------------------------------------------------------------------------
-- If 10 background worker processes are polling a queue for tasks,
-- SKIP LOCKED prevents workers from blocking or fighting over the same task!

CREATE TABLE job_queue (
    job_id     SERIAL PRIMARY KEY,
    task_name  VARCHAR(100) NOT NULL,
    status     VARCHAR(20) NOT NULL DEFAULT 'queued'
);

INSERT INTO job_queue (task_name)
VALUES ('Send welcome email'), ('Process thumbnail'), ('Generate PDF report');

-- Worker 1 grabs the next available job without blocking Worker 2:
BEGIN;
    SELECT job_id, task_name
    FROM job_queue
    WHERE status = 'queued'
    ORDER BY job_id
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    -- Worker processes task...
    UPDATE job_queue SET status = 'processing' WHERE job_id = 1;
COMMIT;

-- ----------------------------------------------------------------------------
-- 4. Optimistic Concurrency Control (OCC) Pattern
-- ----------------------------------------------------------------------------
-- Instead of holding locks, check if the record was modified by another thread:

-- Step A: App reads row (Alice balance = 750.00, version = 1)
-- Step B: Attempt conditional update matching the read version:
UPDATE bank_accounts
SET
    balance = balance + 100.00,
    version = version + 1
WHERE account_id = 1 AND version = 1;

-- If rows affected == 1: Success!
-- If rows affected == 0: Concurrent write detected! Abort or retry.

-- ----------------------------------------------------------------------------
-- 5. Demystifying MVCC Internals (xmin, xmax, ctid)
-- ----------------------------------------------------------------------------
-- Every PostgreSQL table has hidden system columns:
-- - ctid: The physical location of the row version (page number, tuple index)
-- - xmin: The transaction ID that inserted this version
-- - xmax: The transaction ID that updated or deleted this version (0 if active)

SELECT
    ctid,
    xmin,
    xmax,
    account_id,
    owner_name,
    balance
FROM bank_accounts;

-- Update Alice's balance again to observe MVCC creating a new tuple version:
UPDATE bank_accounts SET balance = balance + 10 WHERE account_id = 1;

-- Notice that ctid and xmin have changed, demonstrating that the old row
-- was not overwritten in-place, but a new version was written!
SELECT
    ctid,
    xmin,
    xmax,
    account_id,
    owner_name,
    balance
FROM bank_accounts;
