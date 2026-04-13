# kumo-coding-agent Slash Commands

Three commands for working with the kumo-coding-agent. Available automatically
when you open kumo-coding-agent in Claude Code or Codex — no setup needed.

---

## Commands

### `/kumo-import`

Download kumo-coding-agent from GitHub into your current project.

```
/kumo-import
```

What it does:
- Downloads `kumo-coding-agent/` from GitHub (no local clone needed)
- Adds a reference to your project's `CLAUDE.md`
- Adds `kumo-coding-agent/scratch/` to `.gitignore`

### `/kumo-issue [description]`

Report a gap, bug, or feature request.

```
/kumo-issue agent didn't know about Databricks Unity Catalog connector options
/kumo-issue pql-syntax.md says MODE is a valid aggregation but it isn't
/kumo-issue
```

If no description is given, you'll be asked interactively (Claude Code only).

### `/kumo-pr [description]`

Fix a skill or doc and open a PR.

```
/kumo-pr add Databricks connector details to data-connectors.md
/kumo-pr fix the time unit list in pql-syntax.md
/kumo-pr
```

If no description is given, you'll be asked interactively (Claude Code only).

---

## Setup

### In kumo-coding-agent (no setup needed)

The same three commands are exposed to both tools from this repo:

- **Claude Code** auto-discovers `.claude/skills/`
- **Codex** auto-discovers `.agents/skills/` (mirrored to the same skill definitions)

### In other repos (global install)

Target your specific tool with `--agent` to avoid polluting the project with
folders for every supported agent:

```bash
# Claude Code
npx skills add kumo-ai/kumo-coding-agent --agent claude-code

# Cursor
npx skills add kumo-ai/kumo-coding-agent --agent cursor
```

If you prefer manual setup, symlink the same skill folders into those directories.

### GitHub CLI (`gh`)

Required for all three commands.

```bash
brew install gh          # macOS
gh auth login            # authenticate with GitHub
gh auth status           # verify
```

`/kumo-issue` and `/kumo-pr` should only be used after
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
/kumo-issue

# Codex (provide description upfront)
/kumo-issue agent couldn't answer questions about Snowflake UDFs
```

Ensure `gh` is authenticated in the Codex environment.
