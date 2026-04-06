# Sync from kumo-api

Update DS-agent docs when a new version of the `kumoapi` package is released.
Covers shared data models: RunMode, TimeUnit, ModelPlan sub-plans, loss configs,
and job result types.

**Cross-repo impact:** kumo-api types are referenced by docs owned by kumo-sdk
and kumo-pql. If enum values change, this sync updates ALL affected docs.

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `target_version` | Yes | — | kumoapi PyPI version to sync to (e.g., "0.41.0") |
| `source_path` | No | — | Local clone or venv path; if omitted, install from PyPI |

---

## Prerequisites

- Access to `kumoapi` package at target version
- `context/_sources.yaml` is current
- **Read first**: `context/_sources.yaml` — note current `kumo-api` version
- **Important**: Run this sync BEFORE `sync-kumo-sdk.md` and `sync-kumo-pql.md`
  when doing a full sync. Shared types must be updated first.

---

## Source File Checklist

| Source File | What to Extract | Affected Context Doc(s) |
|---|---|---|
| `kumoapi/model_plan.py` | RunMode enum, ModelPlan, 5 sub-plans, FocalLossConfig, HuberLossConfig, QuantileLossConfig, EarlyStoppingConfig | `platform/sdk-overview.md` |
| `kumoapi/typing.py` | TimeUnit, AggregationType, Dtype, Stype enums | `platform/pql-syntax.md`, `platform/sdk-overview.md` |
| `kumoapi/jobs.py` | AutoTrainerProgress, PredictionProgress, JobStatusReport, ModelEvaluationMetrics, BaselineEvaluationMetrics | `platform/sdk-overview.md` |

---

## Workflow

### Step 0: Version Gate

```bash
grep -A1 "kumo-api:" context/_sources.yaml | grep -oP '"\K[^"]+'
```

Compare current vs target. Skip if already synced.

### Step 1: Obtain Source at Target Version

```bash
uv venv /tmp/api-sync-venv
uv pip install --python /tmp/api-sync-venv kumoapi==<target_version>
KUMOAPI_ROOT=/tmp/api-sync-venv/lib/python3.*/site-packages/kumoapi
```

### Step 2: Check Gaps

Read `context/_gaps.yaml`. Gap entries relevant to this repo:

| Gap ID | Feature | check | check_path |
|--------|---------|-------|------------|
| doc-007 | batch_prediction_job.progress() | `class PredictionProgress` | kumoapi/jobs.py |
| doc-009 | JobStatusReport.event_log | `event_log` | kumoapi/jobs.py |

### Step 3: Extract Enum Values

Extract every enum and compare against docs. These are the authoritative
type definitions for the entire platform.

```bash
# RunMode
grep -A10 "class RunMode" "$KUMOAPI_ROOT/model_plan.py"

# TimeUnit
grep -A10 "class TimeUnit" "$KUMOAPI_ROOT/typing.py"

# AggregationType
grep -A15 "class AggregationType" "$KUMOAPI_ROOT/typing.py"

# Dtype
grep -A15 "class Dtype" "$KUMOAPI_ROOT/typing.py"

# Stype
grep -A15 "class Stype" "$KUMOAPI_ROOT/typing.py"
```

### Step 4: Extract ModelPlan Structure

```bash
# Sub-plan classes
grep "class.*Plan" "$KUMOAPI_ROOT/model_plan.py"

# All fields on each sub-plan
grep -A50 "class OptimizationPlan" "$KUMOAPI_ROOT/model_plan.py" | head -60
grep -A30 "class TrainingJobPlan" "$KUMOAPI_ROOT/model_plan.py" | head -40
grep -A30 "class ModelArchitecturePlan" "$KUMOAPI_ROOT/model_plan.py" | head -40
grep -A20 "class NeighborSamplingPlan" "$KUMOAPI_ROOT/model_plan.py" | head -30
grep -A20 "class ColumnProcessingPlan" "$KUMOAPI_ROOT/model_plan.py" | head -30

# Loss config classes
grep -B2 -A10 "class.*LossConfig" "$KUMOAPI_ROOT/model_plan.py"
```

Compare against `platform/sdk-overview.md` ModelPlan section:
- New sub-plan fields → add to parameter tables
- Renamed fields → update all references
- New loss configs → add to loss function options table
- Removed fields → remove from docs

### Step 5: Extract Job Result Types

