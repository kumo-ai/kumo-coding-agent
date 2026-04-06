# Debug a Failed Prediction

Diagnose and fix PQL prediction failures using a systematic decision tree. Follow the branches below to identify the root cause, then apply the corresponding fix.

---

## Prerequisites

- A PQL query that failed or produced unexpected results
- Access to the graph or semantic view the query targets
- The full error message (if the query errored) or the unexpected output (if it ran but returned wrong results)
- **Read first**: `context/platform/pql-errors.md`

## How to Use This Skill

1. Start with the **Diagnostic Decision Tree** -- read the branch headers and match your symptoms
2. Follow the matching branch to identify the root cause
3. Apply the fix described in that branch
4. If the fix does not resolve the issue, check the **Quick Fixes** table for symptom-based lookup
5. Use the **Error Message Reference** to map exact error strings to fixes
6. Run through the **Checklist** before declaring the issue resolved

---

## Diagnostic Decision Tree

### Branch 1: Is It a Syntax Error?

**Symptoms:** Parser rejects the query before execution. Error message references unexpected tokens or missing clauses.

| Sub-Issue | Example | Fix |
|-----------|---------|-----|
| Missing PREDICT keyword | `SUM(orders.amount, 0, 30, days) FOR EACH users.user_id` | Add `PREDICT` at the start of the query |
| Missing FOR EACH clause | `PREDICT SUM(orders.amount, 0, 30, days)` | Add `FOR EACH table.primary_key` to specify the entity |
| Invalid aggregation syntax | `PREDICT SUM(orders.amount)` (missing time range) | Include all required parameters: `SUM(table.col, start, end, unit)` |
| Single-element time array | `PREDICT SUM(orders.amount, 30, days)` | Time range requires three elements: `(start, end, unit)` |
| Invalid column format | `PREDICT SUM(amount, 0, 30, days)` | Use fully qualified names: `table_name.column_name` |
| Unrecognized time unit | `PREDICT SUM(orders.amount, 0, 30, years)` | Use `days`, `hours`, `minutes`, or `months` only |
| Missing parentheses | `PREDICT SUM orders.amount, 0, 30, days FOR EACH users.user_id` | Wrap aggregation arguments in parentheses |

**Action:** Fix the syntax per the error message, then retry. A correct minimal PQL query looks like:

```
PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id
```

All parts are required: `PREDICT`, aggregation with fully qualified column, time range (for temporal), and `FOR EACH` with entity PK.

### Branch 2: Is It a Reference Error?

**Symptoms:** Query parses but fails at validation. Error message says a table, column, or entity is not found.

| Sub-Issue | Diagnosis | Fix |
|-----------|-----------|-----|
| Unknown table | Table name does not exist in the graph | Run `print_metadata()` or `EXPLAIN_PQL` to list valid tables |
| Unknown column | Column does not exist in the referenced table | Check `column_dict` for exact column names (case-sensitive) |
| Invalid entity column | FOR EACH references a non-PK column | Entity column must be a primary key. Check graph metadata. |
| Invalid wildcard usage | `PREDICT COUNT(orders.*, 0, 30, days)` | Wildcards are not supported in aggregation targets |
| Schema mismatch | Query targets a different semantic view than intended | Verify the `view_name` matches the intended schema |

**Action:** Verify all table and column names against the graph metadata. Correct any misspellings or wrong references.

### Branch 3: Is It a Type Mismatch?

**Symptoms:** Validation fails because the aggregation is incompatible with the column type, or filters compare incompatible types.

| Sub-Issue | Diagnosis | Fix |
|-----------|-----------|-----|
| SUM/AVG on categorical column | Column stype is `categorical`, not `numerical` | Use `COUNT` for categorical columns |
| COUNT on numerical (unintended) | Wanted a sum but used COUNT | Switch to `SUM` or `AVG` for numerical aggregation |
| String comparison without quotes | `WHERE orders.status = completed` | Add quotes: `WHERE orders.status = 'completed'` |
| NULL comparison with = operator | `WHERE orders.discount = NULL` | Use `WHERE orders.discount IS NULL` |
| Boolean treated as string | `WHERE users.active = 'true'` | Use `WHERE users.active = TRUE` (no quotes) |

**Action:** Check column stypes with `print_metadata()`. Match the aggregation function to the column stype.

### Branch 4: Is It a Time Range Error?

**Symptoms:** Error mentions invalid time range, missing time column, or temporal parameters.

