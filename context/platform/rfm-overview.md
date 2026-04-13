# KumoRFM -- Zero-Shot Predictions on Relational Data

> Source: kumo-sdk (kumo-rfm-skill) + kumoai v2.16.3 API | Last synced: 2026-03-31

## Overview

Read this document when you need to make **instant, zero-shot predictions**
on relational data using KumoRFM. RFM (Relational Foundation Model) lets you
express a prediction task in PQL (Predictive Query Language), point it at a
relational graph, and get results without any model training.

**Package**: `kumoai.experimental.rfm` (requires `kumoai>=2.16.3`)

Typical workflow:
1. Build a `Graph` from local DataFrames, Snowflake tables, or a Semantic View.
2. Validate the graph (metadata, links, schema).
3. Write a PQL query describing the prediction.
4. Call `model.predict()` or `model.evaluate()`.

---

## How RFM Works

KumoRFM is a **Relational Foundation Model** — a large pre-trained graph
transformer that makes predictions on relational data without task-specific
training.

**Key concepts:**

- **Graph transformer**: RFM treats your relational database as a graph (tables
  are node types, foreign keys are edges). It uses a transformer architecture
  that operates on this graph structure, attending to neighboring rows across
  tables to build contextual representations.

- **In-context learning**: Instead of training on your data, RFM constructs
  in-context examples from historical data (similar to few-shot prompting in
  LLMs). The `run_mode` parameter controls how many examples are used:
  `fast` (~1K), `normal` (~5K), `best` (~10K).

- **Graph sampling**: For each entity being predicted, RFM samples a local
  neighborhood from the graph (controlled by `num_neighbors`). This subgraph
  provides the relational context the model uses for prediction.

- **Zero-shot generalization**: Because RFM is pre-trained on diverse relational
  schemas, it can make predictions on new datasets and new tasks without any
  fine-tuning. The PQL query tells it WHAT to predict; the graph provides the data.

**Supported use cases**: Churn prediction, demand forecasting, fraud detection,
customer lifetime value, lead scoring, recommendation, and any task expressible
as a PQL query on relational data. See `context/patterns/prediction-patterns.md`
for the full catalog.

---

## Graph Construction

There are four paths to build an RFM graph. Every path produces the same
`rfm.Graph` object.

### Path 1 -- Local pandas DataFrames

```python
import kumoai.experimental.rfm as rfm

graph = rfm.Graph.from_data({
    "users": users_df,
    "orders": orders_df,
    "items": items_df,
})
```

### Path 2 -- Snowflake tables (no Semantic View)

```python
graph = rfm.Graph.from_snowflake(
    connection=connection,
    database="MY_DATABASE",
    schema="MY_SCHEMA",
    tables=["USERS", "ORDERS", "ITEMS"],
)
```

### Path 3 -- Snowflake Semantic View

```python
graph = rfm.Graph.from_snowflake_semantic_view(
    semantic_view_name="MY_SCHEMA.MY_SEMANTIC_VIEW",
    connection=connection,
)
```

Caveats: composite primary keys not fully supported; some cross-table
expressions may be dropped.

### Path 4 -- Manual SnowTable construction

For finer control over database/schema per table:

```python
from kumoai.experimental.rfm.backend.snow import SnowTable

graph = rfm.Graph(
    tables=[
        SnowTable(connection, name="USERS", database="MY_DB", schema="MY_SCHEMA"),
        SnowTable(connection, name="ORDERS", database="MY_DB", schema="MY_SCHEMA"),
    ],
    edges=[],
)
graph.infer_metadata()
graph.infer_links()
```

---

## Graph Validation

Always inspect before querying:

```python
graph.print_metadata()   # High-level table/column summary
graph.print_links()      # FK -> PK edges

for table in graph.tables.values():
    table.print_metadata()   # Per-table column detail

graph.validate()  # Raises on structural errors
```

**What to verify:**
- All relevant tables are present and columns are correct.
- The entity table exists and its entity key is a real PK/ID column.
- Each table has the correct inferred time column (if temporal).
- Links support the requested prediction path.
- Inferred links are semantically correct, not just name-matched.

**Graph rules:**
- All tables must use the same backend (all pandas or all Snowflake).
- PK/FK dtypes must be compatible.
- A FK column cannot be the same as the source table's PK.

---

## Missing or Ambiguous Links

If `infer_links()` misses or misidentifies a relationship:

1. Inspect metadata with `graph.print_links()`.
2. Inspect columns on all tables.
3. Identify plausible FK -> PK pairs.
4. Add confident missing links manually.
5. If ambiguous, ask the user.