```bash
# AutoTrainerProgress structure
grep -A30 "class AutoTrainerProgress" "$KUMOAPI_ROOT/jobs.py" | head -40

# JobStatusReport structure
grep -A20 "class JobStatusReport" "$KUMOAPI_ROOT/jobs.py" | head -30

# ModelEvaluationMetrics
grep -A15 "class ModelEvaluationMetrics" "$KUMOAPI_ROOT/jobs.py" | head -20
```

Compare against `platform/sdk-overview.md` Training Diagnostics section.

### Step 6: Cross-Repo Grep

**This is the critical step.** Search the ENTIRE DS-agent tree for
references to enum values that may have changed:

```bash
# If RunMode values changed
grep -rn "RunMode\|DEBUG\|FAST\|NORMAL\|BEST" context/ skills/

# If TimeUnit values changed
grep -rn "TimeUnit\|days\|hours\|minutes\|months" context/platform/pql-syntax.md

# If AggregationType values changed
grep -rn "SUM\|AVG\|MIN\|MAX\|COUNT" context/platform/pql-syntax.md

# If Dtype/Stype values changed
grep -rn "stype\|dtype" context/platform/sdk-overview.md
```

Fix every occurrence of old values. Do not leave stale references.

### Step 7: Update Context Docs

Primary doc to update: `platform/sdk-overview.md`

Also update if enum values changed:
- `platform/pql-syntax.md` (TimeUnit, AggregationType)
- `platform/rfm-overview.md` (RunMode, run_mode values)
- `platform/graph-construction.md` (Dtype, Stype)

Update Source headers with version and date.

### Step 8: Update `_sources.yaml`

```yaml
_repo_versions:
  kumo-api: "<target_version>"
```

Note: per-doc `version` fields stay at their `source_repo` version (kumo-sdk
or kumo-pql). The kumo-api version is tracked at the repo level only since
it doesn't own docs directly.

### Step 9: Update Skills If Affected

| Skill | When to Update |
|-------|---------------|
| `skills/train-model.md` | ModelPlan sub-plan changes, new loss configs |
| `skills/iterate-model.md` | Tuning playbook parameter names |
| `skills/write-pql.md` | TimeUnit or AggregationType changes |

### Step 10: Update Authoritative Values

If any enum values changed, update the "Known Authoritative Values" section
in `meta/skills/verify-content.md`:

```markdown
**RunMode** (from `kumoapi/model_plan.py`):
`DEBUG`, `FAST`, `NORMAL`, `BEST`

**PQL Time Units** (from `PQLGrammar.g4`):
`days`, `hours`, `minutes`, `months`
```

### Step 11: Review Eval

```bash
cat eval/questions/pql-knowledge.yaml
cat eval/questions/rfm-knowledge.yaml
```

If ModelPlan structure changed, update questions pql-021 through pql-024.
If RunMode values changed, update relevant expected answers.

### Step 12: Commit

```bash
git add context/ skills/ eval/ meta/
git commit -m "sync DS-agent from kumo-api v<target_version>

Updated: <list of updated docs>
Changes: <summary — e.g., 'new QuantileLossConfig, RunMode.TURBO added'>"
```

---

## Cross-Repo Dependency Table

| If This Changes | These Docs Need Updating |
|-----------------|------------------------|
| RunMode enum | sdk-overview.md, rfm-overview.md, skills/train-model.md, skills/rfm-predict.md |
| TimeUnit enum | pql-syntax.md, rfm-overview.md, skills/write-pql.md |
| AggregationType enum | pql-syntax.md, rfm-overview.md |
| Dtype / Stype enums | sdk-overview.md, graph-construction.md |
| ModelPlan sub-plans | sdk-overview.md, skills/train-model.md, skills/iterate-model.md |
| Loss configs | sdk-overview.md, skills/train-model.md, skills/iterate-model.md |
| Job result types | sdk-overview.md, skills/train-model.md |

---

## Checklist

- [ ] Version gate passed
- [ ] Source obtained at correct version
- [ ] Gap manifest checked (doc-007, doc-009)
- [ ] All enum values extracted and compared
- [ ] ModelPlan structure diffed (sub-plans, fields, loss configs)
- [ ] Job result types diffed
- [ ] **Cross-repo grep completed** — all old values fixed across entire tree
- [ ] Context docs updated
- [ ] `_sources.yaml` repo version updated
- [ ] Affected skills updated
- [ ] verify-content.md "Known Authoritative Values" updated
- [ ] Eval questions reviewed
- [ ] Changes committed
