# Run Evaluation

Test the agent's knowledge by asking questions from the eval question banks and scoring the responses.

---

## Prerequisites

- Eval questions exist in `eval/questions/*.yaml`
- Access to the agent (Claude Code session or other LLM tool)

---

## Workflow

### Step 1: Select Question Set

Choose which questions to test:

```bash
ls eval/questions/
# pql-knowledge.yaml
# rfm-knowledge.yaml
```

Read the questions:

```bash
cat eval/questions/pql-knowledge.yaml
```

### Step 2: Run Questions

For each question:

1. Start a fresh context (or clear prior conversation)
2. Ensure the agent has access to `CLAUDE.md` and context docs
3. Ask the question exactly as written
4. Record the agent's response

### Step 3: Score Responses

Score each response against the `expected_answer` using the `grading` type:

| Grading Type | How to Score |
|--------------|-------------|
| `exact_structure` | PQL query structure matches (table/column names can differ) |
| `semantic` | Key concepts from expected_answer are present |
| `procedural` | Correct pattern identified, steps in correct order |
| `factual` | Specific fact is stated correctly |

**Scoring scale**: 1 (wrong/missing) to 5 (complete and accurate)

### Step 4: Record Results

Save results to `eval/results/YYYY-MM-DD-eval-report.md`:

```markdown
# Eval Report — YYYY-MM-DD

## Summary
- Questions asked: N
- Average score: X.X / 5
- Perfect scores (5/5): N
- Failed (1-2/5): N

## Results by Category

| Category | Questions | Avg Score |
|----------|-----------|-----------|
| syntax   | 5         | 4.2       |
| ...      | ...       | ...       |

## Failed Questions

### pql-009 (score: 2/5)
**Question**: ...
**Expected**: ...
**Got**: ...
**Gap**: Missing mention of SQL workaround
```

### Step 5: Identify Gaps

For each failed question:
- Is the knowledge missing from context docs? → Run `meta/skills/add-context-doc.md`
- Is the knowledge present but the agent didn't find it? → Improve CLAUDE.md routing
- Is the expected answer wrong or outdated? → Update the eval question

---

## Checklist

- [ ] Question set selected
- [ ] All questions asked
- [ ] Responses scored
- [ ] Results saved to eval/results/
- [ ] Gaps identified and action planned
