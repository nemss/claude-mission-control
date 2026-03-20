#!/usr/bin/env bash
set -euo pipefail

# Stop hook — generates a session summary when a session ends.
# Reads recent decisions and creates a compressed summary in sessions/.

SHARED_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/shared"
SESSIONS_DIR="$SHARED_DIR/sessions"
DECISIONS_FILE="$SHARED_DIR/decisions.jsonl"

mkdir -p "$SESSIONS_DIR"

TIMESTAMP=$(date -u +%Y-%m-%dT%H%M)
SUMMARY_FILE="$SESSIONS_DIR/${TIMESTAMP}.md"

if [ ! -f "$DECISIONS_FILE" ] || [ ! -s "$DECISIONS_FILE" ]; then
  exit 0
fi

TODAY=$(date -u +%Y-%m-%d)
TODAY_DECISIONS=$(grep "$TODAY" "$DECISIONS_FILE" 2>/dev/null || true)

if [ -z "$TODAY_DECISIONS" ]; then
  exit 0
fi

# JSON field extractor — uses python3 if available, falls back to grep/sed
json_field() {
  local json="$1" field="$2"
  if command -v python3 &>/dev/null; then
    echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('$field','?'))" 2>/dev/null || echo "?"
  else
    echo "$json" | grep -o "\"$field\":\"[^\"]*\"" | sed "s/\"$field\":\"//;s/\"$//" || echo "?"
  fi
}

{
  echo "# Session Summary: $TIMESTAMP"
  echo ""
  echo "## Decisions Made"
  echo "$TODAY_DECISIONS" | while IFS= read -r line; do
    AGENT=$(json_field "$line" "agent")
    TYPE=$(json_field "$line" "type")
    SUMMARY=$(json_field "$line" "summary")
    echo "- **[$AGENT]** ($TYPE): $SUMMARY"
  done
  echo ""

  if [ -f "$SHARED_DIR/context.md" ]; then
    echo "## Context Snapshot"
    cat "$SHARED_DIR/context.md"
  fi
} > "$SUMMARY_FILE"

exit 0
