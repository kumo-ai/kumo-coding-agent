# Add a Context Document

Add new knowledge to the agent's context library. Follow this when you discover a gap — a question the agent can't answer because the relevant information isn't in any context doc.

---

## Prerequisites

- Identified knowledge gap (what question can't the agent answer?)
- Identified authoritative source (which repo, file, or doc has the answer?)
- **Template**: `meta/templates/context-template.md`

---

## Workflow

### Step 1: Identify the Gap

What question failed? Examples:
- "How do I configure Databricks connectors?" → missing connector details
- "What metrics does Kumo report for classification?" → missing evaluation context
- "How does the RANK syntax work?" → missing enterprise PQL features

Write down: the question, where the answer lives, which category it fits (`platform/`, `patterns/`, `integrations/`).

### Step 2: Check for Existing Coverage

Before creating a new doc, check if an existing one should be updated instead:

```bash
# Search existing context docs
grep -ri "<keyword>" context/
```

If an existing doc covers the topic partially, update it rather than creating a new file.

### Step 3: Copy the Template

```bash
cp meta/templates/context-template.md context/<category>/<name>.md
```

Choose the category:
- `platform/` — SDK, RFM, PQL, graph construction, data types
- `patterns/` — Business workflows, experiment design, data modeling
- `integrations/` — Snowflake, Salesforce, Databricks-specific knowledge

### Step 4: Write the Document

Guidelines:
- **200-400 lines** — enough to be useful, not so much it overwhelms context windows
- **Curated, not raw** — extract and organize, don't copy-paste entire source files
- **Include code examples** — agents need runnable code, not just descriptions
- **Source header** — always include `> Source: <repo-name> (<doc-name>) | Last synced: YYYY-MM-DD`
- **Overview section** — start with "Read this when:" so the agent knows when to load it
- **Quick Reference table** — summarize key APIs or patterns for fast lookup
- **Common Pitfalls** — what goes wrong and how to fix it

### Step 5: Update the Provenance Manifest

Add an entry to `context/_sources.yaml`:

```yaml
<category>/<name>.md:
  source_repo: <repo-name>
  version: "<package-version>"
  source_files:
    - <repo-relative-path>
  last_sync: "YYYY-MM-DD"
```

### Step 6: Update the Routing Table

Add a row to `CLAUDE.md` if the new doc serves a distinct task:

```markdown
| <Task description> | <skill or —> | `context/<category>/<name>.md` |
```

### Step 7: Add Eval Questions

Add at least 2 questions to `eval/questions/` that test the new knowledge:

```yaml
- id: <category>-NNN
  category: <topic>
  difficulty: basic|intermediate|advanced
  question: "<question the agent should now be able to answer>"
  expected_answer: "<what a correct answer includes>"
  grading: semantic
```

### Step 8: Verify Against Source Code

Run `meta/skills/verify-content.md` on the new document. Every factual claim
(enum values, valid syntax, API signatures) must be checked against the actual
code, not just copied from other documentation.

### Step 9: Verify End-to-End

1. Start a new Claude Code session
2. Ask the question that originally failed
3. Verify the agent loads the new doc and answers correctly

---

## Checklist

- [ ] Knowledge gap identified and documented
- [ ] Checked existing docs — no duplicate
- [ ] Template copied to correct category
- [ ] Document written (200-400 lines, curated)
- [ ] Source header with repo path and sync date
- [ ] `_sources.yaml` entry added
- [ ] `CLAUDE.md` routing table updated (if needed)
- [ ] Eval questions added
- [ ] Content verified against source code (`meta/skills/verify-content.md`)
- [ ] Verified in new session
