# Add a Workflow Skill

Add a new interactive skill to the agent. Follow this when you identify a common workflow that would benefit from step-by-step guidance.

---

## Prerequisites

- Identified a repeatable workflow (something FDEs do regularly)
- Know the steps and their order
- **Template**: `meta/templates/skill-template.md`

---

## Workflow

### Step 1: Define the Skill Scope

Answer:
- **What does this skill do?** (1-2 sentences)
- **When should the agent use it?** (trigger conditions)
- **What context docs does it depend on?**
- **What are the prerequisites?** (tools, credentials, data)

### Step 2: Copy the Template

```bash
cp meta/templates/skill-template.md skills/<name>.md
```

Naming: use lowercase, hyphen-separated, action-oriented names (e.g., `train-model.md`, `evaluate-model.md`, `compare-experiments.md`).

### Step 3: Write the Skill

Follow the established pattern:

1. **Title + purpose** — 1-2 sentence description
2. **Prerequisites** — tools, credentials, context docs to read first
3. **Workflow steps** — numbered, each with:
   - Clear instructions
   - Code examples (runnable, not pseudocode)
   - Expected output description
   - Verification command where applicable
4. **Quick Reference** — lookup table for the most-used APIs or patterns
5. **Common Errors** — table with Error | Cause | Fix columns
6. **Checklist** — items matching the workflow steps

Guidelines:
- **250-350 lines** — enough detail to follow, not overwhelming
- **Each step should be independently verifiable** — include expected output
- **Reference context docs, don't duplicate them** — link with `context/...`
- **Include error recovery** — what to do when a step fails
- **End with state persistence** — remind to save to scratch/ if long-running

### Step 4: Update the Routing Table

Add a row to `CLAUDE.md`:

```markdown
| <Task description> | `skills/<name>.md` | `context/<relevant>.md` |
```

### Step 5: Test the Skill

1. Start a new Claude Code session
2. Ask for the workflow the skill covers
3. Verify the agent finds and follows the skill
4. Walk through all steps to confirm they work end-to-end

---

## Checklist

- [ ] Skill scope defined (purpose, trigger, prerequisites)
- [ ] Template copied and renamed
- [ ] All workflow steps written with code examples
- [ ] Quick Reference table included
- [ ] Common Errors table included
- [ ] Checklist included
- [ ] `CLAUDE.md` routing table updated
- [ ] Tested in new session end-to-end
