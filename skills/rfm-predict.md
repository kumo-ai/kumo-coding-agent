# RFM Zero-Shot Prediction

Run instant predictions on relational data using KumoRFM — no model training required.

---

## Prerequisites

- `kumoai>=2.16.3` installed (`uv add kumoai` — see `context/platform/data-connectors.md` for full setup)
- API key set: `export KUMO_RFM_API_KEY=...` or pass to `rfm.init()`
- Data accessible: local DataFrames, Snowflake connection, or Snowflake
  Semantic View
- **Read first**: `context/platform/rfm-overview.md`

## Workflow

### Step 1: Initialize RFM

Import the RFM module and authenticate against the KumoRFM service.

```python
import kumoai
import kumoai.experimental.rfm as rfm

# Check SDK version (requires kumoai >= 2.16.3)
print(f"kumoai version: {kumoai.__version__}")
# If outdated: uv add kumoai --upgrade  (or: pip install --upgrade kumoai)

# Option A: Explicit API key
rfm.init(api_key="your-api-key", url="https://kumorfm.ai/api")

# Option B: Environment variable (KUMO_RFM_API_KEY)
rfm.init(url="https://kumorfm.ai/api")

# Option C: Colab — browser-based login (opens auth widget)
# rfm.authenticate()
```

Verify connectivity before proceeding:

```python
# A successful init returns without error.
# If the key is invalid you will see an AuthenticationError immediately.
```

### Step 2: Build Graph

Choose one of 5 paths based on where your data lives.

> **Memory guidance — read before choosing a path:**
>
> With `from_snowflake()` and `from_sqlite()`, the data **stays in the
> database**. The SDK generates in-context samples directly inside
> Snowflake/SQLite and only returns prediction results to Python — your
> notebook never holds the full dataset in memory.
>
> `from_data()` loads everything into pandas first, so the full dataset
> must fit in RAM. Only use it for small data or quick prototyping.
>
> **Choose your path based on data size:**
> - **Small data** (fits comfortably in RAM) → Option A (`from_data()`)
> - **Large data in Snowflake** → Option B/C (`from_snowflake()` or semantic view)
> - **Large local files** → Load into SQLite first, then use `from_sqlite()`
>
> **Before loading CSV/Parquet into pandas**, estimate whether it will fit:
> sample a few thousand rows, measure their memory usage, extrapolate to
> the full file, and compare against available RAM. If the estimated memory
> exceeds ~50% of available RAM, **do not load by default** — suggest a
> Snowflake or SQLite path instead. If the user explicitly asks to proceed
> anyway, load it with a warning.
>
> ```python
> import psutil
> print(f"Available RAM: {psutil.virtual_memory().available / 1e9:.1f} GB")
> ```

**Option A: Local DataFrames**

Best for quick prototyping with pandas DataFrames already in memory.

```python
import pandas as pd

users_df = pd.read_csv("users.csv")
orders_df = pd.read_csv("orders.csv")

graph = rfm.Graph.from_data({
    "users": users_df,
    "orders": orders_df,
})
```

**Option B: Snowflake (all tables in schema)**

Loads every table in the given schema. Good when the schema is clean and
purpose-built for prediction.

```python
graph = rfm.Graph.from_snowflake(
    connection=conn,
    database="MY_DATABASE",
    schema="MY_SCHEMA",
)
```

**Option C: Snowflake Semantic View**

Uses a pre-defined Semantic View that already specifies tables, columns,
relationships, and metadata. This is the recommended production path.

```python
graph = rfm.Graph.from_snowflake_semantic_view(
    semantic_view_name="MY_SCHEMA.MY_SEMANTIC_VIEW",
    connection=conn,
)
```

**Option D: Manual SnowTable (fine control)**

Use when you need to cherry-pick tables or override inferred metadata.

```python
from kumoai.experimental.rfm.backend.snow import SnowTable

users_table = SnowTable(
    conn, name="USERS", database="MY_DB", schema="MY_SCHEMA"
)
orders_table = SnowTable(
    conn, name="ORDERS", database="MY_DB", schema="MY_SCHEMA"
)

graph = rfm.Graph(
    tables=[users_table, orders_table],
    edges=[],
)
graph.infer_metadata()
graph.infer_links()
```

**Option E: Sample dataset (RelBench / SALT)**

