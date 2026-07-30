#!/usr/bin/env bash
set -euo pipefail

# TaskCompleted hook — validates task output before marking complete.
# Exit 0 = approve, Exit 2 = block (stderr sent as feedback).
# Receives hook event JSON on stdin.
# Stack-agnostic: detects test runner from project files.

SHARED_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/memory/shared"
DECISIONS_FILE="$SHARED_DIR/decisions.jsonl"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

mkdir -p "$SHARED_DIR"
[ -f "$DECISIONS_FILE" ] || touch "$DECISIONS_FILE"

# Escape a string for embedding in a JSON string literal.
# python3 handles the full spec; the sed fallback covers the common cases.
json_escape() {
  local value="$1"
  if command -v python3 &>/dev/null; then
    VALUE="$value" python3 -c 'import json,os; print(json.dumps(os.environ["VALUE"])[1:-1])'
  else
    printf '%s' "$value" | tr -d '\000-\010\013\014\016-\037' \
      | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' \
      | awk 'NR>1{printf "\\n"}{printf "%s",$0}'
  fi
}

# Append a single-line JSON entry to decisions.jsonl.
# Usage: log_decision <type> <summary> <detail>
log_decision() {
  local type summary detail
  type=$(json_escape "$1")
  summary=$(json_escape "$2")
  detail=$(json_escape "$3")
  printf '{"ts":"%s","agent":"hook:validate-task","type":"%s","summary":"%s","detail":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$type" "$summary" "$detail" >> "$DECISIONS_FILE"
}

json_field() {
  local json="$1" field="$2"
  if command -v python3 &>/dev/null; then
    FIELD="$field" python3 -c 'import sys,json,os; print(json.load(sys.stdin).get(os.environ["FIELD"],"unknown"))' <<<"$json" 2>/dev/null || echo "unknown"
  else
    echo "$json" | grep -o "\"$field\":\"[^\"]*\"" | sed "s/\"$field\":\"//;s/\"$//" || echo "unknown"
  fi
}

EVENT=$(cat)
TASK_SUBJECT=$(json_field "$EVENT" "task_subject")
TEAMMATE=$(json_field "$EVENT" "teammate_name")

# Staging check.
# A file that is BOTH staged and unstaged is partially staged — the task's own work
# is half-committed, which is a real failure. A file that is only unstaged is
# unrelated work (hand edits, other agents in flight) and only warrants a warning.
if command -v git &>/dev/null && git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
  UNSTAGED_FILES=$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null || true)
  STAGED_FILES=$(git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null || true)

  PARTIAL_FILES=$(comm -12 \
    <(printf '%s\n' "$UNSTAGED_FILES" | sort -u) \
    <(printf '%s\n' "$STAGED_FILES" | sort -u) | sed '/^$/d')
  UNRELATED_FILES=$(comm -23 \
    <(printf '%s\n' "$UNSTAGED_FILES" | sort -u) \
    <(printf '%s\n' "$STAGED_FILES" | sort -u) | sed '/^$/d')

  if [ -n "$PARTIAL_FILES" ]; then
    PARTIAL_LIST=$(printf '%s' "$PARTIAL_FILES" | tr '\n' ' ')
    echo "Task '$TASK_SUBJECT' has partially staged file(s): $PARTIAL_LIST" >&2
    echo "These files have both staged and unstaged changes — stage the rest before completing." >&2
    log_decision "verdict" "FAIL: partially staged changes" \
      "Partially staged files for task '$TASK_SUBJECT': $PARTIAL_LIST"
    exit 2
  fi

  if [ -n "$UNRELATED_FILES" ]; then
    UNRELATED_LIST=$(printf '%s' "$UNRELATED_FILES" | tr '\n' ' ')
    echo "WARN: unstaged file(s) unrelated to this task: $UNRELATED_LIST" >&2
    log_decision "note" "WARN: unstaged files outside task scope" \
      "Unstaged files with no staged counterpart during task '$TASK_SUBJECT': $UNRELATED_LIST"
  fi
fi

# Auto-detect and run tests based on project stack.
# Returns 0 = passed, 1 = failed, 2 = no runner detected.
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

  return 2
}

TEST_STATUS=0
run_tests || TEST_STATUS=$?

case "$TEST_STATUS" in
  1)
    echo "Task '$TASK_SUBJECT' failed: tests did not pass." >&2
    log_decision "verdict" "FAIL: tests failed" "Tests failed for task: $TASK_SUBJECT"
    exit 2
    ;;
  2)
    # No runner found — the gate is decorative here, so make that visible.
    echo "WARN: no test runner detected — task '$TASK_SUBJECT' completed without test validation." >&2
    log_decision "note" "WARN: no test runner detected" \
      "No test runner found in $PROJECT_DIR; task '$TASK_SUBJECT' was not test-validated"
    ;;
esac

log_decision "verdict" "PASS: task completed" \
  "Task '$TASK_SUBJECT' by $TEAMMATE passed validation"

exit 0
