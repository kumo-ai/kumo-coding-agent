# Sync from kumo-sdk

Update kumo-coding-agent context docs when a new version of the `kumoai` package is
released. Covers RFM API, Enterprise SDK, graph construction, and connectors.

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `target_version` | Yes | — | kumoai PyPI version to sync to (e.g., "2.12.0") |
| `source_path` | No | — | Local clone or venv path; if omitted, install from PyPI |

---

## Prerequisites

- Access to `kumoai` package at target version (PyPI or local)
- `context/_sources.yaml` is current
- **Read first**: `context/_sources.yaml` — note current `kumo-sdk` version

---

## Source File Checklist

| Source File (repo-relative) | What to Extract | Affected Context Doc |
|---|---|---|
| `kumoai/experimental/rfm/rfm.py` | KumoRFM.predict(), evaluate(), batch_mode(), get_train_table(), ExplainConfig | `platform/rfm-overview.md` |
| `kumoai/experimental/rfm/graph.py` | RFM Graph, from_data, from_snowflake, validate, link/unlink | `platform/rfm-overview.md`, `platform/graph-construction.md` |
| `kumoai/trainer/trainer.py` | Trainer.fit(), predict(), baseline() signatures | `platform/sdk-overview.md` |
| `kumoai/trainer/job.py` | TrainingJobResult, BatchPredictionJobResult, progress(), model_plan | `platform/sdk-overview.md` |
| `kumoai/trainer/online_serving.py` | OnlineServingEndpoint, ping(), update(), predict() | `platform/sdk-overview.md` |
| `kumoai/graph/graph.py` | Graph, get_table_stats(), get_edge_stats(), visualize() | `platform/sdk-overview.md`, `platform/graph-construction.md` |
| `kumoai/pquery/training_table.py` | TrainingTable, data_df(), export(), update() | `platform/sdk-overview.md` |
| `kumoai/pquery/prediction_table.py` | PredictionTable, anchor_time() | `platform/sdk-overview.md` |
| `kumoai/connector/*.py` | SnowflakeConnector, DatabricksConnector, S3Connector | `platform/data-connectors.md` |

---

## Workflow

### Step 0: Version Gate

```bash
# Read current version
grep -A1 "kumo-sdk:" context/_sources.yaml | grep -oP '"\K[^"]+'
```

Compare `current_version` against `target_version`:
- If target == current → skip, already synced
- If target > current → proceed
- If target < current → warn, downgrade not supported

### Step 1: Obtain Source at Target Version

**Option A: Install into temp venv**
```bash
uv venv /tmp/kumo-sync-venv
uv pip install --python /tmp/kumo-sync-venv kumoai==<target_version>
KUMOAI_ROOT=/tmp/kumo-sync-venv/lib/python3.*/site-packages/kumoai
```

**Option B: Use local clone or existing venv**
```bash
KUMOAI_ROOT=<source_path>/kumoai
# Verify version
python -c "import kumoai; print(kumoai.__version__)"
```

### Step 2: Check Gaps

Read `context/_gaps.yaml`. For each entry with `check_path` starting with
`kumoai/` and `status: open`:

```bash
grep -rn "<check pattern>" "$KUMOAI_ROOT/<check_path relative to kumoai/>"
```

Record which gaps are now resolvable. These will be documented in Step 4.

**Gap entries for this repo:**

| Gap ID | Feature | check | check_path |
|--------|---------|-------|------------|
| doc-001 | training_job.progress() | `def progress` | kumoai/trainer/job.py |
| doc-002 | result.model_plan | `model_plan` | kumoai/trainer/job.py |
| doc-003 | graph.get_table_stats() | `def get_table_stats` | kumoai/graph/graph.py |
| doc-004 | graph.visualize() | `def visualize` | kumoai/graph/graph.py |
| doc-005 | training_table.data_df() | `def data_df` | kumoai/pquery/training_table.py |
| doc-006 | batch_prediction_result inspection | `def summary` | kumoai/trainer/job.py |
| doc-007 | batch_prediction_job.progress() | `class PredictionProgress` | kumoapi/jobs.py |
| doc-008 | job cancel() | `def cancel` | kumoai/trainer/job.py |
| doc-009 | JobStatusReport.event_log | `event_log` | kumoapi/jobs.py |
| doc-010 | endpoint.ping() | `def ping` | kumoai/trainer/online_serving.py |
| doc-011 | BaselineJobResult.metrics() | `class BaselineJobResult` | kumoai/trainer/job.py |
| doc-012 | prediction_table.anchor_time() | `def anchor_time` | kumoai/pquery/prediction_table.py |
| plat-001 | Enterprise explainability | `explain` in trainer/ | kumoai/trainer/ |
| plat-002 | Per-example explanations | `explain` in trainer/ | kumoai/trainer/ |

