# Iterate on Model Quality

Diagnose why predictions are weak and systematically improve them. This is the
most important skill for achieving strong results — the difference between a
useless model and a great one is almost always in the iteration, not the first
attempt.

---

## Prerequisites

- A prediction has already been run (RFM or trained model)
- Evaluation metrics are available (AUC, RMSE, R², etc.)
- The graph, PQL query, and data are accessible
- **Read first**: `context/guides/rfm-vs-training.md`, `context/platform/pql-errors.md`

---

## Workflow

### Step 1: Assess Current Quality

Get your baseline metrics:

**RFM:**

```python
metrics_df = model.evaluate(query, run_mode="fast")
print(metrics_df)
```

**Enterprise SDK:**

```python
# 3-way metrics (test, validation, training)
metrics = result.metrics()
print(metrics)

# What AutoML chose — inspect before tuning further
actual_plan = result.model_plan
print(f"LR: {actual_plan.optimization.base_lr}, "
      f"Channels: {actual_plan.model_architecture.channels}")

# Per-epoch curves — diagnose overfitting vs underfitting
progress = training_job.progress()
for trial_id, trial in progress.trial_progress.items():
    for epoch, m in trial.metrics.items():
        print(f"  Ep {epoch}: train_loss={m.train_metrics.get('loss')}, "
              f"val_loss={m.validation_metrics.get('loss')}")

holdout_df = result.holdout_df()
```

**Quality bands:**

| Task Type | Metric | Weak | Usable | Strong | Excellent |
|-----------|--------|------|--------|--------|-----------|
| Binary classification | AUC-ROC | < 0.6 | 0.6–0.75 | 0.75–0.85 | > 0.85 |
| Regression | R² | < 0.1 | 0.1–0.3 | 0.3–0.6 | > 0.6 |
| Multi-class | Macro-F1 | < 0.3 | 0.3–0.5 | 0.5–0.7 | > 0.7 |

**If metrics are in the "Usable" band**, they may already be good enough for
the business use case. Ask the user what accuracy they need before optimizing.

### Step 2: Diagnose the Root Cause

Work through this decision tree **in order**. Fix the first problem you find
before moving to the next — most weak predictions have one dominant cause.

```
Weak metrics
│
├── 1. Is the task well-defined?
│   ├── Is "churn" defined concretely? Is the target column correct?
│   ├── Is the time window reasonable for the business question?
│   └── FIX: Redefine the task → Step 3
│
├── 2. Is the data quality good?
│   ├── Are there enough rows? (< 1K entities is very thin)
│   ├── Is the target column mostly NULL or mostly one value?
│   ├── Are timestamps correct? (string timestamps, time gaps)
│   └── FIX: Fix data quality → Step 4
│
├── 3. Is the graph correct?
│   ├── Are all relevant tables included?
│   ├── Are FK links correct (no false positives from infer_links)?
│   ├── Is the time column set on event tables?
│   └── FIX: Fix graph → Step 5
│
├── 4. Is this the right approach?
│   ├── Are you using RFM when training would help?
│   ├── Are you using FAST mode when NORMAL/BEST would help?
│   ├── Check result.model_plan — did AutoML choose poor hyperparameters?
│   └── FIX: Change approach → Step 6
│
└── 5. Is the signal genuinely weak?
    ├── Have you tried all the above?
    ├── Is this problem inherently hard to predict?
    └── FIX: Accept or reframe → Step 7
```

### Step 3: Fix Task Definition

The most common cause of weak predictions is a bad task definition.

**Symptoms:**
- AUC near 0.5 (random — model learned nothing)
- All predictions are the same value
- Metrics don't improve regardless of changes

**Things to try:**

| Change | When | Example |
|--------|------|---------|
| Adjust time window | Window too short (not enough signal) or too long (too noisy) | Try 7, 14, 30, 60, 90 days and compare |
| Change aggregation | Wrong metric for the question | SUM instead of COUNT, or COUNT > 0 instead of COUNT |
| Change target column | Column doesn't capture the right signal | Use `order_date` presence instead of `revenue` for churn |
| Change entity | Predicting at wrong grain | Per-account instead of per-user, or per-product instead of per-order |
| Add WHERE filter | Population is too broad | Filter to active customers only: `WHERE customers.status = 'active'` |
| Change threshold | Binary threshold doesn't match the question | `COUNT > 0` vs `COUNT > 5` vs `SUM > 1000` |

**How to test:** Run each variation through RFM evaluate and compare metrics.
This is cheap and fast — try 3-5 variations before settling.

