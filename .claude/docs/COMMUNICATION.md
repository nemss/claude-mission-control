# Communication Standards

How agents write notes, summaries, and handoff messages.

## Decision Log Entries

Every `decisions.jsonl` entry must be:
- **Self-contained**: readable without additional context
- **Actionable**: another agent can act on it without clarification
- **Timestamped**: ISO-8601 UTC format

Format:
```json
{"ts":"2025-01-15T10:30:00Z","agent":"builder","type":"implementation","summary":"one-line what happened","detail":"full context: what, why, what's next"}
```

The `summary` field should answer: "What happened?" in one sentence.
The `detail` field should answer: "What does the next agent need to know?"

## Session Summaries

Written to `sessions/YYYY-MM-DDTHHMM.md`. Structure:

```markdown
# Session Summary: [timestamp]
## What was accomplished
[Bullet list of completed work]
## Decisions made
[Key decisions with reasoning]
## Open items
[What's unfinished or blocked]
```

Keep summaries under 50 lines. Compress, don't transcribe.

## Task Handoff State

When a Builder finishes a task or session ends mid-task, write a handoff in the task file:

```markdown
## Handoff State
- **Last action**: [what was done last]
- **Current state**: [where things stand]
- **Next step**: [what to do next]
- **Watch out for**: [gotchas or context the next agent needs]
```

## Lessons

Written to `lessons/L-NNN.json`. Must include:
- `pattern`: the rule or insight (imperative: "Do X" or "Avoid Y")
- `context`: what happened that taught this lesson
- `severity`: critical | important | minor

Only record lessons that are **durable** — not one-time fixes, but patterns that apply to future work.

## Noise Filtering

The Overseer filters communication to the user:
- **Surface**: completed milestones, blockers needing human input, PASS/FAIL verdicts
- **Suppress**: routine delegation, intermediate progress, expected retries
- **Escalate**: repeated FAILs, agent conflicts, ambiguous requirements

## Oracle Feedback Format

When bouncing work back:
```markdown
## Oracle Feedback
**Verdict**: FAIL
**What failed**: [specific item from acceptance criteria]
**Where**: [file:line or specific location]
**Expected**: [what should happen]
**Actual**: [what happens instead]
**Fix suggestion**: [concrete action to take]
```

Never vague ("looks wrong"). Always specific ("line 42: missing null check on user.email").
