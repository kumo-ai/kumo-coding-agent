# Sync from kumo-pql

Update kumo-coding-agent PQL documentation when a new version of the `kumopql`
package is released. Covers PQL syntax, grammar rules, and error messages.

**Grammar is authoritative.** If a doc says one thing and `PQLGrammar.g4`
says another, the grammar wins.

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `target_version` | Yes | — | kumopql version to sync to (e.g., "0.9.0") |
| `source_path` | No | — | Local clone or venv path; if omitted, install from PyPI |

---

## Prerequisites

- Access to `kumopql` package at target version
- `context/_sources.yaml` is current
- **Read first**: `context/_sources.yaml` — note current `kumo-pql` version

---

## Source File Checklist

| Source File | What to Extract | Affected Context Doc |
|---|---|---|
| `kumopql/grammar/PQLGrammar.g4` | TIME_UNIT tokens, AGGR tokens, PREDICT syntax, ASSUMING grammar, FOR EACH syntax | `platform/pql-syntax.md` |
| `kumopql/validator/time_range_validator.py` | ASSUMING constraints, window validation, start >= 0 rules | `platform/pql-syntax.md`, `platform/pql-errors.md` |
| `kumopql/validator/*.py` | All validator classes, error messages, validation rules | `platform/pql-errors.md` |
| `docs/PQL_SYNTAX_REFERENCE.md` | Narrative syntax documentation | `platform/pql-syntax.md` |
| `docs/PQL_FAILURE_CATEGORIES.md` | Failure category catalog | `platform/pql-errors.md` |
| `docs/PQL_SYNTAX_ERRORS.md` | Error message catalog with examples | `platform/pql-errors.md` |

---

## Workflow

### Step 0: Version Gate

```bash
grep -A1 "kumo-pql:" context/_sources.yaml | grep -oP '"\K[^"]+'
```

Compare current vs target. Skip if already synced.

### Step 1: Obtain Source at Target Version

```bash
uv venv /tmp/pql-sync-venv
uv pip install --python /tmp/pql-sync-venv kumopql==<target_version>
KUMOPQL_ROOT=/tmp/pql-sync-venv/lib/python3.*/site-packages/kumopql
```

Or use local clone at the target tag.

### Step 2: Check Gaps

Read `context/_gaps.yaml`. Currently no gap entries have `check_path` under
`kumopql/`, but check anyway — new gaps may have been added since last sync.

### Step 3: Extract Grammar Tokens

This is the critical step unique to kumo-pql. Extract the authoritative
values directly from the grammar:

```bash
# Time units
grep -oP "TIME_UNIT\s*:\s*\K.*" "$KUMOPQL_ROOT/grammar/PQLGrammar.g4"

# Aggregation functions
grep -oP "AGGR\s*:\s*\K.*" "$KUMOPQL_ROOT/grammar/PQLGrammar.g4"

# ASSUMING grammar rules
grep -A5 "assuming" "$KUMOPQL_ROOT/grammar/PQLGrammar.g4"
```

Compare each extracted list against the corresponding section in
`platform/pql-syntax.md`:
- "PQL Time Units" list
- "Aggregation Functions" list
- "ASSUMING Clause" section

Any mismatch → update the doc to match the grammar.

### Step 4: Extract Validator Rules

```bash
# ASSUMING constraints
grep -rn "whatif_ast\|ASSUMPTION\|start.*>=.*0" "$KUMOPQL_ROOT/validator/"

# All error message strings
grep -rn "raise.*Error\|ValidationError\|PQLError" "$KUMOPQL_ROOT/validator/"
```

Compare against `platform/pql-errors.md`:
- New error messages → add to error catalog
- Changed validation rules → update constraint descriptions
- Removed errors → remove from catalog

### Step 5: Diff Documentation Files

Read the narrative docs from the source repo:
- `docs/PQL_SYNTAX_REFERENCE.md`
- `docs/PQL_FAILURE_CATEGORIES.md`
- `docs/PQL_SYNTAX_ERRORS.md`

Compare against context docs for material changes (new sections, changed
explanations, new examples).

### Step 6: Update Context Docs

Apply changes to:
- `context/platform/pql-syntax.md` — update token lists, syntax rules, examples
- `context/platform/pql-errors.md` — update error catalog, failure categories

Update Source headers with new version and date.

### Step 7: Update `_sources.yaml`

```yaml
_repo_versions:
  kumo-pql: "<target_version>"

platform/pql-syntax.md:
  version: "<target_version>"
  last_sync: "YYYY-MM-DD"

platform/pql-errors.md:
  version: "<target_version>"
  last_sync: "YYYY-MM-DD"
```

### Step 8: Update Skills If Affected

| Skill | When to Update |
|-------|---------------|
| `skills/write-pql.md` | Syntax changes, new aggregations, new time units |
| `skills/debug-prediction.md` | New error messages or failure categories |

### Step 9: Grammar-First Verification

**This step is mandatory.** Re-read the grammar file and verify every
factual claim in the updated docs:

| Claim Type | Authoritative Source | How to Check |
|------------|---------------------|-------------|
| Time units | `PQLGrammar.g4` TIME_UNIT rule | List all alternations |
| Aggregations | `PQLGrammar.g4` AGGR rule | List all alternations |
| ASSUMING rules | `time_range_validator.py` | Read validation logic |
| RFM_SDK_V2 subset | `PQLGrammar.g4` mode-specific rules | Check mode guard |
| Error messages | `kumopql/validator/*.py` | Grep all raise statements |

Also update the "Known Authoritative Values" section in
`meta/skills/verify-content.md` if any values changed.

### Step 10: Review Eval

```bash
cat eval/questions/pql-knowledge.yaml
```

If new syntax was added (e.g., new aggregation function), add eval questions.
If syntax was removed, update expected answers.

### Step 11: Commit

```bash
git add context/ skills/ eval/ meta/
git commit -m "sync kumo-coding-agent from kumo-pql v<target_version>

Updated: pql-syntax.md, pql-errors.md
Changes: <summary — e.g., 'added MEDIAN aggregation, new time unit weeks'>"
```

---

## Checklist

- [ ] Version gate passed
- [ ] Source obtained at correct version
- [ ] Grammar tokens extracted (TIME_UNIT, AGGR, ASSUMING)
- [ ] Token lists compared against pql-syntax.md
- [ ] Validator rules extracted and compared against pql-errors.md
- [ ] Documentation files diffed
- [ ] Context docs updated
- [ ] `_sources.yaml` versions and dates updated
- [ ] Affected skills updated (write-pql, debug-prediction)
- [ ] **Grammar-first verification passed** (all claims match grammar)
- [ ] verify-content.md "Known Authoritative Values" updated if needed
- [ ] Eval questions reviewed and updated
- [ ] Changes committed