```python
# Quick A/B: compare two time windows
for window in [7, 14, 30, 60, 90]:
    query = f"PREDICT COUNT(orders.*, 0, {window}, days) > 0 FOR EACH customers.customer_id"
    metrics = model.evaluate(query, run_mode="fast")
    print(f"Window={window:3d}d  {metrics}")
```

### Step 4: Fix Data Quality

**Symptoms:**
- Metrics are unstable (vary wildly between runs)
- Model performs well on training but badly on holdout
- Errors during training or prediction

**Things to check and fix:**

| Issue | Detection | Fix |
|-------|-----------|-----|
| **Class imbalance** (99% one class) | `train_table.label_distribution()` | Change task: adjust window, threshold, or definition |
| **Too few rows** (< 1K entities) | `train_table.count()` | Can't fix with training — use RFM instead |
| **Stale data** (latest record > 60 days ago) | Check `MAX(timestamp)` | Get fresh data or acknowledge predictions may be outdated |
| **Time gaps** (months of missing data) | Plot event counts by month | Exclude gap period or warn user |
| **NULL-heavy target** (> 30% NULL in target column) | `df['target'].isnull().mean()` | Choose a different target or filter NULLs |
| **Constant column** (1 unique value) | `df['col'].nunique()` | Remove — it adds no signal |
| **Leaky features** (derived from the target) | Inspect column definitions | Remove the leaky column from the graph |

### Step 5: Fix Graph Structure

**Symptoms:**
- "Missing foreign key" errors
- Predictions seem to ignore important information
- Adding tables doesn't change metrics

**Things to try:**

| Change | When | How |
|--------|------|-----|
| **Add a table** | Missing feature information | `graph.add_table(...)` or rebuild |
| **Remove a table** | Noisy or irrelevant table dilutes signal | Rebuild graph without it |
| **Fix a link** | `infer_links()` created a wrong connection | `graph.link(src_table, fkey, dst_table)` |
| **Add a missing link** | Two tables should be connected but aren't | Manually add the edge |
| **Fix time column** | Wrong column set as time, or time column missing | Set correct `time_column` on the table |
| **Fix PK** | Wrong column set as primary key | Rebuild table with correct PK |

**Quick test**: Run RFM evaluate after each graph change to see if metrics improve.

### Step 6: Change Approach

If task, data, and graph are all correct but metrics are still weak:

