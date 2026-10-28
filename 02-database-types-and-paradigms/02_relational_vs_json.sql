-- ============================================================================
-- Part 02: Database Types & Paradigms - Hands-on Lab
-- File: 02_relational_vs_json.sql
-- Goal: Contrast relational structured data with NoSQL semi-structured JSONB
--       in modern SQL systems.
-- ============================================================================

-- Clean slate
DROP TABLE IF EXISTS relational_products CASCADE;
DROP TABLE IF EXISTS document_products CASCADE;

-- ----------------------------------------------------------------------------
-- 1. The Relational (Strict Schema) Approach
-- ----------------------------------------------------------------------------
-- In relational modeling, columns must be planned ahead. Every row conforms
-- to the exact same schema.

CREATE TABLE relational_products (
    product_id   SERIAL PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    brand        VARCHAR(50) NOT NULL,
    price        NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    stock_qty    INTEGER NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO relational_products (name, brand, price, stock_qty)
VALUES
    ('Mechanical Keyboard', 'Keychron', 89.99, 15),
    ('Noise-Canceling Headphones', 'Sony', 299.99, 8),
    ('Ultra-wide Monitor', 'Dell', 549.50, 4);

-- Querying relational tables:
SELECT name, price, stock_qty
FROM relational_products
WHERE price < 300.00;

-- ----------------------------------------------------------------------------
-- 2. The Document (Semi-Structured / NoSQL) Approach via JSONB
-- ----------------------------------------------------------------------------
-- In an e-commerce catalog, a Monitor has 'resolution' and 'refresh_rate',
-- while a Keyboard has 'switch_type' and 'wireless'.
-- Storing heterogeneous attributes in relational columns requires either dozens of
-- NULL columns or complex Entity-Attribute-Value (EAV) patterns.
-- Modern databases provide JSONB (Binary JSON) to solve this:

CREATE TABLE document_products (
    product_id   SERIAL PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    price        NUMERIC(10, 2) NOT NULL,
    attributes   JSONB NOT NULL -- Freeform document payload
);

INSERT INTO document_products (name, price, attributes)
VALUES
    ('Mechanical Keyboard', 89.99, '{
        "category": "Electronics",
        "switch_type": "Gateron Brown",
        "wireless": true,
        "connectivity": ["Bluetooth", "USB-C"],
        "specs": {"weight_g": 650, "battery_mah": 4000}
    }'::jsonb),
    ('Noise-Canceling Headphones', 299.99, '{
        "category": "Audio",
        "anc": true,
        "battery_hours": 30,
        "supported_codecs": ["LDAC", "AAC", "SBC"],
        "specs": {"weight_g": 250}
    }'::jsonb),
    ('Gaming Mouse', 59.99, '{
        "category": "Electronics",
        "dpi": 20000,
        "wireless": false,
        "rgb_lighting": true
    }'::jsonb);

-- ----------------------------------------------------------------------------
-- 3. Querying Document (JSONB) Data with SQL Operators
-- ----------------------------------------------------------------------------

-- Extract JSON text value with '->>' operator:
SELECT
    name,
    price,
    attributes ->> 'category'    AS category,
    attributes ->> 'switch_type' AS switch_type
FROM document_products;

-- Navigate nested JSON paths:
SELECT
    name,
    attributes -> 'specs' ->> 'weight_g' AS weight_in_grams
FROM document_products
WHERE (attributes -> 'specs' ->> 'weight_g')::numeric < 300;

-- JSON Containment search using the '@>' operator:
-- "Find all products that are wireless: true"
SELECT name, price, attributes
FROM document_products
WHERE attributes @> '{"wireless": true}';

-- Querying elements inside a JSON array:
-- "Find products that support Bluetooth"
SELECT name, attributes -> 'connectivity' AS connectivity
FROM document_products
WHERE attributes -> 'connectivity' ? 'Bluetooth';

-- ----------------------------------------------------------------------------
-- 4. Indexing JSONB Documents (GIN - Generalized Inverted Index)
-- ----------------------------------------------------------------------------
-- A common complaint about NoSQL was query speed on deep nested fields.
-- In modern databases, we can build GIN indexes directly on JSON documents!

CREATE INDEX idx_products_attributes_gin ON document_products USING gin (attributes);

-- This query will use the GIN index for lightning-fast lookups even with millions of rows:
EXPLAIN ANALYZE
SELECT * FROM document_products
WHERE attributes @> '{"category": "Audio"}';
