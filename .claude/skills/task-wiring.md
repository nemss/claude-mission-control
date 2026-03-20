---
name: task-wiring
description: How to create, manage, and wire up tasks in the kanban queue
---

# Task Wiring

## Creating a Task

### 1. Get Next ID

Read `.claude/memory/shared/queue/.counter`, increment by 1, write back. Use that number as the task ID. This prevents ID reuse after task deletion.

### 2. Create Task File

Create a markdown file in `.claude/memory/shared/queue/`:

Naming: `NNN-short-description.md` (e.g., `001-add-auth-middleware.md`)

```markdown
---
id: NNN
status: todo
assignee: builder
priority: high|medium|low
depends_on: []
created: YYYY-MM-DDTHH:MM:SSZ
---

# [Task Title]

## Instructions
[Clear description of what to do]

## Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## Handoff State
[Empty for new tasks. Filled by Builder when work is paused or completed.]

## Manager Notes
[Overseer's observations, context, or constraints]

## Oracle Feedback
[Empty until Oracle reviews. Filled on bounce-back.]
```

### depends_on Field

List task IDs that must be `done` before this task can start:
- `depends_on: []` — no dependencies, can start immediately
- `depends_on: [001, 002]` — blocked until tasks 001 and 002 are done

The Overseer checks dependencies before spawning Builder. If a dependency is not done, the task stays in `todo`.

## Task Lifecycle

```
todo → in-progress → review → done (deleted)
                  ↗          ↘
            blocked      todo (bounced by Oracle)
```

1. **todo**: Created by Overseer, waiting for Builder
2. **in-progress**: Builder is actively working on it
3. **review**: Builder finished, waiting for Oracle
4. **done**: Oracle approved (PASS) — task file is deleted, history in decisions.jsonl
5. **blocked**: Waiting for external input or dependency

On Oracle FAIL: status goes back to `todo`, feedback is written to Oracle Feedback section.

## Finding Next Task

Builder picks the highest-priority `todo` task:
1. Read all files in `queue/`
2. Filter by `status: todo` and `assignee: builder`
3. Check `depends_on` — skip tasks with unfinished dependencies
4. Sort by priority (high > medium > low), then by id (lowest first)
5. Pick the first one, change status to `in-progress`

## Completing a Task

1. Builder changes status to `review`, fills in Handoff State
2. Oracle reads the task + code changes
3. Oracle marks `done` (PASS) or bounces to `todo` (FAIL) with feedback
4. On PASS, Overseer deletes the task file from queue
