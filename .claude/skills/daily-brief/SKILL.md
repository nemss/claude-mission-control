---
name: daily-brief
description: Generate a daily summary of all agent activity
---

# Daily Brief

## When to Generate

- At the start of a new day's first session
- On explicit request

## How to Generate

1. Read `.claude/memory/shared/decisions.jsonl` — filter entries from the last 24 hours
2. Read `.claude/memory/shared/queue/` — count tasks by status
3. Read `.claude/memory/shared/context.md` — current state

## Output Format

Save to `.claude/memory/shared/briefs/YYYY-MM-DD.md`:

```markdown
# Daily Brief: [date]

## Activity Summary
- [N] decisions logged
- [N] tasks completed
- [N] tasks in progress
- [N] tasks blocked

## Key Events
- [Agent]: [What happened]

## Queue Status
| Status | Count |
|--------|-------|
| todo | N |
| in-progress | N |
| review | N |
| done | N |
| blocked | N |

## Lessons Learned
[Any new lessons from yesterday]

## Focus for Today
[Based on context.md and queue priorities]
```

Keep it scannable — agents read this to orient, not to study.