For experimentation with a known dataset, download the data and load it
as DataFrames so you can inspect the schema before building the graph.
Do not use `from_relbench()` as a shortcut — it skips the data inspection
step.

```python
# Example: load SALT from HuggingFace
from datasets import load_dataset
ds = load_dataset("SAP/SALT")

# Convert to pandas DataFrames — inspect each table
for table_name in ds:
    df = ds[table_name].to_pandas()
    print(f"\n{table_name}: {len(df)} rows, columns: {list(df.columns)}")
    print(df.dtypes)
```

Then build the graph with `from_data()` (Option A) using the DataFrames.

- **RelBench** (Stanford benchmark): https://relbench.stanford.edu/start/
- **SALT** (SAP enterprise supply chain): https://huggingface.co/datasets/SAP/SALT

### Step 3: Validate Graph

Always inspect the graph before running predictions. A malformed graph is
the single most common source of errors.

```python
# Print full graph metadata
graph.print_metadata()

# Print inferred foreign-key links
graph.print_links()

# Inspect a single table
graph["orders"].print_metadata()
```

**What to verify:**

1. **Entity table exists** — the table you want predictions FOR EACH must
   be present in the graph.
2. **Primary keys are real IDs** — not row indices or surrogate keys that
   carry no semantic meaning.
3. **Time columns are correct** — temporal queries require a valid
   datetime/timestamp column on the target table. Confirm the column is
   detected as `time` type, not `string`.
4. **Links are semantically correct** — a foreign key from `orders.user_id`
   to `users.user_id` means "each order belongs to one user". If a link is
   wrong or missing, fix it manually.
5. **No duplicate or phantom tables** — schema imports can pick up views,
   staging tables, or system tables that do not belong in the graph.

**Fix incorrect or missing links:**

```python
# Remove an incorrect inferred link
graph.unlink("orders", "wrong_fk_column", "wrong_target")

# Add a correct link manually
graph.link("orders", "user_id", "users")
```

**Run validation:**

```python
graph.validate()
# Raises GraphValidationError with actionable messages on failure.
```

### Step 4: Write PQL Query

**Do not write the PQL query until you have inspected the actual data.**
Examine the DataFrames or source tables directly (`df.columns`, `df.dtypes`,
`df.head()`) to learn the real table names, column names, and primary keys.
Never rely solely on `print_metadata()` — always verify against the data
itself. Never guess or use placeholders.

Map the natural-language question to the correct PQL task family, then
write the query string.

| Question Pattern | Task Family | PQL Template |
|---|---|---|
| "Will X happen in next N days?" | Temporal binary classification | `PREDICT COUNT(target.col, 0, N, days) > 0 FOR EACH entity.pk` |
| "How many X in next N days?" | Temporal regression | `PREDICT COUNT(target.col, 0, N, days) FOR EACH entity.pk` |
| "What total X in next N days?" | Temporal regression | `PREDICT SUM(target.col, 0, N, days) FOR EACH entity.pk` |
| "What is the average X?" | Temporal regression | `PREDICT AVG(target.col, 0, N, days) FOR EACH entity.pk` |
| "What category is X?" | Static classification | `PREDICT entity.category_col FOR EACH entity.pk` |
| "What is the value of X?" | Static regression | `PREDICT entity.numeric_col FOR EACH entity.pk` |
| "Forecast X for the next N periods" | Forecasting | Use consecutive non-overlapping windows: `(0,7,days)`, `(7,14,days)`, etc. |
| "Which items will user interact with?" | Link prediction | `PREDICT LIST_DISTINCT(events.item_id, 0, N, days) FOR EACH users.user_id` (target column must be a FK) |
| "What if we change Z?" | What-if | Add `ASSUMING ...` clause to any temporal query |

**Pre-flight checks before running:**

- [ ] Aggregation column exists in the target table
- [ ] Time window values are non-negative integers
- [ ] FOR EACH column is a primary key of an entity table
- [ ] Foreign-key path from entity to target is exactly 1 hop
- [ ] No nested aggregations (e.g., `SUM(COUNT(...))` is invalid)
- [ ] ASSUMING clause wraps a temporal aggregation if present

Example query:

```python
query = (
    "PREDICT SUM(orders.amount, 0, 30, days) "
    "FOR EACH users.user_id"
)
```

### Step 5: Run Prediction

**Ask the user before running:**

