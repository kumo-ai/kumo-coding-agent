# PQL Syntax Reference (RFM_SDK_V2)

> Source: kumo-pql (PQL_SYNTAX_REFERENCE) | Last synced: 2026-03-31
>
> **Authoritative source for PQL syntax:** the `kumo-pql` parser grammar
> (`kumopql/grammar/PQLGrammar.g4`) and the `kumo-api` type definitions
> (`kumoapi/typing.py`). When documentation conflicts with the grammar,
> the grammar wins.

This document describes the PQL (Predictive Query Language) syntax for creating evaluation datasets and constructing prediction queries against semantic views.

---

## Query Structure

Every PQL query follows this top-level pattern:

```
PREDICT <target> [FORECAST N TIMEFRAMES] [CLASSIFY|RANK] [TOP K] (FOR EACH|FOR) <entity> [WHERE <condition>] [ASSUMING <condition>]
```

| Component | Required | Description |
|-----------|----------|-------------|
| `PREDICT` | Yes | Keyword that starts every query |
| `<target>` | Yes | What to predict — a column value or aggregation |
| `FORECAST N TIMEFRAMES` | No | Generate N forecast periods (fine-tuned only) |
| `CLASSIFY` / `RANK` | No | Problem type for multicategorical targets (fine-tuned only) |
| `TOP K` | No | Return top-K results (used with RANK) |
| `FOR EACH` | Yes* | Keyword introducing the entity to predict for (batch mode) |
| `FOR` | Yes* | Single-entity mode: `FOR table.pk = 'ID'` (RFM only) |
| `<entity>` | Yes | The primary key column identifying each entity |
| `WHERE` | No | Filter which entities to include |
| `ASSUMING` | No | Hypothetical condition for what-if analysis |

\* Use `FOR EACH` for batch predictions, `FOR` for single-entity predictions.

---

## Prediction Targets

### Column Targets (Static Prediction)

Predict the value of a single column for each entity.

```
PREDICT users.membership_tier FOR EACH users.user_id
```

**Predictable column types:**
- Numerical (integer, float)
- Categorical (enum-like string columns)

**NOT predictable:**
- Primary key columns
- Foreign key columns
- Timestamp columns
- Free-text columns

### Aggregation Targets (Temporal Prediction)

Predict an aggregated value over a future (or past-to-future) time window.

**Supported aggregations:**
- RFM + fine-tuned: `SUM`, `AVG`, `MIN`, `MAX`, `COUNT`, `LIST_DISTINCT`
- Fine-tuned only: `COUNT_DISTINCT`, `FIRST`, `LAST`

**Syntax:**

```
AGGREGATION(table.column, start, end, time_unit)
AGGREGATION(table.column)                          -- static aggregation (no time range)
```

| Parameter | Description |
|-----------|-------------|
| `table.column` | The column to aggregate (use `table.*` for COUNT) |
| `start` | Start of time window relative to prediction time |
| `end` | End of time window relative to prediction time |
| `time_unit` | One of: `days`, `hours`, `minutes`, `months` |

**Time Window Examples:**

| Window | Meaning |
|--------|---------|
| `(0, 30, days)` | Next 30 days from prediction time |
| `(-7, 30, days)` | From 7 days ago to 30 days from now |
| `(-INF, 30, days)` | From the infinite past to 30 days from now |
| `(0, 24, hours)` | Next 24 hours |
| `(0, 3, months)` | Next 3 months |

**Important rules:**
- `start` must be less than `end`
- The `end` value must be positive (i.e., extend into the future)
- Use `-INF` or `-INFINITY` for unbounded past windows
- Past-only windows (both start and end negative) are **not supported**

**Examples:**

```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id
PREDICT COUNT(claims.*, 0, 90, days) FOR EACH policies.policy_id
PREDICT AVG(transactions.amount, 0, 7, days) FOR EACH accounts.account_id
PREDICT MAX(orders.amount, -INF, 30, days) FOR EACH users.user_id
```

### Filtered Aggregations

Add a `WHERE` clause inside the aggregation to filter which rows are aggregated.

```
PREDICT COUNT(orders.* WHERE orders.status = 'completed', 0, 30, days) FOR EACH users.user_id
PREDICT SUM(orders.amount WHERE orders.category = 'electronics', 0, 30, days) FOR EACH users.user_id
```

**Rules:**
- The filter column must belong to the same table as the aggregated column
- Only simple conditions are supported inside aggregation filters
- `AND` / `OR` logic is supported within the aggregation filter

### Classification (Binary)

Create binary classification targets by applying a comparison to an aggregation.

