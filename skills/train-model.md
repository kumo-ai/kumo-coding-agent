# Train a Model (fine-tuned SDK)

Train a GNN model on historical relational data using the Kumo SDK for maximum prediction accuracy — unlike RFM zero-shot, training produces models tuned to your specific data and task.

---

## Prerequisites

- `kumoai` installed (`uv add kumoai` — see `context/platform/data-connectors.md` for full setup)
- API credentials set: `KUMO_API_URL`, `KUMO_API_KEY` (or pass to `kumoai.init()`)
- A validated graph (follow `skills/build-graph.md` first)
- A validated PQL query (follow `skills/write-pql.md` first)
- **Read first**: `context/platform/sdk-overview.md`

---

## Workflow

### Step 1: Initialize SDK and Verify Graph

```python
import kumoai
from kumoai.pquery import RunMode

kumoai.init(url="https://app.kumo.ai", api_key="YOUR_API_KEY")
```

Confirm your graph and PQL query are ready:

```python
graph.validate()
graph.snapshot()       # Required before training
graph.get_edge_stats() # Check relationship health
```

**Expected output**: No errors from `validate()`. Edge stats show reasonable
row counts and FK coverage.

### Step 2: Define PredictiveQuery

Bind your PQL query to the graph.

```python
pquery = kumoai.PredictiveQuery(
    graph=graph,
    query="PREDICT SUM(orders.amount, 0, 30, days) FOR EACH users.user_id"
)

pquery.validate(verbose=True)
print(f"Task type: {pquery.get_task_type()}")
```

**Expected output**: Validation passes. Task type is one of: `regression`,
`binary_classification`, `multiclass_classification`.

**Save for reuse:**

```python
pquery.save("scratch/pquery_revenue_30d")
# Later: pquery = kumoai.PredictiveQuery.load("scratch/pquery_revenue_30d")
```

### Step 3: Generate Training Table

Training tables are historical snapshots the model learns from.

```python
# Auto-suggest a plan
plan = pquery.suggest_training_table_plan(run_mode=RunMode.FAST)

# Customize the plan (all fields default to "inferred"):
plan.start_time = "2024-01-01"        # Training window start
plan.end_time = "2025-01-01"          # Training window end
plan.timeframe_step = 7               # Sample every 7 time units
plan.forecast_length = 12             # For forecasting tasks
plan.lag_timesteps = 7                # Autoregressive lag features
plan.year_over_year = True            # Year-over-year features

# Generate (use non_blocking=True for large datasets)
train_table_job = pquery.generate_training_table(plan, non_blocking=True)

# Monitor progress
print(train_table_job.status())

# Wait for completion (shows progress bar)
train_table = train_table_job.attach()
```

**Inspect the training table before proceeding:**

```python
print(f"Row count: {train_table.count()}")
train_table.head(n=10)
train_table.stats()
train_table.label_distribution()  # Check for class imbalance
```

**Decision point**: If `label_distribution()` shows severe imbalance (e.g.,
99% negative for classification), the model may struggle. Consider adjusting
the time window, entity filter, or using `FocalLossConfig` in the ModelPlan.

### Step 4: Configure ModelPlan

Auto-suggest a training configuration, then customize sub-plans as needed.

```python
model_plan = pquery.suggest_model_plan(run_mode=RunMode.FAST)

# --- TrainingJobPlan ---
model_plan.training_job.num_experiments = 3       # AutoML search width
model_plan.training_job.tune_metric = "auroc"     # Metric to optimize

# --- OptimizationPlan ---
model_plan.optimization.max_epochs = 50           # Max training epochs
model_plan.optimization.base_lr = [0.001, 0.005]  # Learning rate candidates
model_plan.optimization.batch_size = [512, 1024]  # Batch size candidates

# Loss for class imbalance:
from kumoapi.model_plan import FocalLossConfig, EarlyStoppingConfig
model_plan.optimization.loss = [FocalLossConfig(name="focal", alpha=0.25, gamma=2.0)]
model_plan.optimization.early_stopping = [EarlyStoppingConfig(min_delta=0.001, patience=5)]

# --- ModelArchitecturePlan ---
model_plan.model_architecture.channels = [128, 256]

# --- NeighborSamplingPlan ---
model_plan.neighbor_sampling.adaptive_sampling = True

# --- ColumnProcessingPlan ---
model_plan.column_processing.encoder_overrides = {
    "orders.description": "glove_6B"
}
```

**ModelPlan sub-plans:**

| Sub-plan | Key Parameters | Purpose |
|----------|---------------|---------|
| `training_job` | `num_experiments`, `tune_metric`, `pruning`, `refit_trainval` | AutoML config |
| `optimization` | `max_epochs`, `base_lr`, `batch_size`, `loss`, `early_stopping`, `weight_decay` | Training loop |
| `model_architecture` | `channels`, `num_pre/post_message_passing_layers`, `activation` | GNN architecture |
| `neighbor_sampling` | `num_neighbors`, `adaptive_sampling` | Graph sampling |
| `column_processing` | `encoder_overrides`, `na_strategy` | Feature encoding |

