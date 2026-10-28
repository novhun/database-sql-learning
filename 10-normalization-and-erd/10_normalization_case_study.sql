-- ============================================================================
-- Part 10: Database Normalization & Schema Design - Hands-on Lab
-- File: 10_normalization_case_study.sql
-- Goal: Deconstruct a messy unnormalized table into 1NF, 2NF, and 3NF,
--       and migrate existing records without data loss.
-- ============================================================================

-- Clean slate
DROP TABLE IF EXISTS raw_legacy_orders CASCADE;
DROP TABLE IF EXISTS norm_order_items CASCADE;
DROP TABLE IF EXISTS norm_orders CASCADE;
DROP TABLE IF EXISTS norm_products CASCADE;
DROP TABLE IF EXISTS norm_customers CASCADE;

-- ----------------------------------------------------------------------------
-- 1. The Legacy Unnormalized Spreadsheet Table
-- ----------------------------------------------------------------------------
-- Notice the severe redundancies: customer info repeats on every line,
-- product info repeats, price is duplicated.
CREATE TABLE raw_legacy_orders (
    raw_id          SERIAL PRIMARY KEY,
    order_number    INTEGER NOT NULL,
    order_date      DATE NOT NULL,
    customer_email  VARCHAR(100) NOT NULL,
    customer_name   VARCHAR(100) NOT NULL,
    customer_city   VARCHAR(50) NOT NULL,
    product_sku     VARCHAR(20) NOT NULL,
    product_name    VARCHAR(100) NOT NULL,
    product_price   NUMERIC(8, 2) NOT NULL,
    quantity        INTEGER NOT NULL
);

INSERT INTO raw_legacy_orders
(order_number, order_date, customer_email, customer_name, customer_city, product_sku, product_name, product_price, quantity)
VALUES
    (5001, '2026-03-01', 'alice@ny.com', 'Alice Smith', 'New York', 'KB-MEC-01', 'Mechanical Keyboard', 89.99, 1),
    (5001, '2026-03-01', 'alice@ny.com', 'Alice Smith', 'New York', 'MS-OPT-02', 'Wireless Mouse',      45.00, 2),
    (5002, '2026-03-02', 'bob@ldn.com',  'Bob Jones',   'London',   'KB-MEC-01', 'Mechanical Keyboard', 89.99, 1),
    (5003, '2026-03-03', 'alice@ny.com', 'Alice Smith', 'New York', 'HD-MON-03', '27-inch 4K Monitor',  399.00, 1);

-- ----------------------------------------------------------------------------
-- 2. Designing the Normalized 3NF Schema
-- ----------------------------------------------------------------------------

-- Entity 1: Customers (Eliminates customer update anomalies)
CREATE TABLE norm_customers (
    customer_id SERIAL PRIMARY KEY,
    email       VARCHAR(100) NOT NULL UNIQUE,
    full_name   VARCHAR(100) NOT NULL,
    city        VARCHAR(50) NOT NULL
);

-- Entity 2: Products (Eliminates product price update anomalies & insertion anomalies)
CREATE TABLE norm_products (
    product_id  SERIAL PRIMARY KEY,
    sku         VARCHAR(20) NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL,
    price       NUMERIC(8, 2) NOT NULL CHECK (price >= 0)
);

-- Entity 3: Orders (Represents the parent transactional event)
CREATE TABLE norm_orders (
    order_id     INTEGER PRIMARY KEY, -- Using original order_number
    customer_id  INTEGER NOT NULL REFERENCES norm_customers(customer_id),
    order_date   DATE NOT NULL
);

-- Entity 4: Order Line Items (Junction table with composite PK & historical snapshot)
CREATE TABLE norm_order_items (
    order_id     INTEGER NOT NULL REFERENCES norm_orders(order_id) ON DELETE CASCADE,
    product_id   INTEGER NOT NULL REFERENCES norm_products(product_id),
    quantity     INTEGER NOT NULL CHECK (quantity > 0),
    billed_price NUMERIC(8, 2) NOT NULL, -- Preserves price at purchase time
    PRIMARY KEY (order_id, product_id)
);

-- ----------------------------------------------------------------------------
-- 3. Data Migration Pipeline (Extracting Distinct Entities)
-- ----------------------------------------------------------------------------

-- Step A: Populate Customers
INSERT INTO norm_customers (email, full_name, city)
SELECT DISTINCT customer_email, customer_name, customer_city
FROM raw_legacy_orders;

-- Step B: Populate Products
INSERT INTO norm_products (sku, name, price)
SELECT DISTINCT product_sku, product_name, product_price
FROM raw_legacy_orders;

-- Step C: Populate Orders
INSERT INTO norm_orders (order_id, customer_id, order_date)
SELECT DISTINCT
    r.order_number,
    c.customer_id,
    r.order_date
FROM raw_legacy_orders r
INNER JOIN norm_customers c ON r.customer_email = c.email;

-- Step D: Populate Order Line Items
INSERT INTO norm_order_items (order_id, product_id, quantity, billed_price)
SELECT
    r.order_number,
    p.product_id,
    r.quantity,
    r.product_price
FROM raw_legacy_orders r
INNER JOIN norm_products p ON r.product_sku = p.sku;

-- ----------------------------------------------------------------------------
-- 4. Verification & Clean Relational Query
-- ----------------------------------------------------------------------------
-- Reassemble full order invoices using joins:
SELECT
    o.order_id,
    o.order_date,
    c.full_name AS customer,
    c.city,
    p.name AS product,
    oi.quantity,
    oi.billed_price,
    ROUND(oi.quantity * oi.billed_price, 2) AS line_total
FROM norm_orders o
INNER JOIN norm_customers c    ON o.customer_id = c.customer_id
INNER JOIN norm_order_items oi ON o.order_id = oi.order_id
INNER JOIN norm_products p     ON oi.product_id = p.product_id
ORDER BY o.order_id, p.name;
