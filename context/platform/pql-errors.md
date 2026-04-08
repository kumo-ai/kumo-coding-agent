# PQL Errors and Failure Categories

> Source: kumo-pql (PQL_FAILURE_CATEGORIES, PQL_SYNTAX_ERRORS) | Last synced: 2026-03-31

## Overview

This document is a unified diagnostic reference for PQL query failures. Read it when a PQL query is rejected, produces unexpected results, or when constructing queries that avoid known pitfalls.

**Part 1** catalogs failure categories (A through F) — structural and semantic reasons a valid-looking query cannot be executed. **Part 2** lists the ten most common mistakes when writing PQL, with wrong vs. right examples. **Part 3** covers parser and validator errors — the exact error messages produced by the PQL engine and how to fix them.

---

## Part 1: Failure Categories

### Category A: Schema & Relationship Limitations

| Code | Name | Description | Example |
|------|------|-------------|---------|
| A1 | Missing FK Path | No direct foreign key relationship between the entity table and the target table | Predicting `orders.amount` for `products.product_id` when no FK links products to orders |
| A2 | Multi-hop FK | Requires traversing more than one FK relationship | Predicting across `users → orders → products` when only direct single-hop is supported |
| A3 | Multi-value FK | FK relationship is one-to-many in the wrong direction | Entity table has many rows per target table row |
| A4 | Missing Column | Referenced column does not exist in the semantic view | Typo or column not included in the view definition |
| A5 | Missing Data | Column exists but has no data or all NULLs | Aggregation over an empty or null-only column |

### Category B: Time & Aggregation Limitations

| Code | Name | Description | Example |
|------|------|-------------|---------|
| B1 | Past-Only Aggregation | Time window does not extend into the future | `SUM(orders.amount, -30, -1, days)` — both bounds are negative |
| B2 | Nested Aggregation | Aggregation inside another aggregation | `AVG(SUM(orders.amount, 0, 30, days), 0, 90, days)` |
| B3 | AVG/SUM on Categorical | Numeric aggregation applied to a categorical column | `SUM(orders.status, 0, 30, days)` where status is a string |

### Category C: ASSUMING Clause Limitations

| Code | Name | Description | Example |
|------|------|-------------|---------|
| C1 | Static ASSUMING | ASSUMING used with a static column prediction instead of an aggregation target | `PREDICT users.tier FOR EACH users.user_id ASSUMING users.country = 'US'` |

### Category D: Unsupported and Restricted Operations

**D.1 — Restricted (in grammar, blocked in RFM mode):**

| Code | Name | Description |
|------|------|-------------|
| D1 | COUNT_DISTINCT | Enterprise only — blocked in RFM |
| D2 | FIRST / LAST | Enterprise only — blocked in RFM |
| D4 | LIKE / Pattern Match | In PQL grammar, but blocked in RFM mode for string operations |
| D4b | CONTAINS / STARTS WITH / ENDS WITH | In PQL grammar, but blocked in RFM mode |
| D5 | RANK TOP K | Enterprise only — for multicategorical targets, blocked in RFM |

**D.2 — Truly unsupported (not in grammar):**

| Code | Name | Description |
|------|------|-------------|
| D6 | Subqueries | Nested SELECT statements are not in PQL grammar |
| D7 | ORDER BY / LIMIT | Result ordering and row limits are not part of PQL |
| D8 | GROUP BY | Explicit grouping not in grammar (entity is the implicit group) |
| D9 | Multi-target | Cannot predict multiple targets in a single query |
| D10 | MEDIAN / STDDEV | Not in PQL grammar |

### Category E: Entity & Filter Limitations

| Code | Name | Description | Example |
|------|------|-------------|---------|
| E1 | Non-PK Entity | FOR EACH references a column that is not a primary key | `FOR EACH users.email` |
| E2 | Cross-table Filter | WHERE clause references a table unrelated to the entity | `FOR EACH users.user_id WHERE products.category = 'X'` |
| E3 | Aggregation in WHERE | Aggregation function used inside entity WHERE clause | `FOR EACH users.user_id WHERE COUNT(orders.*, 0, 30, days) > 5` |

