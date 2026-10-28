-- ============================================================================
-- Part 06: Aggregations & Grouping - Hands-on Lab
-- File: 06_aggregations.sql
-- Goal: Master summary metrics, GROUP BY mechanics, HAVING filters,
--       FILTER clauses, and multi-dimensional ROLLUP reporting.
-- ============================================================================

DROP TABLE IF EXISTS sales_orders;

CREATE TABLE sales_orders (
    order_id      SERIAL PRIMARY KEY,
    customer_id   INTEGER NOT NULL,
    region        VARCHAR(50) NOT NULL,
    category      VARCHAR(50) NOT NULL,
    product_name  VARCHAR(100) NOT NULL,
    quantity      INTEGER NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(8, 2) NOT NULL CHECK (unit_price >= 0),
    discount_pct  NUMERIC(4, 2) DEFAULT 0.00,
    order_date    DATE NOT NULL
);

INSERT INTO sales_orders (customer_id, region, category, product_name, quantity, unit_price, discount_pct, order_date)
VALUES
    (101, 'North America', 'Hardware', 'Server Rack 42U', 2, 850.00, 0.05, '2026-01-15'),
    (102, 'North America', 'Hardware', 'Network Switch 24p', 5, 250.00, 0.00, '2026-01-18'),
    (103, 'Europe',        'Hardware', 'Server Rack 42U', 1, 900.00, 0.10, '2026-01-20'),
    (101, 'North America', 'Software', 'OS Enterprise License', 10, 120.00, 0.15, '2026-02-05'),
    (104, 'Asia-Pacific',  'Software', 'OS Enterprise License', 4, 130.00, 0.00, '2026-02-12'),
    (105, 'Europe',        'Services', 'Cloud Migration Consulting', 20, 150.00, 0.00, '2026-02-14'),
    (102, 'North America', 'Software', 'Database Monitoring Suite', 2, 450.00, 0.05, '2026-02-28'),
    (106, 'Asia-Pacific',  'Hardware', 'Network Switch 24p', 3, 260.00, 0.00, '2026-03-02'),
    (103, 'Europe',        'Software', 'OS Enterprise License', 8, 125.00, 0.08, '2026-03-10');

-- ----------------------------------------------------------------------------
-- 1. Basic Aggregation & Summary Metrics
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*)                                       AS total_order_lines,
    COUNT(DISTINCT customer_id)                    AS unique_customers,
    SUM(quantity)                                  AS total_units_sold,
    ROUND(SUM(quantity * unit_price), 2)           AS gross_revenue,
    ROUND(AVG(unit_price), 2)                      AS average_unit_price,
    MIN(unit_price)                                AS cheapest_unit_price,
    MAX(unit_price)                                AS most_expensive_unit_price
FROM sales_orders;

-- ----------------------------------------------------------------------------
-- 2. Grouping by Single & Multiple Columns
-- ----------------------------------------------------------------------------

-- Revenue by Region:
SELECT
    region,
    COUNT(*) AS total_orders,
    ROUND(SUM(quantity * unit_price), 2) AS regional_revenue
FROM sales_orders
GROUP BY region
ORDER BY regional_revenue DESC;

-- Revenue by Region AND Category (Multi-column Group By):
SELECT
    region,
    category,
    COUNT(*) AS transaction_count,
    ROUND(SUM(quantity * unit_price * (1 - discount_pct)), 2) AS net_revenue
FROM sales_orders
GROUP BY region, category
ORDER BY region, net_revenue DESC;

-- ----------------------------------------------------------------------------
-- 3. Filtering with HAVING vs WHERE
-- ----------------------------------------------------------------------------

-- WHERE filters rows before grouping (only Hardware orders in 2026)
-- HAVING filters aggregate groups (only regions with net revenue >= $2,000)
SELECT
    region,
    COUNT(*) AS hardware_orders,
    ROUND(SUM(quantity * unit_price), 2) AS hardware_revenue
FROM sales_orders
WHERE category = 'Hardware'
GROUP BY region
HAVING SUM(quantity * unit_price) >= 2000.00
ORDER BY hardware_revenue DESC;

-- ----------------------------------------------------------------------------
-- 4. Modern SQL: Conditional Aggregation with FILTER
-- ----------------------------------------------------------------------------
-- Produce an executive dashboard pivot in a single scan:
SELECT
    region,
    COUNT(*) AS all_orders,
    COUNT(*) FILTER (WHERE category = 'Hardware') AS hardware_orders,
    COUNT(*) FILTER (WHERE category = 'Software') AS software_orders,
    COUNT(*) FILTER (WHERE category = 'Services') AS services_orders,
    ROUND(SUM(quantity * unit_price) FILTER (WHERE category = 'Hardware'), 2) AS hardware_revenue,
    ROUND(SUM(quantity * unit_price) FILTER (WHERE category = 'Software'), 2) AS software_revenue
FROM sales_orders
GROUP BY region;

-- ----------------------------------------------------------------------------
-- 5. Multi-Dimensional Reporting: ROLLUP, CUBE & GROUPING SETS
-- ----------------------------------------------------------------------------

-- ROLLUP generates hierarchical subtotals:
-- Level 1: (Region, Category)
-- Level 2: (Region, NULL) -> Subtotal per region
-- Level 3: (NULL, NULL)   -> Grand Total
SELECT
    COALESCE(region, '--- ALL REGIONS ---') AS report_region,
    COALESCE(category, '--- SUBTOTAL ---')  AS report_category,
    SUM(quantity)                           AS total_quantity,
    ROUND(SUM(quantity * unit_price), 2)    AS total_sales
FROM sales_orders
GROUP BY ROLLUP (region, category)
ORDER BY region NULLS LAST, category NULLS LAST;