**Manual repair:**

```python
graph.link(src_table="ORDERS", fkey="USER_ID", dst_table="USERS")
graph.print_links()
graph.validate()
```

---

## NL2PQL Rules

### Task Families

| Family | Description |
|--------|-------------|
| Static classification | Predict a categorical column value |
| Static regression | Predict a numeric column value |
| Temporal binary classification | Will event X happen in window? |
| Temporal regression | How much / how many in window? |
| Forecasting | Predict values across future periods |
| Ranking / temporal link prediction | Which items are most likely? |

### Entity Anchoring

Identify: **who** is the entity, which **table** and **PK** column, and whether
explicit IDs are given or the query is for all entities.

Entity styles:

```sql
FOR users.user_id = 42              -- single entity
FOR users.user_id IN (42, 123)      -- explicit set
FOR EACH users.user_id              -- all entities
```

### Static vs Temporal Targets

**Static queries** predict a column value directly — no time window, no
aggregation. The target table does NOT need a time column.
Use for: "What category is X?", "What is the value of X?"

```sql
PREDICT INSURANCE_POLICIES.LOSS_RATIO FOR INSURANCE_POLICIES.POLICY_ID = 'POL-1'
```

**Temporal queries** predict an aggregation over a future time window using
`SUM/COUNT/AVG/MIN/MAX(..., start, end, unit)`. The target table MUST have a
time column. Use for: "Will X happen in next N days?", "How much X in N days?"

```sql
PREDICT SUM(CLAIMS.PAID_AMOUNT, 0, 90, DAYS) FOR INSURANCE_POLICIES.POLICY_ID = 'POL-1'
```

**Key difference**: temporal queries look forward in time and require a time
column; static queries predict the current state of an attribute.

### Target Mapping

| User language | PQL pattern |
|---------------|-------------|
| "will / any / no / likely" | Boolean condition on aggregation |
| "how much / how many / total / expected amount" | Raw aggregation |
| "what status / class / category / value" | Direct column prediction |
| "which items / likely related IDs" | Ranking / temporal link prediction |
| "forecast next N periods" | Forecasting |

### Filter Placement

- **Inside AGG ... WHERE** = what counts toward the target.
- **Top-level WHERE** = who gets scored.

### Counterfactuals

Use `ASSUMING` only for true "what if" requests.

### Time Semantics

| Natural language | PQL window |
|------------------|------------|
| next 7 days | `(0, 7, DAYS)` |
| next 30 days | `(0, 30, DAYS)` |
| next quarter | `(0, 90, DAYS)` |
| next 6 months | `(0, 180, DAYS)` |

Use non-overlapping windows for forecasting tasks.

**SDK time rules:**
- `anchor_time=None` -- derived from latest relevant timestamp.
- `anchor_time="entity"` -- only valid for static queries with entity time column.

---

## Compact Pattern Catalog

### Static classification
```sql
PREDICT TABLE.COLUMN FOR TABLE.PK = 'ID'
```

### Static regression
```sql
PREDICT TABLE.NUMERIC_COLUMN FOR TABLE.PK = 'ID'
```

### Temporal binary
```sql
PREDICT COUNT(EVENTS.*, 0, N, DAYS) > 0 FOR ENTITY.PK = 'ID'
```

### Temporal regression
```sql
PREDICT SUM(EVENTS.AMOUNT, 0, N, DAYS) FOR ENTITY.PK = 'ID'
```

### Filtered temporal
```sql
PREDICT SUM(TABLE.VALUE WHERE TABLE.DIMENSION = 'VALUE', 0, N, DAYS) FOR ENTITY.PK = 'ID'
```

### Forecasting
Supported as a distinct task type, generally one entity at prediction time.

### Ranking / link prediction
Supported when schema relationships and target ID columns make it valid.

### When to refuse

Refuse when:
- Clustering without a target.
- Anomaly detection without a target.
- Required columns are missing from the graph.
- The relationship path is unsupported by the graph links.

---

## KumoRFM API Reference

### Initialization