### Category F: Business Data Limitations

| Code | Name | Description | Example |
|------|------|-------------|---------|
| F1 | Insufficient History | Not enough historical data for the requested prediction window | Predicting 365-day totals with only 90 days of data |
| F2 | Concept Drift | Historical patterns do not reflect future behavior | Seasonal products, one-time events |

---

## Part 2: Common Mistakes When Writing PQL

### 1. Time Window Errors

**Wrong — past-only window:**
```
PREDICT SUM(orders.amount, -30, 0, days) FOR EACH users.user_id
```

**Right — window extends into the future:**
```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id
```

**Rule:** The `end` parameter must be positive. The window must reach into the future.

### 2. Aggregation Type Mismatches

**Wrong — SUM on a categorical column:**
```
PREDICT SUM(orders.status, 0, 30, days) FOR EACH users.user_id
```

**Right — COUNT for categorical, SUM for numeric:**
```
PREDICT COUNT(orders.* WHERE orders.status = 'completed', 0, 30, days) FOR EACH users.user_id
```

**Rule:** `SUM` and `AVG` require numeric columns. Use `COUNT` with filters for categorical analysis.

### 3. Missing FK Path

**Wrong — no direct FK between products and users:**
```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH products.product_id
```

**Right — use an entity that has a direct FK to orders:**
```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id
```

**Rule:** The entity table must have a direct FK relationship to the target table. Check the semantic view for valid FK paths.

### 4. Non-PK Entity Column

**Wrong — email is not a primary key:**
```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.email
```

**Right — use the primary key:**
```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id
```

**Rule:** `FOR EACH` must reference a primary key column.

### 5. Predicting Unpredictable Columns

**Wrong — predicting a primary key:**
```
PREDICT users.user_id FOR EACH users.user_id
```

**Wrong — predicting a timestamp:**
```
PREDICT orders.order_date FOR EACH users.user_id
```

**Right — predict a categorical or numeric column:**
```
PREDICT users.membership_tier FOR EACH users.user_id
```

**Rule:** Only categorical and numeric columns are valid prediction targets. PKs, FKs, timestamps, and free-text columns are not predictable.

### 6. ASSUMING with Static Targets

**Wrong — ASSUMING with a column prediction:**
```
PREDICT users.membership_tier FOR EACH users.user_id ASSUMING users.country = 'US'
```

**Right — ASSUMING with an aggregation target:**
```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id ASSUMING orders.discount = 0.1
```

**Rule:** `ASSUMING` is only valid with aggregation targets, not static column predictions.

### 7. Nested Aggregations

**Wrong:**
```
PREDICT AVG(SUM(orders.amount, 0, 30, days), 0, 90, days) FOR EACH users.user_id
```

**Right:**
```
PREDICT AVG(orders.amount, 0, 30, days) FOR EACH users.user_id
```

**Rule:** Only single-level aggregations are supported. No nesting.

### 8. Unsupported Aggregation Functions

**Wrong:**
```
PREDICT COUNT_DISTINCT(orders.product_id, 0, 30, days) FOR EACH users.user_id
```

**Right — approximate with filtered COUNT:**
```
PREDICT COUNT(orders.* WHERE orders.product_id IS NOT NULL, 0, 30, days) FOR EACH users.user_id
```

**Rule:** In RFM mode, `SUM`, `AVG`, `MIN`, `MAX`, `COUNT`, and `LIST_DISTINCT` are supported. Enterprise mode also supports `COUNT_DISTINCT`, `FIRST`, `LAST`.

### 9. Cross-table Filters in WHERE

**Wrong — filtering by a column from an unrelated table:**
```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id WHERE products.category = 'electronics'
```

**Right — use a filtered aggregation instead:**
```
PREDICT SUM(orders.amount WHERE orders.category = 'electronics', 0, 30, days) FOR EACH users.user_id
```

**Rule:** Entity `WHERE` clause can only reference columns from the entity table. Use filtered aggregations for cross-table conditions.

