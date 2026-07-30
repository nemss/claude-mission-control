#!/usr/bin/env bash
set -euo pipefail

# Session summary hook — writes one summary per day to sessions/YYYY-MM-DD.md.
#
# Event model: registered primarily on SessionEnd, which fires once when a session
# ends. Stop is also registered because it is the only event that fires while a
# session is still alive, so the day's summary stays current during long sessions.
# Stop fires after *every* assistant response, so this hook must be idempotent: it
# regenerates the whole file from decisions.jsonl on each run instead of appending.
# Re-running it without new decisions leaves the file byte-identical.

SHARED_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/shared"
SESSIONS_DIR="$SHARED_DIR/sessions"
DECISIONS_FILE="$SHARED_DIR/decisions.jsonl"

TODAY=$(date -u +%Y-%m-%d)
SUMMARY_FILE="$SESSIONS_DIR/${TODAY}.md"

if [ ! -f "$DECISIONS_FILE" ] || [ ! -s "$DECISIONS_FILE" ]; then
  exit 0
fi

# Match the ts field specifically — a bare date grep also hits summary/detail text.
TODAY_DECISIONS=$(grep -E "\"ts\"[[:space:]]*:[[:space:]]*\"$TODAY" "$DECISIONS_FILE" 2>/dev/null || true)

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

mkdir -p "$SESSIONS_DIR"

# Write to a temp file first so a failed run never truncates a good summary.
TMP_FILE=$(mktemp "${SUMMARY_FILE}.XXXXXX")
trap 'rm -f "$TMP_FILE"' EXIT

{
  echo "# Session Summary: $TODAY"
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
} > "$TMP_FILE"

mv "$TMP_FILE" "$SUMMARY_FILE"
trap - EXIT

exit 0
