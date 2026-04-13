# Check Gaps

Audit `context/_gaps.yaml` to find gaps that have been resolved upstream
(feature now exists in SDK) or documentation gaps that have been filled.
Run this during every sync or verify cycle, or on demand.

---

## Prerequisites

- `context/_gaps.yaml` exists
- Access to the installed `kumoai` / `kumoapi` packages (or their source repos)

---

## Workflow

### Step 1: Load the Gap Manifest

```bash
cat context/_gaps.yaml
```

### Step 2: Check Documentation Gaps

For each entry in `documentation_gaps` with `status: open`:

1. **Grep for the check pattern** in the SDK source:

```bash
# Find the package root
KUMOAI_ROOT=$(python -c "import kumoai; import os; print(os.path.dirname(kumoai.__file__))")

# Check if the feature exists
grep -rn "<check pattern>" "$KUMOAI_ROOT/<check_path>"
```

2. **Classify the result:**

| grep result | Meaning | Action |
|-------------|---------|--------|
| Match found | Feature exists in SDK | → Step 3 (resolve) |
| No match | Feature still missing or renamed | Check if renamed; if truly missing, leave open |
| File not found | check_path may be wrong or package restructured | Update check_path |

### Step 3: Resolve Documentation Gaps

For each gap where the feature now exists:

1. **Read the actual API** — get the full signature, params, return type
2. **Update each file in `affects`** — add the feature with correct API details
3. **Mark the gap as resolved** in `_gaps.yaml`:

```yaml
    status: resolved
    resolved: "YYYY-MM-DD"
```

4. **Add eval questions** if the feature is significant enough to test

### Step 4: Check Platform Gaps

For each entry in `platform_gaps` with `status: open`:

1. **Search for the feature** in the SDK source:

```bash
# Example: check if enterprise explainability was added
grep -rn "explain" "$KUMOAI_ROOT/trainer/"
```

2. **If the feature now exists:**
   - Move the entry from `platform_gaps` to `documentation_gaps` (it's now a doc gap)
   - Update `check` and `check_path` fields
   - Follow Step 3 to document it

3. **If still missing:**
   - Verify the workaround is still accurate
   - Leave as open

### Step 5: Check for New Gaps

Look for SDK features that aren't in `_gaps.yaml` AND aren't in the agent docs:

```bash
# List all public methods on key classes
grep -rn "def [a-z]" "$KUMOAI_ROOT/trainer/job.py" | grep -v "def _"
grep -rn "def [a-z]" "$KUMOAI_ROOT/graph/graph.py" | grep -v "def _"
grep -rn "def [a-z]" "$KUMOAI_ROOT/experimental/rfm/rfm.py" | grep -v "def _"
```

Cross-reference against what's documented in `context/platform/sdk-overview.md`
and `context/platform/rfm-overview.md`. Any public method not in the docs
and not in `_gaps.yaml` is a **new gap** — add it.

### Step 6: Generate Report

```markdown
## Gap Audit Report — YYYY-MM-DD

### Resolved (ready to document)
| ID | Feature | Verified In |
|----|---------|-------------|
| doc-001 | training_job.progress() | kumoai 2.12.0 |

### Still Open
| ID | Feature | Priority | Notes |
|----|---------|----------|-------|
| plat-001 | Fine-tuned explainability | high | Still absent |

### New Gaps Found
| Feature | Source File | Suggested Priority |
|---------|------------|-------------------|
| trainer.baseline() | trainer/trainer.py | medium |

### Summary
- X documentation gaps resolved
- Y platform gaps still open
- Z new gaps discovered
```

---

## Checklist

- [ ] All `documentation_gaps` with `status: open` checked against SDK source
- [ ] All `platform_gaps` with `status: open` checked for new SDK additions
- [ ] Resolved gaps documented in affected files
- [ ] Resolved gaps marked with `status: resolved` and date
- [ ] New undocumented features added as new gap entries
- [ ] Report generated
