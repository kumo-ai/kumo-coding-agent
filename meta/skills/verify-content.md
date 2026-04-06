# Verify Content Against Source Code

Cross-check factual claims in context docs and skills against the authoritative source code. Documentation drifts from code — this skill catches the drift.

---

## Prerequisites

- Access to the installed `kumoai` / `kumopql` / `kumoapi` packages (or their source repos)
- The context doc or skill you want to verify
- **Why this matters**: Every content bug fixed in the March 2026 audit was a case where documentation was trusted over code. Time units, RunMode values, ASSUMING constraints, and aggregation functions were all wrong in docs but correct in the parser grammar and API enums.

---

## Workflow

### Step 1: Extract Factual Claims

Read the document and list every concrete, verifiable claim. Focus on:

| Claim Type | Example | Why It Drifts |
|------------|---------|---------------|
| Enum values | "RunMode: FAST, NORMAL, THOROUGH" | Renamed in code but not docs |
| Valid syntax tokens | "Time units: days, hours, weeks" | Grammar updated, docs not |
| Aggregation functions | "Supported: SUM, AVG, COUNT, MODE" | Functions added/removed in parser |
| API signatures | `model.predict(query, run_mode="fast")` | Parameters renamed or reordered |
| Validation rules | "ASSUMING requires negative time window" | Validator logic changed |
| Default values | "run_mode defaults to NORMAL" | Default changed in code |

Skip subjective claims ("use FAST for prototyping") — those aren't verifiable against code.

### Step 2: Look Up the Authoritative Source

For each claim type, consult the correct source. Do not trust other documentation — read the actual code.

| Claim Type | Authoritative Source | How to Find |
|------------|---------------------|-------------|
| PQL time units | `kumopql/grammar/PQLGrammar.g4` (`TIME_UNIT` rule) | `grep -r "TIME_UNIT" <kumopql package path>` |
| PQL aggregations | `kumopql/grammar/PQLGrammar.g4` (`AGGR` rule) | `grep -r "AGGR" <kumopql package path>` |
| PQL ASSUMING rules | `kumopql/validator/time_range_validator.py` | Search for `whatif_ast` or `ASSUMPTION` |
| RunMode values | `kumoapi/model_plan.py` (`RunMode` enum) | `grep -r "class RunMode" <kumoapi package path>` |
| TimeUnit values | `kumoapi/typing.py` (`TimeUnit` enum) | `grep -r "class TimeUnit" <kumoapi package path>` |
| AggregationType values | `kumoapi/typing.py` (`AggregationType` enum) | `grep -r "class AggregationType" <kumoapi package path>` |
| SDK API signatures | `kumoai` package source | `grep -r "def predict\|def evaluate\|def fit" <kumoai package path>` |
| RFM API signatures | `kumoai/experimental/rfm/` | Read the module directly |
| Column types (Dtype/Stype) | `kumoapi/typing.py` | `grep -r "class Dtype\|class Stype" <kumoapi package path>` |

**Finding installed package paths:**

```bash
python -c "import kumopql; print(kumopql.__file__)"
python -c "import kumoapi; print(kumoapi.__file__)"
python -c "import kumoai; print(kumoai.__file__)"
```

Or search in `.venv/`:

```bash
find .venv -name "PQLGrammar.g4"
find .venv -name "model_plan.py" -path "*/kumoapi/*"
find .venv -name "typing.py" -path "*/kumoapi/*"
```

### Step 3: Compare and Record Discrepancies

For each claim, compare the doc against the code. Record findings:

```markdown
## Verification: <document name>

| Claim | In Doc | In Code | Match? | Fix |
|-------|--------|---------|--------|-----|
| Time units | days, hours, weeks, months | days, hours, minutes, months | NO | Replace weeks with minutes |
| RunMode | FAST, NORMAL, THOROUGH | FAST, NORMAL, BEST, DEBUG | NO | THOROUGH→BEST, add DEBUG |
| Aggregations | SUM, AVG, MIN, MAX, COUNT, MODE | SUM, AVG, MIN, MAX, COUNT | NO | Remove MODE |
| ASSUMING window | negative time window | non-negative only | NO | Fix examples and rules |
```

