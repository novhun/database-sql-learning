-- ============================================================================
-- Part 04: DML & CRUD Operations - Hands-on Lab
-- File: 04_crud_operations.sql
-- Goal: Execute Create, Read, Update, and Delete patterns, including Upserts,
--       RETURNING statements, and Soft Deletes.
-- ============================================================================

-- Ensure Part 03 tables exist before running this script
\i 03-relational-modeling-ddl/03_schema_definition.sql

-- ----------------------------------------------------------------------------
-- 1. CREATE: Multi-Row Batch Inserts
-- ----------------------------------------------------------------------------

-- Insert Categories:
INSERT INTO categories (name, slug, description)
VALUES
    ('Database Engineering', 'database-engineering', 'SQL, NoSQL, and Storage Internals'),
    ('Web Development', 'web-development', 'Frontend and Fullstack Systems'),
    ('DevOps & Cloud', 'devops-cloud', 'Kubernetes, CI/CD, and Infrastructure'),
    ('Mobile Development', 'mobile-development', 'iOS, Android, and Cross-Platform Apps');

-- Insert Users (Instructors and Students) using RETURNING to inspect generated IDs:
INSERT INTO users (username, email, password_hash, full_name, role)
VALUES
    ('sarah_lead', 'sarah@example.com', 'hash_argon2_1', 'Sarah Jenkins', 'instructor'),
    ('alex_db', 'alex@example.com', 'hash_argon2_2', 'Alex Vance', 'instructor'),
    ('john_doe', 'john@example.com', 'hash_argon2_3', 'John Doe', 'student'),
    ('maria_garcia', 'maria@example.com', 'hash_argon2_4', 'Maria Garcia', 'student'),
    ('chen_wei', 'chen@example.com', 'hash_argon2_5', 'Chen Wei', 'student')
RETURNING user_id, username, role, created_at;

-- Insert Courses using subqueries to link foreign keys cleanly:
INSERT INTO courses (category_id, instructor_id, title, slug, summary, price, difficulty, is_published)
VALUES
    (
        (SELECT category_id FROM categories WHERE slug = 'database-engineering'),
        (SELECT user_id FROM users WHERE username = 'alex_db'),
        'Mastering PostgreSQL: Zero to Hero',
        'mastering-postgresql',
        'Learn PostgreSQL internals, query planning, indexing, and administration.',
        99.99,
        'intermediate',
        TRUE
    ),
    (
        (SELECT category_id FROM categories WHERE slug = 'database-engineering'),
        (SELECT user_id FROM users WHERE username = 'alex_db'),
        'High Performance SQL Query Tuning',
        'high-performance-sql',
        'Deep dive into EXPLAIN ANALYZE, B-Trees, and join optimization.',
        129.50,
        'advanced',
        TRUE
    ),
    (
        (SELECT category_id FROM categories WHERE slug = 'web-development'),
        (SELECT user_id FROM users WHERE username = 'sarah_lead'),
        'Modern Full-Stack React & Node',
        'modern-fullstack-react-node',
        'Build scalable microservices and single-page applications.',
        79.00,
        'beginner',
        TRUE
    ),
    (
        (SELECT category_id FROM categories WHERE slug = 'devops-cloud'),
        (SELECT user_id FROM users WHERE username = 'sarah_lead'),
        'Kubernetes Architecture & GitOps',
        'kubernetes-architecture-gitops',
        'Zero downtime deployments and cloud infrastructure.',
        149.00,
        'advanced',
        FALSE
    );

-- ----------------------------------------------------------------------------
-- 2. CREATE: Upsert Pattern (INSERT ... ON CONFLICT)
-- ----------------------------------------------------------------------------
-- Attempting to insert a category with an existing slug:
-- With ON CONFLICT DO UPDATE, it modifies the existing row instead of failing:

INSERT INTO categories (name, slug, description)
VALUES ('Databases & Storage', 'database-engineering', 'Updated description for database engineering.')
ON CONFLICT (slug)
DO UPDATE SET
    description = EXCLUDED.description,
    name = EXCLUDED.name;

-- Verify the category was updated in-place:
SELECT category_id, name, slug, description FROM categories WHERE slug = 'database-engineering';

-- ----------------------------------------------------------------------------
-- 3. UPDATE: Safe Modifying & Arithmetic Expressions
-- ----------------------------------------------------------------------------

-- Increase price by 15% for all advanced courses:
UPDATE courses
SET
    price = ROUND(price * 1.15, 2)
WHERE difficulty = 'advanced'
RETURNING course_id, title, price, difficulty;

-- ----------------------------------------------------------------------------
-- 4. DELETE vs. TRUNCATE with Transaction Safety
-- ----------------------------------------------------------------------------

-- Using a transaction block to test deletion safely:
BEGIN;
    -- Delete inactive or draft courses
    DELETE FROM courses
    WHERE is_published = FALSE
    RETURNING course_id, title;

    -- Look at the state inside the transaction:
    SELECT count(*) AS remaining_courses FROM courses;

-- If you are not satisfied, ROLLBACK to undo!
ROLLBACK;

-- Verify that the draft course is still there:
SELECT title, is_published FROM courses WHERE is_published = FALSE;

-- ----------------------------------------------------------------------------
-- 5. The Soft Delete Pattern
-- ----------------------------------------------------------------------------
-- Add a deleted_at column to courses:
ALTER TABLE courses ADD COLUMN deleted_at TIMESTAMPTZ NULL;

-- Soft-delete a course:
UPDATE courses
SET deleted_at = CURRENT_TIMESTAMP
WHERE slug = 'kubernetes-architecture-gitops';

-- Active records query (for public customer catalog):
SELECT course_id, title, price
FROM courses
WHERE deleted_at IS NULL;

-- Admin query to audit soft-deleted records:
SELECT course_id, title, deleted_at
FROM courses
WHERE deleted_at IS NOT NULL;
