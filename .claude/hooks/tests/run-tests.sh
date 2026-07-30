#!/usr/bin/env bash

# Test suite for the Mission Control hooks.
#
# Dependency-free: bash + coreutils + git only. No bats, no npm.
# Run directly:  bash .claude/hooks/tests/run-tests.sh
# Or via make:   make test
#
# Every test runs against a throwaway fixture project created with mktemp -d and
# addressed through CLAUDE_PROJECT_DIR. No test reads or writes this repo's own
# .claude/memory/shared tree.
#
# Note: `set -e` is deliberately NOT used — a failing assertion must record itself
# and let the suite continue, not abort the run.

set -uo pipefail

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
HOOKS_DIR="$REPO_ROOT/.claude/hooks"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/mc-hook-tests.XXXXXX")
# Only ever removes the mktemp -d directory created above.
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

TODAY=$(date -u +%Y-%m-%d)

# ---------------------------------------------------------------- assertions

pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "    ok    $1"
}

fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "    FAIL  $1"
  [ -n "${2:-}" ] && echo "          $2"
  return 0
}

assert_exit_code() { # expected actual label
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$1" = "$2" ]; then
    pass "$3"
  else
    fail "$3" "expected exit $1, got $2"
  fi
}

assert_contains() { # haystack needle label
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s' "$1" | grep -qF -- "$2"; then
    pass "$3"
  else
    fail "$3" "output did not contain: $2"
  fi
}

assert_not_empty() { # value label
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -n "$1" ]; then
    pass "$2"
  else
    fail "$2" "value was empty"
  fi
}

assert_file_exists() { # path label
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -f "$1" ]; then
    pass "$2"
  else
    fail "$2" "no such file: $1"
  fi
}

assert_not_contains() { # haystack needle label
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s' "$1" | grep -qF -- "$2"; then
    fail "$3" "output unexpectedly contained: $2"
  else
    pass "$3"
  fi
}

assert_file_missing() { # path label
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ ! -e "$1" ]; then
    pass "$2"
  else
    fail "$2" "file should not exist: $1"
  fi
}

assert_equals() { # expected actual label
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$1" = "$2" ]; then
    pass "$3"
  else
    fail "$3" "expected '$1', got '$2'"
  fi
}

# Validates a JSON document. Skips (as a pass) if no JSON parser is available,
# because the hooks themselves fall back to plain text in that case.
assert_valid_json() { # json label
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! command -v python3 >/dev/null 2>&1; then
    pass "$2 (skipped — no python3)"
    return 0
  fi
  if printf '%s' "$1" | python3 -m json.tool >/dev/null 2>&1; then
    pass "$2"
  else
    fail "$2" "not valid JSON"
  fi
}

# Every line of a .jsonl file must parse independently.
assert_jsonl_valid() { # path label
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! command -v python3 >/dev/null 2>&1; then
    pass "$2 (skipped — no python3)"
    return 0
  fi
  if [ ! -s "$1" ]; then
    fail "$2" "file is empty: $1"
    return 0
  fi
  local bad=0 line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s' "$line" | python3 -m json.tool >/dev/null 2>&1 || bad=$((bad + 1))
  done < "$1"
  if [ "$bad" -eq 0 ]; then
    pass "$2"
  else
    fail "$2" "$bad malformed line(s)"
  fi
}

# ------------------------------------------------------------------ fixtures