| Current Approach | Try Instead | Expected Improvement |
|------------------|-------------|---------------------|
| RFM `run_mode="fast"` | RFM `run_mode="best"` | Small (1-5% AUC lift) |
| RFM (any mode) | Enterprise SDK with `RunMode.FAST` | Moderate (5-15% AUC lift if enough data) |
| SDK `RunMode.FAST` | SDK `RunMode.NORMAL` | Small–moderate (2-8% AUC lift) |
| SDK `RunMode.NORMAL` | SDK `RunMode.BEST` | Small (1-5% AUC lift) |
| SDK default config | Tune hyperparameters | Variable (depends on what's wrong) |

**Hyperparameter tuning** (Enterprise SDK only):

```python
# More experiments (wider AutoML search)
model_plan.training_job.num_experiments = 5

# More training epochs
model_plan.optimization.max_epochs = 100

# Larger model capacity
model_plan.model_architecture.channels = [128, 256]

# Learning rate search range
model_plan.optimization.base_lr = [1e-4, 5e-4, 1e-3, 5e-3]

# Batch size search
model_plan.optimization.batch_size = [256, 512, 1024]

# Loss for class imbalance
from kumoapi.model_plan import FocalLossConfig, EarlyStoppingConfig
model_plan.optimization.loss = [FocalLossConfig(name="focal", alpha=0.25, gamma=2.0)]

# Early stopping to prevent overfitting
model_plan.optimization.early_stopping = [EarlyStoppingConfig(min_delta=0.001, patience=5)]

# Adaptive neighbor sampling
model_plan.neighbor_sampling.adaptive_sampling = True

# Text encoding override
model_plan.column_processing.encoder_overrides = {
    'orders.description': 'glove_6B'
}

# Warm-start (continue training from previous model)
result = trainer.fit(graph, train_table, warm_start_job_id="trainingjob-xxx")
```

**Tuning playbook** — match the symptom to the parameter:

| Symptom | Parameter to Tune | Direction |
|---------|------------------|-----------|
| Underfitting (train loss still dropping) | `optimization.max_epochs` | Increase |
| Overfitting (train good, holdout bad) | `optimization.weight_decay` | Increase ([1e-4, 1e-3]) |
| Class imbalance hurting recall | `optimization.loss` | Use `FocalLossConfig` |
| Training too slow | `optimization.batch_size` | Increase |
| Missing graph signal | `neighbor_sampling.adaptive_sampling` | Enable |
| LR too high/low (unstable loss) | `optimization.base_lr` | Widen search range |
| Model capacity too small | `model_architecture.channels` | Use [256, 512] |
| Text columns not contributing | `column_processing.encoder_overrides` | Add text encoder |

**Note on explainability:** The Enterprise SDK has no built-in feature importance API. To understand what drives predictions:
- Run RFM `explain=True` on the same query for feature attributions
- Analyze `holdout_df()` manually — slice predictions by feature values to find drivers
- Use `graph.get_table_stats(wait_for="full")` to check column distributions

### Step 7: Accept or Reframe

If you've tried everything and metrics are still in the "Weak" band:

**The signal may genuinely be weak.** Not everything is predictable. This is a
valid finding — communicate it clearly to the user.

**How to communicate:**
- "Based on the available data, [task] has limited predictability (AUC 0.58).
  This means the model is slightly better than random, but not reliable enough
  for automated decision-making."
- "I recommend either: (a) collecting additional data that may improve signal,
  (b) reframing the question — for example, predicting over a shorter/longer
  window, or predicting a different but related metric."

**Alternative framings:**

| Original Task | Alternative | Why It Might Work Better |
|---------------|-------------|--------------------------|
| Churn in 30 days | Churn in 90 days | Longer window captures more signal |
| Revenue next month | Revenue > $0 (binary) | Binary is easier to predict than exact amount |
| Will they buy product X? | Will they buy anything? | Broader target has more signal |
| Predict exact count | Predict count > 0 (binary) | Binary classification is more robust |

---

## Iteration Log Template

Track your experiments in your scratch file:

```markdown
## Iteration Log

| # | Change | AUC/R² | Delta | Notes |
|---|--------|--------|-------|-------|
| 0 | Baseline (RFM, 30d window) | 0.58 | — | Weak signal |
| 1 | Changed window to 90d | 0.62 | +0.04 | Moderate improvement |
| 2 | Added PRODUCTS table to graph | 0.63 | +0.01 | Marginal |
| 3 | Switched to Enterprise SDK FAST | 0.71 | +0.08 | Significant jump |
| 4 | Enterprise SDK NORMAL | 0.74 | +0.03 | Good enough for production |

**Decision**: Use iteration #4 (SDK NORMAL, 90d window, with PRODUCTS table)
```

---

## Quick Reference: What to Try, Ordered by Effort

| # | Change | Effort | Typical Impact |
|---|--------|--------|----------------|
| 1 | Different time window (7, 30, 90d) | 5 min | High — often the biggest lever |
| 2 | Different aggregation or threshold | 5 min | High — redefines the task |
| 3 | Add/remove tables from graph | 10 min | Medium — adds or removes signal |
| 4 | Fix wrong FK links | 10 min | Medium–High if link was wrong |
| 5 | Switch RFM → Enterprise SDK | 1–4 hours | Medium (5-15% AUC lift) |
| 6 | Run SDK with NORMAL/BEST | +1–4 hours | Small–Medium |
| 7 | Tune hyperparameters | 2–8 hours | Variable |
| 8 | Collect more/better data | Days–weeks | High (if feasible) |

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| AUC = 0.50 exactly | Model learned nothing — task is random or broken | Check task definition (Step 3) |
| AUC dropped after adding a table | New table adds noise, not signal | Remove it, it's hurting |
| Training AUC = 0.90, holdout AUC = 0.55 | Overfitting — too little data or data leakage | Check for leaky features, reduce model complexity |
| Metrics improve with longer window | Short window has too little signal | Use the longer window if business allows |
| All predictions are the same value | Class imbalance or broken target | Check `label_distribution()` |
| Train & val loss both high, not converging | Underfitting — check `training_job.progress()` epoch metrics | Increase `max_epochs`, model capacity, or learning rate |

---

## Checklist
- [ ] Baseline metrics recorded
- [ ] Root cause diagnosed (task? data? graph? approach? weak signal?)
- [ ] First fix applied and re-evaluated
- [ ] Iteration log maintained in scratch file
- [ ] At least 3 variations tried before concluding signal is weak
- [ ] Best configuration identified with metrics
- [ ] Results communicated to user with recommendation
