# Write a PQL Query

Interactive workflow for authoring and validating PQL (Predictive Query Language) queries that translate natural-language prediction questions into executable PQL statements.

---

## Prerequisites

- Schema knowledge: know your tables, columns, primary keys, foreign keys,
  and time columns
- **Read first**: `context/platform/pql-syntax.md`
- **If debugging**: also read `context/platform/pql-errors.md`

## Workflow

### Step 1: Understand the Question

Before writing any PQL, decompose the natural-language question into four
components:

| Component | Question to Ask | Example |
|---|---|---|
| **Prediction vs. Historical** | Is the answer about the future or the past? | "Will this customer churn?" = future prediction |
| **Entity** | Who or what are we predicting for? | Customers, products, stores, accounts |
| **Outcome** | What are we predicting about them? | Churn, spend, category, count of events |
| **Time Horizon** | Over what period? | Next 30 days, next 7 days, next quarter |

If the question is purely historical or analytical (e.g., "What was total
revenue last month?"), it is a SQL question, not a PQL question. PQL is
exclusively for predictions about future or unknown outcomes.

**Decision rule**: If you can answer the question with a `SELECT` and
`GROUP BY` on existing data, use SQL. If the answer requires forecasting
an outcome that has not happened yet, use PQL.

### Step 2: Identify the PQL Task Type

Map the decomposed question to one of the supported PQL task families.

| Question Pattern | Task Type | PQL Pattern |
|---|---|---|
| "Will X happen in next N days?" | Temporal binary classification | `PREDICT COUNT(target.col, 0, N, days) > 0 FOR EACH entity.pk` |
| "How many X in next N days?" | Temporal regression (count) | `PREDICT COUNT(target.col, 0, N, days) FOR EACH entity.pk` |
| "What total X in next N days?" | Temporal regression (sum) | `PREDICT SUM(target.col, 0, N, days) FOR EACH entity.pk` |
| "What average X in next N days?" | Temporal regression (avg) | `PREDICT AVG(target.col, 0, N, days) FOR EACH entity.pk` |
| "What min/max X in next N days?" | Temporal regression (min/max) | `PREDICT MIN(target.col, 0, N, days) FOR EACH entity.pk` |
| "What category/type is X?" | Static classification | `PREDICT entity.category_col FOR EACH entity.pk` |
| "What is the value of X?" | Static regression | `PREDICT entity.numeric_col FOR EACH entity.pk` |
| "What if we change Z?" | What-if analysis | Add `ASSUMING SUM(target.col, 0, N, days) = value` |
| "Forecast over multiple periods" | Multi-window forecast | Use consecutive non-overlapping windows |

If the question does not fit any pattern above, it likely cannot be
expressed in PQL. Common unsupported cases:

- Ranking or ordering ("Who is the top customer?")
- Multi-hop predictions ("Predict X for friends of Y")
- Cross-entity aggregations ("Total across all customers")
- Time-series decomposition ("What is the trend?")

### Step 3: Check Schema Requirements

Verify that the graph schema supports the query you plan to write.

**Required checks:**

1. **Entity table and PK** — `FOR EACH` column must be the primary key of
   an entity table in the graph.
2. **Target table and column** — Column inside `PREDICT` must exist and be
   directly linked (1 FK hop) to the entity table.
3. **Foreign-key path is 1-hop** — No intermediate joins allowed. Pre-join
   in SQL if the path requires multiple hops.
4. **Time column exists** — Temporal queries require a datetime column on
   the target table, detected as time type (not string).
5. **Column types match** — `SUM`/`AVG`/`MIN`/`MAX` require numeric
   columns. `COUNT` works on any type.

If any check fails, fix the schema or graph before proceeding.

### Step 4: Write the Query

Use the canonical PQL template:

```
PREDICT <target>
FOR EACH <entity_table>.<primary_key>
[WHERE <filter_condition>]
[ASSUMING <what_if_condition>]
```

**Target types:**

| Type | Syntax | Example |
|---|---|---|
| Column (static) | `table.column` | `PREDICT users.segment FOR EACH users.user_id` |
| Aggregation (temporal) | `AGG(table.column, start, end, unit)` | `PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id` |
| Binary condition | `AGG(...) > threshold` | `PREDICT COUNT(orders.order_id, 0, 30, days) > 0 FOR EACH users.user_id` |

**Time window semantics:**

- `(table.col, start, end, unit)` — offsets from anchor time into future.
- Both must be non-negative integers, with `start < end`.
- Units: `days`, `hours`, `minutes`, `months` (no `weeks`, `seconds`, or `years` — see PQL grammar).

**WHERE clause (entity filter)** — filters which entities get scored:

```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id WHERE users.status = 'active'
```

**ASSUMING clause (what-if)** — hypothetical scenario, must use
temporal aggregation with non-negative time window:

```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id ASSUMING SUM(marketing.spend, 0, 30, days) = 5000
```

**WHERE inside aggregation (event filter)** — filters which rows count
toward the aggregation:

```
PREDICT SUM(orders.amount, 0, 30, days) WHERE orders.category = 'electronics' FOR EACH users.user_id
```

### Step 5: Pre-flight Checklist

Run through every constraint before executing. A single violation will
cause the query to fail.

- [ ] **Time window non-negative** — Both `start` and `end` are >= 0, and
  `start` < `end`.
- [ ] **Aggregation matches column type** — `SUM`/`AVG`/`MIN`/`MAX` on
  numeric columns only. `COUNT` on any column.
- [ ] **ASSUMING uses temporal aggregation** — The ASSUMING clause must
  contain a temporal aggregation (not a static column reference), and its
  time window must be non-negative (both start and end >= 0).
- [ ] **No nested aggregations** — `SUM(COUNT(...))` is not valid PQL.
  Each query has exactly one aggregation level.
- [ ] **FK path is direct (1-hop)** — The entity table and target table
  are connected by a single foreign key. No intermediate joins.
- [ ] **Entity column is a primary key** — The column after `FOR EACH`
  must be the PK of its table.
- [ ] **No explicit entity IDs with `FOR EACH`** — `FOR EACH table.pk`
  means "all entities". Do not combine with `= 'id'` or `IN (...)`.
  Pass specific entities via `model.predict(query, indices=[...])` instead.
  Use `FOR table.pk = 'id'` only for single-entity queries without `EACH`.
- [ ] **Table and column names are exact** — PQL is case-sensitive to the
  graph schema. Verify spelling against `graph.print_metadata()`.
- [ ] **No unsupported operators** — PQL supports `>`, `<`, `>=`, `<=`,
  `=`, `!=` for binary conditions. No `BETWEEN`, `IN`, `LIKE`.
- [ ] **Single entity table** — You cannot predict `FOR EACH` across
  multiple tables simultaneously.

### Step 6: Validate

Choose the validation method that matches your environment.

**In the RFM SDK (Python):**

```python
import kumoai.experimental.rfm as rfm

model = rfm.KumoRFM(graph)
# predict() will validate the query before execution.
# Invalid queries raise QueryValidationError with details.
# indices is REQUIRED for FOR EACH queries.
entity_ids = graph["entity_table"].df["pk_column"].tolist()
pred_df = model.predict(query, indices=entity_ids, run_mode="fast")
```

**Using the PQuery object directly:**

```python
from kumoai.pql import PQuery

pquery = PQuery.parse(query_string)
pquery.validate(graph, verbose=True)
```

If validation fails, read the error message carefully — it usually
identifies the exact constraint that was violated. Proceed to Step 7.

### Step 7: Iterate If Needed

Common fixes for validation failures:

| Failure | Before | After |
|---|---|---|
| Wrong agg type | `SUM(orders.status, ...)` (categorical col) | `COUNT(orders.status, ...)` |
| Multi-hop FK | `users -> orders -> returns` (2 hops) | Pre-join in SQL to create direct link |
| ASSUMING without agg | `ASSUMING users.segment = 'premium'` | `ASSUMING SUM(spend, 0, 30, days) = 5000` |
| Window reversed | `SUM(orders.amount, 30, 0, days)` | `SUM(orders.amount, 0, 30, days)` |

**Consecutive-window forecast** — use non-overlapping windows:

```
PREDICT SUM(orders.amount, 0, 7, days) FOR EACH users.user_id
PREDICT SUM(orders.amount, 7, 14, days) FOR EACH users.user_id
PREDICT SUM(orders.amount, 14, 21, days) FOR EACH users.user_id
```

## Quick Reference: PQL Syntax

**Aggregation functions:**

| Function | Description | Column Type |
|---|---|---|
| `COUNT` | Number of rows | Any |
| `SUM` | Sum of values | Numeric |
| `AVG` | Mean of values | Numeric |
| `MIN` | Minimum value | Numeric |
| `MAX` | Maximum value | Numeric |

**Time units:** `days`, `hours`, `minutes`, `months`

**Comparison operators:** `>`, `<`, `>=`, `<=`, `=`, `!=`

**Full query template:**

```
PREDICT AGG(table.column, start_offset, end_offset, time_unit)
  [WHERE event_filter]
  [> | < | >= | <= | = | != threshold]
FOR EACH entity_table.primary_key
  [WHERE entity_filter]
  [ASSUMING column = value | AGG(table.column, start, end, time_unit) op value]
```

## Quick Reference: Task Type Mapping

| NL Pattern | PQL Pattern | Task Type |
|---|---|---|
| "Will customer churn?" | `COUNT(orders.id, 0, 30, days) > 0` | Temporal binary |
| "How much will they spend?" | `SUM(orders.amount, 0, 30, days)` | Temporal regression |
| "How many orders next week?" | `COUNT(orders.id, 0, 7, days)` | Temporal regression |
| "What segment is this user?" | `users.segment` | Static classification |
| "What if we increase budget?" | `SUM(...) ASSUMING SUM(spend, 0, 30, days) = X` | What-if |
| "Predict daily revenue 4 weeks" | Multiple `SUM(rev, N, N+7, days)` | Multi-window forecast |

## Common Errors

| Error | Cause | Fix |
|---|---|---|
| `column not found: X.Y` | Table or column name does not exist in graph | Check `graph.print_metadata()` for exact names |
| `multi-hop FK path` | Entity and target separated by 2+ joins | Flatten with SQL join or restructure graph |
| `invalid aggregation for column type` | `SUM`/`AVG` on non-numeric column | Switch to `COUNT` or use a numeric column |
| `nested aggregation` | `SUM(COUNT(...))` or similar nesting | Rewrite as a single aggregation level |
| `start >= end in time window` | Time window bounds inverted or equal | Ensure `start < end`, both non-negative |
| `FOR EACH column is not a primary key` | Predicting for a non-PK column | Use the actual PK of the entity table |
| `ASSUMING requires temporal aggregation` | Static column in ASSUMING clause | Wrap in temporal aggregation with non-negative window |
| `unsupported time unit` | Typo in unit (e.g., `day` instead of `days`) | Use: `days`, `hours`, `minutes`, `months` |
| `query is not a prediction` | Question is historical/analytical | Use SQL instead of PQL |
| `no time column on target table` | Temporal query but table lacks datetime | Add time column to table or fix graph metadata |

## Checklist

- [ ] Question decomposed: entity, outcome, time horizon identified
- [ ] Confirmed the question requires prediction (not historical SQL)
- [ ] PQL task type selected from mapping table
- [ ] Schema requirements verified: PK, FK path, time column, column types
- [ ] Query written following canonical template
- [ ] Pre-flight checklist passed (all 9 constraints)
- [ ] Query validated via SDK, script, or PQuery parser
- [ ] Validation errors resolved (if any)
- [ ] Final query reviewed for correctness and completeness
- [ ] Query documented with the original natural-language question