### Step 4: Apply Fixes

For each discrepancy:

1. Fix the claim in the context doc or skill
2. Search for the same wrong claim in **all** other files — errors propagate

```bash
# Example: find all files mentioning the wrong value
grep -ri "THOROUGH" context/ skills/
grep -ri "MODE" skills/ context/
grep -ri "weeks" context/ skills/  # if weeks is not a valid PQL time unit
```

3. Fix every occurrence, not just the first one found
4. Update eval expected answers if they contain the wrong claim

### Step 5: Check Gap Manifest

After verifying existing claims, check `context/_gaps.yaml` for documentation
gaps that may now be resolvable:

```bash
cat context/_gaps.yaml
```

For each `documentation_gaps` entry with `status: open`:
1. Grep for the `check` pattern in the SDK source
2. If found → document the feature in the affected files and mark resolved
3. If not found → leave open

For each `platform_gaps` entry with `status: open`:
1. Search for the feature in the SDK source
2. If now present → move to documentation_gaps, then document
3. If still absent → verify the workaround is still accurate

See `meta/skills/check-gaps.md` for the full procedure.

### Step 6: Update Verification Log

Add a note to the document's Source header recording the verification:

```markdown
> Source: <original source> | Last synced: YYYY-MM-DD
>
> Verified against `kumo-pql` parser grammar and `kumo-api` type
> definitions on YYYY-MM-DD.
```

---

## Quick Reference: Known Authoritative Values

These are the values as of 2026-03-31. When verifying, always re-read the
source code — do not trust this table if it may be stale.

**PQL Time Units** (from `PQLGrammar.g4`):
`days`, `hours`, `minutes`, `months`

**PQL Aggregations** (from `PQLGrammar.g4`):
`SUM`, `AVG`, `MIN`, `MAX`, `COUNT`, `COUNT_DISTINCT`, `FIRST`, `LAST`, `LIST_DISTINCT`

**RFM Supported Aggregations** (subset — rest are Enterprise only):
`SUM`, `AVG`, `MIN`, `MAX`, `COUNT`

**PQL Comparison Operators** (from `PQLGrammar.g4`):
`=`, `!=`, `<`, `>`, `<=`, `>=`, `IS`, `IS NOT`, `IN`, `IS IN`, `LIKE`, `NOT LIKE`, `CONTAINS`, `NOT CONTAINS`, `STARTS WITH`, `ENDS WITH`

**RunMode** (from `kumoapi/model_plan.py`):
`DEBUG`, `FAST`, `NORMAL`, `BEST`

**Stype** (from `kumoapi/typing.py`):
`numerical`, `categorical`, `multicategorical`, `ID`, `text`, `timestamp`, `sequence`, `image`, `unsupported`

**Dtype** (from `kumoapi/typing.py`):
`bool`, `int`, `byte`, `int16`, `int32`, `int64`, `float`, `float32`, `float64`, `string`, `binary`, `date`, `time`, `timedelta`, `floatlist`, `intlist`, `stringlist`, `unsupported`

**ASSUMING Constraints** (from `kumopql/validator/time_range_validator.py`):
- Only valid with aggregation targets (not static column predictions)
- Time windows inside ASSUMING must be non-negative (start >= 0, end >= 0)

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Can't find package source | Package not installed in current env | Check `.venv/` or install with `uv add kumoai` |
| Grammar file not found | `kumopql` not installed or different version | `find .venv -name "*.g4"` |
| Code contradicts another doc | Two docs disagree on a value | Code wins. Fix both docs. |
| Claim not in code | Doc describes a feature that doesn't exist in code | Feature may be planned but not shipped — remove from doc |
| Code has value not in doc | New feature added in code but not documented | Add to doc if it's stable and user-facing |

---

## Checklist

- [ ] All factual claims extracted from the document
- [ ] Authoritative source located for each claim type
- [ ] Source code read (not other docs) for each verification
- [ ] Discrepancies recorded with exact before/after
- [ ] Fixes applied to the document under review
- [ ] Same wrong claim searched across **all** kumo-agent files
- [ ] Eval expected answers updated if affected
- [ ] Gap manifest checked — resolved gaps documented, new gaps added
- [ ] Source header updated with verification date
