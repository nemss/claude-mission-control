#!/usr/bin/env bash
set -euo pipefail

# TeammateIdle hook — suggests next work when a teammate becomes idle.
# Exit 0 = allow idle. Exit 2 + stderr = send message to teammate.

SHARED_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/shared"
CONTEXT_FILE="$SHARED_DIR/context.md"

# Check queue for pending tasks
if [ -d "$SHARED_DIR/queue" ]; then
  TODO_TASKS=$(grep -rl 'status: todo' "$SHARED_DIR/queue/"*.md 2>/dev/null || true)
  if [ -n "$TODO_TASKS" ]; then
    echo "There are tasks with status 'todo' in the queue. Check .claude/memory/shared/queue/ for available work." >&2
    exit 2
  fi

  REVIEW_TASKS=$(grep -rl 'status: review' "$SHARED_DIR/queue/"*.md 2>/dev/null || true)
  if [ -n "$REVIEW_TASKS" ]; then
    echo "There are tasks waiting for review in the queue. Check .claude/memory/shared/queue/ for tasks to validate." >&2
    exit 2
  fi
fi

# Check if context file has actionable next steps
if [ -f "$CONTEXT_FILE" ]; then
  NEXT_STEPS=$(sed -n '/^## Next Steps/,/^##/p' "$CONTEXT_FILE" | grep -v '^##' | grep -v '^\[' | grep -v '^$' || true)
  if [ -n "$NEXT_STEPS" ]; then
    echo "There are pending next steps in context.md. Review .claude/memory/shared/context.md for available work." >&2
    exit 2
  fi
fi

# Check if there are recent FAIL verdicts that need attention
if [ -f "$SHARED_DIR/decisions.jsonl" ] && [ -s "$SHARED_DIR/decisions.jsonl" ]; then
  RECENT_FAILS=$(tail -20 "$SHARED_DIR/decisions.jsonl" | grep '"FAIL' || true)
  if [ -n "$RECENT_FAILS" ]; then
    echo "There are recent FAIL verdicts in decisions.jsonl that may need attention." >&2
    exit 2
  fi
fi

# Nothing pending — exit quietly
exit 0
