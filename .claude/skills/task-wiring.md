---
name: task-wiring
description: How to create, manage, and wire up tasks in the kanban queue
---

# Task Wiring

## Creating a Task

Create a markdown file in `.claude/memory/shared/queue/`:

Naming: `NNN-short-description.md` (e.g., `001-add-auth-middleware.md`)

```markdown
---
id: NNN
status: todo
assignee: builder
priority: high|medium|low
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

## Task Lifecycle

```
todo → in-progress → review → done
                  ↗          ↘
            blocked      todo (bounced)
```

1. **todo**: Created by Overseer, waiting for Builder
2. **in-progress**: Builder is actively working on it
3. **review**: Builder finished, waiting for Oracle
4. **done**: Oracle approved (PASS)
5. **blocked**: Waiting for external input or dependency

On Oracle FAIL: status goes back to `todo`, feedback is written to Oracle Feedback section.

## Finding Next Task

Builder picks the highest-priority `todo` task:
1. Read all files in `queue/`
2. Filter by `status: todo` and `assignee: builder`
3. Sort by priority (high > medium > low), then by id (lowest first)
4. Pick the first one, change status to `in-progress`

## Completing a Task

1. Builder changes status to `review`
2. Builder fills in Handoff State
3. Oracle reads the task + code changes
4. Oracle marks `done` (PASS) or bounces to `todo` (FAIL) with feedback