| User goal | `run_mode` | In-context examples | Typical latency |
|-----------|-----------|-------------------|-----------------|
| Quick exploration, iteration | `"fast"` | ~1,000 | Seconds |
| Balanced accuracy | `"normal"` | ~5,000 | Minutes |
| Maximum accuracy / final evaluation | `"best"` | ~10,000 | Several minutes |

Default to `"fast"` for first-time predictions. Also ask: "Do you need
predictions for a small set of entities or a large batch?" — if large,
use `batch_mode()`.

```python
model = rfm.KumoRFM(graph)

# FOR EACH queries require indices — pass entity IDs explicitly
pred_df = model.predict(query, indices=entity_ids, run_mode="fast")
print(pred_df.head(10))
print(f"Rows returned: {len(pred_df)}")
```

**`indices` is required for `FOR EACH` queries.** The SDK cannot enumerate
all entities automatically — you must pass the list of entity IDs. Get them
from the source data (e.g., `df["user_id"].tolist()` for pandas, or
`SELECT DISTINCT pk FROM table` for Snowflake/SQLite). For single-entity
queries (`FOR table.pk = 42`), `indices` is optional.

The returned DataFrame contains columns: `ENTITY`, `ANCHOR_TIMESTAMP`,
`TARGET_PRED`, and class probabilities (e.g. `True_PROB`, `False_PROB`).

**Predict for a subset of entities:**

```python
pred_df = model.predict(query, indices=[101, 202, 303], run_mode="fast")
```

**Custom anchor time:**

```python
pred_df = model.predict(query, anchor_time=pd.Timestamp("2025-01-01"), run_mode="normal")
```

**Batch mode (for large entity sets):**

Use `batch_mode()` when predicting for hundreds+ entities — it splits the
request into batches, retries failures, and concatenates results automatically.

```python
with model.batch_mode(batch_size="max", num_retries=1):
    pred_df = model.predict(query, indices=all_ids, run_mode="fast")

# Per-entity timestamps: each entity uses its own time column value as anchor
with model.batch_mode(batch_size="max", num_retries=1):
    pred_df = model.predict(query, indices=all_ids, anchor_time="entity", run_mode="best")
```

**Control neighborhood sampling:**

```python
# Sample 8 neighbors per hop for 2 hops
pred_df = model.predict(query, num_neighbors=[8, 8], run_mode="fast")
```

**Forecasting with prediction-time feature:**

```python
pred_df = model.predict(query, use_prediction_time=True, run_mode="fast")
```

**Autoregressive lag features:**

```python
pred_df = model.predict(query, lag_timesteps=7, run_mode="fast")
```

**Increase label search for strict filters:**

```python
pred_df = model.predict(query, max_pq_iterations=200, run_mode="fast")
```

### Step 5b: Debug Training Labels (Optional)

Inspect what training examples the model sees — useful when predictions
seem wrong or evaluation is unexpectedly weak.

```python
labels_df = model.get_train_table(query, size=500)
print(labels_df.head(10))
print(f"Label distribution:\n{labels_df['TARGET'].value_counts()}")
```

### Step 6: Evaluate (Optional)

Run evaluation to get quality metrics. This performs an automatic
train/test split on historical data.

```python
metrics_df = model.evaluate(query, run_mode="fast")
print(metrics_df)

# Request specific metrics
metrics_df = model.evaluate(query, run_mode="fast", metrics=["auroc", "f1"])
```

Returned metrics depend on task type:

| Task Type | Key Metrics |
|---|---|
| Binary classification | `auroc`, `precision`, `recall`, `f1`, `acc` |
| Regression | `rmse`, `mae`, `r2` |
| Ranking | `mrr` |

Use evaluation results to decide whether the prediction is trustworthy
enough for downstream use. An AUC below 0.6 or R-squared below 0.1
usually indicates the signal is too weak.

### Step 7: Explain (Optional)

Generate feature-importance explanations alongside predictions.

**Constraints:** Explainability only works for **single entity** predictions
with `run_mode="fast"`. If NORMAL/BEST is specified, it auto-downgrades.

```python
# Single entity with explanation
result = model.predict(
    "PREDICT SUM(orders.amount, 0, 30, days) FOR users.user_id = 42",
    explain=True,
    run_mode="fast",
)

# result.prediction — DataFrame with the prediction
# result.summary — natural language explanation
# result.details — structured feature importance
print(result.prediction)
print(result.summary)

# Skip NL summary for faster results
result = model.predict(query_single, explain=rfm.ExplainConfig(skip_summary=True))
```

