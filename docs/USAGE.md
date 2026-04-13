# Kumo Coding Agent — Usage Guide

Get Kumo data science superpowers in any LLM-powered coding tool.

---

## What Is It?

A portable collection of markdown files that teaches your LLM tool how to use the Kumo ML platform — writing PQL queries, running predictions, building graphs, and more. No packages to install, no build step.

---

## Setup

### Prerequisites

| Tool | Install | Required for |
|------|---------|--------------|
| **GitHub CLI** | `brew install gh && gh auth login` | `/kumo-issue` and `/kumo-pr` commands |
| **kumoai** | `pip install kumoai` | Running predictions |

### Add to your project

**Using git submodule (recommended — supports updates):**

```bash
cd your-project
git submodule add https://github.com/kumo-ai/kumo-coding-agent.git kumo-coding-agent
```

**Or clone directly:**

```bash
cd your-project
git clone https://github.com/kumo-ai/kumo-coding-agent.git kumo-coding-agent
```

### Tool-specific setup

**Claude Code** — add a reference to your project's `CLAUDE.md`:

```bash
echo 'Also read kumo-coding-agent/CLAUDE.md for Kumo agent capabilities.' >> CLAUDE.md
```

**Codex** — reads `AGENTS.md` automatically. No extra setup needed.

**Cursor** — reads `.cursor/rules/` automatically. No extra setup needed.

### Install slash commands (optional)

For `/kumo-issue` and `/kumo-pr`, use the `--agent` flag to target only your tool (avoids polluting the project with folders for every other agent):

```bash
# Claude Code
npx skills add kumo-ai/kumo-coding-agent --agent claude-code

# Cursor
npx skills add kumo-ai/kumo-coding-agent --agent cursor
```

For Codex, use `$skill-installer` inside a Codex session:

```
$skill-installer install https://github.com/kumo-ai/kumo-coding-agent
```

---

## Updating

```bash
# Git submodule:
git submodule update --remote kumo-coding-agent

# Git clone:
cd kumo-coding-agent && git pull
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

## Commands

Two commands for reporting issues and contributing fixes:

### `/kumo-issue [description]`

Reports a gap, bug, or feature request as a GitHub issue on `kumo-ai/kumo-coding-agent`.

```
/kumo-issue agent didn't know about Databricks Unity Catalog options
/kumo-issue pql-syntax.md says MODE is a valid aggregation but it isn't
```

### `/kumo-pr [description]`

Fixes a skill or context doc and opens a pull request.

```
/kumo-pr add Databricks connector details to data-connectors.md
/kumo-pr fix the time unit list in pql-syntax.md
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