```python
model = rfm.KumoRFM(graph, verbose=True)
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `graph` | `Graph` | required | The relational graph to predict on |
| `verbose` | `bool` | `True` | Enable progress logging |
| `optimize` | `bool` | `False` | Optimize data backend for querying (requires write access) |

### `model.predict()` — Zero-Shot Prediction

```python
pred_df = model.predict(
    query="PREDICT SUM(orders.amount, 0, 30, DAYS) FOR users.user_id IN (42, 123)",
    indices=None,
    explain=False,
    anchor_time=None,
    context_anchor_time=None,
    run_mode="fast",
    num_neighbors=None,
    num_hops=2,
    max_pq_iterations=10,
    random_seed=42,
    use_prediction_time=False,
    lag_timesteps=0,
    inference_config=None,
)
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `query` | `str` | required | PQL query string |
| `indices` | `list[str\|int\|float]` | `None` | Entity PKs to predict for. Overrides entities in the query. |
| `explain` | `bool \| ExplainConfig` | `False` | Enable explainability. **Single entity + FAST mode only.** |
| `anchor_time` | `pd.Timestamp \| "entity" \| None` | `None` | Prediction anchor. `None` = latest timestamp in graph. `"entity"` = per-entity timestamp from entity table's time column. |
| `context_anchor_time` | `pd.Timestamp \| None` | `None` | Max anchor time for in-context learning examples. `None` = derived from `anchor_time`. |
| `run_mode` | `str` | `"fast"` | `"fast"` (~1K examples), `"normal"` (~5K), `"best"` (~10K). |
| `num_neighbors` | `list[int] \| None` | `None` | Per-hop neighbor sampling. e.g. `[8, 8]` = 8 neighbors per hop for 2 hops. Controls context window size. |
| `num_hops` | `int` | `2` | **Deprecated.** Use `num_neighbors` instead. Ignored if `num_neighbors` is set. |
| `max_pq_iterations` | `int` | `10` | Max iterations to find valid training labels. Increase (e.g. 200) for queries with strict filters. |
| `random_seed` | `int \| None` | `42` | Seed for reproducibility. `None` = non-deterministic. |
| `use_prediction_time` | `bool` | `False` | Use anchor timestamp as a model feature. Enable for **time-series forecasting** where prediction time matters. |
| `lag_timesteps` | `int` | `0` | Number of past timesteps included as lagged features. Use for autoregressive tasks where recent target values improve prediction. **Requires `kumoai>=2.18.0`.** |
| `inference_config` | `InferenceConfig \| dict \| None` | `None` | Inference configuration (from `kumoapi.rfm`). Includes `RegressionInferenceConfig` and `ClassificationInferenceConfig` for task-specific settings. |

**Returns**: `pd.DataFrame`. Columns depend on task type:
- Binary classification: `ENTITY`, `ANCHOR_TIMESTAMP`, `TARGET_PRED`, `True_PROB`, `False_PROB`
- Regression / forecasting: `ENTITY`, `ANCHOR_TIMESTAMP`, `TARGET_PRED`
- Multiclass classification: `ENTITY`, `ANCHOR_TIMESTAMP`, `CLASS`, `SCORE`, `PREDICTED` (one row per class per entity)

**Examples:**

```python
# indices is REQUIRED for FOR EACH queries (SDK cannot enumerate all entities)
pred_df = model.predict(query, indices=[42, 123, 456], run_mode="fast")

# For single-entity queries (FOR table.pk = 42), indices is optional
pred_df = model.predict(single_entity_query, run_mode="fast")

# With custom anchor time
pred_df = model.predict(query, anchor_time=pd.Timestamp("2025-01-01"), run_mode="normal")

# Per-entity timestamps (each entity uses its own time column value)
pred_df = model.predict(query, anchor_time="entity", run_mode="fast")

# Forecasting with prediction-time feature
pred_df = model.predict(query, use_prediction_time=True, run_mode="best")

# Control graph neighborhood sampling
pred_df = model.predict(query, num_neighbors=[8, 8], run_mode="fast")
```

### `model.evaluate()` — Zero-Shot Evaluation

**Note:** `model.evaluate()` creates its own internal train/test split. For
benchmarking against published results, predict on the official held-out
test set and compute metrics manually (see `skills/rfm-predict.md` Step 6).

Same parameters as `predict()` except no `indices` or `explain`, plus `metrics`:

