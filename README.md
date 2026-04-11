# Kumo Coding Agent

A collection of context and skills that extends any LLM coding tool with deep knowledge of the Kumo ML platform.

Works with **Claude Code**, **Codex**, **Cursor**, and any tool that reads markdown.

---

## Installation

### 1. Clone into your project

```bash
cd your-project
git clone https://github.com/kumo-ai/kumo-coding-agent.git kumo-coding-agent
```

### 2. Set up your tool

**<img src="https://anthropic.gallerycdn.vsassets.io/extensions/anthropic/claude-code/2.1.98/1775762394471/Microsoft.VisualStudio.Services.Icons.Default" width="20" height="20" align="top"> Claude Code**

```bash
echo 'Also read kumo-coding-agent/CLAUDE.md for Kumo agent capabilities.' >> CLAUDE.md
npx skills add kumo-ai/kumo-coding-agent --all    # optional: installs /kumo-issue and /kumo-pr
```

**<img src="https://raw.githubusercontent.com/lobehub/lobe-icons/refs/heads/master/packages/static-png/dark/codex.png" width="20" height="20" align="top"> Codex**

Codex reads `AGENTS.md` automatically. Install slash commands inside a Codex session:

```
$skill-installer install https://github.com/kumo-ai/kumo-coding-agent
```

**<img src="https://img.icons8.com/color/512/cursor-ai.png" width="20" height="20" align="top"> Cursor**

Cursor reads `.cursor/rules/` automatically. Install slash commands:

```bash
npx skills add kumo-ai/kumo-coding-agent --all
```

### 3. Install the SDK

```bash
pip install kumoai
```

### 4. Start using it

Ask questions in natural language:

```
"Predict which customers will churn in the next 30 days"
"Run RFM on the SALT dataset"
"Write a PQL query for average order value per user"
"Help me connect to my Snowflake warehouse"
```

---

## Updating

```bash
cd kumo-coding-agent && git pull
```

To pin to a specific version:

```bash
cd kumo-coding-agent && git checkout v1.0.0
```

---

## What Can It Do?

| Task | Start Here |
|------|------------|
| Build a prediction model end-to-end | `skills/scope-prediction-task.md` |
| Get instant predictions (no training) | `skills/rfm-predict.md` |
| Write or fix a PQL query | `skills/write-pql.md` |
| Train a high-accuracy model | `skills/train-model.md` |
| Debug a failed prediction | `skills/debug-prediction.md` |
| Improve weak model performance | `skills/iterate-model.md` |
| Design a SQL+PQL business workflow | `context/patterns/prediction-patterns.md` |
| Decide between RFM and training | `context/guides/rfm-vs-training.md` |

---

## Commands

Two slash commands for reporting issues and contributing fixes.
Requires GitHub CLI (`brew install gh && gh auth login`).

| Command | What it does |
|---------|-------------|
| `/kumo-issue [description]` | Files a GitHub issue on this repo |
| `/kumo-pr [description]` | Creates a branch, fixes a doc, and opens a PR |

---

## Directory Structure

```
kumo-coding-agent/
├── CLAUDE.md              # Entry point for Claude Code
├── AGENTS.md              # Entry point for Codex
├── .cursor/rules/         # Entry point for Cursor
├── context/               # Curated Kumo knowledge (loaded on demand)
│   ├── platform/          # SDK, RFM, PQL, graph, connectors
│   ├── guides/            # Decision guides
│   ├── patterns/          # Business workflow patterns
│   └── verticals/         # Industry-specific guides
├── skills/                # Step-by-step workflows
├── meta/                  # Internal maintenance tools
├── scratch/               # Session state (gitignored)
└── eval/                  # Quality tests
```

---

<p align="center">
  Developed by <a href="https://kumo.ai">Kumo AI</a><br>
  &copy; 2026 Kumo AI, Inc. All rights reserved.
</p>
