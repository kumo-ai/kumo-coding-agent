# Build a Graph

Construct a validated graph from relational data -- the foundation for all Kumo predictions. This skill walks through connecting to data, inspecting schemas, defining tables and edges, and validating the resulting graph.

---

## Prerequisites

- Data accessible from a supported source (local files, Snowflake, S3, Databricks, BigQuery)
- Know your table relationships (which columns are primary keys, which are foreign keys)
- **Read first**: `context/platform/graph-construction.md`

## Workflow

### Step 1: Choose Your Path

Select the right approach based on your data source and use case:

| Scenario | API Path | Entry Point |
|----------|----------|-------------|
| Zero-shot RFM + local DataFrames | RFM | `rfm.Graph.from_data()` |
| Zero-shot RFM + Snowflake tables | RFM | `rfm.Graph.from_snowflake()` |
| Zero-shot RFM + Snowflake semantic view | RFM | `rfm.Graph.from_snowflake_semantic_view()` |
| Enterprise training + any connector | SDK | `kumoai.Graph()` with explicit tables and edges |

**When to use RFM vs SDK:**
- **RFM**: Fast zero-shot predictions, no training required, automatic schema inference
- **SDK**: Custom training, fine-grained control over metadata, production pipelines

### Step 2: Connect to Data

**RFM path -- local DataFrames:**

```python
import kumoai.experimental.rfm as rfm

graph = rfm.Graph.from_data({
    "users": users_df,
    "orders": orders_df,
    "products": products_df,
})
```

**RFM path -- Snowflake:**

```python
graph = rfm.Graph.from_snowflake(
    account="your_account", user="your_user", password="your_password",
    database="MY_DB", schema="MY_SCHEMA", warehouse="MY_WH",
    table_names=["USERS", "ORDERS", "PRODUCTS"],
)
```

**RFM path -- Snowflake semantic view:**

```python
graph = rfm.Graph.from_snowflake_semantic_view(
    account="your_account", user="your_user", password="your_password",
    semantic_view="MY_DB.MY_SCHEMA.MY_SEMANTIC_VIEW", warehouse="MY_WH",
)
```

**SDK path -- using connectors:**

```python
import kumoai
kumoai.init(url="https://api.kumo.ai", api_key="your_api_key")
connector = kumoai.S3Connector("s3://bucket/data/")
print(connector.table_names())
```

| Connector Type | Constructor | Notes |
|---------------|-------------|-------|
| `S3Connector` | `kumoai.S3Connector("s3://...")` | Parquet/CSV files |
| `SnowflakeConnector` | `kumoai.SnowflakeConnector(...)` | Direct Snowflake tables |
| `DatabricksConnector` | `kumoai.DatabricksConnector(...)` | Unity Catalog tables |
| `BigQueryConnector` | `kumoai.BigQueryConnector(...)` | BigQuery datasets |
| `RedshiftConnector` | `kumoai.RedshiftConnector(...)` | Redshift tables |
| `LocalConnector` | `kumoai.LocalConnector("path/")` | Local file directory |

### Step 3: Inspect Schemas

**CRITICAL: Never skip this step.** Incorrect metadata causes silent failures downstream.

**RFM path:**

```python
graph.print_metadata()
graph.print_links()
```

Review the output for each table:
- Column names and inferred dtypes/stypes
- Which column is identified as the primary key
- Which column is identified as the time column
- Inferred foreign key links between tables

**Multiple datetime columns:** When a table has more than one datetime column,
`infer_metadata()` picks one heuristically (prefers columns named `create*`,
then the column with the oldest timestamps). This may not be correct.

**Ask the user:** "Table X has datetime columns [col_a, col_b, col_c]. Which
one represents when each row was created or when the event occurred?"

To override the inferred time column:
```python
graph["orders"].time_column = "order_date"  # RFM
# SDK: specify time_column in Table.from_source_table()
```

**SDK path:**

```python
source_table = connector["users"]
print(source_table.column_dict)
# Output: {'user_id': 'int64', 'name': 'string', 'created_at': 'datetime64[ns]'}
```

