#!/usr/bin/env bash
set -euo pipefail

# Stop hook — generates a session summary when a session ends.
# Reads recent decisions and creates a compressed summary in sessions/.

SHARED_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/shared"
SESSIONS_DIR="$SHARED_DIR/sessions"
DECISIONS_FILE="$SHARED_DIR/decisions.jsonl"

# Ensure sessions directory exists
mkdir -p "$SESSIONS_DIR"

TIMESTAMP=$(date -u +%Y-%m-%dT%H%M)
SUMMARY_FILE="$SESSIONS_DIR/${TIMESTAMP}.md"

# Only create summary if there are decisions from this session
if [ ! -f "$DECISIONS_FILE" ] || [ ! -s "$DECISIONS_FILE" ]; then
  exit 0
fi

# Get today's decisions
TODAY=$(date -u +%Y-%m-%d)
TODAY_DECISIONS=$(grep "$TODAY" "$DECISIONS_FILE" 2>/dev/null || true)

if [ -z "$TODAY_DECISIONS" ]; then
  exit 0
fi

# Build summary
{
  echo "# Session Summary: $TIMESTAMP"
  echo ""
  echo "## Decisions Made"
  echo "$TODAY_DECISIONS" | while IFS= read -r line; do
    AGENT=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agent','?'))" 2>/dev/null || echo "?")
    TYPE=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('type','?'))" 2>/dev/null || echo "?")
    SUMMARY=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('summary','?'))" 2>/dev/null || echo "?")
    echo "- **[$AGENT]** ($TYPE): $SUMMARY"
  done
  echo ""

  # Include current context snapshot
  if [ -f "$SHARED_DIR/context.md" ]; then
    echo "## Context Snapshot"
    cat "$SHARED_DIR/context.md"
  fi
} > "$SUMMARY_FILE"

exit 0
