# DS-agent Command Skills

Commands available when working in this repo with Claude Code or Codex.

| Command | Purpose |
|---------|---------|
| `/ds-agent-issue [description]` | Report a gap, bug, or feature request |
| `/ds-agent-pr [description]` | Fix a skill/doc and open a PR |

Discovery paths:

- Claude Code: `.claude/skills/`
- Codex: `.agents/skills/`

GitHub-backed commands such as `/ds-agent-issue` and `/ds-agent-pr`
expect `gh auth status` to pass first.

See [slash-commands.md](slash-commands.md) for setup and usage details.