```python
metrics_df = model.evaluate(
    query="PREDICT COUNT(orders.*, 0, 30, DAYS) > 0 FOR EACH users.user_id",
    metrics=None,              # e.g. ["auroc", "f1", "mae", "rmse", "r2"]
    run_mode="fast",
    anchor_time=None,
    num_neighbors=None,
    max_pq_iterations=10,
    use_prediction_time=False,
    lag_timesteps=0,
    inference_config=None,
)
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `metrics` | `list[str] \| None` | `None` | Specific metrics to compute. `None` = task-appropriate defaults. |

Available metrics: `auroc`, `auprc`, `ap`, `f1`, `acc`, `precision`, `recall` (binary classification); `acc`, `precision`, `recall`, `f1`, `mrr` (multiclass); `mae`, `mape`, `mse`, `rmse`, `smape`, `r2` (regression/forecasting); `map@K`, `ndcg@K`, `mrr@K`, `precision@K`, `recall@K`, `f1@K`, `hit_ratio@K` (link prediction).

### `model.batch_mode()` — Large-Scale Predictions

Context manager for predicting on large entity sets. Use when passing
hundreds or thousands of entity IDs via `indices` — without batch mode,
large requests may exceed server limits or time out. The context manager
splits the request into batches, sends them sequentially, retries failures,
and concatenates results into a single DataFrame.

```python
with model.batch_mode(batch_size="max", num_retries=1):
    pred_df = model.predict(
        query=query,
        indices=list(range(10000)),
        run_mode="best",
        anchor_time="entity",
    )
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `batch_size` | `int \| "max"` | `"max"` | Entities per batch. `"max"` = auto-determined optimal size. |
| `num_retries` | `int` | `1` | Retry count per failed batch. |

### `model.get_train_table()` — Debug Training Labels

Inspect what training labels the model sees for a query. Use this to debug unexpected predictions.

```python
labels_df = model.get_train_table(
    query=query,
    size=500,
    anchor_time=pd.Timestamp("2025-01-01"),
    max_iterations=200,
)
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `query` | `str` | required | PQL query |
| `size` | `int` | required | Number of training examples to generate |
| `anchor_time` | `pd.Timestamp \| "entity" \| None` | `None` | Anchor time for label generation |
| `max_iterations` | `int` | `10` | Max search iterations for valid labels |
| `random_seed` | `int \| None` | `42` | Seed for reproducibility |

Returns a `DataFrame` with `ENTITY`, `TARGET` (ground-truth label), and context columns.

### Explainability

```python
result = model.predict(query, explain=True, run_mode="fast")
# OR with config:
result = model.predict(query, explain=rfm.ExplainConfig(skip_summary=True), run_mode="fast")
```

**Constraints:**
- Only works for **single entity** predictions (one ID in query or one index).
- Only works with `run_mode="fast"`. If NORMAL/BEST is specified, auto-downgrades to FAST with a warning.

**`ExplainConfig` parameters:**

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `skip_summary` | `bool` | `False` | Skip NL summary generation (faster). |

**Return type:** `Explanation` dataclass:
- `.prediction` — `pd.DataFrame` with the prediction result.
- `.summary` — Natural language explanation string.
- `.details` — Structured explanation:
  - `.task_type` — e.g. `"binary_classification"`, `"regression"`.
  - `.cohorts` — Global feature importance. Each cohort has: `table_name`, `column_name`, `hop`, `stype`, `cohorts` (value ranges), `populations` (proportions), `targets` (average prediction per cohort).
  - `.subgraphs` — Local attribution. Each subgraph has: `seed_id`, `seed_table`, `seed_time`, `tables` (dict of nodes with `.cells[col].value` and `.cells[col].score` attribution).

### TaskTable Flow

Use `TaskTable` when you already have explicit context (training) and
prediction rows prepared as DataFrames — for example, a custom train/test
split or a task that is easier to express as a DataFrame than as a PQL query.
For most use cases, prefer query-driven `model.predict()` instead.

```python
task = rfm.TaskTable(
    task_type=...,               # TaskType enum (e.g. binary classification, regression)
    context_df=context_df,       # DataFrame of labeled context (training) examples
    pred_df=pred_df,             # DataFrame of entities to predict for
    entity_table_name="users",   # Entity table in the graph
    entity_column="user_id",     # Column matching entity PKs
    target_column="target",      # Column with labels (in context_df) or to predict (in pred_df)
    time_column="anchor_time",   # Optional: column for per-row anchor timestamps
    step_size=None,              # Optional: step size for time-based operations
    num_forecasts=1,             # Optional: number of forecast steps (default 1)
)

pred_df = model.predict_task(task, run_mode="fast")
metrics_df = model.evaluate_task(task, run_mode="fast")  # Only works if pred_df contains target_column
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `task_type` | `TaskType` | required | Task type enum (binary classification, regression, etc.) |
| `context_df` | `pd.DataFrame` | required | Labeled examples the model uses as context |
| `pred_df` | `pd.DataFrame` | required | Rows to generate predictions for |
| `entity_table_name` | `str \| Sequence[str]` | required | Entity table name(s) in the graph. For link prediction, pass both entity and target table names. |
| `entity_column` | `str` | required | Column matching entity PKs in the graph |
| `target_column` | `str` | required | Label column in context_df; prediction target in pred_df |
| `time_column` | `str \| None` | `None` | Per-row anchor time column. If set, each row uses its own timestamp. |
| `step_size` | `int \| None` | `None` | Step size for time-based operations |
| `num_forecasts` | `int` | `1` | Number of forecast steps |

