#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook — context recovery sequence.
# Outputs context to stderr so it becomes part of the agent's context.
# Pattern: identity → security → recent sessions → active tasks → lessons → context

SHARED_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/shared"

echo "=== CONTEXT RECOVERY ===" >&2

# 1. Security rules
if [ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/docs/SECURITY.md" ]; then
  echo "" >&2
  echo "--- SECURITY RULES ---" >&2
  head -30 "${CLAUDE_PROJECT_DIR:-.}/.claude/docs/SECURITY.md" >&2
fi

# 2. Last 3 session summaries
if [ -d "$SHARED_DIR/sessions" ]; then
  SESSIONS=$(ls -t "$SHARED_DIR/sessions/"*.md 2>/dev/null | head -3)
  if [ -n "$SESSIONS" ]; then
    echo "" >&2
    echo "--- RECENT SESSIONS ---" >&2
    for s in $SESSIONS; do
      echo "" >&2
      echo "[$(basename "$s")]" >&2
      head -20 "$s" >&2
    done
  fi
fi

# 3. Active tasks from queue
if [ -d "$SHARED_DIR/queue" ]; then
  ACTIVE=$(grep -rl 'status: todo\|status: in-progress\|status: review\|status: blocked' "$SHARED_DIR/queue/"*.md 2>/dev/null || true)
  if [ -n "$ACTIVE" ]; then
    echo "" >&2
    echo "--- ACTIVE TASKS ---" >&2
    for t in $ACTIVE; do
      echo "" >&2
      echo "[$(basename "$t")]" >&2
      head -15 "$t" >&2
    done
  fi
fi

# 4. Recent lessons (last 10)
if [ -d "$SHARED_DIR/lessons" ]; then
  LESSONS=$(ls -t "$SHARED_DIR/lessons/"*.json 2>/dev/null | head -10)
  if [ -n "$LESSONS" ]; then
    echo "" >&2
    echo "--- LESSONS ---" >&2
    for l in $LESSONS; do
      cat "$l" >&2
      echo "" >&2
    done
  fi
fi

# 5. Current context
if [ -f "$SHARED_DIR/context.md" ]; then
  echo "" >&2
  echo "--- CURRENT CONTEXT ---" >&2
  cat "$SHARED_DIR/context.md" >&2
fi

# 6. Recent decisions (last 10)
if [ -f "$SHARED_DIR/decisions.jsonl" ] && [ -s "$SHARED_DIR/decisions.jsonl" ]; then
  echo "" >&2
  echo "--- RECENT DECISIONS ---" >&2
  tail -10 "$SHARED_DIR/decisions.jsonl" >&2
fi

echo "" >&2
echo "=== END CONTEXT RECOVERY ===" >&2

exit 0