**What to look for:**
- Primary key column exists and is unique per row
- Foreign key columns reference valid primary keys in other tables
- Time columns are actual timestamps (not strings or integers)
- No unexpected NULL-heavy columns that could cause issues

### Step 4: Define Tables (SDK Path Only)

For the SDK path, you must explicitly create Table objects:

```python
users_table = kumoai.Table.from_source_table(
    source_table=connector["users"],
    primary_key="user_id",
).infer_metadata()

orders_table = kumoai.Table.from_source_table(
    source_table=connector["orders"],
    primary_key="order_id",
    time_column="order_date",
).infer_metadata()

users_table.validate()
orders_table.validate()
```

**Dtype and Stype reference:**

| Dtype | Description | Example |
|-------|-------------|---------|
| `int` | Integer values | IDs, counts |
| `float` | Floating-point values | Prices, scores |
| `str` | String/text values | Names, categories |
| `datetime` | Timestamp values | Created dates, event times |
| `bool` | Boolean values | Flags, binary indicators |

| Stype | Description | Predictable? | Use With |
|-------|-------------|-------------|----------|
| `numerical` | Continuous numeric | Yes | SUM, AVG, MIN, MAX |
| `categorical` | Discrete categories | Yes | COUNT, MODE |
| `timestamp` | Time values | No | Time columns only |
| `text` | Free-form text | No | Not directly usable |
| `id` | Unique identifiers | No | PK/FK columns |
| `multicategorical` | Multiple categories | No | Specialized use |

**Key rules:**
- PK and FK columns must have compatible types. If one is `int` and the other is `str`, cast both to `str` before graph construction.
- Time columns must have `datetime` dtype. Integer Unix timestamps must be converted.
- Only `numerical` and `categorical` stypes are predictable targets.

### Step 5: Define Edges

**RFM path -- automatic inference:**

```python
graph.infer_links()
graph.print_links()
```

Review the inferred links. If any are incorrect or missing:

```python
# Add a missing link
graph.link("orders", "user_id", "users")

# Remove an incorrect link (re-create graph without it)
```

**SDK path -- explicit edge definition:**

```python
graph = kumoai.Graph(
    tables={
        "users": users_table,
        "orders": orders_table,
        "products": products_table,
    },
    edges=[
        kumoai.Edge("orders", "users", keys=("user_id", "user_id")),
        kumoai.Edge("orders", "products", keys=("product_id", "product_id")),
    ],
)
```

**Edge semantics:**
- Edges are defined as `src_table.fkey -> dst_table.pkey` (bidirectional for message passing)
- The FK column must exist in the source table; the PK column must exist in the destination table
- Self-referential edges (same table) are supported (e.g., user referrals)

### Step 6: Validate

**RFM path:**

```python
graph.validate()
graph.print_metadata()
graph.print_links()
```

**Visualize the graph (recommended in notebooks):**

```python
# Auto-detects Jupyter/Colab and renders ER diagram inline
graph.visualize()

# Mermaid backend (no system dependencies, needs mermaid-py):
graph.visualize(backend="mermaid")

# Save to file:
graph.visualize(path="graph.png")

# Less clutter for large schemas — show only PKs, FKs, and time columns:
graph.visualize(show_columns=False)
```

`visualize()` supports backends `'auto'`, `'graphviz'`, and `'mermaid'`.
Requires either `graphviz` (system package + Python binding) or `mermaid-py`.

**SDK path:**

```python
graph.validate()
snapshot = graph.snapshot()
edge_stats = graph.get_edge_stats()
print(edge_stats)
```

**Validation checklist -- verify all of the following:**
- Every table has a primary key column
- FK columns have matching dtypes to their referenced PK columns
- Time columns are correctly identified (datetime dtype)
- All expected links appear in the graph
- Links are semantically correct (the FK actually references that PK)
- No orphan tables (tables with no edges, unless intended)
- Edge stats show reasonable join ratios (no unexpected 0-match edges)

### Step 7: Repair If Needed

