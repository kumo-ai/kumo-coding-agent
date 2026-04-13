# Kumo Coding Agent

A portable collection of context and skills that extends any LLM coding tool with deep knowledge of the Kumo ML platform.

Works with **Claude Code**, **Codex**, **Cursor**, and any tool that reads markdown.

---

## Setup

### Prerequisites

- **kumoai**: `pip install kumoai` (needed for running predictions, not for the agent itself)
- **GitHub CLI**: `brew install gh && gh auth login` (needed only for `/kumo-issue` and `/kumo-pr` commands)

---

### <img src="https://anthropic.gallerycdn.vsassets.io/extensions/anthropic/claude-code/2.1.98/1775762394471/Microsoft.VisualStudio.Services.Icons.Default" width="24" height="24" align="top"> Claude Code

**1. Add the agent to your project:**

```bash
cd your-project
git submodule add https://github.com/kumo-ai/kumo-coding-agent.git kumo-coding-agent
```

**2. Tell Claude Code to read the agent:**

```bash
echo 'Also read kumo-coding-agent/CLAUDE.md for Kumo agent capabilities.' >> CLAUDE.md
```

**3. Install slash commands (optional):**

```bash
npx skills add kumo-ai/kumo-coding-agent --agent claude-code
```

This installs `/kumo-issue` and `/kumo-pr` for reporting bugs and contributing fixes.

**4. Start using it.** Ask questions in natural language:

```
"Predict which customers will churn in the next 30 days by running RFM on the SALT dataset"
```

---

### <img src="https://raw.githubusercontent.com/lobehub/lobe-icons/refs/heads/master/packages/static-png/dark/codex.png" width="24" height="24" align="top"> Codex

**1. Add the agent to your project:**

```bash
cd your-project
git submodule add https://github.com/kumo-ai/kumo-coding-agent.git kumo-coding-agent
```

**2. No extra setup needed.** Codex reads `AGENTS.md` automatically.

**3. Install slash commands (optional).** Inside a Codex session:

```
$skill-installer install https://github.com/kumo-ai/kumo-coding-agent
```

**4. Start using it.** Ask questions in natural language.

---

### <img src="https://img.icons8.com/color/512/cursor-ai.png" width="24" height="24" align="top"> Cursor

**1. Add the agent to your project:**

```bash
cd your-project
git submodule add https://github.com/kumo-ai/kumo-coding-agent.git kumo-coding-agent
```

**2. No extra setup needed.** Cursor reads `.cursor/rules/` automatically.

**3. Install slash commands (optional):**

```bash
npx skills add kumo-ai/kumo-coding-agent --agent cursor
```

**4. Start using it.** Ask questions in natural language.

---

### Other tools

Clone the repo into your project. Any LLM tool that reads markdown can use `CLAUDE.md` as the entry point.

```bash
git clone https://github.com/kumo-ai/kumo-coding-agent.git kumo-coding-agent
```

---

## Updating

To pull the latest version of the agent:

```bash
git submodule update --remote kumo-coding-agent
```

If you used `git clone` instead of submodule:

```bash
cd kumo-coding-agent && git pull
```

**For cloning projects containing `kumo-coding-agent`:** Git submodules are
stored as references, not files. The `kumo-coding-agent/` folder will be
empty unless you include `--recurse-submodules`:

```bash
# When cloning for the first time:
git clone --recurse-submodules <your-project-repo>

# If already cloned and the folder is empty:
git submodule init && git submodule update
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

Two commands are available for reporting issues and contributing fixes.
Requires GitHub CLI (`gh auth status` must pass).

| Command | What it does |
|---------|-------------|
| `/kumo-issue [description]` | Files a GitHub issue on this repo |
| `/kumo-pr [description]` | Creates a branch, fixes a doc, and opens a PR |

---

## Directory Structure

```
kumo-coding-agent/
├── CLAUDE.md              # Entry point for Claude Code
├── AGENTS.md              # Entry point for Codex (points to CLAUDE.md)
├── .cursor/rules/         # Entry point for Cursor (points to CLAUDE.md)
├── context/               # Curated Kumo knowledge (loaded on demand)
│   ├── platform/          # SDK, RFM, PQL, graph, connectors
│   ├── guides/            # Decision guides
│   ├── patterns/          # Business workflow patterns
│   └── verticals/         # Industry-specific guides
├── skills/                # Step-by-step workflows
├── meta/                  # Add docs, sync from upstream, verify
├── scratch/               # Session state (gitignored)
└── eval/                  # Test questions for agent quality
```

---

## Extending the Agent

| Action | Instructions |
|--------|-------------|
| Add a context document | `meta/skills/add-context-doc.md` |
| Add a workflow skill | `meta/skills/add-skill.md` |
| Sync from upstream repos | `meta/skills/sync-from-source.md` |
| Check doc freshness | `meta/skills/validate-freshness.md` |
| Verify claims against code | `meta/skills/verify-content.md` |
| Audit known gaps | `meta/skills/check-gaps.md` |

---

## Design Principles

- **Portable**: Plain markdown, works with any LLM tool
- **On-demand loading**: Only loads what the task needs
- **Version-tracked**: Every doc traces to a specific package version
- **Self-correcting**: Gap manifest + verify-content catch drift
- **Testable**: Eval questions verify knowledge quality

---

## We love your feedback! ❤️

As you work with the Kumo Coding Agent, if you encounter any problems or
things that are confusing or don't work quite right, please
[open a new issue](https://github.com/kumo-ai/kumo-coding-agent/issues/new).
Join our [Discord](https://discord.com/invite/uNB4bJkapQ)!

## Community contribution 🤝

If you're considering contributing an example notebook or a new skill,
please first [open a new issue](https://github.com/kumo-ai/kumo-coding-agent/issues/new)
and describe your proposal so we can discuss it together before you invest a
ton of time. We'll invite you to our Mountain View, CA office (if you're local)
or send you Kumo Swag if your contribution is accepted.

Thank you and excited to see what you'll build with the Kumo Coding Agent!

---

## License

Released under the [MIT License](LICENSE).

---

<p align="center">
  Developed by <a href="https://kumo.ai">Kumo AI</a><br>
  &copy; 2026 Kumo AI, Inc. All rights reserved.
</p>