```
PREDICT COUNT(orders.*, 0, 30, days) > 0 FOR EACH users.user_id
```

This predicts the **probability** that the condition is true (e.g., probability a customer places at least one order in the next 30 days).

**Supported comparisons:** `>`, `>=`, `<`, `<=`, `=`, `!=`

### Forecasting (Fine-tuned Only)

Generate predictions across multiple future time periods.

```
PREDICT SUM(orders.amount, 0, 30, days) FORECAST 12 TIMEFRAMES FOR EACH users.user_id
```

**Rules:**
- `FORECAST N` where N >= 1 (max 10,000)
- Only works with temporal (time-ranged) aggregation targets
- Only works with numerical targets

### Link Prediction / Multicategorical

Predict which related entities are most likely.

```
PREDICT LIST_DISTINCT(orders.product_id, 0, 30, days) FOR EACH users.user_id
```

**Rules:**
- The target column of `LIST_DISTINCT` must be registered as a **foreign key** in the graph
- Used for link prediction and recommendation tasks
- Fine-tuned SDK also supports `RANK TOP K` and `CLASSIFY` modifiers for ranking output

---

## Entity Selection

### FOR EACH (Batch Mode)

The `FOR EACH` clause specifies which entity type to generate predictions for. The column must be a primary key.

```
PREDICT ... FOR EACH users.user_id
PREDICT ... FOR EACH policies.policy_id
```

### FOR (Single-Entity Mode, RFM)

The `FOR` clause specifies a specific entity or set of entities by value.

```
PREDICT ... FOR users.user_id = 42
PREDICT ... FOR users.user_id IN (42, 123, 456)
PREDICT ... FOR users.user_id = 42 WHERE users.country = 'US'
```

### WHERE (Entity Filtering)

Filter which entities to include in the prediction batch.

```
PREDICT ... FOR EACH users.user_id WHERE users.country = 'US'
PREDICT ... FOR EACH users.user_id WHERE users.signup_date > '2024-01-01'
```

---

## Conditions

### Comparison Operators

| Operator | Description | Notes |
|----------|-------------|-------|
| `=` | Equal to | |
| `!=` | Not equal to | |
| `<` | Less than | |
| `>` | Greater than | |
| `<=` | Less than or equal to | |
| `>=` | Greater than or equal to | |
| `LIKE` / `NOT LIKE` | Pattern matching | fine-tuned only, blocked in RFM |
| `CONTAINS` / `NOT CONTAINS` | Substring match | fine-tuned only, blocked in RFM |
| `STARTS WITH` / `ENDS WITH` | Prefix/suffix match | fine-tuned only, blocked in RFM |

### NULL Checks

```
WHERE users.email IS NOT NULL
WHERE orders.discount IS NULL
```

### Membership

```
WHERE users.country IN ('US', 'CA', 'UK')
```

### Logical Operators

```
WHERE users.country = 'US' AND users.status = 'active'
WHERE users.tier = 'gold' OR users.tier = 'platinum'
WHERE NOT users.status = 'inactive'
WHERE (users.country = 'US' OR users.country = 'CA') AND users.status = 'active'
```

---

## What-If Analysis (ASSUMING)

The `ASSUMING` clause lets you set hypothetical values for what-if predictions.

```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id ASSUMING orders.discount = 0.1
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id ASSUMING SUM(marketing.spend, 0, 30, days) >= 1000
```

**Rules:**
- ASSUMING only works with **aggregation targets** (not static column predictions)
- ASSUMING supports both static column conditions and temporal aggregation conditions
- Any time windows inside ASSUMING must be **non-negative** (both start and end >= 0)
- Only simple assignments are supported (column = value or aggregation comparison)

---

## Data Types

| Type | Examples |
|------|---------|
| Integer | `42`, `0`, `-7` |
| Decimal | `3.14`, `0.5`, `-INF` |
| Boolean | `true`, `false` |
| String | `'hello'`, `'US'` |
| NULL | `NULL`, `null` |
| Date | `'2024-01-15'` |
| DateTime | `'2024-01-15T10:30:00'` |
| Array | `('US', 'CA', 'UK')` — used only with `IN` |

**Special values:**
- `-INF` / `-INFINITY` — negative infinity (for unbounded past time windows)
- `NULL` / `null` — null value
- `true` / `false` — boolean literals

---

## Complete Examples

### 1. Basic Temporal Prediction

```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id
```
Predict total order amount in the next 30 days for each user.

### 2. Categorical Prediction

```
PREDICT users.membership_tier FOR EACH users.user_id
```
Predict membership tier for each user.

