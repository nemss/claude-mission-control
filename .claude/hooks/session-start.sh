#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook — context recovery sequence + decisions rotation + daily brief check.
# Outputs context to stderr so it becomes part of the agent's context.

SHARED_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/shared"

# Auto-initialize missing files and directories on first run
mkdir -p "$SHARED_DIR/sessions" "$SHARED_DIR/lessons" "$SHARED_DIR/briefs" \
         "$SHARED_DIR/queue" "$SHARED_DIR/findings" "$SHARED_DIR/content"
[ -f "$SHARED_DIR/decisions.jsonl" ] || touch "$SHARED_DIR/decisions.jsonl"
[ -f "$SHARED_DIR/context.md" ] || cat > "$SHARED_DIR/context.md" <<'TMPL'
# Current Context

## Active Goal
[What we're working on]

## Key Decisions
[Recent decisions from decisions.jsonl]

## Blockers
[Current blockers]

## Next Steps
[What needs to happen next]
TMPL

# Rotate decisions.jsonl if over 500 lines
if [ -f "$SHARED_DIR/decisions.jsonl" ] && [ -s "$SHARED_DIR/decisions.jsonl" ]; then
  LINES=$(wc -l < "$SHARED_DIR/decisions.jsonl" | tr -d ' ')
  if [ "$LINES" -gt 500 ]; then
    ARCHIVE_DIR="$SHARED_DIR/decisions-archive"
    mkdir -p "$ARCHIVE_DIR"
    ARCHIVE_NAME="decisions-$(date -u +%Y-%m-%dT%H%M).jsonl"
    # Keep last 100 lines, archive the rest
    head -n -100 "$SHARED_DIR/decisions.jsonl" > "$ARCHIVE_DIR/$ARCHIVE_NAME"
    tail -100 "$SHARED_DIR/decisions.jsonl" > "$SHARED_DIR/decisions.jsonl.tmp"
    mv "$SHARED_DIR/decisions.jsonl.tmp" "$SHARED_DIR/decisions.jsonl"
    echo "Rotated decisions.jsonl: archived $(( LINES - 100 )) entries to $ARCHIVE_NAME" >&2
  fi
fi

# Check if daily brief exists for today — suggest generating one if not
TODAY=$(date -u +%Y-%m-%d)
if [ ! -f "$SHARED_DIR/briefs/$TODAY.md" ] && [ -s "$SHARED_DIR/decisions.jsonl" ]; then
  YESTERDAY_ENTRIES=$(grep "$TODAY" "$SHARED_DIR/decisions.jsonl" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$YESTERDAY_ENTRIES" -eq 0 ]; then
    # Check if there are any recent entries at all
    RECENT=$(tail -1 "$SHARED_DIR/decisions.jsonl" 2>/dev/null || true)
    if [ -n "$RECENT" ]; then
      echo "" >&2
      echo "--- DAILY BRIEF ---" >&2
      echo "No brief for today ($TODAY). Consider running the daily-brief skill to generate one." >&2
    fi
  fi
fi

echo "=== CONTEXT RECOVERY ===" >&2

# 1. Security rules
if [ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/docs/SECURITY.md" ]; then
  echo "" >&2
  echo "--- SECURITY RULES ---" >&2
  head -30 "${CLAUDE_PROJECT_DIR:-.}/.claude/docs/SECURITY.md" >&2
fi

# 2. Last 3 session summaries
SESSIONS=$(ls -t "$SHARED_DIR/sessions/"*.md 2>/dev/null | head -3 || true)
if [ -n "$SESSIONS" ]; then
  echo "" >&2
  echo "--- RECENT SESSIONS ---" >&2
  for s in $SESSIONS; do
    echo "" >&2
    echo "[$(basename "$s")]" >&2
    head -20 "$s" >&2
  done
fi

# 3. Active tasks from queue
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

# 4. Recent lessons (last 10)
LESSONS=$(ls -t "$SHARED_DIR/lessons/"*.json 2>/dev/null | head -10 || true)
if [ -n "$LESSONS" ]; then
  echo "" >&2
  echo "--- LESSONS ---" >&2
  for l in $LESSONS; do
    cat "$l" >&2
    echo "" >&2
  done
fi

# 5. Today's daily brief (if exists)
if [ -f "$SHARED_DIR/briefs/$TODAY.md" ]; then
  echo "" >&2
  echo "--- TODAY'S BRIEF ---" >&2
  cat "$SHARED_DIR/briefs/$TODAY.md" >&2
fi

# 6. Current context
if [ -f "$SHARED_DIR/context.md" ]; then
  echo "" >&2
  echo "--- CURRENT CONTEXT ---" >&2
  cat "$SHARED_DIR/context.md" >&2
fi

# 7. Recent decisions (last 10)
if [ -s "$SHARED_DIR/decisions.jsonl" ]; then
  echo "" >&2
  echo "--- RECENT DECISIONS ---" >&2
  tail -10 "$SHARED_DIR/decisions.jsonl" >&2
fi

echo "" >&2
echo "=== END CONTEXT RECOVERY ===" >&2

exit 0