### 10. Unsupported Operations

**Wrong — LIKE pattern matching:**
```
PREDICT ... FOR EACH users.user_id WHERE users.name LIKE '%smith%'
```

**Right — use exact match or IN:**
```
PREDICT ... FOR EACH users.user_id WHERE users.name = 'Smith'
PREDICT ... FOR EACH users.user_id WHERE users.name IN ('Smith', 'Johnson')
```

**Rule:** `LIKE`, `RANK TOP K`, and string operators (`CONTAINS`, `STARTS WITH`, `ENDS WITH`) are in the PQL grammar but blocked in RFM mode. `ORDER BY`, `LIMIT`, `GROUP BY`, and subqueries are not part of PQL.

---

## Part 3: Parser and Validator Errors

### Grammar-Level Syntax Errors

#### Missing or Misplaced Keywords

| Error | Cause | Fix |
|-------|-------|-----|
| `Expected 'PREDICT' keyword` | Query does not start with PREDICT | Start every query with `PREDICT` |
| `Expected 'FOR EACH' after target` | Missing FOR EACH clause | Add `FOR EACH <table>.<pk_column>` |
| `Unexpected token after FOR EACH` | Extra keywords or malformed entity | Ensure entity is `table.column` format |
| `Expected aggregation or column reference` | Invalid target expression | Use `table.column` or `AGG(table.column, ...)` |

#### Invalid Clause Structure

| Error | Cause | Fix |
|-------|-------|-----|
| `Invalid WHERE clause syntax` | Malformed condition expression | Check operator, value, and parentheses |
| `Invalid ASSUMING clause syntax` | Malformed hypothetical condition | Use simple `column = value` assignments |
| `Unexpected tokens after query end` | Extra content after valid query | Remove trailing text |

#### Specific Syntax Rules

| Error | Cause | Fix |
|-------|-------|-----|
| `String literal must use single quotes` | Double quotes used for strings | Replace `"value"` with `'value'` |
| `Unterminated string literal` | Missing closing quote | Add the closing `'` |
| `Invalid number format` | Malformed numeric literal | Use valid integer or decimal format |
| `Empty IN list` | `IN ()` with no values | Provide at least one value in the IN list |

### Reference Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Unknown table: <name>` | Table not in semantic view | Check available tables in the view |
| `Unknown column: <table>.<column>` | Column not in table definition | Verify column name and table |
| `Table <name> has no timestamp column` | Temporal aggregation on a table without timestamps | Use a table that has a timestamp column, or use static prediction |

### Type Mismatch Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Cannot apply SUM to categorical column` | SUM/AVG on non-numeric data | Use COUNT with filter, or choose a numeric column |
| `Cannot apply AVG to categorical column` | AVG on non-numeric data | Use COUNT or choose a numeric column |
| `Cannot predict primary key column` | Target is a PK | Choose a predictable (categorical/numeric) column |
| `Cannot predict foreign key column` | Target is an FK | Choose a predictable column |
| `Cannot predict timestamp column` | Target is a timestamp | Timestamps are used for windowing, not prediction |
| `Cannot predict text column` | Target is free-text | Free-text columns are not supported |

### Semantic Type Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Column <col> is not a valid prediction target` | Column type is not predictable | Use categorical or numeric columns only |
| `ASSUMING requires aggregation target` | ASSUMING used with static column prediction | Change to an aggregation target |
| `Filter column must be from aggregation table` | WHERE inside aggregation references a different table | Use a column from the same table as the aggregation |

### Time Range Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Start must be less than end` | e.g., `(30, 0, days)` | Swap so start < end |
| `End must be positive` | e.g., `(-30, -1, days)` | End must be > 0 (window must extend into future) |
| `Invalid time unit` | e.g., `years`, `seconds` | Use `days`, `hours`, `minutes`, or `months` |
| `Time parameters must be numeric` | String or other type in time position | Use integers or `-INF` |

