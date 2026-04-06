---
name: ds-agent-import
description: Download the DS-agent (context docs, skills, and infrastructure) from GitHub into the current project directory so FDEs can use the Kumo data science agent in their own repos. Use when someone says "import ds-agent", "set up ds-agent in my project", "get the agent", or "import kumo-agent".
argument-hint: ""
allowed-tools: [Bash, Read, Write, Glob]
---

# Import DS-agent from GitHub

Download the DS-agent from the kumo-ai/DS-agent repo into the current
project directory. No local clone of DS-agent is needed.

**This command works in both Claude Code (interactive) and Codex (headless).**

## Instructions

### Step 1: Validate Environment

1. Verify `gh` is available and authenticated: `gh auth status`
   - If not, tell the user to run `brew install gh && gh auth login`
2. Check if `ds-agent/` already exists in the current directory:
   - If so, ask the user whether to overwrite or abort
   - In headless mode, overwrite by default

### Step 2: Download DS-agent

Run:
```bash
tmpdir=$(mktemp -d)
gh api repos/kumo-ai/DS-agent/tarball/main \
  | tar xz -C "$tmpdir" --strip-components=1
mkdir -p ds-agent
cp -R "$tmpdir"/* ds-agent/
rm -rf "$tmpdir"
```

This downloads the full repo contents into a `ds-agent/` subdirectory.

If the command fails, fall back to sparse checkout:
```bash
tmpdir=$(mktemp -d)
git clone --filter=blob:none --depth=1 \
  https://github.com/kumo-ai/DS-agent.git "$tmpdir"
cp -R "$tmpdir"/* ds-agent/
rm -rf "$tmpdir"
```

### Step 3: Clean Up Unwanted Files

Remove files that are only relevant inside the DS-agent repo itself:

```bash
rm -rf ds-agent/.github/
rm -rf ds-agent/.claude/
rm -rf ds-agent/.agents/
rm -rf ds-agent/Makefile
rm -rf ds-agent/eval/results/
rm -rf ds-agent/scratch/*
```

Preserve `ds-agent/scratch/README.md` and `ds-agent/scratch/.gitkeep` if they exist.

### Step 4: Integrate with Project

**CLAUDE.md integration:**
- If `CLAUDE.md` exists in the current directory, append this line (if not already present):
  ```
  Also read ds-agent/CLAUDE.md for Kumo data science agent capabilities.
  ```
- If `CLAUDE.md` does not exist, create one with:
  ```markdown
  # Project Instructions

  Also read ds-agent/CLAUDE.md for Kumo data science agent capabilities.
  ```

**.gitignore integration:**
- If `.gitignore` exists, append these lines (if not already present):
  ```
  # Kumo DS agent scratch (session-specific)
  ds-agent/scratch/*
  !ds-agent/scratch/README.md
  !ds-agent/scratch/.gitkeep
  ds-agent/eval/results/
  ```
- If no `.gitignore` exists, create one with the above content.

### Step 5: Report Results

Count and report:
- Number of context docs (files in `ds-agent/context/`)
- Number of skills (files in `ds-agent/skills/`)
- Number of meta-skills (files in `ds-agent/meta/skills/`)

Print a summary like:
```
DS-agent imported to ./ds-agent/

  Source:         kumo-ai/DS-agent@main
  Context docs:   11
  Skills:          8
  Meta-skills:     9
  Verticals:       2

  CLAUDE.md:      updated (reference added)
  .gitignore:     updated (scratch/ excluded)

Next steps:
  1. Ask a prediction question — the agent will load relevant context
  2. Try: "Help me predict customer churn using my orders data"
```