| Sub-Issue | Diagnosis | Fix |
|-----------|-----------|-----|
| Negative start time | `PREDICT SUM(orders.amount, -30, 0, days)` | Start time must be >= 0. Use `(0, 30, days)` for future window. |
| Start >= End | `PREDICT SUM(orders.amount, 30, 10, days)` | Start must be strictly less than end |
| Missing time column | Target table has no timestamp column | Add a time column to the table, or use a different target table |
| Missing time range on temporal table | `PREDICT SUM(orders.amount) FOR EACH ...` | Temporal tables require time range: `(start, end, unit)` |
| Static aggregation on temporal data | Aggregation without time range on a table that has a time column | Either add time range or confirm the column is truly static |
| Wrong anchor_time | `anchor_time` is in the future or misformatted | Use ISO 8601 format. Anchor time should be at or before current time. |

**Action:** Ensure time ranges are non-negative, start < end, and the target table has a valid time column.

### Branch 5: Is It a Relationship Error?

**Symptoms:** Error mentions missing foreign key path, ambiguous link, or unreachable table.

| Sub-Issue | Diagnosis | Fix |
|-----------|-----------|-----|
| No FK path between tables | Entity table and target table are not connected | Check `print_links()`. Add missing edge with `graph.link()`. |
| Ambiguous link | Multiple FK paths exist between two tables | Specify the exact path or simplify the graph to remove ambiguity |
| Multi-hop required | Tables are connected only through intermediate tables | PQL supports only 1-hop. Use Two-Step Aggregation: run SQL to materialize the intermediate result, then PQL on the result. |
| Self-referential FK issue | Table references itself (e.g., manager_id -> user_id) | Verify the self-edge is defined in the graph |

**Action:** Inspect graph links. For multi-hop scenarios, break the prediction into SQL + PQL steps.

**Multi-hop workaround example:**

If you need to predict across `users -> orders -> products` (2 hops), break it into:
1. SQL step: Join `orders` and `products` to create a flat table with the needed columns
2. PQL step: Predict using the entity table that is 1-hop from the flat result

### Branch 6: Is It an Unsupported Operation?

**Symptoms:** Error says the operation is not supported, or the query uses a function that does not exist.

| Unsupported Operation | Alternative |
|-----------------------|-------------|
| `COUNT_DISTINCT` | Use SQL to pre-compute distinct counts, then predict on the result |
| `FIRST` / `LAST` | Not available. Use SQL to extract first/last values. |
| `LIKE` / `CONTAINS` | Use SQL WHERE with LIKE, then pass filtered entity list via `entity_sql` |
| Nested aggregations | `PREDICT AVG(SUM(...))` is invalid. Break into two queries. |
| Link prediction | Predicting whether a relationship will form is not supported |
| Static column in ASSUMING | `ASSUMING` only works with temporal aggregations |
| `GROUP BY` in PQL | PQL does not support GROUP BY. Use `FOR EACH` for entity grouping. |
| `ORDER BY` / `LIMIT` in PQL | Not supported. Apply ordering/limits in post-processing SQL. |

**Action:** Check if the operation is in the unsupported list. Use a SQL workaround or restructure as a multi-step workflow.

**General principle:** PQL handles the predictive aggregation. Everything else (filtering, grouping, ordering, deduplication) belongs in SQL -- either in `entity_sql` (pre-processing) or in a post-processing query on the prediction results.

### Branch 7: Query Runs But Produces Unexpected Results

**Symptoms:** No error, but the output values or rows are wrong.

| Sub-Issue | Diagnosis | Fix |
|-----------|-----------|-----|
| Wrong entity IDs returned | `entity_sql` selects wrong rows | Verify `entity_sql` returns the correct PK values |
| Too few results | `entity_sql` filters too aggressively | Broaden the WHERE clause in `entity_sql` |
| All NULL predictions | Entity IDs do not match any graph data | Ensure entity IDs exist in the graph's source data |
| Wrong time window | Predicting too far out or wrong direction | Verify `(start, end, unit)` matches intent: 0=now, future is positive |
| Wrong filter placement | Filter inside AGG vs top-level WHERE | Filters inside aggregation apply to target rows. Top-level WHERE applies to entity rows. |
| anchor_time issues | Results are stale or nonsensical | Check that `anchor_time` is set correctly. Default is current time. |
| Unexpected aggregation values | SUM looks like COUNT, or vice versa | Confirm the aggregation function matches the business question |

**Action:** Examine `entity_sql`, time windows, and filter placement. Run `entity_sql` independently to verify it returns expected rows.

**Debugging strategy for unexpected results:**

