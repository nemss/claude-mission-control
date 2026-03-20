---
name: builder-oracle-loop
description: The core productivity pattern — Builder reads from queue, implements, Oracle validates from queue, retry on FAIL
---

# Builder-Oracle Loop

The core productivity pattern. All work flows through queue task files.

## The Loop

```
Overseer creates task in queue/
  → Builder reads task file, implements, sets status: review
    → Oracle reads task file, validates
      → PASS: status: done
      → FAIL: status: todo + Oracle Feedback written → Builder reads feedback, retries
```

## How the Overseer Runs It

### Step 0: Create Task File (MANDATORY)

Before spawning any agent, create a task file in `.claude/memory/shared/queue/`:

```markdown
---
id: NNN
status: todo
assignee: builder
priority: high
created: YYYY-MM-DDTHH:MM:SSZ
---
# [Task Title]
## Instructions
[What to do]
## Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
## Handoff State
[Empty]
## Manager Notes
[Context]
## Oracle Feedback
[Empty]
```

### Step 1: Spawn Builder

Point Builder to the specific task file:

```
Agent(subagent_type="builder", prompt="
  Read your task from .claude/memory/shared/queue/NNN-description.md.
  Follow the instructions and acceptance criteria in the file.
  Read .claude/docs/CONVENTIONS.md and check lessons/ before starting.
  Update task status to 'in-progress' when you start, 'review' when done.
  Write handoff state. Make an atomic commit.
")
```

Builder reads everything from the task file — no need to paste instructions in the prompt.

### Step 2: Spawn Oracle

Point Oracle to the same task file:

```
Agent(subagent_type="oracle", prompt="
  Validate task .claude/memory/shared/queue/NNN-description.md.
  Read acceptance criteria from the task file.
  Check: tests pass, lint clean, conventions followed, spec matched.
  Report your verdict. If FAIL, provide structured feedback.
")
```

After Oracle reports, Overseer updates the task file:
- PASS → set `status: done`
- FAIL → set `status: todo`, write Oracle's feedback to Oracle Feedback section

### Step 3: Handle Result

- **PASS**: Delete the task file from queue (history is in decisions.jsonl and git log). Update context.md, proceed to next task or report to user
- **FAIL**: Re-spawn Builder pointing to the same task file. Builder will read Oracle Feedback section. Max 3 total attempts (initial + 2 retries).

### Step 4: On Max Retries

If all 3 attempts fail (initial + 2 retries):
1. Log a blocker in decisions.jsonl
2. Set task status to `blocked`
3. Escalate to the user with all feedback history

## Why Queue Files Matter

- Tasks persist across sessions — pick up where you left off
- Oracle Feedback is written IN the task file — Builder reads it directly
- Handoff State preserves context for retries or next session
- Full audit trail: who did what, when, and what feedback was given
