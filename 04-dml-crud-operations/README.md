# Part 04: DML & CRUD Operations (Data Manipulation Language)

Once tables are defined with DDL, applications spend 95% of their runtime executing **DML (Data Manipulation Language)**.

DML translates directly to the classic software acronym **CRUD**:
- **C**reate: `INSERT`
- **R**ead: `SELECT` (covered in depth in Part 05)
- **U**pdate: `UPDATE`
- **D**elete: `DELETE` / `TRUNCATE`

---

## 1. Inserting Data (`INSERT`)

### Batch Inserts vs. Loop Inserts
A critical junior-to-senior engineering distinction:

> **Anti-Pattern:** Running 1,000 single `INSERT INTO ...` queries in a loop from your application. This incurs 1,000 network roundtrips and 1,000 transaction commits!
>
> **Best Practice:** Send multi-row batch inserts in a single statement.

```sql
-- Single multi-row batch insert:
INSERT INTO categories (name, slug, description)
VALUES
    ('Database Engineering', 'database-engineering', 'SQL, NoSQL, and Storage Internals'),
    ('Web Development', 'web-development', 'Frontend and Fullstack Systems'),
    ('DevOps & Cloud', 'devops-cloud', 'Kubernetes, CI/CD, and Infrastructure');
```

### The `RETURNING` Clause
Instead of inserting a row and then making a separate query to fetch its auto-generated `id` or `created_at`, modern databases support `RETURNING`:

```sql
INSERT INTO users (username, email, password_hash, full_name)
VALUES ('dev_dan', 'dan@example.com', 'argon2$hash...', 'Dan Smith')
RETURNING user_id, created_at;
```

### Upsert (`ON CONFLICT`)
An "Upsert" inserts a row if it does not exist, or updates it if a key conflict occurs:

```sql
INSERT INTO user_settings (user_id, dark_mode, email_notifications)
VALUES ('c1a4e1...', TRUE, FALSE)
ON CONFLICT (user_id)
DO UPDATE SET
    dark_mode = EXCLUDED.dark_mode,
    email_notifications = EXCLUDED.email_notifications,
    updated_at = CURRENT_TIMESTAMP;
```

---

## 2. Modifying Data (`UPDATE`)

An `UPDATE` alters existing rows matching a `WHERE` predicate.

```sql
UPDATE courses
SET
    price = price * 0.90,  -- 10% discount
    updated_at = CURRENT_TIMESTAMP
WHERE difficulty = 'beginner';
```

> [!CAUTION]
> If you run `UPDATE courses SET price = 0;` without a `WHERE` clause, **every single course in your database will become free.**
> In production terminals or migration scripts, always wrap destructive operations in a transaction block (`BEGIN; ... ROLLBACK;`) first to verify row count!

---

## 3. Removing Data: `DELETE` vs. `TRUNCATE`

| Feature | `DELETE FROM table WHERE ...` | `TRUNCATE table` |
| :--- | :--- | :--- |
| **Command Type** | DML (Data Manipulation) | DDL (Data Definition) |
| **Granularity** | Filters specific rows using `WHERE` | Drops all data in the table instantly |
| **Speed** | Slower (deletes row-by-row, logs WAL records) | Fast (deallocates disk data pages directly) |
| **Triggers** | Fires row-level `ON DELETE` triggers | Does not fire row-level triggers |
| **Identity Reset** | Preserves auto-increment sequence | Resets sequence (`RESTART IDENTITY`) |

---

## 4. The Soft Delete Pattern

In modern production databases (finance, healthcare, e-commerce, enterprise SaaS), physical `DELETE` is often prohibited due to audit requirements and foreign key cascade risks.

Instead, we use **Soft Deletion**:
1. Add a nullable timestamp column: `deleted_at TIMESTAMPTZ NULL`.
2. To "delete" an item:
   ```sql
   UPDATE users SET deleted_at = CURRENT_TIMESTAMP WHERE user_id = $1;
   ```
3. To query active records:
   ```sql
   SELECT * FROM users WHERE deleted_at IS NULL;
   ```

Check out [`04_crud_operations.sql`](./04_crud_operations.sql) to practice all CRUD operations in a hands-on environment.
