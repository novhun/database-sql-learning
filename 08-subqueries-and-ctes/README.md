# Part 08: Subqueries, Common Table Expressions (CTEs) & Set Operations

As business logic increases in complexity, single-pass queries are no longer sufficient. You need intermediate computations, recursive graph traversals, and mathematical set combinations.

In this module, you will master **Subqueries**, **CTEs (`WITH` clause)**, **Recursive CTEs**, and **Set Operations**.

---

## 1. Classification of Subqueries

A subquery is a query nested inside another SQL statement.

### A. Scalar Subquery
Returns exactly **one value** (one row, one column). Can be used anywhere an expression is expected (even in the `SELECT` list):
```sql
SELECT
    name,
    salary,
    (SELECT ROUND(AVG(salary), 2) FROM employees) AS company_average
FROM employees;
```

### B. Correlated Subquery
A subquery that references a column from the outer query. It executes once for every candidate row evaluated by the outer query:
```sql
-- Find employees who earn more than the average of THEIR specific department:
SELECT e.name, e.salary, e.department_id
FROM employees e
WHERE e.salary > (
    SELECT AVG(inner_emp.salary)
    FROM employees inner_emp
    WHERE inner_emp.department_id = e.department_id
);
```

---

## 2. Common Table Expressions (CTEs)

Deeply nested subqueries quickly become unreadable ("SQL Spaghetti").
**Common Table Expressions (CTEs)**, introduced via the `WITH` keyword, allow you to define named temporary result sets that act like readable virtual tables for the duration of the query.

```sql
WITH department_stats AS (
    SELECT
        department_id,
        ROUND(AVG(salary), 2) AS avg_dept_salary,
        COUNT(*)              AS head_count
    FROM employees
    GROUP BY department_id
),
high_earning_staff AS (
    SELECT
        e.name,
        e.salary,
        e.department_id,
        ds.avg_dept_salary
    FROM employees e
    INNER JOIN department_stats ds ON e.department_id = ds.department_id
    WHERE e.salary > ds.avg_dept_salary
)
SELECT * FROM high_earning_staff;
```

---

## 3. Recursive CTEs: The Secret Weapon for Trees & Graphs

How do you query an organizational hierarchy of unknown depth (e.g., CEO $\rightarrow$ VP $\rightarrow$ Director $\rightarrow$ Manager $\rightarrow$ Senior Engineer $\rightarrow$ Junior Engineer)?

A standard `JOIN` can only go down a fixed number of levels. A **Recursive CTE** loops automatically until the leaf nodes are reached!

### Anatomy of a Recursive CTE:
```sql
WITH RECURSIVE org_tree AS (
    -- 1. ANCHOR MEMBER: Base case (starts at top of tree)
    SELECT
        employee_id,
        name,
        manager_id,
        1 AS depth_level,
        CAST(name AS TEXT) AS hierarchy_path
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- 2. RECURSIVE MEMBER: References the CTE itself
    SELECT
        e.employee_id,
        e.name,
        e.manager_id,
        ot.depth_level + 1,
        ot.hierarchy_path || ' -> ' || e.name
    FROM employees e
    INNER JOIN org_tree ot ON e.manager_id = ot.employee_id
)
SELECT * FROM org_tree ORDER BY depth_level, employee_id;
```

---

## 4. Set Operations: `UNION`, `INTERSECT`, `EXCEPT`

Set operations combine the results of two queries into a single result set vertically:

| Operation | Description | Performance Note |
| :--- | :--- | :--- |
| **`UNION`** | Combines rows, removes duplicates. | Slower (requires internal sort/hash to deduplicate). |
| **`UNION ALL`** | Combines rows, **keeps** duplicates. | **Fast** (simply appends streams; use whenever duplicates are impossible or acceptable). |
| **`INTERSECT`** | Returns only rows present in **both** queries. | Inner set intersection. |
| **`EXCEPT` (or `MINUS`)** | Returns rows present in Query 1 that do **not** appear in Query 2. | Set difference. |

### Strict Rules for Set Operations:
1. Both queries must output the **exact same number of columns**.
2. Corresponding columns must share **compatible data types**.
3. Column names in the final output are determined by the **first** query.

Dive into [`08_subqueries_and_ctes.sql`](./08_subqueries_and_ctes.sql) for hands-on practice.
