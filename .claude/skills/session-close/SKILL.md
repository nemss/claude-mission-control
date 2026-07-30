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

If anything surprising or important happened, create a lesson at
`.claude/memory/shared/lessons/L-NNN.json` — one JSON object per file.

The format and field set are specified in `.claude/docs/COMMUNICATION.md` ("Lessons"). Follow it
there rather than copying it here.

Allocate the ID as highest-existing + 1, never `ls | wc -l` — a count reuses the ID of any
deleted lesson:

```bash
LESSONS_DIR=.claude/memory/shared/lessons
MAX=$(ls "$LESSONS_DIR"/L-*.json 2>/dev/null | sed 's/.*L-\([0-9]*\)\.json/\1/' | sort -n | tail -1)
# 10# forces base 10 — without it bash reads a zero-padded ID as octal (010 → 8, 008 → error)
printf 'L-%03d\n' "$(( 10#${MAX:-0} + 1 ))"
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
