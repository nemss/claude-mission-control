---
name: session-close
description: Compress a session into a summary and extract durable lessons
---

# Session Close

Run this before ending a session to preserve context for next time.

## Step 1: Generate Session Summary

Create a file in `.claude/memory/shared/sessions/` named `YYYY-MM-DDTHHMM.md`:

```markdown
# Session Summary: [timestamp]

## What was accomplished
- [Completed item 1]
- [Completed item 2]

## Decisions made
- [Decision 1: what was decided and why]

## Open items
- [Unfinished task or blocker]
```

Keep it under 50 lines. Compress, don't transcribe.

## Step 2: Extract Lessons

If anything surprising or important happened, create a lesson in `.claude/memory/shared/lessons/`:

Find the next available ID: `ls lessons/ | wc -l` → L-{next number}

```json
{"id":"L-NNN","severity":"critical|important|minor","pattern":"Do X / Avoid Y","context":"What happened that taught this","agent":"your-name","ts":"ISO-8601"}
```

Only record **durable** lessons — patterns that apply to future work, not one-time fixes.

## Step 3: Update Context

Update `.claude/memory/shared/context.md` to reflect the current state:
- Active goal (unchanged or updated)
- Key decisions (add new ones)
- Blockers (resolved or new)
- Next steps (what the next session should do)

## Step 4: Commit Handoff State

If any task in `queue/` is in-progress, update its Handoff State section:
- Last action taken
- Current state of the work
- Next step to pick up
- Gotchas or context needed
