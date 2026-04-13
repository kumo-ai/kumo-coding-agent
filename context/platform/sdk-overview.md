# Kumo SDK -- Fine-tuned ML Workflows

> Source: kumo-sdk (kumo-tune-skill) + kumoapi v0.74.0 API | Last synced: 2026-03-31

## Overview

Read this document when you need to build **end-to-end trained ML workflows**
on relational data using the Kumo SDK. Unlike KumoRFM (zero-shot), the SDK
trains GNN models on historical data for maximum accuracy.

**Package**: `kumoai`

End-to-end workflow:
1. Initialize the SDK and connect to data sources.
2. Define tables and columns (metadata, dtypes, stypes).
3. Build a relational graph with edges.
4. Write a PQL query defining the prediction task.
5. Generate training tables from historical data.
6. Train a model.
7. Run batch predictions or launch an online serving endpoint.

---

## Initialization

```python
import kumoai

# Option A: explicit credentials
kumoai.init(url="https://app.kumo.ai", api_key="YOUR_API_KEY")

# Option B: environment variables
#   KUMO_API_URL, KUMO_API_KEY
kumoai.init()
```

State is stored in a `GlobalState` singleton. Calling `kumoai.init()` again
overwrites the previous connection.

Environment variables:
| Variable | Purpose |
|----------|---------|
| `KUMO_API_URL` | API endpoint URL |
| `KUMO_API_KEY` | Authentication token |

---

## Connectors

Connectors define how the SDK reaches your data warehouse.

| Connector type | Class |
|----------------|-------|
| Snowflake | `kumoai.SnowflakeConnector` |
| Databricks | `kumoai.DatabricksConnector` |
| S3 | `kumoai.S3Connector` |

### Creating a connector

```python
connector = kumoai.SnowflakeConnector(
    name="my_snowflake",
    account="ACCOUNT",
    warehouse="WAREHOUSE",
    database="DATABASE",
    schema_name="SCHEMA",
    credentials={"user": "USER", "password": "PASSWORD"},
    # or use key-pair auth:
    # credentials={"user": "USER", "private_key": "...", "private_key_passphrase": "..."}
)
```

### Loading existing connectors

```python
connector = kumoai.SnowflakeConnector.get_by_name("my_snowflake")
```

### SourceTable inspection

```python
source = connector.source_table("TABLE_NAME")
source.column_names()
source.column_types()
source.head(n=5)
source.count()
source.schema()
```

---

## Tables and Columns

Tables define the schema the SDK uses for training and prediction. Each column
has a **dtype** (data type) and an **stype** (semantic type).

### Dtype values

| Dtype | Meaning |
|-------|---------|
| `bool` | Boolean |
| `int` | Integer |
| `float` | Floating point |
| `string` | String / text |
| `binary` | Binary data |
| `date` | Date without time |
| `time` | Timestamp |
| `timedelta` | Duration / time difference |
| `floatlist` | List of floats (embeddings) |
| `intlist` | List of integers |
| `stringlist` | List of strings |

Sub-precision types also available: `byte`, `int16`, `int32`, `int64`, `float32`, `float64`.

### Stype values

| Stype | Meaning |
|-------|---------|
| `ID` | Primary key or foreign key |
| `numerical` | Continuous numeric |
| `categorical` | Discrete category |
| `multicategorical` | Multi-label categorical |
| `text` | Free-form text |
| `timestamp` | Event timestamp |
| `sequence` | Embedding / list of floats |
| `image` | Image data |

### Creating a table from a SourceTable

```python
table = kumoai.Table.from_source_table(
    source_table=source,
    primary_key="USER_ID",
    time_column="CREATED_AT",     # optional; for temporal tables
)
```

### Inspecting and adjusting metadata

```python
table.infer_metadata()
table.print_metadata()

# Override column types
table.column("REGION").stype = "categorical"
table.column("AMOUNT").dtype = "float"

table.validate()
```

### PK / FK gotchas

- Primary keys must be unique within the table.
- Foreign keys must reference a valid PK in another table.
- PK/FK columns should have dtype `str` or `int`, stype `id`.
- If a PK column has duplicates, `validate()` will raise an error.
- Composite primary keys are supported via a list of column names.

---

## Graph Construction

A `Graph` links tables via directed edges (FK -> PK).

```python
graph = kumoai.Graph(
    tables={
        "users": users_table,
        "orders": orders_table,
        "items": items_table,
    },
    edges=[
        kumoai.Edge("orders", "USER_ID", "users"),
        kumoai.Edge("orders", "ITEM_ID", "items"),
    ],
)
```

### Edge semantics

