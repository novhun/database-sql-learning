-- ============================================================================
-- Part 01: What is a Database? - Hands-on Lab
-- File: 01_system_catalog.sql
-- Goal: Interact directly with the DBMS internal metadata and run your first DDL/DML.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Inspect the Database Server
-- ----------------------------------------------------------------------------

-- Check the exact database engine and operating system version:
SELECT version();

-- View current connection metadata:
SELECT
    current_database() AS database_name,
    current_user       AS connected_user,
    inet_server_addr() AS server_ip,
    inet_server_port() AS server_port,
    now()              AS current_server_timestamp;

-- ----------------------------------------------------------------------------
-- 2. Exploring the System Catalog (How a DB stores its own metadata)
-- ----------------------------------------------------------------------------
-- Did you know? Databases store their own table definitions, index definitions,
-- and column types as relational tables inside the system catalog!

-- List all databases running on this server instance:
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS total_size
FROM pg_database
WHERE datistemplate = false;

-- Query standard information_schema to view schemas available:
SELECT schema_name
FROM information_schema.schemata;

-- ----------------------------------------------------------------------------
-- 3. File System vs. DBMS: Demonstrating Integrity Constraints
-- ----------------------------------------------------------------------------
-- If you stored users in a JSON file, a buggy script could save:
-- { "id": -5, "email": "not-an-email", "age": -99 }
--
-- Notice how a DBMS enforces integrity guarantees directly at the data layer!

-- Drop table if it previously existed (clean slate):
DROP TABLE IF EXISTS system_demo_users;

-- Create our first table with constraints:
CREATE TABLE system_demo_users (
    user_id     SERIAL PRIMARY KEY,
    username    VARCHAR(50) NOT NULL UNIQUE,
    email       VARCHAR(255) NOT NULL UNIQUE,
    age         INTEGER CHECK (age >= 0 AND age <= 120),
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Insert valid records:
INSERT INTO system_demo_users (username, email, age)
VALUES
    ('alice_dev', 'alice@example.com', 28),
    ('bob_coder', 'bob@example.com', 34),
    ('charlie_db', 'charlie@example.com', 22);

-- Query all inserted rows:
SELECT * FROM system_demo_users;

-- ----------------------------------------------------------------------------
-- 4. Constraint Violation Tests (Observe the DBMS guarding your data)
-- ----------------------------------------------------------------------------

-- TEST 1: Duplicate unique email (Uncomment to test - will throw error:
-- "ERROR: duplicate key value violates unique constraint")
-- INSERT INTO system_demo_users (username, email, age)
-- VALUES ('alice_clone', 'alice@example.com', 30);

-- TEST 2: Check constraint violation (Uncomment to test - will throw error:
-- "ERROR: new row for relation violates check constraint")
-- INSERT INTO system_demo_users (username, email, age)
-- VALUES ('invalid_age_user', 'invalid@example.com', -10);

-- TEST 3: Null constraint violation:
-- INSERT INTO system_demo_users (username, email, age)
-- VALUES (NULL, 'noname@example.com', 25);

-- ----------------------------------------------------------------------------
-- 5. Querying the Table Catalog
-- ----------------------------------------------------------------------------
-- View the columns and data types we just created through the information_schema:
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'system_demo_users'
ORDER BY ordinal_position;