**RunMode guidance:**

| Mode | When to Use |
|------|-------------|
| `DEBUG` | Testing only — verify pipeline works end-to-end |
| `FAST` | Default for iteration — quick experiments |
| `NORMAL` | Balanced speed and quality |
| `BEST` | Final production model — highest quality |

Use `FAST` for initial experiments. Switch to `NORMAL` or `BEST` only after
you've validated the task definition, graph, and training table.

### Step 5: Train the Model

```python
trainer = kumoai.Trainer(model_plan)

training_job = trainer.fit(
    graph=graph,
    train_table=train_table,
    non_blocking=True,
    warm_start_job_id=None,      # Set to previous job ID to resume training
    custom_tags={
        "task": "revenue_prediction",
        "version": "v1",
    }
)

print(f"Tracking URL: {training_job.tracking_url}")
```

**Monitor training:**

```python
# Poll status
print(training_job.status())   # 'PENDING', 'RUNNING', 'COMPLETED', 'FAILED'
print(training_job.done())     # bool

# Block until complete
result = training_job.attach()
```

**Save state** — training jobs are long-running. Persist the job ID so you can
resume from a different session:

```python
# Save job ID to scratch
job_id = training_job.job_id
print(f"Training job ID: {job_id}")
# Write this to scratch/YYYY-MM-DD_train.md

# Re-attach from another session
training_job = kumoai.TrainingJob(job_id)
result = training_job.attach()
```

### Step 6: Evaluate Results

```python
# 3-way metric split (test, validation, training)
metrics = result.metrics()
print(metrics)

# What AutoML actually chose (critical for iteration)
actual_plan = result.model_plan
print(f"Best LR: {actual_plan.optimization.base_lr}")
print(f"Best channels: {actual_plan.model_architecture.channels}")

# Holdout predictions vs actuals
holdout_df = result.holdout_df()
print(holdout_df.head(10))
```

**Per-epoch training metrics (diagnose overfitting):**

```python
# Only available while job is running or just completed via the job object
progress = training_job.progress()
for trial_id, trial in progress.trial_progress.items():
    for epoch, m in trial.metrics.items():
        print(f"Trial {trial_id} Ep {epoch}: "
              f"train={m.train_metrics}, val={m.validation_metrics}")
```

**Debug failed jobs:**

```python
status = training_job.status()
for event in status.event_log:
    print(f"{event.stage_name}: {event.detail}")
```

**Quality thresholds** (rules of thumb):

| Task Type | Metric | Weak Signal | Usable | Strong |
|-----------|--------|-------------|--------|--------|
| Binary classification | AUC-ROC | < 0.6 | 0.6–0.8 | > 0.8 |
| Regression | R-squared | < 0.1 | 0.1–0.5 | > 0.5 |
| Multi-class | Macro-F1 | < 0.3 | 0.3–0.6 | > 0.6 |

If metrics are weak:
- Check training table quality (Step 3 — enough rows? balanced labels?)
- Re-run with `RunMode.NORMAL` or `BEST`
- Consider graph quality — are all relevant tables and edges included?
- Try a warm-start from the current model with more epochs

### Step 7: Run Batch Predictions

Generate predictions on new or current entities.

**Step 7a: Generate prediction table**

```python
pred_plan = pquery.suggest_prediction_table_plan(run_mode=RunMode.FAST)

# Customize anchor time for temporal queries:
import datetime
pred_plan.anchor_time = datetime.datetime(2025, 3, 30)
pred_plan.forecast_length = 12     # For forecasting tasks
pred_plan.lag_timesteps = 7        # Autoregressive lag

pred_table = pquery.generate_prediction_table(pred_plan, non_blocking=False)
```

**Step 7b: Run batch prediction**

```python
# Use the same connector from graph construction (see skills/build-graph.md Step 2)
# e.g. connector = kumoai.SnowflakeConnector(name=..., account=..., warehouse=..., database=..., schema_name=...)

prediction_job = trainer.predict(
    graph=graph,
    prediction_table=pred_table,
    output_config=kumoai.OutputConfig(
        output_types={"predictions"},          # or {"predictions", "embeddings"}
        output_connector=connector,
        output_table_name="revenue_predictions",
        output_metadata_fields=[
            kumoai.MetadataField.JOB_TIMESTAMP,
            kumoai.MetadataField.ANCHOR_TIMESTAMP,
        ],
    ),
    binary_classification_threshold=0.5,       # Optional: for binary class labels
    num_workers=1,
    non_blocking=True,
)

prediction_result = prediction_job.attach()
```