```python
kumoai.Edge(
    src_table="orders",     # table containing the FK
    fkey="USER_ID",         # FK column name
    dst_table="users",      # table containing the PK
)
```

Edges are directional: from the table with the FK to the table with the PK.

### Validation and inspection

```python
graph.validate()          # Structural + type checks
graph.print_metadata()    # Summary of tables and columns
graph.print_links()       # All FK -> PK edges
```

### Snapshot

```python
graph.snapshot()          # Capture current state for reproducibility
```

### Automatic link inference

```python
graph.infer_links()       # Infer FK -> PK edges from column names
```

Always verify inferred links with `print_links()` before proceeding.

---

## Predictive Query (PQL)

PQL defines what to predict and for whom.

```python
pq = kumoai.PredictiveQuery(
    query="PREDICT SUM(orders.amount, 0, 30, DAYS) FOR EACH users.user_id",
    graph=graph,
)
```

### Key methods

```python
pq.validate()             # Check PQL syntax against the graph
pq.get_task_type()        # Returns: 'regression', 'binary_classification', etc.
pq.save("path/to/pq")    # Persist to disk
pq = kumoai.PredictiveQuery.load("path/to/pq")
```

### PQL syntax summary

See `rfm-overview.md` for the full PQL pattern catalog. The same PQL syntax
applies to both the SDK and RFM.

---

## Training Tables

Training tables are historical snapshots the model learns from.

### Planning

```python
plan = pq.suggest_training_table_plan(run_mode=kumoai.RunMode.FAST)
```

The plan specifies how to sample historical data. You can customize it before generation:

```python
# Customize the training table plan
plan.start_time = "2024-01-01"          # Training data start (date string or int offset)
plan.end_time = "2025-01-01"            # Training data end
plan.timeframe_step = 7                 # Sample every N time units (e.g. every 7 days)
plan.train_start_offset = 0             # Offset from anchor for train split start
plan.train_end_offset = 90              # Offset from anchor for train split end
plan.forecast_length = 12               # For forecasting tasks: number of periods
plan.lag_timesteps = 7                  # Autoregressive lag features
plan.year_over_year = True              # Add year-over-year features
```

**TrainingTableGenerationPlan parameters** (all default to inferred unless noted):

| Parameter | Type | Purpose |
|-----------|------|---------|
| `split` | `str` | Train/val/test split strategy |
| `start_time`, `end_time` | `str \| int` | Training data window bounds |
| `train_start_offset`, `train_end_offset` | `int` | Offsets from anchor for train split |
| `timeframe_step` | `int` | Sampling frequency in time units |
| `forecast_length` | `int` | Number of forecast periods |
| `lag_timesteps` | `int` | Lag for autoregressive features |
| `year_over_year` | `bool` | Enable year-over-year features |
| `weight_col` | `str \| None` | Column for weighted training (default: `None`) |

### Generation

```python
training_table = pq.generate_training_table(plan, non_blocking=False)
```

### RunMode

| Mode | Behavior |
|------|----------|
| `DEBUG` | Fastest, lowest quality (testing only) |
| `FAST` | ~4x faster than NORMAL, good for iteration |
| `NORMAL` | Balanced speed and quality (default) |
| `BEST` | ~4x slower than NORMAL, highest quality (production) |

### Inspection

```python
training_table.head(n=10)
training_table.count()
training_table.stats()
training_table.label_distribution()
```

---

## Model Training

### ModelPlan

The ModelPlan is a composite of 5 sub-plans. Always start from a suggested plan:

```python
model_plan = pq.suggest_model_plan(run_mode=kumoai.RunMode.FAST)
```

Then customize sub-plans as needed:

```python
# --- TrainingJobPlan ---
model_plan.training_job.num_experiments = 3       # AutoML search width
model_plan.training_job.tune_metric = "auroc"     # Metric to optimize
model_plan.training_job.refit_trainval = True      # Refit on train+val after selection

# --- OptimizationPlan ---
model_plan.optimization.max_epochs = 50           # Max training epochs
model_plan.optimization.base_lr = [0.001, 0.005]  # Learning rate candidates
model_plan.optimization.batch_size = [512, 1024]  # Batch size candidates
model_plan.optimization.weight_decay = [1e-5, 1e-4]

# Loss functions (for class imbalance or robust regression):
from kumoapi.model_plan import FocalLossConfig, HuberLossConfig, QuantileLossConfig
model_plan.optimization.loss = [FocalLossConfig(name="focal", alpha=0.25, gamma=2.0)]
# Other options: HuberLossConfig(name="huber", delta=1.0), QuantileLossConfig(name="quantile", q=0.5)

# Early stopping:
from kumoapi.model_plan import EarlyStoppingConfig
model_plan.optimization.early_stopping = [EarlyStoppingConfig(min_delta=0.001, patience=5)]

# --- ModelArchitecturePlan ---
model_plan.model_architecture.channels = [128, 256]                 # GNN hidden dimensions
model_plan.model_architecture.num_pre_message_passing_layers = [2]  # Layers before GNN
model_plan.model_architecture.num_post_message_passing_layers = [2] # Layers after GNN

# --- NeighborSamplingPlan ---
model_plan.neighbor_sampling.adaptive_sampling = True   # Adaptive neighbor sampling

# --- ColumnProcessingPlan ---
model_plan.column_processing.encoder_overrides = {
    "orders.description": "glove_6B"    # Text encoding override
}
```

