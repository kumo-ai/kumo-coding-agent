---
name: ds-agent-issue
description: File a GitHub issue on the DS-agent repo to report a gap, bug, or feature request for the Kumo data science agent (context docs, skills, or verticals). Use when someone says "report a problem with the agent", "the agent got something wrong", "file an issue", or "request a new skill".
argument-hint: "[description of the issue]"
allowed-tools: [Bash, Read, Glob, Grep]
---

# File a DS-agent Issue

Create a structured GitHub issue on kumo-ai/DS-agent for agent
gaps, bugs, or feature requests.

**This command works in both Claude Code (interactive) and Codex (headless).**
In Codex, provide a description as the argument — interactive prompting is
not available.

**User input:** $ARGUMENTS

## Instructions

### Step 1: Validate GitHub CLI Auth

Run:
```bash
gh auth status
```

If `gh` is not authenticated, tell the user to run `gh auth login -h github.com`
first and stop before gathering more information.

### Step 2: Gather Information

If `$ARGUMENTS` is provided, parse it to understand the issue.

If `$ARGUMENTS` is empty, ask the user these questions (skip in headless mode):
1. What happened? (What were you trying to do?)
2. Which skill or context doc was involved? (If known)
3. What did you expect vs what happened?

### Step 3: Classify the Issue

Determine the type based on the description:

| Type | Signal | Label |
|------|--------|-------|
| **gap** | "agent didn't know", "missing info", "couldn't answer" | `gap` |
| **bug** | "wrong info", "incorrect", "outdated", "says X but should be Y" | `bug` |
| **feature** | "add support for", "new skill", "new vertical", "would be nice" | `enhancement` |

### Step 4: Identify Affected Files

Search for files related to the issue:
```bash
grep -rl "<relevant keyword>" context/ skills/
```

If the user mentioned a specific file, verify it exists and note the
relevant section.

Also check if this is already tracked:
```bash
grep -i "<keyword>" context/_gaps.yaml
```

If already tracked, tell the user and ask if they still want to file an issue.

### Step 5: Compose the Issue

**Title format:** `ds-agent: <concise description>`

Examples:
- `ds-agent: missing Databricks Unity Catalog connector docs`
- `ds-agent: pql-syntax.md lists MODE as valid aggregation`
- `ds-agent: add healthcare/clinical trials vertical`

**Body template:**
```markdown
## Type

<gap | bug | feature>

## Affected File(s)

- `<path>` (line ~N)

## Description

<Clear description of the issue>

## Expected Behavior

<What should happen / what info should be there>

## Current Behavior

<What actually happens / what the doc currently says>

## Suggested Fix

<If obvious — otherwise "Needs investigation">

## Context

<Any additional context: SDK version, customer use case, etc.>

---
*Filed via `/ds-agent-issue` by @REPORTER*
```

### Step 6: Create the Issue

First, capture the reporter's GitHub identity:
```bash
gh_user=$(gh api user --jq '.login')
```

Replace `@REPORTER` in the body template with `@$gh_user`.

Run:
```bash
gh issue create \
  --repo kumo-ai/DS-agent \
  --title "<title>" \
  --label "ds-agent,<type-label>" \
  --assignee "manushmurali-kumo" \
  --body "<body>"
```

Use a heredoc for the body to preserve formatting.

If `gh` is not authenticated, tell the user to run `gh auth login -h github.com` first
and provide the exact command to retry.

### Step 7: Follow Up

After the issue is created:
1. Print the issue URL
2. Tell the user: "Your issue has been filed. A Kumo team member will review it and follow up with you."
3. If the type is **gap**, suggest also adding an entry to
   `context/_gaps.yaml` with status: open
4. If the type is **bug** and the fix is obvious, suggest running
   `/ds-agent-pr` to fix it directly