### 3. Filtered Entity Set

```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id WHERE users.country = 'US'
```
Predict next-30-day order total, but only for US users.

### 4. Filtered Aggregation

```
PREDICT COUNT(orders.* WHERE orders.status = 'completed', 0, 30, days) FOR EACH users.user_id
```
Predict number of completed orders in the next 30 days.

### 5. Binary Classification

```
PREDICT COUNT(claims.*, 0, 90, days) > 0 FOR EACH policies.policy_id
```
Predict probability of at least one claim in the next 90 days.

### 6. What-If Analysis

```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id ASSUMING orders.discount = 0.1
```
Predict next-30-day spend if a 10% discount is applied.

### 7. Infinite Past Window

```
PREDICT MAX(orders.amount, -INF, 30, days) FOR EACH users.user_id
```
Predict the maximum order amount from all history through the next 30 days.

### 8. Complex Condition

```
PREDICT SUM(orders.amount WHERE orders.category = 'electronics' AND orders.status = 'completed', 0, 30, days) FOR EACH users.user_id WHERE users.country IN ('US', 'CA')
```
Predict completed electronics order total in the next 30 days for US and Canadian users.

---

## Unsupported and Restricted Operations

### Restricted Aggregations (Fine-tuned Only)

These are valid PQL syntax but blocked in RFM mode:

| Operation | Status | Notes |
|-----------|--------|-------|
| `COUNT_DISTINCT` | fine-tuned only | Blocked in RFM |
| `FIRST` | fine-tuned only | Blocked in RFM |
| `LAST` | fine-tuned only | Blocked in RFM |

### Unsupported Aggregations

These do not exist in the PQL grammar:

| Operation | Status | Workaround |
|-----------|--------|------------|
| `MEDIAN` | Not in grammar | Use `AVG` as approximation |
| `STDDEV` | Not in grammar | None |

### Unsupported Target Types

| Target | Reason |
|--------|--------|
| Primary key columns | Identifiers, not predictable |
| Foreign key columns | Relationships, not predictable |
| Timestamp columns | Time columns are used for windowing |
| Free-text columns | Unstructured text not supported |
| Sequence predictions | Cannot predict ordered lists |

### Unsupported Patterns

| Pattern | Example | Why |
|---------|---------|-----|
| `LIKE` / pattern matching | `WHERE name LIKE '%smith%'` | In grammar but blocked in RFM mode |
| `RANK TOP K` | Top 10 customers by spend | fine-tuned only (multicategorical targets) |
| Nested aggregations | `AVG(SUM(...))` | Only single-level aggregation |
| Multi-hop joins | Predicting across 3+ tables | FK path must be direct |
| Subqueries | `WHERE x IN (SELECT ...)` | Not in grammar |
| `ORDER BY` / `LIMIT` | Sorting or limiting results | Not in grammar |
| `GROUP BY` | Grouping results | Not in grammar; entity is the implicit group |

### Workarounds

| Unsupported | Workaround |
|-------------|------------|
| `COUNT_DISTINCT` in RFM | Use `COUNT(orders.* WHERE orders.product_id IS NOT NULL, ...)` or switch to fine-tuned |
| Past-only window `(-30, -1, days)` | Use `(-30, 1, days)` — window must extend into the future |
| `LIKE` filtering in RFM | Use `=` with exact values or `IN` with a list |
| Multi-hop prediction | Break into separate queries along direct FK paths |

---

## Quick Reference Card

**Supported Aggregations:** `SUM`, `AVG`, `MIN`, `MAX`, `COUNT`, `LIST_DISTINCT` (all modes); `COUNT_DISTINCT`, `FIRST`, `LAST` (fine-tuned only)

**Time Units:** `days`, `hours`, `minutes`, `months`

**Comparison Operators:** `=`, `!=`, `<`, `>`, `<=`, `>=`, `LIKE`, `CONTAINS`, `STARTS WITH`, `ENDS WITH` (fine-tuned only for string ops)

**Logical Operators:** `AND`, `OR`, `NOT`

**Special Operators:** `IS NULL`, `IS NOT NULL`, `IN (...)`

**Query Template:**

```
PREDICT <aggregation>(<table>.<column>, <start>, <end>, <time_unit>) FOR EACH <table>.<pk_column> [WHERE <condition>] [ASSUMING <aggregation>(<table>.<column>, <start>, <end>, <time_unit>) = <value>]
```

**Binary Classification Template:**

```
PREDICT <aggregation>(<table>.<column>, <start>, <end>, <time_unit>) <comparator> <value> FOR EACH <table>.<pk_column>
```
