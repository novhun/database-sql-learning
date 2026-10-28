# Part 06: Aggregations & Grouping

Data analysis and business intelligence rely on turning millions of atomic transactions into actionable summaries: monthly revenue, active user counts, average order values, and churn rates.

In this module, you will master **Aggregate Functions** and the intricacies of **`GROUP BY`** and **`HAVING`**.

---

## 1. Core Aggregate Functions

Aggregate functions take multiple values from a column and compute a single summary value:

| Function | Description | How It Handles `NULL` |
| :--- | :--- | :--- |
| **`COUNT(*)`** | Counts total rows in the relation/group. | Includes `NULL` rows. |
| **`COUNT(column)`** | Counts non-null values in `column`. | Ignores `NULL` values! |
| **`COUNT(DISTINCT col)`** | Counts unique non-null values. | Ignores `NULL` values. |
| **`SUM(column)`** | Calculates total sum of numeric column. | Ignores `NULL` values. |
| **`AVG(column)`** | Computes arithmetic mean ($\frac{\text{sum}}{\text{count}}$). | Ignores `NULL` values! |
| **`MIN(column)` / `MAX(column)`** | Finds lowest/highest value (numbers, dates, or strings). | Ignores `NULL` values. |

> [!WARNING]
> **The `AVG()` NULL Trap:** If 4 students score 100, 100, 100, and `NULL` (did not take exam):
> - `AVG(score)` will return **100** (because it computes $300 / 3$, ignoring the NULL).
> - If you want missing scores counted as 0: use `AVG(COALESCE(score, 0))` which gives **75** ($300 / 4$).

---

## 2. The Golden Rule of `GROUP BY`

When using `GROUP BY`, every column in your `SELECT` list must be either:
1. Part of an **Aggregate Function** (e.g., `SUM(price)`), or
2. Listed in the **`GROUP BY`** clause.

```sql
-- INVALID: The database cannot know which title to show for each category!
SELECT category, title, COUNT(*)
FROM courses
GROUP BY category; -- ERROR!

-- VALID:
SELECT category, COUNT(*) AS course_count, AVG(price) AS avg_price
FROM courses
GROUP BY category;
```

---

## 3. `WHERE` vs. `HAVING`

Understanding the distinction is one of the most common SQL interview questions:

```
[ Raw Table Rows ]
         |
         v  Filtered by WHERE (cannot reference aggregate functions)
[ Eligible Rows ]
         |
         v  Collapses into summary rows by GROUP BY
[ Aggregated Groups ]
         |
         v  Filtered by HAVING (can reference aggregate conditions)
[ Final Result Groups ]
```

- **Use `WHERE`** to filter individual rows *before* aggregation (e.g., `WHERE status = 'completed'`).
- **Use `HAVING`** to filter groups *after* aggregation (e.g., `HAVING COUNT(*) > 5` or `HAVING SUM(amount) >= 1000.00`).

---

## 4. Modern SQL Superpower: Aggregate `FILTER` Clause

Instead of writing cumbersome `CASE WHEN` statements inside aggregates, modern SQL supports the `FILTER` clause:

```sql
-- Clean, declarative, standard SQL:
SELECT
    category,
    COUNT(*) AS total_courses,
    COUNT(*) FILTER (WHERE difficulty = 'beginner') AS beginner_courses,
    COUNT(*) FILTER (WHERE price = 0) AS free_courses
FROM courses
GROUP BY category;
```

---

## 5. Multi-Dimensional Rollups (`ROLLUP` & `CUBE`)

When generating executive financial reports, you often need subtotals across hierarchies (e.g., Country $\rightarrow$ City $\rightarrow$ Store $\rightarrow$ Total):

```sql
SELECT country, city, SUM(revenue) AS total_revenue
FROM store_sales
GROUP BY ROLLUP (country, city);
```
This single query computes:
1. Revenue per (Country, City)
2. Subtotal per Country
3. Grand Total across all countries

Explore [`06_aggregations.sql`](./06_aggregations.sql) to see these aggregations executed on a realistic sales ledger.
