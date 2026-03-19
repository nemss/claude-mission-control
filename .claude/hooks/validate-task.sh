#!/usr/bin/env bash
set -euo pipefail

# TaskCompleted hook — validates task output before marking complete.
# Exit 0 = approve, Exit 2 = block (stderr sent as feedback).
# Receives hook event JSON on stdin.

SHARED_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/shared"
DECISIONS_FILE="$SHARED_DIR/decisions.jsonl"

# Read hook event from stdin
EVENT=$(cat)

TASK_SUBJECT=$(echo "$EVENT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('task_subject','unknown'))" 2>/dev/null || echo "unknown")
TEAMMATE=$(echo "$EVENT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('teammate_name','unknown'))" 2>/dev/null || echo "unknown")

# Check if there are uncommitted changes (potential unfinished work)
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
  UNSTAGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  if [ "$UNSTAGED" -gt 0 ]; then
    echo "Task '$TASK_SUBJECT' has $UNSTAGED unstaged file(s). Commit or stage changes before completing." >&2
    # Log FAIL verdict
    if [ -d "$SHARED_DIR" ]; then
      echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"agent\":\"hook:validate-task\",\"type\":\"verdict\",\"summary\":\"FAIL: unstaged changes\",\"detail\":\"$UNSTAGED unstaged files found for task: $TASK_SUBJECT\"}" >> "$DECISIONS_FILE"
    fi
    exit 2
  fi
fi

# Run tests if package.json exists and has a test script
if [ -f "${CLAUDE_PROJECT_DIR:-.}/package.json" ]; then
  HAS_TEST=$(python3 -c "import json; d=json.load(open('${CLAUDE_PROJECT_DIR:-.}/package.json')); print('yes' if 'test' in d.get('scripts',{}) else 'no')" 2>/dev/null || echo "no")
  if [ "$HAS_TEST" = "yes" ]; then
    if ! npm test --prefix "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null; then
      echo "Task '$TASK_SUBJECT' failed: npm test did not pass." >&2
      if [ -d "$SHARED_DIR" ]; then
        echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"agent\":\"hook:validate-task\",\"type\":\"verdict\",\"summary\":\"FAIL: tests failed\",\"detail\":\"npm test failed for task: $TASK_SUBJECT\"}" >> "$DECISIONS_FILE"
      fi
      exit 2
    fi
  fi
fi

# Log PASS verdict
if [ -d "$SHARED_DIR" ]; then
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"agent\":\"hook:validate-task\",\"type\":\"verdict\",\"summary\":\"PASS: task completed\",\"detail\":\"Task '$TASK_SUBJECT' by $TEAMMATE passed validation\"}" >> "$DECISIONS_FILE"
fi

exit 0
