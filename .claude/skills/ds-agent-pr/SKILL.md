---
name: ds-agent-pr
description: Create a branch, fix a DS-agent skill or context doc, and open a pull request on kumo-ai/DS-agent. Use when someone says "fix the agent docs", "update a skill", "contribute a fix", "open a PR for ds-agent", or "improve the agent".
argument-hint: "[description of what to fix]"
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

# Fix DS-agent and Open a PR

Create a branch, apply fixes to DS-agent skills or context docs, and
open a pull request for review.

**This command works in both Claude Code (interactive) and Codex (headless).**
In Codex, provide a description of the fix as the argument — interactive
prompting is not available.

**User input:** $ARGUMENTS

## Instructions

### Step 1: Validate GitHub CLI Auth

Run:
```bash
gh auth status
```

If `gh` is not authenticated, tell the user to run `gh auth login -h github.com`
first and stop before creating a branch or making changes.

### Step 2: Understand the Fix

If `$ARGUMENTS` is provided, parse it to understand what needs to change.

If `$ARGUMENTS` is empty, ask the user (skip in headless mode):
1. Which file needs fixing? (skill, context doc, or vertical)
2. What's wrong with it?
3. Do you know the correct information?

### Step 3: Detect Environment and Create a Branch

Generate `<slug>` from the fix description: lowercase, hyphens, max 50 chars.
Examples: `fix-pql-time-units`, `add-databricks-connector-docs`, `update-fraud-vertical`.

**Check whether we're already inside the DS-agent repo:**

```bash
git remote get-url origin 2>/dev/null | grep -q "DS-agent"
```

**If YES** (already in the right repo):
```bash
git checkout main
git pull --ff-only origin main 2>/dev/null || true
git checkout -b ds-agent/<slug>
# WORK_DIR = current directory
```

**If NO** (e.g., running from a project that used ds-agent-import):
```bash
WORK_DIR=$(mktemp -d)
git clone --filter=blob:none --depth=1 \
  git@github.com:kumo-ai/DS-agent.git "$WORK_DIR"
cd "$WORK_DIR"
git checkout -b ds-agent/<slug>
```

All subsequent steps operate inside `$WORK_DIR`. Remember it for cleanup.

### Step 4: Make the Changes

Apply the requested fixes.

**Guidelines:**
- Follow existing document structure and conventions
- If updating a context doc, update the Source header date
- If adding new content, keep the same style as surrounding content
- If fixing a claim, check the authoritative source (see
  `meta/skills/verify-content.md` for source locations)

### Step 5: Run Verification Checks

After making changes, verify nothing is broken:

```bash
# 1. YAML validity (if _sources.yaml or _gaps.yaml was touched)
python3 -c "import yaml; yaml.safe_load(open('context/_sources.yaml'))" 2>&1
python3 -c "import yaml; yaml.safe_load(open('context/_gaps.yaml'))" 2>&1

# 2. Cross-reference check: every file in CLAUDE.md routing table exists
grep -oE '`[^`]+\.md`' CLAUDE.md | tr -d '`' | while read f; do
  test -f "$f" || echo "MISSING: $f"
done
```

If any check fails, fix the issue before proceeding.

### Step 6: Commit

Stage the changes:

```bash
git add .
git status
```

Review the staged changes. Commit with a descriptive message:

```bash
git commit -m "<type>: <description>

<details of what changed and why>"
```

Where `<type>` is one of: `fix`, `docs`, `feat`, `refactor`.

### Step 7: Push and Create PR

```bash
git push -u origin ds-agent/<slug>
```

Create the PR — always pass `--head` and `--base` explicitly so this works
regardless of which directory the command runs from:

```bash
gh pr create \
  --repo kumo-ai/DS-agent \
  --head ds-agent/<slug> \
  --base main \
  --title "<concise title>" \
  --body "$(cat <<'EOF'
## Summary

- <1-3 bullet points of what changed>

## Files Changed

- `...`

## Verification

- [ ] YAML files are valid
- [ ] CLAUDE.md routing table references exist
- [ ] Content verified against source (if applicable)

---
*Created via `/ds-agent-pr` by @AUTHOR*
EOF
)"
```

Before creating the PR, capture the author's GitHub identity and replace
`@AUTHOR` in the body:
```bash
gh_user=$(gh api user --jq '.login')
```

If `gh` is not authenticated, tell the user to run `gh auth login -h github.com` first.

If a clone tmpdir was created in Step 3, clean it up after the PR is open:
```bash
rm -rf "$WORK_DIR"
```

### Step 8: Report

Print:
1. The PR URL
2. Summary of changes made
3. Tell the user: "Your PR has been submitted. A Kumo team member will review it and follow up with you."