**Structured details** (for programmatic use):
- `result.details.cohorts` — global feature importance (which columns matter most)
- `result.details.subgraphs` — local attribution (which specific values drove this prediction)

### Step 8: Save State

Persist intermediate results to `scratch/` so you can resume without
re-running expensive operations.

```python
import pickle

pred_df.to_parquet("scratch/predictions_users_30d_spend.parquet")
metrics_df.to_csv("scratch/eval_users_30d_spend.csv", index=False)

with open("scratch/graph_ecom.pkl", "wb") as f:
    pickle.dump(graph, f)
```

## Quick Reference

| Method | Description | Key Arguments |
|---|---|---|
| `rfm.init()` | Authenticate with KumoRFM | `api_key`, `url` |
| `rfm.Graph.from_data()` | Build graph from DataFrames | `dict[str, DataFrame]` |
| `rfm.Graph.from_snowflake()` | Build graph from Snowflake schema | `connection`, `database`, `schema` |
| `rfm.Graph.from_snowflake_semantic_view()` | Build graph from Semantic View | `semantic_view_name`, `connection` |
| `graph.print_metadata()` | Display table/column metadata | — |
| `graph.print_links()` | Display foreign-key relationships | — |
| `graph.link()` | Add a foreign-key link | `src_table`, `fk_col`, `dst_table` |
| `graph.unlink()` | Remove a foreign-key link | `src_table`, `fk_col`, `dst_table` |
| `graph.validate()` | Check graph for errors | — |
| `rfm.KumoRFM(graph)` | Create model from graph | `graph`, `verbose` |
| `model.predict()` | Run zero-shot prediction | `query`, `indices`, `run_mode`, `anchor_time`, `explain`, `num_neighbors`, `max_pq_iterations`, `use_prediction_time`, `lag_timesteps`, `inference_config` |
| `model.evaluate()` | Evaluate prediction quality | `query`, `run_mode`, `metrics`, `anchor_time`, `num_neighbors`, `lag_timesteps`, `inference_config` |
| `model.batch_mode()` | Context manager for large batches | `batch_size="max"`, `num_retries=1` |
| `model.get_train_table()` | Debug training labels | `query`, `size`, `anchor_time`, `max_iterations` |
| `model.is_valid_entity()` | Check entity validity | `query`, `indices`, `anchor_time` |

## Common Errors

| Error | Cause | Fix |
|---|---|---|
| `AuthenticationError` | Invalid or expired API key | Regenerate key and re-run `rfm.init()` |
| `GraphValidationError: no primary key` | Table missing a detected PK | Set PK explicitly: `graph["table"].set_primary_key("col")` |
| `GraphValidationError: no time column` | Temporal query but target table has no datetime column | Verify column type or cast to timestamp before building graph |
| `QueryValidationError: column not found` | Typo in table or column name in PQL | Run `graph["table"].print_metadata()` to list valid columns |
| `QueryValidationError: multi-hop FK path` | Entity and target are more than 1 FK hop apart | Join tables in SQL first to create a direct relationship |
| `TimeoutError` | Large dataset with `run_mode="best"` | Switch to `run_mode="fast"` or filter entities |
| `ConnectionError: Snowflake` | Snowflake session expired or credentials wrong | Re-establish `conn` with fresh credentials |
| `ValueError: explain requires single entity` | Explainability with multiple entities | Use single entity ID in query or indices |
| `Context size exceeded (30MB limit)` | Too many tables/columns or large subgraphs | Reduce `num_neighbors`, remove tables/columns, or use `run_mode="fast"` |
| `BatchError` | Batch mode failure (OOM, timeout) | Reduce `batch_size` to a fixed int, increase `num_retries` |

## Checklist

- [ ] RFM initialized and authenticated
- [ ] Graph built from correct data source
- [ ] `graph.print_metadata()` reviewed — PKs, types, and time columns correct
- [ ] `graph.print_links()` reviewed — all FK relationships valid
- [ ] `graph.validate()` passes without errors
- [ ] PQL query written with correct aggregation, time window, and entity
- [ ] Pre-flight checks passed (no nested aggs, 1-hop FK, non-negative window)
- [ ] Prediction executed and output shape inspected
- [ ] Evaluation metrics reviewed (if applicable)
- [ ] Results saved to `scratch/` for reproducibility
