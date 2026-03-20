#!/usr/bin/env bash
set -euo pipefail

# TaskCompleted hook — validates task output before marking complete.
# Exit 0 = approve, Exit 2 = block (stderr sent as feedback).
# Receives hook event JSON on stdin.

SHARED_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/shared"
DECISIONS_FILE="$SHARED_DIR/decisions.jsonl"

# Ensure decisions file exists
[ -f "$DECISIONS_FILE" ] || touch "$DECISIONS_FILE"

# JSON field extractor — uses python3 if available, falls back to grep/sed
json_field() {
  local json="$1" field="$2"
  if command -v python3 &>/dev/null; then
    echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('$field','unknown'))" 2>/dev/null || echo "unknown"
  else
    echo "$json" | grep -o "\"$field\":\"[^\"]*\"" | sed "s/\"$field\":\"//;s/\"$//" || echo "unknown"
  fi
}

EVENT=$(cat)

TASK_SUBJECT=$(json_field "$EVENT" "task_subject")
TEAMMATE=$(json_field "$EVENT" "teammate_name")

# Check if there are uncommitted changes (potential unfinished work)
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
  UNSTAGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  if [ "$UNSTAGED" -gt 0 ]; then
    echo "Task '$TASK_SUBJECT' has $UNSTAGED unstaged file(s). Commit or stage changes before completing." >&2
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"agent\":\"hook:validate-task\",\"type\":\"verdict\",\"summary\":\"FAIL: unstaged changes\",\"detail\":\"$UNSTAGED unstaged files found for task: $TASK_SUBJECT\"}" >> "$DECISIONS_FILE"
    exit 2
  fi
fi

# Run tests if package.json exists and has a test script
if [ -f "${CLAUDE_PROJECT_DIR:-.}/package.json" ]; then
  HAS_TEST="no"
  if command -v python3 &>/dev/null; then
    HAS_TEST=$(python3 -c "import json; d=json.load(open('${CLAUDE_PROJECT_DIR:-.}/package.json')); print('yes' if 'test' in d.get('scripts',{}) else 'no')" 2>/dev/null || echo "no")
  else
    HAS_TEST=$(grep -q '"test"' "${CLAUDE_PROJECT_DIR:-.}/package.json" 2>/dev/null && echo "yes" || echo "no")
  fi
  if [ "$HAS_TEST" = "yes" ]; then
    if ! npm test --prefix "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null; then
      echo "Task '$TASK_SUBJECT' failed: npm test did not pass." >&2
      echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"agent\":\"hook:validate-task\",\"type\":\"verdict\",\"summary\":\"FAIL: tests failed\",\"detail\":\"npm test failed for task: $TASK_SUBJECT\"}" >> "$DECISIONS_FILE"
      exit 2
    fi
  fi
fi

# Log PASS verdict
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"agent\":\"hook:validate-task\",\"type\":\"verdict\",\"summary\":\"PASS: task completed\",\"detail\":\"Task '$TASK_SUBJECT' by $TEAMMATE passed validation\"}" >> "$DECISIONS_FILE"

exit 0