# A minimal shared-memory tree. context.md keeps its placeholder Next Steps so
# on-idle.sh sees no actionable work (it filters lines starting with '[').
new_fixture() {
  local f
  f=$(mktemp -d "$TMP_ROOT/fixture.XXXXXX")
  mkdir -p "$f/.claude/memory/shared/sessions" \
           "$f/.claude/memory/shared/lessons" \
           "$f/.claude/memory/shared/briefs" \
           "$f/.claude/memory/shared/queue" \
           "$f/.claude/memory/shared/findings" \
           "$f/.claude/memory/shared/content"
  : > "$f/.claude/memory/shared/decisions.jsonl"
  printf '0' > "$f/.claude/memory/shared/queue/.counter"
  cat > "$f/.claude/memory/shared/context.md" <<'CTX'
# Current Context

## Active Goal
[What we're working on]

## Blockers
[Current blockers]

## Next Steps
[What needs to happen next]
CTX
  printf '%s\n' "$f"
}

# A fixture with the full .claude tree copied in, for health-check.sh.
new_full_fixture() {
  local f
  f=$(new_fixture)
  cp -R "$REPO_ROOT/.claude/agents"   "$f/.claude/"
  cp -R "$REPO_ROOT/.claude/skills"   "$f/.claude/"
  cp -R "$REPO_ROOT/.claude/hooks"    "$f/.claude/"
  cp -R "$REPO_ROOT/.claude/docs"     "$f/.claude/"
  cp "$REPO_ROOT/.claude/settings.json" "$f/.claude/settings.json"
  cp "$REPO_ROOT/CLAUDE.md" "$f/CLAUDE.md"
  printf '7' > "$f/.claude/memory/shared/queue/.counter"
  printf '%s\n' "$f"
}

# A fixture that is a real git repo, for validate-task.sh.
# Deliberately has no package.json/Makefile/etc so the hook's test-runner
# detection finds nothing and cannot recurse into this suite.
new_git_fixture() {
  local f
  f=$(new_fixture)
  git -C "$f" init -q 2>/dev/null
  git -C "$f" config user.email "test@example.com"
  git -C "$f" config user.name "Test"
  git -C "$f" config commit.gpgsign false
  printf 'v1\n' > "$f/tracked.txt"
  git -C "$f" add tracked.txt
  git -C "$f" commit -qm "init" 2>/dev/null
  printf '%s\n' "$f"
}

TASK_EVENT='{"task_subject":"test task","teammate_name":"builder"}'

# --------------------------------------------------------------- session-start

test_session_start() {
  echo "  session-start.sh"
  local f out code

  f=$(new_fixture)
  out=$(CLAUDE_PROJECT_DIR="$f" bash "$HOOKS_DIR/session-start.sh" 2>/dev/null)
  code=$?
  assert_exit_code 0 "$code" "exits 0"
  assert_not_empty "$out" "emits non-empty stdout"
  assert_valid_json "$out" "stdout is valid JSON"
  assert_contains "$out" "additionalContext" "payload carries additionalContext"
  assert_contains "$out" "CONTEXT RECOVERY" "payload contains the recovery block"

  # A bare directory with no .claude tree at all must be self-initialising.
  local bare
  bare=$(mktemp -d "$TMP_ROOT/bare.XXXXXX")
  out=$(CLAUDE_PROJECT_DIR="$bare" bash "$HOOKS_DIR/session-start.sh" 2>/dev/null)
  code=$?
  assert_exit_code 0 "$code" "survives an empty memory dir"
  assert_not_empty "$out" "still emits a payload on a bare project"
  assert_file_exists "$bare/.claude/memory/shared/decisions.jsonl" \
    "creates decisions.jsonl on first run"
  assert_file_exists "$bare/.claude/memory/shared/context.md" \
    "creates context.md on first run"

  # Rotation: >500 lines archives all but the last 100.
  local rot dfile lines
  rot=$(new_fixture)
  dfile="$rot/.claude/memory/shared/decisions.jsonl"
  local i
  for i in $(seq 1 600); do
    printf '{"ts":"2020-01-01T00:00:00Z","agent":"t","type":"note","summary":"e%s","detail":"d"}\n' "$i" >> "$dfile"
  done
  CLAUDE_PROJECT_DIR="$rot" bash "$HOOKS_DIR/session-start.sh" >/dev/null 2>&1
  code=$?
  assert_exit_code 0 "$code" "exits 0 while rotating"
  lines=$(wc -l < "$dfile" | tr -d ' ')
  assert_equals "100" "$lines" "keeps the last 100 entries after rotation"
  TESTS_RUN=$((TESTS_RUN + 1))
  if ls "$rot/.claude/memory/shared/decisions-archive/"*.jsonl >/dev/null 2>&1; then
    pass "writes an archive file"
  else
    fail "writes an archive file" "no archive in decisions-archive/"
  fi

  # Under 500 lines must be left alone.
  local keep
  keep=$(new_fixture)
  dfile="$keep/.claude/memory/shared/decisions.jsonl"
  for i in $(seq 1 10); do
    printf '{"ts":"2020-01-01T00:00:00Z","agent":"t","type":"note","summary":"e%s","detail":"d"}\n' "$i" >> "$dfile"
  done
  CLAUDE_PROJECT_DIR="$keep" bash "$HOOKS_DIR/session-start.sh" >/dev/null 2>&1
  lines=$(wc -l < "$dfile" | tr -d ' ')
  assert_equals "10" "$lines" "does not rotate under the threshold"
}

# ----------------------------------------------------------------- stop.sh

test_stop() {
  echo "  stop.sh"
  local f code summary first second

  f=$(new_fixture)
  printf '{"ts":"%sT10:00:00Z","agent":"builder","type":"note","summary":"did a thing","detail":"d"}\n' \
    "$TODAY" >> "$f/.claude/memory/shared/decisions.jsonl"

  CLAUDE_PROJECT_DIR="$f" bash "$HOOKS_DIR/stop.sh" >/dev/null 2>&1
  code=$?
  assert_exit_code 0 "$code" "exits 0"

  summary="$f/.claude/memory/shared/sessions/$TODAY.md"
  assert_file_exists "$summary" "writes sessions/$TODAY.md (day-scoped filename)"
  assert_contains "$(cat "$summary" 2>/dev/null)" "did a thing" \
    "summary includes today's decision"

  # Idempotent: a second run with no new decisions changes nothing.
  first=$(cat "$summary")
  CLAUDE_PROJECT_DIR="$f" bash "$HOOKS_DIR/stop.sh" >/dev/null 2>&1
  second=$(cat "$summary")
  assert_equals "$first" "$second" "idempotent across two runs"

  # No leftover temp files from the atomic write.
  TESTS_RUN=$((TESTS_RUN + 1))
  if ls "$f/.claude/memory/shared/sessions/$TODAY.md."* >/dev/null 2>&1; then
    fail "leaves no temp files behind" "found $TODAY.md.XXXX leftovers"
  else
    pass "leaves no temp files behind"
  fi

  # Empty decisions.jsonl → no summary at all.
  local empty
  empty=$(new_fixture)
  CLAUDE_PROJECT_DIR="$empty" bash "$HOOKS_DIR/stop.sh" >/dev/null 2>&1
  code=$?
  assert_exit_code 0 "$code" "exits 0 with empty decisions"
  assert_file_missing "$empty/.claude/memory/shared/sessions/$TODAY.md" \
    "writes no file when decisions are empty"

  # Decisions exist but none are from today → still no summary.
  local old
  old=$(new_fixture)
  printf '{"ts":"2020-01-01T10:00:00Z","agent":"builder","type":"note","summary":"old","detail":"d"}\n' \
    >> "$old/.claude/memory/shared/decisions.jsonl"
  CLAUDE_PROJECT_DIR="$old" bash "$HOOKS_DIR/stop.sh" >/dev/null 2>&1
  assert_file_missing "$old/.claude/memory/shared/sessions/$TODAY.md" \
    "writes no file when nothing is from today"
}

# ---------------------------------------------------------- validate-task.sh

test_validate_task() {
  echo "  validate-task.sh"
  local f code err

  # An unstaged file with no staged counterpart is unrelated work → warn, allow.
  f=$(new_git_fixture)
  printf 'v2\n' > "$f/tracked.txt"
  err=$(printf '%s' "$TASK_EVENT" | CLAUDE_PROJECT_DIR="$f" bash "$HOOKS_DIR/validate-task.sh" 2>&1 >/dev/null)
  code=$?
  assert_exit_code 0 "$code" "unrelated unstaged file → exit 0"
  assert_contains "$err" "WARN" "warns about the unstaged file"

  # Staged AND unstaged changes to one file → half-committed work → block.
  local g
  g=$(new_git_fixture)
  printf 'staged\n' > "$g/tracked.txt"
  git -C "$g" add tracked.txt
  printf 'staged then edited again\n' > "$g/tracked.txt"
  err=$(printf '%s' "$TASK_EVENT" | CLAUDE_PROJECT_DIR="$g" bash "$HOOKS_DIR/validate-task.sh" 2>&1 >/dev/null)
  code=$?
  assert_exit_code 2 "$code" "partially staged file → exit 2"
  assert_contains "$err" "partially staged" "explains the partial staging"
  assert_contains "$err" "tracked.txt" "names the offending file"
  local log
  log=$(cat "$g/.claude/memory/shared/decisions.jsonl")
  assert_contains "$log" "FAIL: partially staged changes" "logs a FAIL verdict"
  assert_not_contains "$log" "PASS: task completed" "does not also log a PASS"

  # A clean tree passes.
  local c
  c=$(new_git_fixture)
  printf '%s' "$TASK_EVENT" | CLAUDE_PROJECT_DIR="$c" bash "$HOOKS_DIR/validate-task.sh" >/dev/null 2>&1
  code=$?
  assert_exit_code 0 "$code" "clean tree → exit 0"

  # No test runner in the fixture, so the gate must say so out loud.
  err=$(printf '%s' "$TASK_EVENT" | CLAUDE_PROJECT_DIR="$c" bash "$HOOKS_DIR/validate-task.sh" 2>&1 >/dev/null)
  assert_contains "$err" "no test runner detected" "reports a missing test runner"

  # Everything it appends must be parseable JSON, one object per line.
  assert_jsonl_valid "$c/.claude/memory/shared/decisions.jsonl" \
    "appends only valid JSON lines"
  assert_contains "$(cat "$c/.claude/memory/shared/decisions.jsonl")" \
    "hook:validate-task" "attributes entries to the hook"

  # Makefile detection is what makes the gate live for this project (see the
  # root Makefile). Stub targets keep this from recursing into the suite itself.
  local m
  m=$(new_git_fixture)
  printf 'test:\n\t@exit 1\n' > "$m/Makefile"
  err=$(printf '%s' "$TASK_EVENT" | CLAUDE_PROJECT_DIR="$m" bash "$HOOKS_DIR/validate-task.sh" 2>&1 >/dev/null)
  code=$?
  assert_exit_code 2 "$code" "failing 'make test' target → exit 2"
  assert_contains "$err" "tests did not pass" "reports the test failure"

  printf 'test:\n\t@exit 0\n' > "$m/Makefile"
  err=$(printf '%s' "$TASK_EVENT" | CLAUDE_PROJECT_DIR="$m" bash "$HOOKS_DIR/validate-task.sh" 2>&1 >/dev/null)
  code=$?
  assert_exit_code 0 "$code" "passing 'make test' target → exit 0"
  assert_not_contains "$err" "no test runner detected" "no longer warns about a missing runner"
}

# --------------------------------------------------------------- on-idle.sh

test_on_idle() {
  echo "  on-idle.sh"
  local f code err

  f=$(new_fixture)
  cat > "$f/.claude/memory/shared/queue/001-thing.md" <<'TASK'
---
id: 001
status: todo
assignee: builder
---
# A pending task
TASK
  err=$(CLAUDE_PROJECT_DIR="$f" bash "$HOOKS_DIR/on-idle.sh" 2>&1 >/dev/null)
  code=$?
  assert_exit_code 2 "$code" "todo task in queue → exit 2"
  assert_contains "$err" "todo" "message mentions the todo task"

  # Empty queue, placeholder context, empty decisions → nothing to suggest.
  local e
  e=$(new_fixture)
  err=$(CLAUDE_PROJECT_DIR="$e" bash "$HOOKS_DIR/on-idle.sh" 2>&1 >/dev/null)
  code=$?
  assert_exit_code 0 "$code" "empty queue → exit 0"
  assert_equals "" "$err" "stays quiet when there is nothing to do"

  # A task awaiting review is also actionable.
  local r
  r=$(new_fixture)
  cat > "$r/.claude/memory/shared/queue/002-review.md" <<'TASK'
---
id: 002
status: review
assignee: builder
---
# Awaiting review
TASK
  err=$(CLAUDE_PROJECT_DIR="$r" bash "$HOOKS_DIR/on-idle.sh" 2>&1 >/dev/null)
  code=$?
  assert_exit_code 2 "$code" "review task in queue → exit 2"
  assert_contains "$err" "review" "message mentions the review task"
}

# ----------------------------------------------------------- health-check.sh

test_health_check() {
  echo "  health-check.sh"
  local f out code

  f=$(new_full_fixture)
  out=$(CLAUDE_PROJECT_DIR="$f" bash "$HOOKS_DIR/health-check.sh" 2>&1)
  code=$?
  assert_exit_code 0 "$code" "well-formed fixture → exit 0"
  assert_contains "$out" "ALL CHECKS PASSED" "prints the summary banner"

  # The regression that started all this: a flat skill file must be caught.
  printf -- '---\nname: zzz-flat\n---\n' > "$f/.claude/skills/zzz-flat.md"
  out=$(CLAUDE_PROJECT_DIR="$f" bash "$HOOKS_DIR/health-check.sh" 2>&1)
  code=$?
  assert_exit_code 1 "$code" "flat skill file → non-zero exit"
  assert_contains "$out" "flat skill file" "names the flat skill problem"
  assert_contains "$out" "ISSUE(S) FOUND" "summary banner still prints on failure"
  rm -f "$f/.claude/skills/zzz-flat.md"

  # A skill whose frontmatter name disagrees with its directory is unloadable.
  local g
  g=$(new_full_fixture)
  printf -- '---\nname: not-daily-brief\ndescription: x\n---\n' \
    > "$g/.claude/skills/daily-brief/SKILL.md"
  out=$(CLAUDE_PROJECT_DIR="$g" bash "$HOOKS_DIR/health-check.sh" 2>&1)
  code=$?
  assert_exit_code 1 "$code" "skill name/dir mismatch → non-zero exit"
  assert_contains "$out" "does not match directory" "explains the mismatch"

  # Counter sanity.
  local h
  h=$(new_full_fixture)
  : > "$h/.claude/memory/shared/queue/.counter"
  out=$(CLAUDE_PROJECT_DIR="$h" bash "$HOOKS_DIR/health-check.sh" 2>&1)
  code=$?
  assert_exit_code 1 "$code" "empty .counter → non-zero exit"
  assert_contains "$out" ".counter is empty" "explains the empty counter"

  # Lessons must be L-NNN.json and must parse.
  local l
  l=$(new_full_fixture)
  printf '{broken' > "$l/.claude/memory/shared/lessons/L-999.json"
  out=$(CLAUDE_PROJECT_DIR="$l" bash "$HOOKS_DIR/health-check.sh" 2>&1)
  code=$?
  assert_exit_code 1 "$code" "malformed lesson → non-zero exit"
  assert_contains "$out" "not valid JSON" "explains the malformed lesson"

  # A WARN must never change the exit code.
  local w
  w=$(new_full_fixture)
  printf '#!/usr/bin/env bash\necho hi\n' > "$w/.claude/hooks/zzz-orphan.sh"
  chmod +x "$w/.claude/hooks/zzz-orphan.sh"
  out=$(CLAUDE_PROJECT_DIR="$w" bash "$HOOKS_DIR/health-check.sh" 2>&1)
  code=$?
  assert_exit_code 0 "$code" "orphaned hook warns but still exits 0"
  assert_contains "$out" "orphaned" "reports the orphaned hook"
}

# -------------------------------------------------------------------- runner

echo "=== Mission Control Hook Tests ==="
echo ""

test_session_start
echo ""
test_stop
echo ""
test_validate_task
echo ""
test_on_idle
echo ""
test_health_check

echo ""
echo "================================="
echo "  $TESTS_RUN assertions, $TESTS_PASSED passed, $TESTS_FAILED failed"

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