### Step 3: Diff Source Files

For each file in the Source File Checklist:

1. Read the source file at target version
2. Extract all public method signatures (`def <name>` excluding `_private`)
3. Compare against claims in the affected context doc
4. Record material changes:
   - New methods or parameters
   - Changed signatures (renamed params, new defaults)
   - Removed or deprecated features
   - Changed return types

Skip cosmetic changes (docstring rewording, internal refactors).

### Step 4: Update Context Docs

For each doc with material changes:

1. Update the relevant sections
2. Update the Source header: version and date
3. Preserve document structure (Overview, Quick Reference, Common Pitfalls)
4. If a gap entry was resolved, document the feature and mark resolved in `_gaps.yaml`

### Step 5: Update `_sources.yaml`

For each updated doc:
```yaml
  version: "<target_version>"
  last_sync: "YYYY-MM-DD"
```

Update the repo-level version:
```yaml
_repo_versions:
  kumo-sdk: "<target_version>"
```

### Step 6: Update Skills If Affected

Check these skills for code examples that reference updated APIs:

| Skill | When to Update |
|-------|---------------|
| `skills/rfm-predict.md` | RFM API changes (predict, evaluate, explain signatures) |
| `skills/train-model.md` | Trainer, ModelPlan, TrainingTable, PredictionTable changes |
| `skills/iterate-model.md` | Diagnostic or tuning API changes |
| `skills/build-graph.md` | Graph construction API changes |
| `skills/explore-data.md` | Connector or SourceTable changes |

### Step 7: Repo-Specific Verification

After updating docs, verify:

1. **RFM API signatures**: Every `model.predict()` / `model.evaluate()` call in
   `platform/rfm-overview.md` and `skills/rfm-predict.md` must match actual `rfm.py`

2. **Enterprise SDK signatures**: Every `trainer.fit()` / `trainer.predict()` call
   in `platform/sdk-overview.md` and `skills/train-model.md` must match actual code

3. **Cross-repo types**: If RunMode or TimeUnit references appear in updated docs,
   verify they still match `kumoapi/typing.py`. If kumo-api has also updated,
   flag that `sync-kumo-api.md` should run first.

```bash
# Quick check: grep for RunMode values in updated docs
grep -rn "RunMode\|run_mode" context/platform/sdk-overview.md skills/train-model.md
```

### Step 8: Run Verify-Content

Run `meta/skills/verify-content.md` on every updated context doc to catch
any remaining drift between docs and source code.

### Step 9: Review Eval

```bash
cat eval/questions/rfm-knowledge.yaml
cat eval/questions/pql-knowledge.yaml
```

If new APIs were added, add eval questions. If APIs were removed, update
expected answers.

### Step 10: Commit

```bash
git add context/ skills/ eval/
git commit -m "sync kumo-coding-agent from kumo-sdk v<target_version>

Updated: <list of updated docs>
Changes: <brief summary of material changes>"
```

---

## Checklist

- [ ] Version gate passed (target > current)
- [ ] Source obtained at correct version
- [ ] Gap manifest checked (14 entries for this repo)
- [ ] All 9 source files diffed against context docs
- [ ] Material changes applied to context docs
- [ ] `_sources.yaml` versions and dates updated
- [ ] Affected skills updated (rfm-predict, train-model, iterate-model, build-graph)
- [ ] RFM and SDK API signatures verified against source
- [ ] Cross-repo type references checked
- [ ] Content verified via verify-content.md
- [ ] Eval questions reviewed and updated
- [ ] Changes committed
