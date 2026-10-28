# Part 09: Advanced SQL: Window Functions

Window functions are arguably the most powerful analytical feature in modern SQL.

The fundamental difference between regular aggregation and window functions:
- **`GROUP BY` Aggregation:** Collapses multiple rows into a single summary row. Individual row details are discarded.
- **Window Function:** Computes an aggregated or ranking value across a "window" of related rows, **while keeping every individual row intact** in the output.

---

## 1. Syntax Breakdown

```sql
SELECT
    column1,
    FUNCTION() OVER (
        PARTITION BY partition_column  -- 1. Splits data into independent partitions (like mini GROUP BYs)
        ORDER BY sort_column           -- 2. Sorts rows inside each partition
        ROWS frame_specification       -- 3. Defines the exact sliding window frame
    ) AS window_result
FROM table_name;
```

---

## 2. Ranking Functions Comparison

Suppose three employees in Engineering earn: Alice (\$150k), Bob (\$150k), and Charlie (\$110k):

| Function | Alice | Bob | Charlie | Behavior |
| :--- | :---: | :---: | :---: | :--- |
| **`ROW_NUMBER()`** | 1 | 2 | 3 | Deterministic unique row number; arbitrarily breaks ties. |
| **`RANK()`** | 1 | 1 | 3 | Tied rows get the same rank; skips subsequent ranks (gap). |
| **`DENSE_RANK()`** | 1 | 1 | 2 | Tied rows get the same rank; **no gaps** in sequence numbers. |

---

## 3. Value Navigation: `LAG()` and `LEAD()`

These functions let you peek at preceding or succeeding rows without performing expensive self-joins:

- **`LAG(column, offset)`:** Returns the value of `column` from $N$ rows prior to the current row. Essential for **Month-over-Month (MoM)** and **Year-over-Year (YoY)** growth rates:
  $$\text{Growth \%} = \frac{\text{Current Month} - \text{Previous Month}}{\text{Previous Month}} \times 100$$
- **`LEAD(column, offset)`:** Returns the value of `column` from $N$ rows ahead of the current row.

---

## 4. Window Frames: Running Totals & Moving Averages

By default, an `ORDER BY` inside an `OVER` clause defaults to:
`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.

### A. Running Total:
```sql
SELECT
    order_date,
    daily_sales,
    SUM(daily_sales) OVER (ORDER BY order_date) AS running_total
FROM daily_revenue;
```

### B. 7-Day Moving Average:
```sql
SELECT
    order_date,
    daily_sales,
    ROUND(AVG(daily_sales) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS seven_day_moving_avg
FROM daily_revenue;
```

---

## 5. The Canonical Problem: Top-N per Category

A classic technical interview question: *"How do you find the top 2 highest-paid employees in EACH department?"*

Attempting this with `GROUP BY` is impossible because `GROUP BY` collapses rows. With window functions and CTEs, it becomes trivial:

```sql
WITH ranked_employees AS (
    SELECT
        name,
        department_id,
        salary,
        DENSE_RANK() OVER (
            PARTITION BY department_id
            ORDER BY salary DESC
        ) AS salary_rank
    FROM employees
)
SELECT *
FROM ranked_employees
WHERE salary_rank <= 2;
```

Jump into [`09_window_functions.sql`](./09_window_functions.sql) to run running totals, moving averages, MoM analytics, and quartile distributions.
