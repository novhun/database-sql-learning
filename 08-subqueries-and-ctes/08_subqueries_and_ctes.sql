-- ============================================================================
-- Part 08: Subqueries, CTEs & Set Operations - Hands-on Lab
-- File: 08_subqueries_and_ctes.sql
-- Goal: Write modular SQL with scalar/correlated subqueries, CTEs,
--       recursive hierarchical CTEs, and set operations.
-- ============================================================================

-- Re-use tables from Part 07 (departments, employees)
\i 07-table-joins-and-relations/07_joins_mastery.sql

-- ----------------------------------------------------------------------------
-- 1. Subquery Variations
-- ----------------------------------------------------------------------------

-- A. Scalar Subquery in SELECT (Company-wide benchmark):
SELECT
    name,
    salary,
    (SELECT ROUND(AVG(salary), 2) FROM employees) AS company_average,
    ROUND(salary - (SELECT AVG(salary) FROM employees), 2) AS diff_from_average
FROM employees
ORDER BY salary DESC;

-- B. Correlated Subquery in WHERE:
-- "Find all employees who earn more than the average salary of their own department"
SELECT
    e.name,
    e.salary,
    e.department_id
FROM employees e
WHERE e.salary > (
    SELECT AVG(inner_e.salary)
    FROM employees inner_e
    WHERE inner_e.department_id = e.department_id
);

-- C. EXISTS vs IN (Performance & NULL Safety):
-- "Find departments that have active projects assigned"
SELECT d.name AS department_with_projects
FROM departments d
WHERE EXISTS (
    SELECT 1
    FROM employees e
    INNER JOIN employee_projects ep ON e.employee_id = ep.employee_id
    WHERE e.department_id = d.department_id
);

-- ----------------------------------------------------------------------------
-- 2. Common Table Expressions (CTEs)
-- ----------------------------------------------------------------------------
-- Refactor complex logic into readable, testable named pipelines:

WITH dept_aggregates AS (
    SELECT
        department_id,
        COUNT(*) AS total_staff,
        ROUND(AVG(salary), 2) AS avg_salary,
        MAX(salary) AS top_salary
    FROM employees
    WHERE department_id IS NOT NULL
    GROUP BY department_id
),
department_summary AS (
    SELECT
        d.name AS department_name,
        d.location,
        da.total_staff,
        da.avg_salary,
        da.top_salary
    FROM departments d
    INNER JOIN dept_aggregates da ON d.department_id = da.department_id
)
SELECT * FROM department_summary
WHERE total_staff > 1
ORDER BY avg_salary DESC;

-- ----------------------------------------------------------------------------
-- 3. Recursive CTE: Generating Continuous Series / Calendars
-- ----------------------------------------------------------------------------
-- Often in reporting, days with 0 sales disappear from GROUP BY.
-- We can generate a calendar of all 7 days of a week using a Recursive CTE:

WITH RECURSIVE date_series AS (
    -- Anchor: Starting Date
    SELECT CAST('2026-10-01' AS DATE) AS report_date

    UNION ALL

    -- Recursive Step: Add 1 day until reaching target date
    SELECT report_date + 1
    FROM date_series
    WHERE report_date < '2026-10-07'
)
SELECT report_date FROM date_series;

-- ----------------------------------------------------------------------------
-- 4. Recursive CTE: Hierarchical Organization Tree & Breadcrumbs
-- ----------------------------------------------------------------------------
-- Recursively traverse the management tree to calculate employee seniority level
-- and print their full managerial path:

WITH RECURSIVE employee_hierarchy AS (
    -- Anchor member: The CEO / top manager (manager_id is NULL)
    SELECT
        employee_id,
        name,
        manager_id,
        1 AS level,
        CAST(name AS TEXT) AS path_string
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive member: Find subordinates of everyone currently discovered
    SELECT
        e.employee_id,
        e.name,
        e.manager_id,
        eh.level + 1,
        eh.path_string || ' -> ' || e.name
    FROM employees e
    INNER JOIN employee_hierarchy eh ON e.manager_id = eh.employee_id
)
SELECT
    level,
    REPEAT('  ', level - 1) || name AS indented_tree,
    path_string
FROM employee_hierarchy
ORDER BY level, employee_id;

-- ----------------------------------------------------------------------------
-- 5. Set Operations: UNION, UNION ALL, INTERSECT, EXCEPT
-- ----------------------------------------------------------------------------

-- Temporary demo tables for set comparison:
CREATE TEMPORARY TABLE branch_tokyo_staff (name VARCHAR(50));
CREATE TEMPORARY TABLE branch_berlin_staff (name VARCHAR(50));

INSERT INTO branch_tokyo_staff VALUES ('Alice'), ('Bob'), ('Charlie');
INSERT INTO branch_berlin_staff VALUES ('Bob'), ('David'), ('Charlie');

-- UNION (Deduplicated union: Alice, Bob, Charlie, David)
SELECT name FROM branch_tokyo_staff
UNION
SELECT name FROM branch_berlin_staff;

-- UNION ALL (Preserves duplicates: Alice, Bob, Charlie, Bob, David, Charlie)
-- Much faster in high-throughput pipelines because it skips sorting!
SELECT name FROM branch_tokyo_staff
UNION ALL
SELECT name FROM branch_berlin_staff;

-- INTERSECT (Staff present in both offices: Bob, Charlie)
SELECT name FROM branch_tokyo_staff
INTERSECT
SELECT name FROM branch_berlin_staff;

-- EXCEPT (Staff in Tokyo who are NOT in Berlin: Alice)
SELECT name FROM branch_tokyo_staff
EXCEPT
SELECT name FROM branch_berlin_staff;
