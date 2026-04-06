# DS-agent Slash Commands

Three commands for working with the DS-agent. Available automatically
when you open DS-agent in Claude Code or Codex — no setup needed.

---

## Commands

### `/ds-agent-import`

Download DS-agent from GitHub into your current project.

```
/ds-agent-import
```

What it does:
- Downloads `ds-agent/` from GitHub (no local clone needed)
- Adds a reference to your project's `CLAUDE.md`
- Adds `ds-agent/scratch/` to `.gitignore`

### `/ds-agent-issue [description]`

Report a gap, bug, or feature request.

```
/ds-agent-issue agent didn't know about Databricks Unity Catalog connector options
/ds-agent-issue pql-syntax.md says MODE is a valid aggregation but it isn't
/ds-agent-issue
```

If no description is given, you'll be asked interactively (Claude Code only).

### `/ds-agent-pr [description]`

Fix a skill or doc and open a PR.

```
/ds-agent-pr add Databricks connector details to data-connectors.md
/ds-agent-pr fix the time unit list in pql-syntax.md
/ds-agent-pr
```

If no description is given, you'll be asked interactively (Claude Code only).

---

## Setup

### In DS-agent (no setup needed)

The same three commands are exposed to both tools from this repo:

- **Claude Code** auto-discovers `.claude/skills/`
- **Codex** auto-discovers `.agents/skills/` (mirrored to the same skill definitions)

### In other repos (global install)

Run:

```bash
make install-slash-commands
```

This installs symlinks for:

- `~/.claude/skills/` for Claude Code
- `~/.agents/skills/` for Codex

If you prefer manual setup, symlink the same skill folders into those directories.

### GitHub CLI (`gh`)

Required for all three commands.

```bash
brew install gh          # macOS
gh auth login            # authenticate with GitHub
gh auth status           # verify
```

`/ds-agent-issue` and `/ds-agent-pr` should only be used after
`gh auth status` succeeds in the current environment.

---

## Codex

Codex discovers these commands from `.agents/skills/`, not `.claude/skills/`.

In the Codex app, enabled skills can appear in the slash-command picker. In
CLI/IDE flows, the same skills can still be invoked directly.

**Key difference:** Codex runs headless — no interactive prompts. Always
provide arguments:

```
# Claude Code (interactive OK)
/ds-agent-issue

# Codex (provide description upfront)
/ds-agent-issue agent couldn't answer questions about Snowflake UDFs
```

Ensure `gh` is authenticated in the Codex environment.