```python
# Step 1: Run entity_sql alone to verify it returns the right IDs
result = session.sql(entity_sql).collect()
print(f"Entity count: {len(result)}")
print(result[:5])

# Step 2: Verify those IDs exist in the graph source data
source_ids = session.sql("SELECT DISTINCT user_id FROM users").collect()
overlap = set(r[0] for r in result) & set(r[0] for r in source_ids)
print(f"Matching IDs: {len(overlap)} / {len(result)}")

# Step 3: Re-run with a known-good entity to isolate the issue
test_sql = "SELECT 'KNOWN_GOOD_ID' AS USER_ID"
```

---

## Quick Fixes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `unexpected token 'FOR'` | Missing aggregation parentheses | Wrap aggregation arguments in `()` |
| `table 'X' not found` | Misspelled table name | Check `print_metadata()` for exact names |
| `column 'X' not found in table 'Y'` | Wrong column name or wrong table | Verify with `column_dict` or `EXPLAIN_PQL` |
| `entity column must be a primary key` | FOR EACH uses a non-PK column | Change to the table's actual PK column |
| `invalid time range` | Start >= end or negative values | Use `(0, N, days)` with 0 <= start < end |
| `cannot apply SUM to categorical` | Aggregation/stype mismatch | Use COUNT or MODE for categorical columns |
| `no path between tables` | Missing FK link in graph | Add edge with `graph.link()` or reconstruct graph |
| `ASSUMING requires temporal aggregation` | Used ASSUMING with a static prediction | Add time range to the aggregation |
| All predictions are NULL | Entity IDs not in source data | Check that `entity_sql` returns IDs present in the graph |
| Empty result set | `entity_sql` returns no rows | Run `entity_sql` alone to debug the SQL query |
| Prediction values seem inverted | Time window direction confusion | `(0, 30, days)` means next 30 days from anchor, not past |
| `ambiguous link between tables` | Multiple FK paths exist | Simplify graph or specify exact relationship |

---

## Error Message Reference

| Error Message | Category | Fix |
|---------------|----------|-----|
| `ParseError: unexpected token` | Syntax | Check query structure against PQL syntax reference |
| `ValidationError: table not found` | Reference | Verify table name in graph metadata |
| `ValidationError: column not found` | Reference | Verify column name in table schema |
| `ValidationError: entity must be primary key` | Reference | Use a PK column in FOR EACH |
| `ValidationError: incompatible stype for aggregation` | Type | Match aggregation to column stype |
| `ValidationError: time range invalid` | Time | Ensure 0 <= start < end |
| `ValidationError: no path between X and Y` | Relationship | Add missing edge to graph |
| `ValidationError: ambiguous path` | Relationship | Remove duplicate edges or specify path |
| `ExecutionError: unsupported operation` | Unsupported | Use SQL workaround |
| `ExecutionError: anchor_time format invalid` | Time | Use ISO 8601 datetime format |
| `ExecutionError: ASSUMING on static column` | Unsupported | Add temporal aggregation to use ASSUMING |
| `RuntimeError: timeout` | Infrastructure | Reduce entity count or simplify query |

---

## Aggregation-Stype Compatibility

Use this table to quickly check whether your aggregation function is valid for the target column:

| Aggregation | `numerical` | `categorical` | `timestamp` | `text` | `id` |
|-------------|:-----------:|:--------------:|:-----------:|:------:|:----:|
| SUM | Yes | No | No | No | No |
| AVG | Yes | No | No | No | No |
| MIN | Yes | No | No | No | No |
| MAX | Yes | No | No | No | No |
| COUNT | Yes | Yes | No | No | No |

> **Note:** `MODE` is not a valid PQL aggregation. The authoritative source for
> PQL syntax is the `kumo-pql` parser grammar (`PQLGrammar.g4`).

If your aggregation is invalid for the column stype, either:
- Switch to a compatible aggregation (e.g., COUNT instead of SUM for categorical)
- Use a different target column that has the right stype
- Pre-process with SQL to derive a numerical column from categorical data

---

## Checklist

- [ ] Error message read and categorized (syntax, reference, type, time, relationship, unsupported)
- [ ] Schema verified (all referenced tables and columns exist in graph)
- [ ] Column types verified (stype matches the aggregation function used)
- [ ] Time window is valid (0 <= start < end, correct unit)
- [ ] FK path is direct (1-hop between entity table and target table)
- [ ] Aggregation matches column type (numerical for SUM/AVG/MIN/MAX, any for COUNT)
- [ ] ASSUMING clause uses temporal aggregation (if present)
- [ ] Entity column in FOR EACH is a primary key
- [ ] `entity_sql` returns expected rows (run independently to verify)
- [ ] Query runs successfully after applying fix
