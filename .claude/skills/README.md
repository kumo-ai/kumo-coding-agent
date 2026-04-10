# kumo-coding-agent Command Skills

Slash commands available when working in this repo with Claude Code or Codex.

| Command | Purpose |
|---------|---------|
| `/kumo-import` | Download kumo-coding-agent from GitHub into your project |
| `/kumo-issue [description]` | Report a gap, bug, or feature request |
| `/kumo-pr [description]` | Fix a skill/doc and open a PR |

Discovery paths:

- Claude Code: `.claude/skills/`
- Codex: `.agents/skills/`

GitHub-backed commands such as `/kumo-issue` and `/kumo-pr`
expect `gh auth status` to pass first.

See [slash-commands.md](slash-commands.md) for setup and usage details.
