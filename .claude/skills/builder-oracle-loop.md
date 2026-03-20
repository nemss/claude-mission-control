---
name: builder-oracle-loop
description: The core productivity pattern — Builder implements, Oracle validates, retry on FAIL
---

# Builder-Oracle Loop

The core productivity pattern. Without review, agents drift from the goal.

## The Loop

```
Builder implements → Oracle validates → PASS (done) or FAIL (retry)
```

## How the Overseer Runs It

### Step 1: Spawn Builder

```
Agent(subagent_type="builder", prompt="
  Task: [from queue file]
  Acceptance criteria: [from queue file]
  Read .claude/docs/CONVENTIONS.md before starting.
  Check .claude/memory/shared/lessons/ for relevant lessons.
  When done: make an atomic commit and update the task status to 'review'.
")
```

### Step 2: Spawn Oracle

```
Agent(subagent_type="oracle", prompt="
  Validate task [id] from .claude/memory/shared/queue/[file].
  Read the acceptance criteria in the task file.
  Check: tests pass, lint clean, conventions followed, spec matched.
  If PASS: mark task status as 'done', log verdict to decisions.jsonl.
  If FAIL: mark task status as 'todo', write specific feedback to Oracle Feedback section.
")
```

### Step 3: Handle Result

- **PASS**: Update context.md, report to user
- **FAIL**: Read Oracle's feedback, spawn Builder again with the feedback. Max 3 retries.

```
Agent(subagent_type="builder", prompt="
  Task [id] was bounced by Oracle.
  Feedback: [paste Oracle's feedback from the task file]
  Fix the issues. Do not change anything outside the feedback scope.
  When done: commit and set status to 'review'.
")
```

Then spawn Oracle again. Repeat until PASS or max retries.

### Step 4: On Max Retries

If 3 Builder-Oracle cycles fail:
1. Log a blocker in decisions.jsonl
2. Escalate to the user with all feedback history
3. Mark task as `blocked`

## Why This Pattern Matters

- Catches 80% of issues before human review
- Prevents quality drift over time
- Specific feedback makes fixes fast
- Without review, agents slowly diverge from the actual goal
