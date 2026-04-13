# Explore Data

Inspect and assess data quality before building a graph. This skill prevents
wasted effort from bad data — most prediction failures trace back to issues
that were visible in the raw data but not caught early.

---

## Prerequisites

- Connected to the data source (see `context/platform/data-connectors.md`)
- Know which database/schema to explore
- **Read first**: `context/platform/data-connectors.md`

---

## Workflow

### Step 1: List Available Tables

Before anything else, discover what's in the schema.

**fine-tuned SDK:**

```python
import kumoai
kumoai.init(url="https://app.kumo.ai", api_key="YOUR_API_KEY")

connector = ...  # e.g. kumoai.SnowflakeConnector(...), S3Connector(...), etc.

print(connector.table_names())
# ['CUSTOMERS', 'ORDERS', 'PRODUCTS', 'ORDER_ITEMS', 'RETURNS', ...]
```

**RFM (Snowflake):**

```python
cursor = connection.cursor()
cursor.execute("SHOW TABLES IN SCHEMA MY_DATABASE.MY_SCHEMA")
for row in cursor.fetchall():
    print(f"{row[1]:30s}  rows: {row[3]}")
```

**RFM (Local):**

```python
import os
files = [f for f in os.listdir("data/") if f.endswith(('.csv', '.parquet'))]
for f in files:
    df = pd.read_parquet(f"data/{f}") if f.endswith('.parquet') else pd.read_csv(f"data/{f}")
    print(f"{f:30s}  rows: {len(df):>10,}  cols: {len(df.columns)}")
```

**Record**: Write the full table list to your scratch file. Note which tables
look relevant vs. which might be staging, archive, or system tables.

### Step 2: Classify Tables

For each table, classify its role in the prediction task:

| Classification | Include in Graph? | Examples |
|----------------|-------------------|---------|
| **Entity table** | Yes (with PK) | CUSTOMERS, USERS, ACCOUNTS |
| **Event/transaction table** | Yes (with time column) | ORDERS, TRANSACTIONS, LOGINS |
| **Dimension table** | Yes (with PK) | PRODUCTS, CATEGORIES, REGIONS |
| **Junction/bridge table** | Maybe (if it adds signal) | ORDER_ITEMS, CAMPAIGN_MEMBERS |
| **Archive/history table** | Usually no | ORDERS_ARCHIVE, CUSTOMERS_BACKUP |
| **Staging/temp table** | No | STG_ORDERS, TMP_IMPORT |
| **System/metadata table** | No | INFORMATION_SCHEMA.*, __DBT_* |
| **Aggregated/derived table** | Usually no | MONTHLY_REVENUE_SUMMARY |

**Ask the user if unclear**: "I see tables X, Y, Z — which are relevant to
your prediction task? Are any of these staging or archive tables?"

### Step 3: Inspect Each Candidate Table

For every table you plan to include, collect these stats:

**fine-tuned SDK:**

```python
source = connector["CUSTOMERS"]
print(source.column_dict)           # Column names and storage types

# After building table object:
table = kumoai.Table.from_source_table(source, primary_key="CUSTOMER_ID")
table.infer_metadata()
print(table.metadata)               # DataFrame of column configs
table.get_stats(wait_for="minimal") # Column-level statistics
```

**RFM (Snowflake):**

```python
cursor = connection.cursor()

# Row count
cursor.execute("SELECT COUNT(*) FROM MY_SCHEMA.CUSTOMERS")
row_count = cursor.fetchone()[0]

# Column info
cursor.execute("DESCRIBE TABLE MY_SCHEMA.CUSTOMERS")
columns = cursor.fetchall()
for col in columns:
    print(f"  {col[0]:25s}  type: {col[1]}")

# NULL counts per column
cursor.execute("""
    SELECT
        COUNT(*) as total_rows,
        COUNT(CUSTOMER_ID) as non_null_customer_id,
        COUNT(EMAIL) as non_null_email,
        COUNT(CREATED_AT) as non_null_created_at
    FROM MY_SCHEMA.CUSTOMERS
""")
```