**ModelPlan sub-plan reference:**

| Sub-plan | Key Parameters | Purpose |
|----------|---------------|---------|
| `training_job` | `num_experiments`, `metrics`, `tune_metric`, `pruning`, `refit_trainval`, `refit_full`, `manual_seed` | AutoML search configuration |
| `optimization` | `max_epochs`, `base_lr`, `batch_size`, `weight_decay`, `loss`, `early_stopping`, `lr_scheduler`, `majority_sampling_ratio`, `optimizer`, `weight_mode` | Training loop |
| `model_architecture` | `channels`, `num_pre_message_passing_layers`, `num_post_message_passing_layers`, `activation`, `normalization` | GNN architecture |
| `neighbor_sampling` | `num_neighbors`, `adaptive_sampling`, `sample_from_entity_table` | Graph sampling |
| `column_processing` | `encoder_overrides`, `na_strategy` | Feature encoding |

**Loss function options:**

| Loss | Class | Key Params | Use When |
|------|-------|------------|----------|
| Focal | `FocalLossConfig` | `alpha` (0-1), `gamma` (>=1) | Class imbalance |
| Huber | `HuberLossConfig` | `delta` | Robust regression (outlier-tolerant) |
| Quantile | `QuantileLossConfig` | `q` (0-1) | Quantile regression |
| OrdinalLog | `OrdinalLogLossConfig` | `alpha` | Ordinal classification |

### Trainer

```python
trainer = kumoai.Trainer(model_plan)
result = trainer.fit(
    graph=graph,
    train_table=training_table,
    non_blocking=False,
    warm_start_job_id=None,    # Resume from previous training job
)
```

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `graph` | `Graph` | required | The relational graph |
| `train_table` | `TrainingTable` | required | Generated training data |
| `non_blocking` | `bool` | `False` | Return immediately |
| `warm_start_job_id` | `str \| None` | `None` | Previous training job ID to continue from |
| `custom_tags` | `Mapping[str, str]` | `{}` | Custom key-value tags for the job |

### Metrics

```python
result.metrics()           # Returns ModelEvaluationMetrics with test/validation/training splits
result.model_plan          # The actual ModelPlan used after AutoML (see what won)
```

### Non-blocking training

```python
training_job = trainer.fit(graph=graph, train_table=training_table, non_blocking=True)
training_job.status()      # JobStatusReport (status, tracking_url, event_log)
training_job.progress()    # AutoTrainerProgress (per-trial, per-epoch train/val metrics)
training_job.cancel()      # Cancel in-progress job
training_job.attach()      # Block with live progress bar, returns TrainingJobResult
```

### Training Diagnostics

Inspect training progress and results for iteration decisions.

**Per-epoch metrics (training curves):**

```python
progress = training_job.progress()
for trial_id, trial in progress.trial_progress.items():
    for epoch, metrics in trial.metrics.items():
        print(f"Trial {trial_id} Epoch {epoch}: "
              f"train_loss={metrics.train_metrics.get('loss', '?')}, "
              f"val_auroc={metrics.validation_metrics.get('auroc', '?')}")
```

**Post-training inspection:**

```python
result = training_job.attach()

# What AutoML actually chose
actual_plan = result.model_plan
print(f"Best LR: {actual_plan.optimization.base_lr}")
print(f"Best channels: {actual_plan.model_architecture.channels}")

# 3-way metric split
metrics = result.metrics()
# metrics.test_metrics, metrics.validation_metrics, metrics.training_metrics

# Holdout data for manual analysis
holdout_df = result.holdout_df()          # Load into memory
holdout_url = result.holdout_url()        # Presigned URL (large datasets)
```

**Job event log (debug failures):**

```python
status = training_job.status()
for event in status.event_log:
    print(f"{event.stage_name}: {event.last_updated_at} — {event.detail}")
```

