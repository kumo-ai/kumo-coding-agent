# Sync Context from Source Repos

Orchestrate syncing kumo-agent context docs from upstream source repositories.
Delegates to per-repo sub-skills for the actual work.

---

## Prerequisites

- Access to source repos (local clones, PyPI, or GitHub)
- `context/_sources.yaml` is up to date

---

## Usage Modes

### Mode 1: Sync a Specific Repo

When you know which repo changed (e.g., new kumoai release):

1. Read `context/_sources.yaml` — note the `_repo_versions` block
2. Run the appropriate sub-skill with the target version:

| Repo | Sub-skill | Package |
|------|-----------|---------|
| kumo-sdk | `meta/skills/sync/sync-kumo-sdk.md` | `kumoai` |
| kumo-pql | `meta/skills/sync/sync-kumo-pql.md` | `kumopql` |
| kumo-api | `meta/skills/sync/sync-kumo-api.md` | `kumoapi` |

Example: "Sync from kumo-sdk v2.12.0" → run `sync-kumo-sdk.md` with
`target_version=2.12.0`.

### Mode 2: Full Sync (All Repos)

When doing a periodic freshness check or coordinated version bump:

1. Run `meta/skills/validate-freshness.md` to identify stale repos
2. Determine the latest version for each stale repo:
   ```bash
   pip index versions kumoai 2>/dev/null | head -1
   pip index versions kumopql 2>/dev/null | head -1
   pip index versions kumoapi 2>/dev/null | head -1
   ```
3. Run sub-skills **in dependency order**:
   1. `sync-kumo-api.md` first (shared types — may cascade to other docs)
   2. `sync-kumo-pql.md` second (grammar — independent of SDK)
   3. `sync-kumo-sdk.md` last (depends on kumo-api types)
4. After all syncs, run `meta/skills/check-gaps.md` for a full audit

### Mode 3: GitHub Action Triggered

When a GitHub Action triggers a sync (via `workflow_dispatch` or
`repository_dispatch`):

1. The action provides `repo` and `target_version` as inputs
2. The matching sub-skill is run automatically
3. A PR is created with the changes for human review

See `.github/workflows/sync-kumo-agent.yml` for the workflow definition.

---

## Dependency Order

```
kumo-api  ──→  kumo-pql  ──→  kumo-sdk
(types)        (grammar)       (SDK APIs)
```

**Why this order matters:** kumo-api defines shared types (RunMode, TimeUnit,
AggregationType) that are referenced in docs owned by both kumo-sdk and
kumo-pql. If kumo-api enum values change but kumo-sdk docs are synced first,
the SDK docs will have stale type references.

kumo-pql and kumo-api are independent of each other — either can go first.
kumo-sdk should always be last.

---

## Cross-Repo Dependency Table

| If this changes in kumo-api | These docs need updating |
|----------------------------|------------------------|
| RunMode enum | sdk-overview.md, rfm-overview.md, train-model.md, rfm-predict.md |
| TimeUnit enum | pql-syntax.md, rfm-overview.md, write-pql.md |
| AggregationType enum | pql-syntax.md, rfm-overview.md |
| Dtype / Stype enums | sdk-overview.md, graph-construction.md |
| ModelPlan sub-plans | sdk-overview.md, train-model.md, iterate-model.md |

---

## Source-to-Context Mapping

Reference table — the sub-skills contain the authoritative per-repo mappings.

| Context Doc | Primary Repo | Sub-Skill |
|-------------|-------------|-----------|
| `platform/rfm-overview.md` | kumo-sdk | sync-kumo-sdk.md |
| `platform/sdk-overview.md` | kumo-sdk + kumo-api | sync-kumo-sdk.md (primary), sync-kumo-api.md (types) |
| `platform/pql-syntax.md` | kumo-pql + kumo-api | sync-kumo-pql.md (primary), sync-kumo-api.md (types) |
| `platform/pql-errors.md` | kumo-pql | sync-kumo-pql.md |
| `platform/graph-construction.md` | kumo-sdk | sync-kumo-sdk.md |
| `platform/data-connectors.md` | kumo-sdk | sync-kumo-sdk.md |
| `patterns/prediction-patterns.md` | kumo-ai-engineering | Manual (no sub-skill) |
| `guides/rfm-vs-training.md` | n/a | Authored — manual review only |
| `guides/interpret-results.md` | n/a | Authored — manual review only |

---

## Checklist

- [ ] Identified which repos need syncing (freshness check or trigger)
- [ ] Determined target versions for each repo
- [ ] Ran sub-skills in dependency order (api → pql → sdk)
- [ ] Cross-repo dependencies checked
- [ ] Full gap audit completed (if Mode 2)
- [ ] All changes committed