### Entity Specification Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `FOR EACH must reference a primary key` | Non-PK column used | Use the table's PK column |
| `FOR EACH column must use table.column format` | Missing table prefix | Use `table.column` format |
| `Entity table not found in view` | Table not in semantic view | Check available tables |

### Unsupported Operation Errors

#### Aggregation Functions

| Error | Cause | Fix |
|-------|-------|-----|
| `Unsupported aggregation: COUNT_DISTINCT` | Blocked in RFM mode | Use `COUNT` with `IS NOT NULL` filter, or use Enterprise mode |
| `Unsupported aggregation: FIRST` | Blocked in RFM mode | Use Enterprise mode |
| `Unsupported aggregation: LAST` | Blocked in RFM mode | Use Enterprise mode |
| `Unsupported aggregation: MEDIAN` | Not in PQL grammar | Use `AVG` as approximation |
| `Unsupported aggregation: STDDEV` | Not in PQL grammar | No workaround |

#### Column Operations

| Error | Cause | Fix |
|-------|-------|-----|
| `Arithmetic in target not supported` | e.g., `PREDICT col1 + col2` | Predict columns individually |
| `CASE expressions not supported` | SQL-style CASE in PQL | Use WHERE filters instead |
| `Column aliasing not supported` | `AS alias` in PQL | Remove alias |

#### String Operations

| Error | Cause | Fix |
|-------|-------|-----|
| `LIKE operator not supported` | Blocked in RFM mode (valid in Enterprise) | Use `=` or `IN` in RFM, or use Enterprise mode |
| `CONTAINS / STARTS WITH / ENDS WITH not supported` | Blocked in RFM mode (valid in Enterprise) | Use `=` or `IN` in RFM |
| `String functions not supported` | e.g., `UPPER()`, `CONCAT()` | Use exact column references |

#### Structural Limitations

| Error | Cause | Fix |
|-------|-------|-----|
| `Subqueries not supported` | `WHERE x IN (SELECT ...)` | Use literal value lists |
| `Multiple targets not supported` | More than one PREDICT target | Write separate queries |
| `ORDER BY not supported` | Sorting results | Not part of PQL |
| `LIMIT not supported` | Row limits | Not part of PQL |
| `GROUP BY not supported` | Explicit grouping | Entity is the implicit group |

### Join Resolution Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Missing foreign key` | Tables are not directly connected (no FK path) | Check semantic view for valid FK relationships |
| `Ambiguous link between tables` | Multiple FK paths exist between tables | Specify the intended relationship explicitly |
| `Multi-hop join required` | Path requires intermediate tables | Use only directly connected tables |
| `Couldn't pick a unique X for each Y` | Reverse FK resolution (one-to-many) | Use an aggregation instead of direct column reference |

---

## Pre-flight Checklist

Before submitting a PQL query, verify each item:

- [ ] Query starts with `PREDICT` and contains `FOR EACH`
- [ ] `FOR EACH` column is a **primary key**
- [ ] Target column is **categorical or numeric** (not PK, FK, timestamp, or text)
- [ ] If using aggregation: function is one of `SUM`, `AVG`, `MIN`, `MAX`, `COUNT`
- [ ] If using aggregation: `end` parameter is **positive** (window extends into the future)
- [ ] If using aggregation: `start < end`
- [ ] If using `SUM` or `AVG`: target column is **numeric**
- [ ] Time unit is one of `days`, `hours`, `minutes`, `months`
- [ ] Entity table and target table are connected by a **direct FK path** in the semantic view
- [ ] `WHERE` conditions reference columns from the **entity table** only
- [ ] Filtered aggregation `WHERE` references columns from the **aggregation table** only
- [ ] `ASSUMING` is only used with **aggregation targets**, not static column predictions
- [ ] String literals use **single quotes** (`'value'`, not `"value"`)
- [ ] No unsupported operations: `ORDER BY`, `LIMIT`, `GROUP BY`, subqueries
- [ ] If using RFM: no `COUNT_DISTINCT`, `FIRST`, `LAST`, `LIKE`, `CONTAINS`
- [ ] No nested aggregations
- [ ] All referenced tables and columns **exist** in the semantic view
