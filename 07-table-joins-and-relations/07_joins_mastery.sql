-- ============================================================================
-- Part 07: Table Joins & Relationships - Hands-on Lab
-- File: 07_joins_mastery.sql
-- Goal: Master INNER, LEFT, RIGHT, FULL, CROSS, SELF, Semi, and Anti-Joins.
-- ============================================================================

DROP TABLE IF EXISTS employee_projects CASCADE;
DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS salary_grades CASCADE;

-- ----------------------------------------------------------------------------
-- Schema & Seed Data
-- ----------------------------------------------------------------------------
CREATE TABLE departments (
    department_id SERIAL PRIMARY KEY,
    name          VARCHAR(50) NOT NULL,
    location      VARCHAR(50) NOT NULL
);

CREATE TABLE employees (
    employee_id   SERIAL PRIMARY KEY,
    name          VARCHAR(50) NOT NULL,
    department_id INTEGER REFERENCES departments(department_id),
    manager_id    INTEGER REFERENCES employees(employee_id),
    salary        NUMERIC(10, 2) NOT NULL
);

CREATE TABLE salary_grades (
    grade_level   CHAR(1) PRIMARY KEY,
    min_salary    NUMERIC(10, 2) NOT NULL,
    max_salary    NUMERIC(10, 2) NOT NULL
);

CREATE TABLE projects (
    project_id    SERIAL PRIMARY KEY,
    project_name  VARCHAR(100) NOT NULL
);

CREATE TABLE employee_projects (
    employee_id   INTEGER NOT NULL REFERENCES employees(employee_id),
    project_id    INTEGER NOT NULL REFERENCES projects(project_id),
    hours_logged  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (employee_id, project_id)
);

-- Seed Departments
INSERT INTO departments (name, location)
VALUES
    ('Engineering', 'San Francisco'),
    ('Product',     'New York'),
    ('Marketing',   'London'),
    ('Research',    'Zurich'); -- Has NO employees initially

-- Seed Employees (Hierarchical org chart)
INSERT INTO employees (employee_id, name, department_id, manager_id, salary)
VALUES
    (1, 'Eleanor Vance', 1,    NULL, 210000.00), -- CEO / Engineering Lead (No manager)
    (2, 'Marcus Brody',  1,    1,    150000.00), -- Reports to Eleanor
    (3, 'Sophia Loren',  2,    1,    140000.00), -- Reports to Eleanor
    (4, 'David Kim',     1,    2,    110000.00), -- Reports to Marcus
    (5, 'Aisha Khan',    NULL, 3,     95000.00); -- Contractor (NO department assigned)

-- Reset serial sequence to continue after manual IDs:
SELECT setval('employees_employee_id_seq', 5);

-- Seed Salary Grades
INSERT INTO salary_grades (grade_level, min_salary, max_salary)
VALUES
    ('C', 70000.00,  99999.99),
    ('B', 100000.00, 160000.00),
    ('A', 160001.00, 300000.00);

-- Seed Projects
INSERT INTO projects (project_name)
VALUES
    ('Postgres Engine Migration'),
    ('Mobile App Redesign'),
    ('Quantum AI Exploration'); -- Has no assigned employees

INSERT INTO employee_projects (employee_id, project_id, hours_logged)
VALUES
    (1, 1, 40),
    (2, 1, 120),
    (4, 1, 95),
    (3, 2, 80);

-- ----------------------------------------------------------------------------
-- 1. INNER JOIN
-- ----------------------------------------------------------------------------
-- Only returns employees who have a valid department:
-- (Aisha Khan is excluded because department_id IS NULL)
SELECT
    e.employee_id,
    e.name AS employee_name,
    d.name AS department_name,
    d.location
FROM employees e
INNER JOIN departments d ON e.department_id = d.department_id;

-- ----------------------------------------------------------------------------
-- 2. LEFT OUTER JOIN
-- ----------------------------------------------------------------------------
-- Keeps all employees, even contractors without a department:
SELECT
    e.name AS employee_name,
    COALESCE(d.name, 'Unassigned / Contractor') AS department_name
FROM employees e
LEFT JOIN departments d ON e.department_id = d.department_id;

-- ----------------------------------------------------------------------------
-- 3. RIGHT OUTER JOIN & Finding Unstaffed Departments
-- ----------------------------------------------------------------------------
-- Keeps all departments, including 'Research' which has no employees:
SELECT
    d.name AS department_name,
    e.name AS employee_name
FROM employees e
RIGHT JOIN departments d ON e.department_id = d.department_id;

-- ----------------------------------------------------------------------------
-- 4. FULL OUTER JOIN
-- ----------------------------------------------------------------------------
-- Preserves unassigned employees AND unstaffed departments simultaneously:
SELECT
    COALESCE(e.name, '[No Employee]') AS employee_name,
    COALESCE(d.name, '[No Department]') AS department_name
FROM employees e
FULL OUTER JOIN departments d ON e.department_id = d.department_id;

-- ----------------------------------------------------------------------------
-- 5. SELF JOIN (Organizational Chart)
-- ----------------------------------------------------------------------------
SELECT
    emp.name AS employee,
    COALESCE(mgr.name, '--- Board of Directors (CEO) ---') AS manager
FROM employees emp
LEFT JOIN employees mgr ON emp.manager_id = mgr.employee_id;

-- ----------------------------------------------------------------------------
-- 6. Non-Equi JOIN (Joining on Inequalities / Ranges)
-- ----------------------------------------------------------------------------
-- Match each employee to their salary grade bracket without a direct FK:
SELECT
    e.name,
    e.salary,
    sg.grade_level
FROM employees e
INNER JOIN salary_grades sg
    ON e.salary BETWEEN sg.min_salary AND sg.max_salary
ORDER BY e.salary DESC;

-- ----------------------------------------------------------------------------
-- 7. Anti-Joins: Identifying Missing Relationships
-- ----------------------------------------------------------------------------

-- Pattern A: Find departments with ZERO employees using LEFT JOIN ... IS NULL:
SELECT d.name AS empty_department
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
WHERE e.employee_id IS NULL;

-- Pattern B: Find projects with ZERO assigned employees using NOT EXISTS:
SELECT p.project_id, p.project_name
FROM projects p
WHERE NOT EXISTS (
    SELECT 1
    FROM employee_projects ep
    WHERE ep.project_id = p.project_id
);

-- ----------------------------------------------------------------------------
-- 8. CROSS JOIN (Cartesian Matrix)
-- ----------------------------------------------------------------------------
-- Generate a staffing matrix: Every department paired with every project:
SELECT
    d.name AS department,
    p.project_name
FROM departments d
CROSS JOIN projects p;
