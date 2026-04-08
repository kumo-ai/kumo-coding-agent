# Data Connectors

> Source: kumo-sdk (kumo-tune-skill connectors section, kumo-rfm-skill graph paths) | Last synced: 2026-03-31

## Overview

Read this document when you need to connect to a user's data source. Kumo
supports multiple backends — the right connector depends on where the data lives
and whether you're using RFM (zero-shot) or the Enterprise SDK (training).

---

## Environment Setup

Use [uv](https://docs.astral.sh/uv/) for project and package management. Install
it first if not available: `curl -LsSf https://astral.sh/uv/install.sh | sh`

```bash
uv init my-kumo-project && cd my-kumo-project

# Core — always needed
uv add kumoai              # Kumo SDK (includes RFM, Enterprise SDK, kumoapi)

# Data connectors — add what you need
uv add snowflake-connector-python   # Snowflake (RFM path)
uv add pandas pyarrow               # DataFrames, Parquet I/O

# Analysis & visualization
uv add matplotlib seaborn            # Plot predictions, distributions
uv add graphviz                      # graph.visualize() support
uv add scikit-learn                  # Offline metrics (confusion matrix, etc.)

# Experiment tracking (optional — no built-in integration, manual logging)
uv add mlflow                        # or: uv add wandb
```

**Environment variables** — set before running:

```bash
# RFM
export KUMO_RFM_API_KEY="your-rfm-api-key"

# Enterprise SDK
export KUMO_API_URL="https://app.kumo.ai"
export KUMO_API_KEY="your-api-key"

# Snowflake (if using Snowflake connector directly)
export SNOWFLAKE_ACCOUNT="xy12345.us-east-1"
export SNOWFLAKE_USER="MY_USER"
export SNOWFLAKE_PASSWORD="MY_PASSWORD"   # or use key-pair / SSO
```

---

## Connector Reference

### Enterprise SDK Connectors

| Connector | Class | Key Arguments |
|-----------|-------|---------------|
| **Amazon S3** | `kumoai.S3Connector(root_dir)` | `root_dir` — S3 path (e.g., `"s3://bucket/prefix/"`) |
| **Snowflake** | `kumoai.SnowflakeConnector(name, account, warehouse, database, schema_name)` | Credentials via env vars or dict |
| **Databricks** | `kumoai.DatabricksConnector(name, host, cluster_id, warehouse_id, catalog)` | Credentials via env vars or dict |
| **BigQuery** | `kumoai.BigQueryConnector(name, project_id, dataset_id)` | Credentials via env vars or dict |
| **File Upload** | `kumoai.FileUploadConnector(...)` | Direct file upload |
| **AWS Glue** | `kumoai.GlueConnector(...)` | Glue Catalog access |

### RFM Data Paths

| Data Location | Method | When to Use |
|---------------|--------|-------------|
| Local pandas DataFrames | `rfm.Graph.from_data({"table": df, ...})` | Prototyping, small data, CSV/Parquet loaded locally |
| Snowflake (all tables) | `rfm.Graph.from_snowflake(connection, database, schema)` | Quick start — grabs all tables in schema |
| Snowflake (select tables) | `rfm.Graph.from_snowflake(..., tables=["T1", "T2"])` | Control which tables to include |
| Snowflake (fine control) | `rfm.Graph(tables=[SnowTable(...)], edges=[])` | Per-table config before graph construction |
| SQLite database | `rfm.Graph.from_sqlite(connection, tables)` | Local relational databases |
| Snowflake Semantic View | `rfm.Graph.from_snowflake_semantic_view(name, connection)` | Pre-defined schema with validated relationships |

---

## Connection Setup

### Snowflake (most common)

**What you need from the user:**
1. **Account identifier** — e.g., `xy12345.us-east-1` (find in Snowflake console → Admin → Accounts)
2. **User** — their Snowflake username
3. **Authentication** — password, key pair, or OAuth token
4. **Warehouse** — compute resource name (e.g., `COMPUTE_WH`)
5. **Database** — which database contains their data
6. **Schema** — which schema within the database

**RFM path:**

```python
import snowflake.connector

connection = snowflake.connector.connect(
    account="xy12345.us-east-1",
    user="MY_USER",
    password="MY_PASSWORD",       # or use authenticator="externalbrowser"
    warehouse="COMPUTE_WH",
    database="MY_DATABASE",
    schema="MY_SCHEMA",
)
```

**Enterprise SDK path:**

```python
import kumoai

kumoai.init(url="https://app.kumo.ai", api_key="KUMO_API_KEY")

connector = kumoai.SnowflakeConnector(
    name="my_sf_connector",
    account="xy12345.us-east-1",
    warehouse="COMPUTE_WH",
    database="MY_DATABASE",
    schema_name="MY_SCHEMA",
    credentials={"user": "MY_USER", "password": "MY_PASSWORD"},
    # or key-pair auth:
    # credentials={"user": "MY_USER", "private_key": "...", "private_key_passphrase": "..."}
)

# Load existing connector by name
connector = kumoai.SnowflakeConnector.get_by_name("my_sf_connector")
```

### Amazon S3

**What you need:**
- S3 path to the data (e.g., `s3://my-bucket/ecommerce/`)
- AWS credentials configured (via env vars, IAM role, or `~/.aws/credentials`)
- Data in Parquet or CSV format (one folder per table)

```python
# Enterprise SDK
connector = kumoai.S3Connector("s3://my-bucket/ecommerce/")
print(connector.table_names())  # ['customers', 'orders', 'products']

# RFM — load to pandas first
import pandas as pd
customers_df = pd.read_parquet("s3://my-bucket/ecommerce/customers/")
orders_df = pd.read_parquet("s3://my-bucket/ecommerce/orders/")
graph = rfm.Graph.from_data({"customers": customers_df, "orders": orders_df})
```

**Supported file formats (S3 and file connectors):**

| Format | Supported | Notes |
|--------|-----------|-------|
| Parquet | Yes | Standard compression (Snappy, etc.) handled transparently by PyArrow |
| CSV | Yes | Uncompressed only — `.csv.gz` is **not** supported |

**CSV delimiter support:** Auto-detected from `|`, `,`, `;`, `\t` (tab). The
SDK samples the file header and uses `csv.Sniffer` for detection. If detection
fails, defaults to `,`.

### Local Files (CSV, Parquet)

**RFM only** (Enterprise SDK requires cloud storage):

```python
import pandas as pd

# CSV
customers = pd.read_csv("data/customers.csv")
orders = pd.read_csv("data/orders.csv")

# Parquet
customers = pd.read_parquet("data/customers.parquet")
orders = pd.read_parquet("data/orders.parquet")

graph = rfm.Graph.from_data({
    "customers": customers,
    "orders": orders,
})
```

### Databricks

```python
connector = kumoai.DatabricksConnector(
    name="my_db_connector",
    host="adb-1234567890.azuredatabricks.net",
    cluster_id="0123-456789-abcde",
    warehouse_id="abcdef1234567890",
    catalog="my_catalog",
)
```

### BigQuery

```python
connector = kumoai.BigQueryConnector(
    name="my_bq_connector",
    project_id="my-gcp-project",
    dataset_id="my_dataset",
)
```

---

## Schema Discovery

After connecting, always discover what's available before building a graph.

### Enterprise SDK

```python
# List all tables
print(connector.table_names())
# Output: ['CUSTOMERS', 'ORDERS', 'PRODUCTS', 'ORDER_ITEMS', ...]

# Inspect a single table's columns
source = connector["CUSTOMERS"]
print(source.column_dict)
# Output: {'CUSTOMER_ID': 'varchar', 'NAME': 'varchar', 'AGE': 'number', ...}
```

### RFM (Snowflake)

```python
# Option 1: Load all tables, inspect after
graph = rfm.Graph.from_snowflake(connection, database="DB", schema="SCHEMA")
graph.print_metadata()

# Option 2: Query Snowflake directly
cursor = connection.cursor()
cursor.execute("SHOW TABLES IN SCHEMA MY_DATABASE.MY_SCHEMA")
tables = cursor.fetchall()
for t in tables:
    print(t[1])  # table name
```

### RFM (Local)

```python
# List files in directory
import os
files = [f for f in os.listdir("data/") if f.endswith(('.csv', '.parquet'))]
print(files)
```

---

## Choosing the Right Connector

| User Says | Connector | Notes |
|-----------|-----------|-------|
| "Data is in Snowflake" | `SnowflakeConnector` (SDK) or `from_snowflake` (RFM) | Most common for enterprise |
| "Data is in S3" | `S3Connector` (SDK) or load to pandas (RFM) | Parquet format expected |
| "I have CSV files" | Load to pandas → `from_data` (RFM only) | SDK requires cloud storage |
| "Data is in Databricks" | `DatabricksConnector` (SDK only) | Enterprise SDK path |
| "Data is in BigQuery" | `BigQueryConnector` (SDK only) | Enterprise SDK path |
| "I have a Semantic View" | `from_snowflake_semantic_view` (RFM) | Pre-validated graph structure |
| "I don't know where data is" | Ask the user | Need account details first |

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Connection refused` / timeout | Wrong account name or network issue | Verify account identifier format, check firewall |
| `Incorrect username or password` | Bad credentials | Re-check user/password, try `authenticator="externalbrowser"` |
| `Warehouse does not exist` | Typo or no access | List warehouses: `SHOW WAREHOUSES` in Snowflake |
| `Database/schema does not exist` | Wrong name or no access | List databases: `SHOW DATABASES` in Snowflake |
| `Access denied` | User lacks privileges on the schema | Request USAGE + SELECT grants from admin |
| `No tables found` | Empty schema or wrong schema | Verify schema name, check `SHOW TABLES` |
| `dtype=unsupported` on PK/FK | ID columns stored as large int or UUID | Cast PK/FK columns to `string` in source |

---

## Quick Reference

| Operation | Enterprise SDK | RFM |
|-----------|---------------|-----|
| Connect | `kumoai.SnowflakeConnector(...)` | `snowflake.connector.connect(...)` |
| List tables | `connector.table_names()` | `SHOW TABLES` or `graph.print_metadata()` |
| Inspect columns | `connector["table"].column_dict` | `table.print_metadata()` |
| Check existence | `"table" in connector` | — |