**Access results:**

```python
predictions_df = prediction_result.predictions_df()
print(predictions_df.head(10))
print(f"Row count: {len(predictions_df)}")
```

### Step 8: Save State

Persist everything for reproducibility and future sessions.

```python
# Save artifacts
pquery.save("scratch/pquery_revenue_30d")
graph.save("scratch/graph_ecom")

# Save predictions locally
predictions_df.to_parquet("scratch/predictions_revenue_30d.parquet")

# Tag the model for later retrieval
result.tag("revenue-v1")
# Later: model = kumoai.Model.load_by_tag(tag="revenue-v1")
```

Document in scratch file:
- Graph source and version
- PQL query used
- Training table stats (row count, label distribution)
- RunMode used
- Final metrics
- Model ID and tracking URL

---

## Quick Reference

| Step | Method | Key Arguments |
|------|--------|---------------|
| Init | `kumoai.init()` | `url`, `api_key` |
| Define task | `kumoai.PredictiveQuery(graph, query)` | PQL string |
| Validate | `pquery.validate(verbose=True)` | — |
| Plan training table | `pquery.suggest_training_table_plan()` | `run_mode` |
| Customize training plan | `plan.start_time`, `plan.end_time`, etc. | `timeframe_step`, `forecast_length`, `lag_timesteps` |
| Generate training table | `pquery.generate_training_table(plan)` | `non_blocking` |
| Plan model | `pquery.suggest_model_plan()` | `run_mode` |
| Customize model plan | Sub-plans: `training_job`, `optimization`, `model_architecture`, `neighbor_sampling`, `column_processing` | See sdk-overview.md |
| Train | `kumoai.Trainer(plan).fit(graph, train_table)` | `non_blocking`, `warm_start_job_id` |
| Evaluate | `result.metrics()` | — |
| Inspect AutoML result | `result.model_plan` | Shows what AutoML chose |
| Training curves | `training_job.progress()` | Per-epoch train/val metrics |
| Debug failed job | `training_job.status().event_log` | Stage-by-stage log |
| Cancel job | `training_job.cancel()` | — |
| Plan prediction table | `pquery.suggest_prediction_table_plan()` | `run_mode` |
| Generate prediction table | `pquery.generate_prediction_table(plan)` | `non_blocking` |
| Predict | `trainer.predict(graph, pred_table)` | `output_config`, `binary_classification_threshold`, `num_workers` |
| Save model | `result.tag("name")` | — |
| Re-attach | `kumoai.TrainingJob(job_id).attach()` | `job_id` |

### RunMode

| Mode | Speed | Quality | Use Case |
|------|-------|---------|----------|
| `DEBUG` | Fastest | Lowest | Pipeline testing |
| `FAST` | ~4x faster than NORMAL | Good | Experimentation (default) |
| `NORMAL` | Baseline | Balanced | Production candidates |
| `BEST` | ~4x slower than NORMAL | Highest | Final production models |

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `ValidationError: PK not unique` | Duplicate values in primary key | Deduplicate source data or choose different PK |
| `ValidationError: FK references unknown table` | Edge points to missing table | Add table to graph or fix edge definition |
| `ValidationError: dtype mismatch` | FK and PK have incompatible types | Cast to matching types (typically `string`) |
| `PQLSyntaxError` | Invalid PQL query | Run `pquery.validate(verbose=True)` for details |
| `Missing foreign key` | No direct FK between entity and target | Check `graph.get_edge_stats()` and add missing edge |
| `Semantic Type Mismatch` | SUM/AVG on categorical column | Use COUNT, or pick a numeric column |
| `JobFailedError` | Training or prediction job failed | Check `job.error_message()` for details |
| `TimeoutError` | Job exceeded time limit | Use `non_blocking=True` and monitor |
| `ResourceNotFoundError` | Model/table ID not found | Verify ID or re-run job |
| `Cannot set Time Column to dtype 'kumo.string'` | String column set as time | Cast to timestamp before building graph |
| `ConnectionError` | Bad credentials or unreachable API | Verify `kumoai.init()` parameters |

---

## Checklist

- [ ] SDK initialized and authenticated
- [ ] Graph validated and snapshotted
- [ ] PQL query validated — `pquery.validate(verbose=True)` passes
- [ ] Training table generated — row count and label distribution reviewed
- [ ] ModelPlan configured — RunMode appropriate for stage (FAST for experimentation)
- [ ] Model trained — metrics reviewed against quality thresholds
- [ ] `result.model_plan` inspected — AutoML choices reviewed
- [ ] Training progress checked for overfitting (train vs val metrics)
- [ ] Weak signals investigated if metrics are poor
- [ ] Batch predictions generated and output shape verified
- [ ] State saved to `scratch/` (job IDs, metrics, model tags)
- [ ] Model tagged for retrieval