**RFM (pandas):**

```python
df = pd.read_parquet("data/customers.parquet")
print(f"Rows: {len(df):,}")
print(f"Columns: {list(df.columns)}")
print(f"\nDtypes:\n{df.dtypes}")
print(f"\nNull counts:\n{df.isnull().sum()}")
print(f"\nNull %:\n{(df.isnull().sum() / len(df) * 100).round(1)}")
print(f"\nUnique counts:\n{df.nunique()}")
print(f"\nSample:\n{df.head()}")
```

### Step 4: Run Quality Checks

For each table, verify these quality dimensions:

#### 4a. Row Count

| Check | Threshold | Action |
|-------|-----------|--------|
| Table is empty | 0 rows | Exclude — no signal |
| Very small | < 100 rows | Warn — model may overfit |
| Small | 100–1,000 rows | OK for RFM, may be tight for training |
| Normal | 1,000–10M rows | Good |
| Very large | > 10M rows | OK, but training will be slow — consider sampling |

#### 4b. Missing Values (NULLs)

```python
# For each column, calculate NULL percentage
null_pct = (df.isnull().sum() / len(df) * 100).round(1)
```

| NULL % | Severity | Action |
|--------|----------|--------|
| 0–5% | Normal | No action needed |
| 5–20% | Mild | Note it, proceed |
| 20–50% | Concerning | Warn the user — column may not be useful as a feature |
| > 50% | Severe | Exclude column, or ask user if data is expected to be sparse |
| 100% | Dead column | Exclude — no signal |

**Critical**: If the **primary key** column has NULLs, the table is broken.
If the **time column** has NULLs, temporal queries will have gaps.

#### 4c. Cardinality (Unique Values)

```python
for col in df.columns:
    n_unique = df[col].nunique()
    print(f"  {col}: {n_unique:,} unique ({n_unique/len(df)*100:.1f}%)")
```

| Column Role | Expected Cardinality | Red Flag |
|-------------|---------------------|----------|
| Primary key | 100% unique | Duplicates → broken PK |
| Foreign key | < 100% unique, > 1 | 1 unique value → constant, useless |
| Categorical feature | 2–1,000 unique | > 10,000 → consider as text or ID, not categorical |
| Numerical feature | Many unique | 1 unique value → constant, exclude |
| Boolean/flag | 2 unique | 1 unique → constant, exclude |

#### 4d. Temporal Coverage

For tables with a time column:

```python
# Snowflake
cursor.execute("""
    SELECT
        MIN(CREATED_AT) as earliest,
        MAX(CREATED_AT) as latest,
        DATEDIFF('day', MIN(CREATED_AT), MAX(CREATED_AT)) as span_days
    FROM MY_SCHEMA.ORDERS
""")

# pandas
print(f"Earliest: {df['created_at'].min()}")
print(f"Latest:   {df['created_at'].max()}")
print(f"Span:     {(df['created_at'].max() - df['created_at'].min()).days} days")
```

| Check | Threshold | Action |
|-------|-----------|--------|
| Span < 30 days | Too short for most tasks | Warn — may not have enough history |
| Span < prediction window | Impossible task | Cannot predict 90-day churn with 60 days of data |
| Latest record > 30 days ago | Stale data | Warn — predictions may not reflect current state |
| Large gaps (e.g., no data for 6 months) | Unreliable | Warn — model may learn gap as signal |

#### 4e. Data Type Verification

Check that columns have the types you expect:

| Expected | Actual | Problem | Fix |
|----------|--------|---------|-----|
| Timestamp | String (e.g., "2025-01-15") | Won't be recognized as time column | Cast: `pd.to_datetime(df['col'])` or `TO_TIMESTAMP()` in SQL |
| Numeric ID | Integer (e.g., 12345678901) | May get `dtype=unsupported` | Cast to string: `df['id'] = df['id'].astype(str)` |
| Categorical | Free-text (high cardinality) | Too many categories | Consider stype=text instead |
| Boolean | String ("true"/"false") | Won't be categorical | Map to 0/1 or ensure consistent values |

