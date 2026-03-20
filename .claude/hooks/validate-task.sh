#!/usr/bin/env bash
set -euo pipefail

# TaskCompleted hook — validates task output before marking complete.
# Exit 0 = approve, Exit 2 = block (stderr sent as feedback).
# Receives hook event JSON on stdin.
# Stack-agnostic: detects test runner from project files.

SHARED_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/shared"
DECISIONS_FILE="$SHARED_DIR/decisions.jsonl"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

[ -f "$DECISIONS_FILE" ] || touch "$DECISIONS_FILE"

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

# Check for uncommitted changes
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
  UNSTAGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  if [ "$UNSTAGED" -gt 0 ]; then
    echo "Task '$TASK_SUBJECT' has $UNSTAGED unstaged file(s). Commit or stage changes before completing." >&2
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"agent\":\"hook:validate-task\",\"type\":\"verdict\",\"summary\":\"FAIL: unstaged changes\",\"detail\":\"$UNSTAGED unstaged files found for task: $TASK_SUBJECT\"}" >> "$DECISIONS_FILE"
    exit 2
  fi
fi

# Auto-detect and run tests based on project stack
run_tests() {
  # Node.js
  if [ -f "$PROJECT_DIR/package.json" ]; then
    local HAS_TEST="no"
    if command -v python3 &>/dev/null; then
      HAS_TEST=$(python3 -c "import json; d=json.load(open('$PROJECT_DIR/package.json')); print('yes' if 'test' in d.get('scripts',{}) else 'no')" 2>/dev/null || echo "no")
    else
      HAS_TEST=$(grep -q '"test"' "$PROJECT_DIR/package.json" 2>/dev/null && echo "yes" || echo "no")
    fi
    if [ "$HAS_TEST" = "yes" ]; then
      npm test --prefix "$PROJECT_DIR" 2>/dev/null && return 0 || return 1
    fi
  fi

  # Python
  if [ -f "$PROJECT_DIR/pytest.ini" ] || [ -f "$PROJECT_DIR/setup.py" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
    if command -v pytest &>/dev/null; then
      pytest "$PROJECT_DIR" 2>/dev/null && return 0 || return 1
    elif command -v python3 &>/dev/null; then
      python3 -m pytest "$PROJECT_DIR" 2>/dev/null && return 0 || return 1
    fi
  fi

  # Go
  if [ -f "$PROJECT_DIR/go.mod" ]; then
    if command -v go &>/dev/null; then
      (cd "$PROJECT_DIR" && go test ./... 2>/dev/null) && return 0 || return 1
    fi
  fi

  # Rust
  if [ -f "$PROJECT_DIR/Cargo.toml" ]; then
    if command -v cargo &>/dev/null; then
      (cd "$PROJECT_DIR" && cargo test 2>/dev/null) && return 0 || return 1
    fi
  fi

  # Makefile
  if [ -f "$PROJECT_DIR/Makefile" ]; then
    if grep -q '^test:' "$PROJECT_DIR/Makefile" 2>/dev/null; then
      (cd "$PROJECT_DIR" && make test 2>/dev/null) && return 0 || return 1
    fi
  fi

  # No test runner detected — pass by default
  return 0
}

if ! run_tests; then
  echo "Task '$TASK_SUBJECT' failed: tests did not pass." >&2
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"agent\":\"hook:validate-task\",\"type\":\"verdict\",\"summary\":\"FAIL: tests failed\",\"detail\":\"Tests failed for task: $TASK_SUBJECT\"}" >> "$DECISIONS_FILE"
  exit 2
fi

# Log PASS
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"agent\":\"hook:validate-task\",\"type\":\"verdict\",\"summary\":\"PASS: task completed\",\"detail\":\"Task '$TASK_SUBJECT' by $TEAMMATE passed validation\"}" >> "$DECISIONS_FILE"

exit 0
