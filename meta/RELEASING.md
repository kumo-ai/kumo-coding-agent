# Releasing the Kumo Coding Agent

This document explains how to version, release, and manage the agent.

---

## Version Format

We use **semantic versioning**: `major.minor.patch`

| Part | When to bump | Example change |
|------|-------------|----------------|
| **Patch** (x.x.1) | Bug fixes, typo corrections, fixing wrong defaults | Fix `max_pq_iterations` default from 20 to 10 |
| **Minor** (x.1.x) | New features, new skills, new context docs | Add a new vertical (healthcare), add a new skill |
| **Major** (1.x.x) | Breaking changes that require users to update their setup | Rename CLAUDE.md, remove a skill, change directory structure |

---

## How to Cut a Release

**1. Make sure main is clean and all PRs are merged.**

```bash
git checkout main
git pull origin main
```

**2. Decide the version number.**

Look at what changed since the last release:

```bash
git log --oneline $(git describe --tags --abbrev=0)..HEAD
```

- Only bug fixes? Bump patch (v1.0.0 -> v1.0.1)
- New features? Bump minor (v1.0.0 -> v1.1.0)
- Breaking changes? Bump major (v1.0.0 -> v2.0.0)

**3. Create the tag.**

```bash
git tag -a v1.1.0 -m "v1.1.0: Brief description of what changed"
git push origin v1.1.0
```

**4. Create a GitHub release (optional but recommended).**

```bash
gh release create v1.1.0 --title "v1.1.0" --notes "
## What's new
- Added healthcare vertical
- Fixed connector init examples

## Upgrade
git submodule update --remote kumo-coding-agent
"
```

This creates a release page on GitHub that users can see.

---

## How Users Pin to a Version

Users who added the agent as a git submodule can pin to a specific version:

```bash
cd kumo-coding-agent
git fetch --tags
git checkout v1.1.0
cd ..
git add kumo-coding-agent
git commit -m "pin kumo-coding-agent to v1.1.0"
```

To update to the latest:

```bash
cd kumo-coding-agent
git fetch --tags
git checkout v1.2.0
cd ..
git add kumo-coding-agent
git commit -m "update kumo-coding-agent to v1.2.0"
```

---

## Backporting a Fix

If you need to fix a bug in an older major version while main has moved ahead:

**1. Create a release branch from the old tag.**

```bash
git checkout -b release/v1.x v1.2.0
```

**2. Cherry-pick the fix.**

```bash
git cherry-pick <commit-hash>
```

**3. Tag the patch release.**

```bash
git tag -a v1.2.1 -m "v1.2.1: Backported fix for XYZ"
git push origin v1.2.1
git push origin release/v1.x
```

Users on v1.x can now upgrade to v1.2.1 without jumping to v2.x.

---

## Forward Porting

If a fix is made on a release branch and also needs to go to main:

```bash
git checkout main
git cherry-pick <commit-hash>
```

Or open a PR with the same change targeting main.

---

## Release Checklist

Before every release:

- [ ] All PRs merged to main
- [ ] No remaining `grep -r "TODO\|FIXME\|HACK" skills/ context/` issues
- [ ] `context/_sources.yaml` versions are current
- [ ] Eval questions pass (see `eval/README.md`)
- [ ] README.md version references are correct
- [ ] Tag created and pushed
- [ ] GitHub release created with changelog
