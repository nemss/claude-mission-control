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

This section is the canonical spec for the lessons store. Everything else references it.

Each lesson is a single JSON object written to
`.claude/memory/shared/lessons/L-NNN.json` — one lesson per file, `NNN` zero-padded to 3 digits.

Must include:
- `pattern`: the rule or insight (imperative: "Do X" or "Avoid Y")
- `context`: what happened that taught this lesson
- `severity`: critical | important | minor

Also carried on each lesson: `id` (matches the filename), `agent` (who recorded it), and
`ts` (ISO-8601 UTC).

```json
{"id":"L-001","severity":"important","pattern":"Do X / Avoid Y","context":"What happened that taught this","agent":"builder","ts":"2026-07-30T10:00:00Z"}
```

**ID allocation**: take the highest existing ID and add 1 — never a file count, which reuses
IDs as soon as a lesson is deleted:

```bash
LESSONS_DIR=.claude/memory/shared/lessons
MAX=$(ls "$LESSONS_DIR"/L-*.json 2>/dev/null | sed 's/.*L-\([0-9]*\)\.json/\1/' | sort -n | tail -1)
# 10# forces base 10 — without it bash reads a zero-padded ID as octal (010 → 8, 008 → error)
printf 'L-%03d\n' "$(( 10#${MAX:-0} + 1 ))"
```

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