### Advanced Patterns

**Single-table workflow** (tabular data without relational structure):
```python
df = pd.DataFrame({"id": range(len(X)), "features": X_list, "target": y})
graph = rfm.Graph.from_data({"table": df})
model = rfm.KumoRFM(graph)
pred_df = model.predict("PREDICT table.target=1 FOR EACH table.id", run_mode="fast")
```

**Context table pattern** (custom train/test splits):
```python
context_table = rfm.LocalTable(context_df, name="context", primary_key="index")
graph.add_table(context_table)
graph.link("context", "entity_id", "main_table")
pred_df = model.predict("PREDICT context.target=1 FOR EACH context.index")
```

---

## Quick Reference

| Method | Key Parameters | Returns |
|--------|---------------|---------|
| `rfm.KumoRFM(graph)` | `verbose=True` | Model instance |
| `model.predict(query)` | `indices`, `run_mode`, `anchor_time`, `explain`, `num_neighbors`, `max_pq_iterations`, `use_prediction_time`, `lag_timesteps`, `inference_config` | `DataFrame` or `Explanation` |
| `model.evaluate(query)` | `metrics`, `run_mode`, `anchor_time`, `num_neighbors`, `max_pq_iterations`, `use_prediction_time`, `lag_timesteps`, `inference_config` | `DataFrame` of metrics |
| `model.batch_mode()` | `batch_size="max"`, `num_retries=1` | Context manager |
| `model.get_train_table(query)` | `size`, `anchor_time`, `max_iterations` | `DataFrame` of labels |
| `model.retry()` | `num_retries=1` | Context manager |
| `model.predict_task(task)` | `run_mode` | `DataFrame` |
| `model.evaluate_task(task)` | `run_mode` | `DataFrame` of metrics |
| `rfm.ExplainConfig()` | `skip_summary=False` | Config object |
| `rfm.Graph.from_data(dfs)` | `infer_metadata=True`, `verbose=True` | `Graph` |
| `rfm.Graph.from_sqlite(connection)` | `tables`, `edges`, `infer_metadata` | `Graph` |
| `rfm.Graph(tables, edges)` | — | `Graph` |
| `graph.link(src, fkey, dst)` | — | `self` |
| `graph.infer_links()` | `verbose=True` | `self` |
| `graph.validate()` | — | `self` |
| `graph.visualize()` | `show_columns=True`, `backend='auto'` | `None` |

### run_mode Reference

| Mode | In-Context Examples | Best For |
|------|-------------------|----------|
| `"fast"` | ~1,000 | Prototyping, iteration, explainability |
| `"normal"` | ~5,000 | Improved accuracy with moderate latency |
| `"best"` | ~10,000 | Maximum accuracy, production evaluation |

---

## Common Pitfalls

1. **Skipping validation.** Always call `graph.validate()` before querying.
   Structural errors surface here, not at prediction time.

2. **Trusting inferred links blindly.** `infer_links()` matches by column name,
   which can produce false joins. Always inspect with `print_links()`.

3. **Wrong time column.** If the graph picks the wrong timestamp, temporal
   predictions will be meaningless. Verify per-table metadata.

4. **Mismatched PK/FK dtypes.** An `INT` FK pointing at a `VARCHAR` PK will
   silently produce an empty join. Check dtype compatibility.

5. **Using `anchor_time="entity"` on temporal queries.** This is only valid for
   static queries where the entity table has a time column.

6. **Forgetting filter placement.** `WHERE` inside the aggregation filters
   *what counts*; top-level `WHERE` filters *who gets scored*. Swapping them
   changes the semantics entirely.

7. **Overlapping forecast windows.** Forecasting requires non-overlapping
   windows. Using `(0, 30, DAYS)` and `(15, 45, DAYS)` is invalid.

8. **Mixed backends.** All tables in a graph must use the same backend. You
   cannot mix pandas DataFrames with Snowflake tables.

9. **FK equals source PK.** A foreign key column cannot be the same column as
   the source table's primary key. This is a graph constraint violation.

10. **Requesting unsupported tasks.** Clustering, anomaly detection, and other
    tasks without a clear target column are not supported by RFM.
