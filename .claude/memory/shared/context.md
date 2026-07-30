# Current Context

## Active Goal
Idle. The full-system audit remediation (7 tasks) is complete and committed.

## Key Decisions
- Skills must live at `.claude/skills/<name>/SKILL.md` — flat `.md` files are never loaded
  by Claude Code. All 10 skills migrated with `git mv`.
- SessionStart hooks must emit context on **stdout** (JSON with
  `hookSpecificOutput.additionalContext`). stderr is discarded for context purposes.
- `Stop` fires after every assistant response, not once per session. Session summaries are
  now idempotent day-scoped files (`sessions/YYYY-MM-DD.md`) and the hook is registered on
  `SessionEnd` as the primary trigger.
- `validate-task` blocks only on partially-staged files (staged ∩ unstaged), not on any
  unstaged file in the repo. Unstaged-only files are a WARN.
- Canonical lesson format is `lessons/L-NNN.json`, IDs allocated as max-existing + 1.
- Health checks must be able to fail. The previous one reported ALL PASS while an entire
  subsystem was dead.

## Blockers
None.

## Next Steps
- Consider pruning legacy `sessions/*.md` files using the old `YYYY-MM-DDTHHMM.md` naming,
  if any accumulate.
- The `TeammateIdle` hook caused two builders to collide on tasks 005 and 007 by
  self-assigning queued work. Worth deciding whether idle builders should claim tasks
  autonomously or wait for Overseer assignment.
- `.claude/settings.local.json` has a stale permission entry referencing the old flat
  skills glob; harmless but untidy.
