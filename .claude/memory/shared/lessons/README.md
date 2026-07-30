# Lessons

Durable patterns the swarm has learned — what works, what to avoid. All agents read this
directory before starting work; `session-close` writes to it.

Unlike the rest of shared memory, lessons are **tracked in git**: they are project knowledge
that should survive a fresh clone.

## Format

One lesson per file, named `L-NNN.json` with `NNN` zero-padded to 3 digits. Each file holds a
single JSON object:

```json
{"id":"L-001","severity":"important","pattern":"Do X / Avoid Y","context":"What happened that taught this","agent":"builder","ts":"2026-07-30T10:00:00Z"}
```

Required fields — `pattern`, `context`, `severity` (`critical` | `important` | `minor`) — are
specified in `.claude/docs/COMMUNICATION.md` ("Lessons"), which is the source of truth. Each
lesson also carries `id` (matching the filename), `agent`, and `ts` (ISO-8601 UTC).

## ID allocation

Take the highest existing ID and add 1. Never derive the next ID from a file count — a count
reuses the ID of any deleted lesson, which is the same bug the queue `.counter` exists to
prevent.

```bash
MAX=$(ls L-*.json 2>/dev/null | sed 's/L-\([0-9]*\)\.json/\1/' | sort -n | tail -1)
# 10# forces base 10 — without it bash reads a zero-padded ID as octal (010 → 8, 008 → error)
printf 'L-%03d\n' "$(( 10#${MAX:-0} + 1 ))"
```

## What belongs here

Record a lesson only if it is durable — a pattern that applies to future work. A one-time fix
belongs in `decisions.jsonl`, not here.
