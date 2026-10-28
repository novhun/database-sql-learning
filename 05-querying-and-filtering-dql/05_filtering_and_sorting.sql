-- ============================================================================
-- Part 05: Querying & Filtering Essentials - Hands-on Lab
-- File: 05_filtering_and_sorting.sql
-- Goal: Practice SELECT projections, logical predicates, three-valued logic,
--       sorting, and production keyset pagination.
-- ============================================================================

-- Clean demo setup for testing NULLs and edge cases
DROP TABLE IF EXISTS query_demo_items;

CREATE TABLE query_demo_items (
    item_id     SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    category    VARCHAR(50) NOT NULL,
    price       NUMERIC(8, 2),
    discount    NUMERIC(4, 2), -- Can be NULL
    stock_qty   INTEGER NOT NULL DEFAULT 0,
    status      VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO query_demo_items (name, category, price, discount, stock_qty, status, created_at)
VALUES
    ('Database Fundamentals Book', 'Books', 35.00, 5.00, 50, 'active', '2026-01-10 10:00:00Z'),
    ('Advanced SQL Handbook', 'Books', 55.00, NULL, 12, 'active', '2026-01-15 11:30:00Z'),
    ('USB-C Fast Charger', 'Electronics', 25.99, 3.50, 100, 'active', '2026-02-01 09:15:00Z'),
    ('Mechanical Keyboard Blue', 'Electronics', 89.99, NULL, 0, 'out_of_stock', '2026-02-10 14:00:00Z'),
    ('Ergonomic Mouse', 'Electronics', 65.50, 10.00, 25, 'active', '2026-02-20 16:45:00Z'),
    ('System Design Blueprint', 'Books', 75.00, NULL, 5, 'archived', '2026-03-01 12:00:00Z'),
    ('Noise Isolating Earplugs', 'Accessories', 15.00, 0.00, 200, 'active', '2026-03-05 08:30:00Z');

-- ----------------------------------------------------------------------------
-- 1. Computed Columns & Aliasing
-- ----------------------------------------------------------------------------
SELECT
    name,
    price,
    COALESCE(discount, 0.00) AS applied_discount,
    ROUND(price - COALESCE(discount, 0.00), 2) AS effective_price,
    CASE
        WHEN stock_qty = 0 THEN 'Out of Stock'
        WHEN stock_qty < 20 THEN 'Low Stock'
        ELSE 'In Stock'
    END AS inventory_status
FROM query_demo_items;

-- ----------------------------------------------------------------------------
-- 2. Logical Operators and Precedence
-- ----------------------------------------------------------------------------
-- Caution with AND / OR precedence: AND takes precedence over OR!
-- Always use parentheses for clarity.

-- Find items that are either Books OR Electronics, AND have stock > 0:
SELECT name, category, stock_qty
FROM query_demo_items
WHERE (category = 'Books' OR category = 'Electronics')
  AND stock_qty > 0;

-- ----------------------------------------------------------------------------
-- 3. Pattern Matching (LIKE, ILIKE)
-- ----------------------------------------------------------------------------
-- Case-insensitive search for anything containing "book" or "handbook":
SELECT item_id, name, category
FROM query_demo_items
WHERE name ILIKE '%book%';

-- Range check with BETWEEN:
SELECT name, price
FROM query_demo_items
WHERE price BETWEEN 25.00 AND 70.00;

-- ----------------------------------------------------------------------------
-- 4. The Three-Valued Logic (3VL) NULL Trap
-- ----------------------------------------------------------------------------

-- WRONG: You might expect this to return rows where discount is not 5.00.
-- But it drops rows where discount IS NULL!
SELECT name, discount
FROM query_demo_items
WHERE discount != 5.00;

-- CORRECT: Explicitly handle NULL state
SELECT name, discount
FROM query_demo_items
WHERE discount != 5.00 OR discount IS NULL;

-- Or using NULL-safe equality / COALESCE:
SELECT name, discount
FROM query_demo_items
WHERE COALESCE(discount, -1) != 5.00;

-- ----------------------------------------------------------------------------
-- 5. Sorting & NULL Positioning
-- ----------------------------------------------------------------------------
-- Default ordering puts NULLs at the end or start depending on DBMS.
-- Standardize behavior using NULLS FIRST or NULLS LAST:
SELECT name, price, discount
FROM query_demo_items
ORDER BY discount ASC NULLS LAST;

-- Multi-column sort: Category ASC, Price DESC:
SELECT category, name, price
FROM query_demo_items
ORDER BY category ASC, price DESC;

-- ----------------------------------------------------------------------------
-- 6. Pagination: OFFSET vs Keyset (Cursor) Pagination
-- ----------------------------------------------------------------------------

-- A. Traditional Offset Pagination (Page 1, 2 items):
SELECT item_id, name, price, created_at
FROM query_demo_items
ORDER BY created_at ASC
LIMIT 2 OFFSET 0;

-- Traditional Offset Pagination (Page 2, 2 items):
SELECT item_id, name, price, created_at
FROM query_demo_items
ORDER BY created_at ASC
LIMIT 2 OFFSET 2;

-- B. Keyset / Cursor Pagination (Scales infinitely):
-- Suppose the last item from page 1 had created_at = '2026-01-15 11:30:00Z' and item_id = 2.
-- Page 2 query seeks directly past that tuple:
SELECT item_id, name, price, created_at
FROM query_demo_items
WHERE (created_at, item_id) > ('2026-01-15 11:30:00Z', 2)
ORDER BY created_at ASC, item_id ASC
LIMIT 2;
