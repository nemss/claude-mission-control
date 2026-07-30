#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook — context recovery sequence + decisions rotation + daily brief check.
# The recovery payload goes to STDOUT: Claude Code reads SessionStart stdout as either JSON
# with hookSpecificOutput.additionalContext or as plain text. Diagnostics go to stderr.

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
    # Keep last 100 lines, archive the rest.
    # awk instead of `head -n -100`: negative counts are GNU-only, BSD/macOS head errors out.
    awk -v keep=$(( LINES - 100 )) 'NR<=keep' "$SHARED_DIR/decisions.jsonl" > "$ARCHIVE_DIR/$ARCHIVE_NAME"
    tail -100 "$SHARED_DIR/decisions.jsonl" > "$SHARED_DIR/decisions.jsonl.tmp"
    mv "$SHARED_DIR/decisions.jsonl.tmp" "$SHARED_DIR/decisions.jsonl"
    echo "Rotated decisions.jsonl: archived $(( LINES - 100 )) entries to $ARCHIVE_NAME" >&2
  fi
fi

# Check if daily brief exists for today — the nudge is agent-facing, so it joins the payload
TODAY=$(date -u +%Y-%m-%d)
BRIEF_NUDGE=""
if [ ! -f "$SHARED_DIR/briefs/$TODAY.md" ] && [ -s "$SHARED_DIR/decisions.jsonl" ]; then
  TODAY_ENTRIES=$(grep -c "$TODAY" "$SHARED_DIR/decisions.jsonl" 2>/dev/null || true)
  if [ "${TODAY_ENTRIES:-0}" -eq 0 ]; then
    # Check if there are any recent entries at all
    RECENT=$(tail -1 "$SHARED_DIR/decisions.jsonl" 2>/dev/null || true)
    if [ -n "$RECENT" ]; then
      BRIEF_NUDGE="
--- DAILY BRIEF ---
No brief for today ($TODAY). Consider running the daily-brief skill to generate one."
    fi
  fi
fi

# Build the recovery payload — 7 sections, order is load-bearing for the agent
build_payload() {
  [ -n "$BRIEF_NUDGE" ] && echo "$BRIEF_NUDGE"

  echo "=== CONTEXT RECOVERY ==="

  # 1. Security rules
  if [ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/docs/SECURITY.md" ]; then
    echo ""
    echo "--- SECURITY RULES ---"
    head -30 "${CLAUDE_PROJECT_DIR:-.}/.claude/docs/SECURITY.md"
  fi

  # 2. Last 3 session summaries
  SESSIONS=$(ls -t "$SHARED_DIR/sessions/"*.md 2>/dev/null | head -3 || true)
  if [ -n "$SESSIONS" ]; then
    echo ""
    echo "--- RECENT SESSIONS ---"
    for s in $SESSIONS; do
      echo ""
      echo "[$(basename "$s")]"
      head -20 "$s"
    done
  fi

  # 3. Active tasks from queue
  ACTIVE=$(grep -rl 'status: todo\|status: in-progress\|status: review\|status: blocked' "$SHARED_DIR/queue/"*.md 2>/dev/null || true)
  if [ -n "$ACTIVE" ]; then
    echo ""
    echo "--- ACTIVE TASKS ---"
    for t in $ACTIVE; do
      echo ""
      echo "[$(basename "$t")]"
      head -15 "$t"
    done
  fi

  # 4. Recent lessons (last 10)
  LESSONS=$(ls -t "$SHARED_DIR/lessons/"*.json 2>/dev/null | head -10 || true)
  if [ -n "$LESSONS" ]; then
    echo ""
    echo "--- LESSONS ---"
    for l in $LESSONS; do
      cat "$l"
      echo ""
    done
  fi

  # 5. Today's daily brief (if exists)
  if [ -f "$SHARED_DIR/briefs/$TODAY.md" ]; then
    echo ""
    echo "--- TODAY'S BRIEF ---"
    cat "$SHARED_DIR/briefs/$TODAY.md"
  fi

  # 6. Current context
  if [ -f "$SHARED_DIR/context.md" ]; then
    echo ""
    echo "--- CURRENT CONTEXT ---"
    cat "$SHARED_DIR/context.md"
  fi

  # 7. Recent decisions (last 10)
  if [ -s "$SHARED_DIR/decisions.jsonl" ]; then
    echo ""
    echo "--- RECENT DECISIONS ---"
    tail -10 "$SHARED_DIR/decisions.jsonl"
  fi

  echo ""
  echo "=== END CONTEXT RECOVERY ==="
}

PAYLOAD=$(build_payload || true)

# Emit on stdout as JSON. Fall back to plain text — also valid for SessionStart — if python3
# is unavailable or the encoding fails, so a broken encoder never blocks a session start.
if command -v python3 >/dev/null 2>&1 &&
   ENCODED=$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": sys.stdin.read(),
}}))
' 2>/dev/null) && [ -n "$ENCODED" ]; then
  printf '%s\n' "$ENCODED"
else
  printf '%s\n' "$PAYLOAD"
fi

exit 0
