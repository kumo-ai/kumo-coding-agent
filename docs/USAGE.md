# DS-agent Usage Guide

Get Kumo data science superpowers in any LLM-powered coding tool.

---

## What Is DS-agent?

A portable collection of markdown files that teaches your LLM tool how to use the Kumo ML platform — writing PQL queries, running predictions, building graphs, and more. No packages to install, no build step.

---

## Setup

### Prerequisites

| Tool | Install | Required for |
|------|---------|--------------|
| **GitHub CLI** | `brew install gh && gh auth login` | Slash commands (`/ds-agent-import`, `/ds-agent-issue`, `/ds-agent-pr`) |
| **kumoai** | `pip install kumoai` | Running predictions (not the agent itself) |

### Claude Code

Clone the repo into your project, or use `/ds-agent-import` if slash commands
are installed globally. Claude Code reads `CLAUDE.md` as the entry point and
auto-discovers slash commands from `.claude/skills/`.

```bash
git clone https://github.com/kumo-ai/DS-agent.git ds-agent
# Or from within Claude Code: /ds-agent-import
```

### Codex

Clone the repo into your project. Codex reads `CLAUDE.md` and auto-discovers
slash commands from `.agents/skills/`. Always provide arguments inline —
Codex runs headless with no interactive prompts.

```bash
git clone https://github.com/kumo-ai/DS-agent.git ds-agent
```

### Cursor

Clone the repo into your project. Cursor reads `CLAUDE.md` and all context
docs and skills work. Slash commands are not available in Cursor — use the
manual clone.

```bash
git clone https://github.com/kumo-ai/DS-agent.git ds-agent
```

### Global slash commands (optional)

To make `/ds-agent-import`, `/ds-agent-issue`, and `/ds-agent-pr` available
from **any** project (Claude Code and Codex only):

```bash
# From the DS-agent repo
make install-slash-commands

# To remove later
make uninstall-slash-commands
```

---

## Using the Agent

Once set up, just ask questions in natural language:

```
"Predict which customers will churn in the next 30 days"
"Write a PQL query for average order value per user"
"Help me connect to my Snowflake warehouse"
"What's the difference between RFM and training a model?"
```

The agent reads `CLAUDE.md` as its routing table, then loads only the relevant context docs and skills on demand.

---

## Slash Commands

Three commands are available in Claude Code and Codex:

### `/ds-agent-import`

Downloads DS-agent from GitHub into your current project.

```
/ds-agent-import
```

- Downloads `ds-agent/` from `kumo-ai/DS-agent@main`
- Adds a reference to your project's `CLAUDE.md`
- Adds scratch files to `.gitignore`
- No local clone of DS-agent needed

### `/ds-agent-issue [description]`

Reports a gap, bug, or feature request as a GitHub issue on `kumo-ai/DS-agent`.

```
/ds-agent-issue agent didn't know about Databricks Unity Catalog options
/ds-agent-issue pql-syntax.md says MODE is a valid aggregation but it isn't
/ds-agent-issue add a healthcare vertical
```

Omit the description in Claude Code to be prompted interactively. In Codex (headless), always provide it inline.

### `/ds-agent-pr [description]`

Fixes a skill or context doc and opens a pull request on `kumo-ai/DS-agent`.

```
/ds-agent-pr add Databricks connector details to data-connectors.md
/ds-agent-pr fix the time unit list in pql-syntax.md
```

Creates a branch, makes the edit, runs verification checks, and opens the PR — all in one command. Omit the description in Claude Code to be prompted interactively.

---

## What's Inside

```
ds-agent/
├── CLAUDE.md              # Entry point and routing table
├── context/               # Curated Kumo knowledge (loaded on demand)
│   ├── platform/          # SDK, RFM, PQL, graph, connectors
│   ├── guides/            # Decision guides (RFM vs training, interpreting results)
│   ├── patterns/          # Business workflow patterns (SQL + PQL)
│   └── verticals/         # Industry-specific guides (fraud, demand forecasting)
├── skills/                # Step-by-step workflows
├── meta/                  # Self-improvement: add docs, sync from upstream, verify
└── scratch/               # Session state for experiments (gitignored)
```

---

## Quick Reference

| I want to... | Start here |
|--------------|------------|
| Build a prediction model end-to-end | `skills/scope-prediction-task.md` |
| Get instant predictions (no training) | `skills/rfm-predict.md` |
| Write or fix a PQL query | `skills/write-pql.md` |
| Train a high-accuracy model | `skills/train-model.md` |
| Debug a failed prediction | `skills/debug-prediction.md` |
| Improve weak model performance | `skills/iterate-model.md` |
| Decide between RFM and training | `context/guides/rfm-vs-training.md` |
| Design a SQL + PQL workflow | `context/patterns/prediction-patterns.md` |
