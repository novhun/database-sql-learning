-- ============================================================================
-- Part 09: Window Functions - Hands-on Lab
-- File: 09_window_functions.sql
-- Goal: Calculate running totals, moving averages, MoM growth rates,
--       and solve the Top-N per Category pattern using Window Functions.
-- ============================================================================

DROP TABLE IF EXISTS monthly_sales;

CREATE TABLE monthly_sales (
    sale_id       SERIAL PRIMARY KEY,
    sales_rep     VARCHAR(50) NOT NULL,
    territory     VARCHAR(50) NOT NULL,
    sale_month    DATE NOT NULL,
    amount        NUMERIC(10, 2) NOT NULL
);

INSERT INTO monthly_sales (sales_rep, territory, sale_month, amount)
VALUES
    ('Alice',   'East', '2026-01-01', 12000.00),
    ('Bob',     'East', '2026-01-01', 15000.00),
    ('Charlie', 'West', '2026-01-01',  9000.00),
    ('Diana',   'West', '2026-01-01', 14000.00),

    ('Alice',   'East', '2026-02-01', 14500.00),
    ('Bob',     'East', '2026-02-01', 13000.00),
    ('Charlie', 'West', '2026-02-01', 11000.00),
    ('Diana',   'West', '2026-02-01', 16500.00),

    ('Alice',   'East', '2026-03-01', 18000.00),
    ('Bob',     'East', '2026-03-01', 17500.00),
    ('Charlie', 'West', '2026-03-01', 13000.00),
    ('Diana',   'West', '2026-03-01', 19000.00);

-- ----------------------------------------------------------------------------
-- 1. ROW_NUMBER, RANK, and DENSE_RANK Side-by-Side
-- ----------------------------------------------------------------------------
SELECT
    sales_rep,
    territory,
    amount,
    ROW_NUMBER() OVER (PARTITION BY territory ORDER BY amount DESC) AS row_num,
    RANK()       OVER (PARTITION BY territory ORDER BY amount DESC) AS rnk,
    DENSE_RANK() OVER (PARTITION BY territory ORDER BY amount DESC) AS dense_rnk,
    NTILE(2)     OVER (PARTITION BY territory ORDER BY amount DESC) AS half_tier
FROM monthly_sales
WHERE sale_month = '2026-03-01';

-- ----------------------------------------------------------------------------
-- 2. Cumulative Sum (Running Total)
-- ----------------------------------------------------------------------------
-- Track cumulative earnings for Alice across the quarter:
SELECT
    sales_rep,
    sale_month,
    amount,
    SUM(amount) OVER (
        PARTITION BY sales_rep
        ORDER BY sale_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sales
FROM monthly_sales
WHERE sales_rep = 'Alice'
ORDER BY sale_month;

-- ----------------------------------------------------------------------------
-- 3. Moving Average (Sliding Window Frame)
-- ----------------------------------------------------------------------------
-- Calculate a 2-month rolling average for each rep:
SELECT
    sales_rep,
    sale_month,
    amount,
    ROUND(AVG(amount) OVER (
        PARTITION BY sales_rep
        ORDER BY sale_month
        ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
    ), 2) AS two_month_rolling_avg
FROM monthly_sales
ORDER BY sales_rep, sale_month;

-- ----------------------------------------------------------------------------
-- 4. Value Navigation: Month-over-Month (MoM) Growth with LAG()
-- ----------------------------------------------------------------------------
WITH monthly_totals AS (
    SELECT
        sale_month,
        SUM(amount) AS current_month_revenue
    FROM monthly_sales
    GROUP BY sale_month
)
SELECT
    sale_month,
    current_month_revenue,
    LAG(current_month_revenue, 1) OVER (ORDER BY sale_month) AS previous_month_revenue,
    ROUND(
        (current_month_revenue - LAG(current_month_revenue, 1) OVER (ORDER BY sale_month))
        / LAG(current_month_revenue, 1) OVER (ORDER BY sale_month) * 100, 2
    ) AS mom_growth_percentage
FROM monthly_totals
ORDER BY sale_month;

-- ----------------------------------------------------------------------------
-- 5. The Top-N per Category Pattern
-- ----------------------------------------------------------------------------
-- Find the #1 top performing sales rep for each territory across the whole Q1:
WITH rep_q1_totals AS (
    SELECT
        territory,
        sales_rep,
        SUM(amount) AS total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY territory
            ORDER BY SUM(amount) DESC
        ) AS rank_in_territory
    FROM monthly_sales
    GROUP BY territory, sales_rep
)
SELECT
    territory,
    sales_rep AS top_performer,
    total_revenue
FROM rep_q1_totals
WHERE rank_in_territory = 1;
