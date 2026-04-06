# Scratch Memory

Session-persistent state for long-running experiments and multi-session workflows.

## Convention

- **File name**: `YYYY-MM-DD_<task-slug>.md`
- **One file per experiment/task**
- Check for existing scratch files before starting a new task

## File Template

```markdown
# <Task Description>
Started: YYYY-MM-DD HH:MM
Status: in-progress | completed | failed

## Objective
<What we're trying to accomplish>

## State
<Current progress, job IDs, intermediate results, file paths>

## Log
### YYYY-MM-DD HH:MM
<What happened, decisions made, results observed>
```

## How It Works

1. Agent creates a scratch file when starting a multi-step or long-running task
2. Records graph definitions, PQL queries, job IDs, metrics, intermediate results
3. Next session: agent checks `scratch/` for existing state and resumes
4. External tools (MLFlow, etc.) can be referenced by URL in the State section
5. Mark Status as `completed` or `failed` when done

## Notes

- This directory is gitignored — files persist locally across Claude Code sessions
- Files are plain markdown — readable by any LLM tool or human
- Keep files focused: one experiment per file, not a general log
