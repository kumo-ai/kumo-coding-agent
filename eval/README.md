# Evaluation

Test whether the agent can answer questions correctly using its context docs.

## How It Works

1. Question banks in `questions/` contain YAML files organized by topic
2. Each question has an `expected_answer` and `grading` type
3. Run `eval/run-eval.md` to test the agent against the questions
4. Results saved to `eval/results/` (gitignored)

## Question Format

```yaml
questions:
  - id: pql-001
    category: syntax
    difficulty: basic          # basic | intermediate | advanced
    question: "..."
    expected_answer: "..."
    grading: semantic          # exact_structure | semantic | procedural | factual
```

## Grading Types

| Type | Description |
|------|-------------|
| `exact_structure` | PQL/code structure matches (tolerant of table/column names) |
| `semantic` | Key concepts are present (LLM-judged) |
| `procedural` | Correct pattern identified, steps in right order |
| `factual` | Specific fact is stated correctly |

## Adding Questions

When you add a new context doc or skill, add at least 2 eval questions:
1. A `basic` question testing direct knowledge recall
2. An `intermediate` or `advanced` question testing application

## Running Evaluation

Follow `eval/run-eval.md` for the full process.
