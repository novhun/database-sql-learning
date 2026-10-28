-- ============================================================================
-- Part 13: Views, Stored Functions, Triggers & Security - Hands-on Lab
-- File: 13_programmable_objects.sql
-- Goal: Create standard and materialized views, write a PL/pgSQL function,
--       deploy an automated JSON audit trail trigger, and configure RLS.
-- ============================================================================

DROP VIEW IF EXISTS v_active_course_directory CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_category_metrics CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS employee_compensation CASCADE;
DROP TABLE IF EXISTS tenant_notes CASCADE;

-- ----------------------------------------------------------------------------
-- 1. Standard View: Encapsulating Business Logic & Hiding Complexity
-- ----------------------------------------------------------------------------
-- A standard view acts as a reusable query without storing duplicate data:

CREATE TABLE demo_courses (
    course_id   SERIAL PRIMARY KEY,
    title       VARCHAR(100) NOT NULL,
    price       NUMERIC(8, 2) NOT NULL,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO demo_courses (title, price, is_active)
VALUES
    ('Database Mastery', 99.00, TRUE),
    ('Legacy Fortran',    49.00, FALSE),
    ('Cloud Architect', 149.00, TRUE);

CREATE VIEW v_active_course_directory AS
SELECT
    course_id,
    title,
    price,
    ROUND(price * 0.90, 2) AS discounted_price
FROM demo_courses
WHERE is_active = TRUE;

-- Query the view just like a normal table:
SELECT * FROM v_active_course_directory;

-- ----------------------------------------------------------------------------
-- 2. Materialized View: Physically Caching Expensive Aggregations
-- ----------------------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_category_metrics AS
SELECT
    is_active,
    COUNT(*)               AS course_count,
    ROUND(AVG(price), 2)   AS average_price,
    CURRENT_TIMESTAMP      AS snapshot_time
FROM demo_courses
GROUP BY is_active;

-- Create unique index to allow CONCURRENT refreshes without locking readers:
CREATE UNIQUE INDEX idx_mv_category_metrics_active ON mv_category_metrics (is_active);

-- Query cached data instantly:
SELECT * FROM mv_category_metrics;

-- Refresh the materialized view when underlying data changes:
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_category_metrics;

-- ----------------------------------------------------------------------------
-- 3. PL/pgSQL User-Defined Function (UDF)
-- ----------------------------------------------------------------------------
-- Compute custom tax and discount logic encapsulated inside the DBMS:

CREATE OR REPLACE FUNCTION fn_calculate_final_invoice(
    base_price NUMERIC,
    tax_rate   NUMERIC,
    is_vip     BOOLEAN
)
RETURNS NUMERIC AS $$
DECLARE
    discount_amount NUMERIC := 0.00;
    tax_amount      NUMERIC := 0.00;
    final_total     NUMERIC := 0.00;
BEGIN
    IF base_price < 0 THEN
        RAISE EXCEPTION 'Price cannot be negative: %', base_price;
    END IF;

    IF is_vip THEN
        discount_amount := base_price * 0.15; -- 15% VIP discount
    END IF;

    tax_amount  := (base_price - discount_amount) * tax_rate;
    final_total := (base_price - discount_amount) + tax_amount;

    RETURN ROUND(final_total, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Test the function:
SELECT fn_calculate_final_invoice(100.00, 0.08, TRUE)  AS vip_invoice;
SELECT fn_calculate_final_invoice(100.00, 0.08, FALSE) AS regular_invoice;

-- ----------------------------------------------------------------------------
-- 4. Automated JSONB Audit Trail with Triggers
-- ----------------------------------------------------------------------------
-- Centralized audit log table:
CREATE TABLE audit_logs (
    log_id        SERIAL PRIMARY KEY,
    table_name    VARCHAR(50) NOT NULL,
    action        VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    changed_by    VARCHAR(50) NOT NULL,
    row_key       TEXT,
    old_values    JSONB,
    new_values    JSONB,
    occurred_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Target table holding sensitive compensation data:
CREATE TABLE employee_compensation (
    emp_id        SERIAL PRIMARY KEY,
    employee_name VARCHAR(50) NOT NULL,
    salary        NUMERIC(10, 2) NOT NULL
);

-- Generic Trigger Function:
CREATE OR REPLACE FUNCTION fn_audit_compensation_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_logs (table_name, action, changed_by, row_key, new_values)
        VALUES ('employee_compensation', 'INSERT', current_user, NEW.emp_id::text, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_logs (table_name, action, changed_by, row_key, old_values, new_values)
        VALUES ('employee_compensation', 'UPDATE', current_user, NEW.emp_id::text, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_logs (table_name, action, changed_by, row_key, old_values)
        VALUES ('employee_compensation', 'DELETE', current_user, OLD.emp_id::text, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Attach the trigger:
CREATE TRIGGER trg_audit_compensation
AFTER INSERT OR UPDATE OR DELETE ON employee_compensation
FOR EACH ROW EXECUTE FUNCTION fn_audit_compensation_changes();

-- Test trigger in action:
INSERT INTO employee_compensation (employee_name, salary) VALUES ('Alice Martin', 95000.00);
UPDATE employee_compensation SET salary = 110000.00 WHERE emp_id = 1;
DELETE FROM employee_compensation WHERE emp_id = 1;

-- Inspect the automatic audit records:
SELECT log_id, action, changed_by, row_key, old_values, new_values, occurred_at
FROM audit_logs
ORDER BY log_id;

-- ----------------------------------------------------------------------------
-- 5. Row-Level Security (RLS) for Multi-Tenant Architecture
-- ----------------------------------------------------------------------------
CREATE TABLE tenant_notes (
    note_id    SERIAL PRIMARY KEY,
    tenant_id  VARCHAR(50) NOT NULL,
    content    TEXT NOT NULL
);

-- Enable RLS:
ALTER TABLE tenant_notes ENABLE ROW LEVEL SECURITY;

-- Create policy restricting visibility:
CREATE POLICY tenant_isolation_policy ON tenant_notes
FOR ALL
USING (tenant_id = current_setting('app.current_tenant', true));

-- Insert multi-tenant records:
INSERT INTO tenant_notes (tenant_id, content)
VALUES
    ('acme_corp', 'Acme quarterly roadmap confidential'),
    ('globex_inc', 'Globex secret patents');

-- Simulate session for 'acme_corp':
SET LOCAL app.current_tenant = 'acme_corp';
SELECT * FROM tenant_notes; -- Only Acme's notes appear!

-- Simulate session for 'globex_inc':
SET LOCAL app.current_tenant = 'globex_inc';
SELECT * FROM tenant_notes; -- Only Globex's notes appear!
