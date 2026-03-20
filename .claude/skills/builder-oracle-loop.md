---
name: builder-oracle-loop
description: The core productivity pattern — Builder stages, Oracle validates, Overseer commits on PASS
---

# Builder-Oracle Loop

The core productivity pattern. All work flows through queue task files. Builder stages but does NOT commit — Oracle validates first, then Overseer commits.

## The Loop

```
Overseer creates task in queue/
  → Builder reads task file, implements, stages (git add), sets status: review
    → Oracle reads task file, validates staged changes
      → PASS: Overseer commits and deletes task file
      → FAIL: status: todo + Oracle Feedback → Builder reads feedback, retries
```

## Why Stage-Then-Commit?

Builder stages changes (`git add`) but does NOT `git commit`. Oracle validates the staged diff. Only after PASS does the Overseer commit. This prevents bad code from entering git history on FAIL — no fix-up commits, clean history.

## How the Overseer Runs It

### Step 0: Create Task File (MANDATORY)

Before spawning any agent, create a task file in `.claude/memory/shared/queue/`. Read `.counter` for the next ID, increment and save.

### Step 1: Spawn Builder

```
Agent(subagent_type="builder", prompt="
  Read your task from .claude/memory/shared/queue/NNN-description.md.
  Follow the instructions and acceptance criteria in the file.
  Read .claude/docs/CONVENTIONS.md and check lessons/ before starting.
  Stage your changes with git add. Do NOT commit.
  Update task status to 'in-progress' when you start, 'review' when done.
  Write handoff state.
")
```

### Step 2: Spawn Oracle

```
Agent(subagent_type="oracle", prompt="
  Validate task .claude/memory/shared/queue/NNN-description.md.
  Read acceptance criteria from the task file.
  Check staged changes with git diff --staged.
  Check: tests pass, lint clean, conventions followed, spec matched.
  If PASS: update status to 'done', log verdict.
  If FAIL: update status to 'todo', write structured feedback in Oracle Feedback section.
")
```

### Step 3: Handle Result

- **PASS**: Overseer runs `git commit` with conventional message. Deletes task file from queue. Proceeds to next task.
- **FAIL**: Re-spawn Builder pointing to the same task file. Builder reads Oracle Feedback section. Max 3 total attempts (initial + 2 retries).

### Step 4: On Max Retries

If all 3 attempts fail (initial + 2 retries):
1. Run `git checkout -- .` to unstage and discard changes
2. Log a blocker in decisions.jsonl
3. Set task status to `blocked`
4. Escalate to the user with all feedback history

## Why This Pattern Matters

- No bad commits in git history — only Oracle-approved code gets committed
- Catches 80% of issues before human review
- Prevents quality drift over time
- Specific feedback makes fixes fast
