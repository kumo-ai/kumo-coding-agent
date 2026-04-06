# Graph Construction

> Source: kumo-sdk (kumo-rfm-skill, kumo-tune-skill) | Last synced: 2026-03-31

## Overview

Read this document when you need to build, validate, or repair a graph object
in either the RFM (zero-shot) or Enterprise SDK workflow. The **graph** is the
central abstraction in Kumo — it connects relational tables via foreign-key to
primary-key edges and tells the platform how to traverse relationships when
constructing features and training models.

---

## RFM Graphs (Zero-Shot)

RFM exposes four construction paths, from highest to lowest automation.

### From DataFrames

```python
import kumoai.experimental.rfm as rfm

graph = rfm.Graph.from_data({
    "users": users_df,
    "orders": orders_df,
    "products": products_df,
})
```

Infers PKs, FKs, column metadata, and edges automatically.

### From Snowflake (schema-level)

```python
graph = rfm.Graph.from_snowflake(
    connection=conn, database="ANALYTICS",
    schema="PUBLIC", tables=["USERS", "ORDERS", "PRODUCTS"],
)
```

Pass an explicit `tables` list to avoid pulling in every table in the schema.

### From Snowflake Semantic View

```python
graph = rfm.Graph.from_snowflake_semantic_view(
    semantic_view_name="ANALYTICS.PUBLIC.MY_SEMANTIC_VIEW",
    connection=conn,
)
```

### From SQLite

```python
import sqlite3
conn = sqlite3.connect("data.db")
graph = rfm.Graph.from_sqlite(
    connection=conn,
    tables=["users", "orders"],
)
```

### Manual Construction

```python
from kumoai.experimental.rfm.backend.snow import SnowTable

tables = [
    SnowTable(conn, name="USERS", database="DB", schema="SCH"),
    SnowTable(conn, name="ORDERS", database="DB", schema="SCH"),
]
graph = rfm.Graph(tables=tables, edges=[])
graph.infer_metadata()
graph.infer_links()
```

Use when tables span multiple schemas or automatic inference needs overrides.

---

## Enterprise SDK Graphs

The SDK gives explicit control over every table, column, and edge.

```python
import kumoai

source = kumoai.SnowflakeSourceTable(
    database="DB", schema="SCH", table="ORDERS", warehouse="WH",
)
table = kumoai.Table.from_source_table(source_table=source, primary_key="ORDER_ID")
table.infer_metadata()

graph = kumoai.Graph(
    tables={"users": users_table, "orders": orders_table, "products": products_table},
    edges=[
        kumoai.Edge("orders", "USER_ID", "users"),
        kumoai.Edge("orders", "PRODUCT_ID", "products"),
        # dict form also accepted: {"src": "orders", "fkey": "USER_ID", "dst": "users"}
    ],
)
```

---

## Tables and Columns

### Dtype vs Stype

Every column has two type descriptors:

| Concept | Description | Values |
|---------|-------------|--------|
| **dtype** | Physical storage type | `int`, `float`, `string`, `binary`, `date`, `time`, `timedelta`, `floatlist`, `intlist`, `stringlist` |
| **stype** | Semantic role | `ID`, `numerical`, `categorical`, `multicategorical`, `text`, `timestamp`, `sequence`, `image` |

The stype drives feature engineering — a `string` column with stype `ID` is
treated very differently from one with stype `text`.

### Column Objects (SDK)

```python
col = kumoai.Column(name="AMOUNT", stype="numerical", dtype="float")
```

### Key Requirements

- **Primary key**: Exactly one PK column per table (stype `ID`). Composite PKs
  are not fully supported in the RFM semantic view path.
- **Foreign key**: Must have dtype compatible with the target PK.
- **time_column**: Must be actual `datetime` dtype, not a string. Cast in SQL
  if necessary before ingestion.

---

## Edge Semantics

An edge connects `src_table.fkey` to `dst_table.pkey`:

```
orders.USER_ID  --FK-->  users.USER_ID (PK)
```

1. **Bidirectional** — Kumo traverses edges in both directions for features.
2. **FK dtype must match PK dtype** — cast both to `string` if mismatched.
3. **No self-loops** — src and dst must be different tables.
4. **Multi-edges allowed** — a table can have multiple FKs to same/different tables.

---

## Metadata Inference and Link Detection

### RFM

