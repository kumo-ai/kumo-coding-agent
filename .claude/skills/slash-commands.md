# DS-agent Commands

Two commands for working with the DS-agent. Available automatically
when you open DS-agent in Claude Code or Codex — no setup needed.

---

## Commands

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

Commands are exposed to both tools from this repo:

- **Claude Code** auto-discovers `.claude/skills/`
- **Codex** auto-discovers `.agents/skills/`

### In other repos (global install)

Run:

```bash
make install-slash-commands
```

This installs symlinks for:

- `~/.claude/skills/` for Claude Code
- `~/.agents/skills/` for Codex

### GitHub CLI (`gh`)

Required for both commands.

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

**Key difference:** Codex runs headless — no interactive prompts. Always
provide arguments:

```
# Claude Code (interactive OK)
/ds-agent-issue

# Codex (provide description upfront)
/ds-agent-issue agent couldn't answer questions about Snowflake UDFs
```

Ensure `gh` is authenticated in the Codex environment.