#### 4f. Duplicate Check

```python
# Check primary key uniqueness
pk_dupes = df.duplicated(subset=['CUSTOMER_ID']).sum()
if pk_dupes > 0:
    print(f"WARNING: {pk_dupes} duplicate PKs")
```

Duplicates in PK → the table cannot serve as an entity table without dedup.

### Step 5: Summarize Findings

Create a data quality summary in your scratch file:

```markdown
## Data Quality Summary

### Tables Inspected
| Table | Rows | Columns | PK | Time Column | Status |
|-------|------|---------|----|-----------  |--------|
| CUSTOMERS | 50,000 | 12 | CUSTOMER_ID (unique) | CREATED_AT | Good |
| ORDERS | 1,200,000 | 8 | ORDER_ID (unique) | ORDER_DATE | Good |
| PRODUCTS | 500 | 6 | PRODUCT_ID (unique) | — | Good |
| ORDER_ITEMS | 3,500,000 | 5 | — (junction table) | — | Good |
| STAGING_ORDERS | 100 | 8 | — | — | EXCLUDE (staging) |

### Issues Found
- CUSTOMERS.PHONE: 45% NULL — minor, non-critical column
- ORDERS.DISCOUNT: 80% NULL — sparse, may not add signal
- ORDER_ITEMS has no PK — treat as event table, link via ORDER_ID

### Temporal Coverage
- ORDERS: 2022-01-01 to 2025-12-15 (~4 years) — good
- Latest data is 3 months old — predictions will use this as anchor

### Recommendation
Include: CUSTOMERS, ORDERS, PRODUCTS, ORDER_ITEMS
Exclude: STAGING_ORDERS (staging table)
```

### Step 6: Present to User

Share the summary and get confirmation before proceeding to graph construction:

- "I found N tables. Here's what I recommend including and why."
- "These issues need your input: [list]"
- "Does this look right? Any tables I should add or remove?"

---

## Quick Reference

| Check | SQL (Snowflake) | pandas |
|-------|-----------------|--------|
| Row count | `SELECT COUNT(*) FROM T` | `len(df)` |
| Column types | `DESCRIBE TABLE T` | `df.dtypes` |
| NULL count | `SELECT COUNT(col) FROM T` | `df['col'].isnull().sum()` |
| Unique count | `SELECT COUNT(DISTINCT col) FROM T` | `df['col'].nunique()` |
| Time range | `SELECT MIN(ts), MAX(ts) FROM T` | `df['ts'].min(), df['ts'].max()` |
| Duplicates | `SELECT col, COUNT(*) ... HAVING COUNT(*) > 1` | `df.duplicated(subset=[col]).sum()` |
| Sample rows | `SELECT * FROM T LIMIT 5` | `df.head()` |

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Table not found" | Wrong schema or table name | Check `SHOW TABLES` or `connector.table_names()` |
| Slow queries on large tables | Full table scan on 10B+ rows | Use `LIMIT` or `TABLESAMPLE` for exploration |
| `dtype=unsupported` after infer_metadata | ID column stored as large int | Cast to string before connecting |
| Time column not detected | Stored as string, not timestamp | Cast with `TO_TIMESTAMP()` or `pd.to_datetime()` |

---

## Checklist

- [ ] All tables in schema listed
- [ ] Tables classified (entity, event, dimension, staging, etc.)
- [ ] Irrelevant tables excluded (staging, archive, system)
- [ ] Row counts checked for each candidate table
- [ ] NULL percentages checked — severe cases flagged
- [ ] Primary key uniqueness verified for entity tables
- [ ] Cardinality checked — constant columns flagged
- [ ] Temporal coverage verified — sufficient history for prediction window
- [ ] Data types verified — timestamps are timestamps, IDs are strings
- [ ] Summary written to scratch file
- [ ] User confirmed table selection