---

## Predictions

### Prediction Table Generation

Generate a prediction table (analogous to training table, but for inference):

```python
pred_plan = pq.suggest_prediction_table_plan(run_mode=kumoai.RunMode.FAST)

# Customize anchor time for temporal queries:
import datetime
pred_plan.anchor_time = datetime.datetime(2025, 3, 30)
pred_plan.forecast_length = 12     # For forecasting tasks
pred_plan.lag_timesteps = 7        # Autoregressive lag features

pred_table = pq.generate_prediction_table(pred_plan, non_blocking=False)
```

### Batch Prediction

```python
prediction_job = trainer.predict(
    graph=graph,
    prediction_table=pred_table,
    output_config=kumoai.OutputConfig(
        output_types={"predictions"},           # or {"predictions", "embeddings"}
        output_connector=connector,
        output_table_name="PREDICTIONS_OUTPUT",
        output_metadata_fields=[
            kumoai.MetadataField.JOB_TIMESTAMP,
            kumoai.MetadataField.ANCHOR_TIMESTAMP,
        ],
    ),
    binary_classification_threshold=0.5,        # Optional: threshold for binary predictions
    num_classes_to_return=5,                     # Optional: top-K classes for multi-class
    num_workers=1,                              # Parallelism
    non_blocking=True,
)
```

**`trainer.predict()` parameters:**

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `graph` | `Graph` | required | The relational graph |
| `prediction_table` | `PredictionTable` | required | Generated prediction data |
| `output_config` | `OutputConfig \| None` | `None` | Where to write results |
| `training_job_id` | `str \| None` | `None` | Specific training job to use for prediction |
| `binary_classification_threshold` | `float \| None` | `None` | Threshold for binary class labels |
| `num_classes_to_return` | `int \| None` | `None` | Top-K classes for multi-class |
| `num_workers` | `int` | `1` | Prediction parallelism |
| `custom_tags` | `Mapping[str, str]` | `{}` | Custom key-value tags for the job |
| `non_blocking` | `bool` | `False` | Return immediately |

### Prediction Diagnostics

```python
pred_job = trainer.predict(..., non_blocking=True)
pred_job.progress()        # PredictionProgress (completed/total iterations, elapsed time)
pred_job.cancel()          # Cancel in-progress prediction

pred_result = pred_job.attach()
pred_result.summary()              # BatchPredictionJobSummary (num_entities_predicted)
pred_result.predictions_df()       # Load predictions into memory
pred_result.predictions_urls()     # Parquet URLs (for large results)
pred_result.embeddings_df()        # Entity embeddings (if output_types includes "embeddings")
pred_result.export(output_config)  # Re-export to different connector
```

**`OutputConfig` parameters:**

| Parameter | Type | Purpose |
|-----------|------|---------|
| `output_types` | `set[str]` | `{"predictions"}` and/or `{"embeddings"}` |
| `output_connector` | `Connector \| None` | Target warehouse connector |
| `output_table_name` | `str \| tuple \| None` | Target table (tuple for Databricks: `(schema, table)`) |
| `output_metadata_fields` | `list[MetadataField] \| None` | Add `JOB_TIMESTAMP`, `ANCHOR_TIMESTAMP` columns |

### Output types

| Type | Method |
|------|--------|
| pandas DataFrame | `pred_table.to_df()` |
| Write to warehouse | Use `OutputConfig` with connector |
| Entity embeddings | Use `output_types={"embeddings"}` |

---

## Async Jobs and Persistence

All long-running operations support `non_blocking=True`. Re-attach from another session:

```python
model = kumoai.Model.attach(model_id="MODEL_ID")
training_table = kumoai.TrainingTable.attach(job_id="JOB_ID")
model.tag("production-v1")
model = kumoai.Model.load_by_tag(tag="production-v1")

# Re-create a Trainer from a previous job
trainer = kumoai.Trainer.load(job_id="JOB_ID")
trainer = kumoai.Trainer.load_from_tags(tags={"env": "production"})
```

---

## Online Serving

Deploy a trained model as a real-time prediction endpoint.

### Launch

```python
endpoint_future = result.launch_online_serving_endpoint()
endpoint = endpoint_future.attach()  # Block until ready
```

### Predict

```python
result = endpoint.predict(
    fkey={"user_id": "42"},
    time=None,                       # Optional anchor timestamp
    realtime_features=None,          # Optional feature overrides
)
```

### Update / Destroy / Ping

```python
endpoint.update(refresh_graph_data=True)  # Refresh data + optionally update model
endpoint.ping()                            # Check endpoint liveness
endpoint.destroy()                         # Tear down endpoint
```