```python
graph.infer_metadata()   # Infers dtype, stype, PK for each table
graph.infer_links()      # Infers FK->PK edges by name matching + type compat
```

`infer_links()` can produce false positives when columns share a name but have
no real relationship — **always verify inferred links semantically**.

### SDK

```python
table.infer_metadata()   # Per-table inference
graph.infer_metadata()   # Across all tables
graph.infer_links()      # Same heuristics as RFM
```

In SDK you typically define edges explicitly; `infer_links()` is for exploration.

---

## Validation Workflow

### Inspection

```python
# RFM
graph.print_metadata()
graph.print_links()
for table in graph.tables.values():
    table.print_metadata()

# SDK
graph.validate()
graph.visualize()   # Returns a visual diagram
```

### Verification Checklist

- [ ] Every table has exactly one primary key
- [ ] All FK/PK pairs have compatible dtypes
- [ ] No spurious inferred links (name match without real relationship)
- [ ] Time columns are `datetime` dtype, not `string`
- [ ] No missing tables that should participate in the graph
- [ ] Edge directions correct (FK lives on the "many" side)
- [ ] Column stypes correct (e.g., zip codes = `categorical`, not `numerical`)

Call `graph.validate()` (both RFM and SDK) to get a descriptive error if the
graph is malformed. Fix all issues before proceeding.

---

## Repairing Links

### RFM

```python
graph.link("orders", "USER_ID", "users")
graph.validate()
```

### SDK

Adjust the `edges` list and rebuild:

```python
graph = kumoai.Graph(
    tables=tables_dict,
    edges=existing_edges + [kumoai.Edge("orders", "STORE_ID", "stores")],
)
graph.validate()
```

### When to Ask the User

Ask when you cannot determine the correct FK/PK mapping:
- Multiple candidate FK columns for the same target table
- Columns with generic names like `ID`, `CODE`, `REF`
- Tables with no obvious relationship to the rest of the graph

---

## Snapshots

SDK-only concept that freezes graph state for reproducible ML.

```python
graph.snapshot()                  # Required before get_edge_stats
stats = graph.get_edge_stats()    # Inspect edge-level statistics
```

Also required before creating training jobs or prediction tasks in the SDK.

---

## Quick Reference

| Operation | RFM | SDK |
|-----------|-----|-----|
| From DataFrames | `rfm.Graph.from_data(dict)` | N/A |
| From SQLite | `rfm.Graph.from_sqlite(conn)` | N/A |
| From Snowflake | `rfm.Graph.from_snowflake(...)` | `Table.from_source_table(...)` + `Graph(...)` |
| From semantic view | `rfm.Graph.from_snowflake_semantic_view(...)` | N/A |
| Manual table | `SnowTable(...)` | `Table.from_source_table(...)` |
| Infer metadata | `graph.infer_metadata()` | `table.infer_metadata()` or `graph.infer_metadata()` |
| Infer links | `graph.infer_links()` | `graph.infer_links()` |
| Add edge | `graph.link(src, fkey, dst)` | Add `Edge(...)` to edges list |
| Print metadata | `graph.print_metadata()` | `graph.validate()` + `graph.visualize()` |
| Print links | `graph.print_links()` | `graph.visualize()` |
| Validate | `graph.validate()` | `graph.validate()` |
| Snapshot | N/A | `graph.snapshot()` |
| Edge stats | N/A | `graph.get_edge_stats()` |

---

## Common Pitfalls

1. **PK/FK dtypes must be compatible** — cast to `string` if one side is `int`
   and the other `string`. Mismatched types cause silent join failures.
2. **`infer_links()` can match on name only** — columns named `ID` in different
   tables may be linked even if unrelated. Always verify against the data model.
3. **Time column must be actual `datetime` dtype, not `string`** — `"2025-01-15"`
   as a string is not recognized as temporal. Cast in SQL before ingestion.
4. **Composite PKs not fully supported in RFM semantic view path** — create a
   surrogate single-column PK if needed.
5. **All tables in one RFM graph must use the same backend** — no mixing
   DataFrames with Snowflake tables in a single `rfm.Graph`.
6. **SDK requires `graph.snapshot()` before `get_edge_stats()`** — calling
   stats on an un-snapshotted graph raises an error.
7. **Cross-table expressions may be dropped in RFM** — computed columns
   referencing other tables may not survive graph construction. Verify with
   `print_metadata()`.
