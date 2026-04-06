# Validate Context Freshness

Check which context documents are potentially stale and may need syncing
from source repos. Uses both date-based and version-based staleness checks.

---

## Prerequisites

- `context/_sources.yaml` exists (with `_repo_versions` and per-doc `version` fields)
- Today's date (for age calculation)

---

## Workflow

### Step 1: Read the Manifest

```bash
cat context/_sources.yaml
```

Note the `_repo_versions` block at the top for current repo-level versions.

### Step 2: Check Latest Available Versions

For each repo in `_repo_versions`, check the latest published version:

```bash
pip index versions kumoai 2>/dev/null | head -1     # kumo-sdk
pip index versions kumopql 2>/dev/null | head -1     # kumo-pql
pip index versions kumoapi 2>/dev/null | head -1     # kumo-api
```

Or check GitHub release tags if not on PyPI.

### Step 3: Classify Each Document

For each entry, classify freshness using **two signals**:

**Version staleness** (stronger signal):

| Classification | Criteria |
|----------------|----------|
| **Current** | Doc `version` matches latest available version |
| **Behind** | Latest version is newer than doc `version` |
| **Unknown** | Cannot determine latest version |

**Date staleness** (weaker signal, use when version check unavailable):

| Classification | Criteria |
|----------------|----------|
| **Fresh** | Synced within 14 days |
| **Potentially stale** | 14-30 days since last sync |
| **Stale** | 30+ days since last sync |

Version staleness takes precedence. A doc synced yesterday is still stale if
the package has been updated since.

### Step 4: Generate Report

```markdown
## Context Freshness Report — YYYY-MM-DD

### Repo Versions
| Repo | Synced Version | Latest Version | Status |
|------|---------------|----------------|--------|
| kumo-sdk | 2.16.3 | 2.16.3 | Current |
| kumo-pql | 6caec97 | 6caec97 | Current |
| kumo-api | 0.74.0 | 0.74.0 | Current |

### Document Details
| Document | Repo | Version | Last Synced | Status |
|----------|------|---------|-------------|--------|
| platform/rfm-overview.md | kumo-sdk | 2.16.3 | 2026-03-31 | Current |
| platform/pql-syntax.md | kumo-pql | 6caec97 | 2026-03-31 | Current |
| guides/rfm-vs-training.md | n/a | n/a | 2026-03-30 | Fresh (authored) |
```

### Step 5: Recommend Actions

For repos that are **behind**:
- Run the per-repo sync sub-skill with the latest version:
  - `meta/skills/sync/sync-kumo-sdk.md` (target_version=X.Y.Z)
  - `meta/skills/sync/sync-kumo-pql.md` (target_version=X.Y.Z)
  - `meta/skills/sync/sync-kumo-api.md` (target_version=X.Y.Z)
- Sync in dependency order: kumo-api → kumo-pql → kumo-sdk

For repos that are **current** but date-stale (30+ days):
- The docs are at the right version but may benefit from a freshness check
- Run `meta/skills/verify-content.md` rather than a full sync

For **authored docs** (source_repo: n/a):
- Only date staleness applies
- Review content for accuracy if 30+ days old

---

## Checklist

- [ ] Manifest read (`_repo_versions` + per-doc versions)
- [ ] Latest available versions checked (PyPI or GitHub)
- [ ] Version comparison done for each repo
- [ ] Date staleness checked as secondary signal
- [ ] Freshness report generated
- [ ] Behind repos flagged with target versions for sync