---

## Quick Reference

### Core classes (`import kumoai`)

| Class | Purpose |
|-------|---------|
| `kumoai.SnowflakeConnector` | Connect to Snowflake |
| `kumoai.DatabricksConnector` | Connect to Databricks |
| `kumoai.S3Connector` | Connect to S3 |
| `kumoai.Table` | Schema definition with column metadata |
| `kumoai.Edge` | FK -> PK relationship |
| `kumoai.Graph` | Relational graph of tables and edges |
| `kumoai.PredictiveQuery` | PQL query bound to a graph |
| `kumoai.ModelPlan` | Training configuration |
| `kumoai.Trainer` | Model training orchestrator |
| `kumoai.Model` | Trained model |
| `kumoai.OutputConfig` | Prediction output destination |
| `kumoai.RunMode` | Enum: `DEBUG`, `FAST`, `NORMAL`, `BEST` |
| `kumoai.TrainingTable` | Generated training data |

### Key methods

| Object | Method | Purpose |
|--------|--------|---------|
| `Table` | `.from_source_table()` | Create from connector |
| `Table` | `.infer_metadata()` | Auto-detect column types |
| `Table` | `.validate()` | Check schema correctness |
| `Graph` | `.validate()` | Structural checks |
| `Graph` | `.infer_links()` | Auto-detect FK->PK edges |
| `PredictiveQuery` | `.validate()` | PQL syntax check |
| `PredictiveQuery` | `.get_task_type()` | Infer ML task type |
| `PredictiveQuery` | `.suggest_training_table_plan()` | Plan training data |
| `PredictiveQuery` | `.suggest_prediction_table_plan()` | Plan prediction data |
| `PredictiveQuery` | `.suggest_model_plan()` | Plan model configuration |
| `PredictiveQuery` | `.generate_training_table(plan)` | Generate training data |
| `PredictiveQuery` | `.generate_prediction_table(plan)` | Generate prediction data |
| `Trainer` | `.fit(graph, train_table)` | Train model |
| `Trainer` | `.predict(graph, pred_table)` | Run batch predictions |
| `TrainingJobResult` | `.metrics()` | Evaluation results |
| `TrainingJobResult` | `.model_plan` | Actual ModelPlan after AutoML |
| `TrainingJob` | `.progress()` | Per-epoch training metrics |
| `TrainingJob` | `.attach()` | Block with live progress bar |
| `TrainingJob` | `.cancel()` | Cancel in-progress job |
| `BatchPredictionResult` | `.summary()` | Prediction count |
| `BatchPredictionResult` | `.predictions_urls()` | Parquet URLs |
| `BatchPredictionResult` | `.embeddings_df()` | Entity embeddings |

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `ValidationError: PK not unique` | Duplicate values in PK column | Deduplicate or choose a different PK |
| `ValidationError: FK references unknown table` | Edge points to missing table | Add the table to the graph or fix the edge |
| `ValidationError: dtype mismatch` | FK and PK have incompatible types | Cast one to match the other |
| `ConnectionError` | Bad credentials or unreachable warehouse | Check connector config and network |
| `PQLSyntaxError` | Invalid PQL query | Run `pq.validate()` for details |
| `JobFailedError` | Training or prediction job failed | Check `job.error_message()` for details |
| `TimeoutError` | Job exceeded time limit | Use `non_blocking=True` and poll |
| `ResourceNotFoundError` | Model/table ID not found | Verify the ID or re-train |

---

## Common Pitfalls

1. **Forgetting `kumoai.init()`.** All SDK calls require an active session.
2. **Not calling `infer_metadata()`.** Column types default to `str`/`categorical` without inference, breaking numeric predictions.
3. **Wrong stype on ID columns.** PK/FK columns must have `stype="id"`, not `categorical`.
4. **Edge direction reversed.** Edges go FK → PK: `Edge("orders", "USER_ID", "users")`.
5. **Skipping `validate()`.** Always validate tables, graphs, and queries before training.
6. **Using `FAST` for production.** Use `NORMAL` or `BEST` for production-quality models.
7. **Ignoring training table stats.** Check `label_distribution()` and `count()` before training.
8. **Using wrong ModelPlan param names.** Use `optimization.base_lr` (not `learning_rate`), `optimization.max_epochs` (not `epochs`), `model_architecture.channels` (not `hidden_channels`). After training, inspect `result.model_plan` to see what AutoML actually chose.
9. **Training on too-recent data.** Customize `plan.start_time`/`end_time` for sufficient history.
10. **Forgetting to tag production models.** Use `result.tag()` for retrieval.
