---
name: context-recovery
description: Recover full context at session start — identity, security, recent sessions, active tasks, lessons
---

# Context Recovery

Every agent wakes up empty. This skill restores full context in seconds.

## Recovery Sequence

Execute these steps in order:

### 1. Identity
Read your agent definition from `.claude/agents/[your-name].md`. Understand:
- Your role and boundaries
- What tools you can use
- What you do and don't do

### 2. Security
Read `.claude/docs/SECURITY.md`. Note:
- Trust hierarchy levels
- Your scope guards
- What you must never do

### 3. Recent Sessions
Read the last 3 files from `.claude/memory/shared/sessions/` (sorted by name, newest first).
Extract: what was accomplished, open items, key decisions.

### 4. Active Tasks
Read all files in `.claude/memory/shared/queue/` where status is `todo`, `in-progress`, `review`, or `blocked`.
Note: your assigned tasks, their acceptance criteria, any handoff state.

### 5. Lessons
Read all files in `.claude/memory/shared/lessons/`.
Pay special attention to `critical` severity lessons.

### 6. Current Context
Read `.claude/memory/shared/context.md`.
This is the Overseer's view of the current project state.

### 7. Recent Decisions
Read the last 20 lines of `.claude/memory/shared/decisions.jsonl`.
Understand: what just happened, what's pending, any FAIL verdicts.

## After Recovery

You should now know:
- Who you are and what you can do
- What the project is working on
- What happened recently
- What needs to happen next
- What mistakes to avoid
