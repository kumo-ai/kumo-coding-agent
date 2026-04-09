# Kumo Data Science Agent

A self-contained, portable collection of context and skills that extends any LLM with deep knowledge of the Kumo ML platform. Everything the agent needs is inside this repository — no external files or repositories are required at runtime.

Works with Claude Code, Codex, Cursor, or any LLM tool that reads markdown.

## Use Cases

| What You Want to Do | Start Here |
|---------------------|------------|
| Build a prediction model end-to-end | `skills/scope-prediction-task.md` then follow the chain |
| Get instant predictions (no training) | `skills/rfm-predict.md` |
| Write or fix a PQL query | `skills/write-pql.md` |
| Train a high-accuracy model | `skills/train-model.md` |
| Debug a failed prediction | `skills/debug-prediction.md` |
| Improve weak model performance | `skills/iterate-model.md` |
| Design a SQL+PQL business workflow | `context/patterns/prediction-patterns.md` |
| Decide between RFM and Training | `context/guides/rfm-vs-training.md` |

## Quick Start

### Claude Code

Clone the repo into your project, then add a reference to your project's `CLAUDE.md`:

```bash
cd your-project
git clone https://github.com/kumo-ai/DS-agent.git ds-agent
echo 'Also read ds-agent/CLAUDE.md for Kumo data science agent capabilities.' >> CLAUDE.md
```

### Codex

Clone the repo into your project. Codex reads `AGENTS.md` which points to `CLAUDE.md`.

```bash
cd your-project
git clone https://github.com/kumo-ai/DS-agent.git ds-agent
```

### Cursor

Clone the repo into your project. Cursor reads `.cursor/rules/` which points to `CLAUDE.md`.

```bash
cd your-project
git clone https://github.com/kumo-ai/DS-agent.git ds-agent
```

### Then

Ask a question — the agent loads relevant context docs on demand.

For environment setup (uv, kumoai, credentials), see `context/platform/data-connectors.md`.

## Commands

Two commands are available when working in this repo with Claude Code or Codex:

| Command | Purpose |
|---------|---------|
| `/ds-agent-issue [description]` | Report a gap, bug, or feature request |
| `/ds-agent-pr [description]` | Fix a skill/doc and open a PR |

Requires `gh` CLI (`brew install gh && gh auth login`).

To make commands available in **any project** on your machine:

```bash
make install-slash-commands    # symlinks to ~/.claude/skills/ and ~/.agents/skills/
make uninstall-slash-commands  # remove
```

## Directory Structure

```
DS-agent/
├── CLAUDE.md              # Entry point: routing table + hard rules
├── AGENTS.md              # Codex entry point (points to CLAUDE.md)
├── .cursor/rules/         # Cursor entry point (points to CLAUDE.md)
├── context/               # Curated knowledge (loaded on demand)
│   ├── platform/          # SDK, RFM, PQL, graph, connectors (6 docs)
│   ├── guides/            # Decision guides: RFM vs training, interpreting results
│   ├── patterns/          # Business workflow patterns (SQL+PQL)
│   ├── _sources.yaml      # Provenance: what version each doc was synced from
│   └── _gaps.yaml         # Known gaps: missing docs + platform limitations
├── skills/                # Step-by-step workflows (8 skills)
├── meta/                  # Self-improvement infrastructure
│   ├── skills/            # How to add, sync, verify, and audit knowledge
│   │   └── sync/          # Per-repo sync sub-skills (kumo-sdk, kumo-pql, kumo-api)
│   └── templates/         # Templates for new docs and skills
├── scratch/               # Session state for long-running experiments (gitignored)
└── eval/                  # Test questions to verify agent quality
```

## Extending the Agent

### Add knowledge or skills

| Action | Instructions |
|--------|-------------|
| Add a context document | `meta/skills/add-context-doc.md` — copy template, write 200-400 lines, add to `_sources.yaml` and routing table, add eval questions |
| Add a workflow skill | `meta/skills/add-skill.md` — copy template, write workflow, add to routing table |

### Sync from upstream repos

When a new version of `kumoai`, `kumopql`, or `kumoapi` is released:

| Approach | How |
|----------|-----|
| Sync one repo | Run the sub-skill directly: `meta/skills/sync/sync-kumo-sdk.md`, `sync-kumo-pql.md`, or `sync-kumo-api.md` with a `target_version` |
| Full sync | Run `meta/skills/sync-from-source.md` — orchestrates all three in dependency order (api → pql → sdk) |
| Automated | `.github/workflows/sync-context.yml` — triggered by `workflow_dispatch` or `repository_dispatch` from upstream CI |

Current versions tracked in `context/_sources.yaml` under `_repo_versions`.

### Check freshness and correctness

| Action | Instructions |
|--------|-------------|
| Which docs are stale? | `meta/skills/validate-freshness.md` — compares doc versions against latest PyPI releases |
| Do docs match source code? | `meta/skills/verify-content.md` — cross-checks every factual claim against authoritative source |

### Report a gap

If you discover something wrong, missing, or unsupported:

1. Check `context/_gaps.yaml` — is it already tracked?
2. If not, add an entry following the format in that file (type: `documentation` for features that exist but aren't documented, `platform` for features that don't exist)
3. Run `meta/skills/check-gaps.md` to audit the full manifest and detect which gaps are now resolvable

Gaps are checked automatically during every sync and verify-content run.

## Testing the Agent

The `eval/` directory contains question banks that test whether the agent answers correctly. See `eval/README.md` for details.

After any content change, run the relevant eval to verify no regression.

## Design Principles

- **Portable**: Plain markdown + YAML, works with any LLM tool
- **On-demand loading**: `CLAUDE.md` is small; context loaded only when needed
- **Version-tracked**: Every doc traces to a specific package version via `_sources.yaml`
- **Self-correcting**: Gap manifest + verify-content catch drift between docs and code
- **Testable**: Eval questions verify knowledge quality