**Missing links:**

```python
# RFM
graph.link("orders", "user_id", "users")

# SDK: add the edge to the Graph constructor and recreate
```

**Wrong time column:**

```python
# RFM: set after inference
graph["orders"].time_column = "order_date"

# SDK: specify in Table constructor
orders_table = kumoai.Table.from_source_table(
    source_table=connector["orders"],
    primary_key="order_id",
    time_column="order_date",  # correct column
).infer_metadata()
```

**Type mismatch on FK/PK:**

```python
# Cast both columns to string before building the graph
users_df["user_id"] = users_df["user_id"].astype(str)
orders_df["user_id"] = orders_df["user_id"].astype(str)
```

**Ambiguous links:**
When two tables share multiple possible FK relationships, ask the user which relationship is semantically correct. Do not guess -- incorrect links produce incorrect predictions.

---

## Quick Reference: Methods

| RFM Method | SDK Equivalent | Purpose |
|-----------|----------------|---------|
| `Graph.from_data()` | `kumoai.Graph()` | Create graph |
| `Graph.from_snowflake()` | `SnowflakeConnector` + `Graph()` | Connect to Snowflake |
| `Graph.from_snowflake_semantic_view()` | N/A | Build from semantic view |
| `graph.infer_links()` | Explicit `Edge()` list | Define relationships |
| `graph.link()` | Add `Edge()` to constructor | Add single relationship |
| `graph.print_metadata()` | `source_table.column_dict` | Inspect schema |
| `graph.print_links()` | `graph.get_edge_stats()` | Inspect relationships |
| `graph.validate()` | `graph.validate()` | Validate graph |
| N/A | `graph.snapshot()` | Materialize for training |
| N/A | `table.infer_metadata()` | Auto-detect dtypes/stypes |

## Quick Reference: Dtype and Stype

| Dtype | Compatible Stypes | Notes |
|-------|-------------------|-------|
| `int` | `numerical`, `categorical`, `id` | Use `id` for PK/FK |
| `float` | `numerical` | Always numerical |
| `str` | `categorical`, `text`, `id`, `multicategorical` | Check cardinality |
| `datetime` | `timestamp` | Required for time columns |
| `bool` | `categorical` | Treated as binary category |

| Stype | Valid Aggregations | Can Be Target? |
|-------|-------------------|----------------|
| `numerical` | SUM, AVG, MIN, MAX, COUNT | Yes |
| `categorical` | COUNT, MODE | Yes |
| `timestamp` | None (used for temporal ordering) | No |
| `text` | None | No |
| `id` | None (used for PK/FK matching) | No |

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Primary key column not found` | PK column name misspelled or missing | Check `column_dict` and correct the column name |
| `Foreign key column not found in source table` | FK column does not exist in the specified table | Verify column name with `print_metadata()` |
| `Incompatible dtype for FK/PK join` | PK is `int` but FK is `str` (or vice versa) | Cast both columns to the same type (prefer `str`) |
| `Time column has non-datetime dtype` | Time column stored as `int` or `str` | Convert to proper datetime before graph construction |
| `Composite primary key not supported` | Table uses multi-column PK | Create a synthetic single-column PK (concatenate columns) |
| `Unsupported dtype detected` | Column has complex/nested type | Drop the column or convert to a supported dtype |
| `No links inferred` | Tables share no obvious FK relationships | Manually specify links with `graph.link()` or `Edge()` |
| `Duplicate primary key values` | PK column is not unique | Deduplicate the table or choose a different PK column |

---

## Checklist

- [ ] Data source connected and tables accessible
- [ ] All table schemas inspected (`print_metadata()` or `column_dict`)
- [ ] Primary keys identified and validated (unique, correct dtype)
- [ ] Foreign key relationships verified (columns exist, dtypes match)
- [ ] Time columns confirmed (datetime dtype, semantically correct)
- [ ] Graph validated successfully (`graph.validate()` passes)
- [ ] Links reviewed for semantic correctness
- [ ] Edge stats checked (SDK path: after `snapshot()`)
