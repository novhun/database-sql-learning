-- ============================================================================
-- Part 03: Relational Modeling & DDL - Hands-on Lab
-- File: 03_schema_definition.sql
-- Goal: Create a production-ready relational schema for "DevAcademy"
--       using best practices for keys, data types, and integrity constraints.
-- ============================================================================

-- Clean up any prior tables (order matters due to foreign key dependencies!)
DROP TABLE IF EXISTS course_reviews CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Ensure UUID generation extension is available (standard in Postgres)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. Categories Table (Lookup / Taxonomy entity)
-- ----------------------------------------------------------------------------
CREATE TABLE categories (
    category_id  SERIAL PRIMARY KEY,
    name         VARCHAR(50) NOT NULL UNIQUE,
    slug         VARCHAR(60) NOT NULL UNIQUE,
    description  TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_slug_lowercase CHECK (slug = lower(slug))
);

-- ----------------------------------------------------------------------------
-- 2. Users Table (Core entity with UUID surrogate key)
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    user_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username      VARCHAR(30) NOT NULL UNIQUE,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(100) NOT NULL,
    role          VARCHAR(20) NOT NULL DEFAULT 'student'
                  CHECK (role IN ('student', 'instructor', 'admin')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_email_format CHECK (email LIKE '%@%.%')
);

-- ----------------------------------------------------------------------------
-- 3. Courses Table (Entity with Foreign Key to Categories & Instructor User)
-- ----------------------------------------------------------------------------
CREATE TABLE courses (
    course_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id    INTEGER NOT NULL,
    instructor_id  UUID NOT NULL,
    title          VARCHAR(200) NOT NULL,
    slug           VARCHAR(220) NOT NULL UNIQUE,
    summary        VARCHAR(500),
    price          NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    difficulty     VARCHAR(20) NOT NULL DEFAULT 'intermediate'
                   CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
    is_published   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Price cannot be negative
    CONSTRAINT chk_course_price CHECK (price >= 0.00),

    -- Foreign Key: If a category is deleted, restrict deletion if courses exist
    CONSTRAINT fk_courses_category
        FOREIGN KEY (category_id)
        REFERENCES categories(category_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- Foreign Key: If an instructor is deleted, restrict deletion
    CONSTRAINT fk_courses_instructor
        FOREIGN KEY (instructor_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT
);

-- ----------------------------------------------------------------------------
-- 4. Enrollments Table (Many-to-Many Bridge Table with Composite Primary Key)
-- ----------------------------------------------------------------------------
CREATE TABLE enrollments (
    user_id        UUID NOT NULL,
    course_id      UUID NOT NULL,
    enrolled_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    progress_pct   INTEGER NOT NULL DEFAULT 0 CHECK (progress_pct BETWEEN 0 AND 100),
    completed_at   TIMESTAMPTZ,

    -- Composite Primary Key: a user can only enroll in a course once
    PRIMARY KEY (user_id, course_id),

    -- If a user deletes their account, cascade delete their enrollments
    CONSTRAINT fk_enrollments_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    -- If a course is removed, cascade delete enrollment records
    CONSTRAINT fk_enrollments_course
        FOREIGN KEY (course_id)
        REFERENCES courses(course_id)
        ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 5. Course Reviews Table (Demonstrating Rating Check Constraints)
-- ----------------------------------------------------------------------------
CREATE TABLE course_reviews (
    review_id    SERIAL PRIMARY KEY,
    course_id    UUID NOT NULL,
    user_id      UUID NOT NULL,
    rating       SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment      TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- A user can only write one review per course
    CONSTRAINT uq_course_user_review UNIQUE (course_id, user_id),

    CONSTRAINT fk_reviews_course
        FOREIGN KEY (course_id)
        REFERENCES courses(course_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_reviews_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 6. DDL Alteration Practice
-- ----------------------------------------------------------------------------
-- Adding a column:
ALTER TABLE courses ADD COLUMN view_count BIGINT NOT NULL DEFAULT 0;

-- Modifying a column default:
ALTER TABLE courses ALTER COLUMN view_count SET DEFAULT 10;

-- Dropping a column:
ALTER TABLE courses DROP COLUMN view_count;

-- Verify schema creation:
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
