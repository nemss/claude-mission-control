#!/usr/bin/env bash
set -euo pipefail

# Health check — validates Mission Control system integrity.
# Run manually: bash .claude/hooks/health-check.sh
# Exit 0 = healthy, Exit 1 = issues found.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
SHARED_DIR="$CLAUDE_DIR/memory/shared"
ISSUES=0

check() {
  local label="$1" condition="$2"
  if eval "$condition"; then
    echo "  PASS  $label"
  else
    echo "  FAIL  $label"
    ISSUES=$((ISSUES + 1))
  fi
}

echo "=== Mission Control Health Check ==="
echo ""

echo "--- Directories ---"
check "agents/"    "[ -d '$CLAUDE_DIR/agents' ]"
check "skills/"    "[ -d '$CLAUDE_DIR/skills' ]"
check "hooks/"     "[ -d '$CLAUDE_DIR/hooks' ]"
check "docs/"      "[ -d '$CLAUDE_DIR/docs' ]"
check "queue/"     "[ -d '$SHARED_DIR/queue' ]"
check "sessions/"  "[ -d '$SHARED_DIR/sessions' ]"
check "lessons/"   "[ -d '$SHARED_DIR/lessons' ]"
check "findings/"  "[ -d '$SHARED_DIR/findings' ]"
check "content/"   "[ -d '$SHARED_DIR/content' ]"
check "briefs/"    "[ -d '$SHARED_DIR/briefs' ]"

echo ""
echo "--- Core Files ---"
check "CLAUDE.md"       "[ -f '$PROJECT_DIR/CLAUDE.md' ]"
check "settings.json"   "[ -f '$CLAUDE_DIR/settings.json' ]"
check "context.md"      "[ -f '$SHARED_DIR/context.md' ]"
check "queue/.counter"  "[ -f '$SHARED_DIR/queue/.counter' ]"

echo ""
echo "--- Agents ---"
for agent in overseer builder oracle researcher writer council-explorer council-challenger historian voice; do
  check "$agent.md" "[ -f '$CLAUDE_DIR/agents/$agent.md' ]"
done

echo ""
echo "--- Hooks (executable) ---"
for hook in session-start.sh stop.sh validate-task.sh on-idle.sh health-check.sh; do
  check "$hook" "[ -x '$CLAUDE_DIR/hooks/$hook' ]"
done

echo ""
echo "--- Settings Validation ---"
check "settings.json valid JSON" "python3 -m json.tool '$CLAUDE_DIR/settings.json' > /dev/null 2>&1 || jq . '$CLAUDE_DIR/settings.json' > /dev/null 2>&1"

echo ""
echo "--- decisions.jsonl ---"
if [ -f "$SHARED_DIR/decisions.jsonl" ] && [ -s "$SHARED_DIR/decisions.jsonl" ]; then
  LINES=$(wc -l < "$SHARED_DIR/decisions.jsonl" | tr -d ' ')
  echo "  INFO  $LINES entries"
  if [ "$LINES" -gt 500 ]; then
    echo "  WARN  decisions.jsonl has $LINES entries — consider running rotation"
    ISSUES=$((ISSUES + 1))
  fi
else
  echo "  INFO  empty or missing (normal for fresh setup)"
fi

echo ""
echo "--- Queue Status ---"
QUEUE_FILES=$(find "$SHARED_DIR/queue" -name "*.md" 2>/dev/null || true)
if [ -n "$QUEUE_FILES" ]; then
  TODO=$(echo "$QUEUE_FILES" | xargs grep -l 'status: todo' 2>/dev/null | wc -l | tr -d ' ')
  IN_PROGRESS=$(echo "$QUEUE_FILES" | xargs grep -l 'status: in-progress' 2>/dev/null | wc -l | tr -d ' ')
  REVIEW=$(echo "$QUEUE_FILES" | xargs grep -l 'status: review' 2>/dev/null | wc -l | tr -d ' ')
  BLOCKED=$(echo "$QUEUE_FILES" | xargs grep -l 'status: blocked' 2>/dev/null | wc -l | tr -d ' ')
else
  TODO=0; IN_PROGRESS=0; REVIEW=0; BLOCKED=0
fi
echo "  INFO  todo=$TODO  in-progress=$IN_PROGRESS  review=$REVIEW  blocked=$BLOCKED"

echo ""
echo "==========================="
if [ "$ISSUES" -eq 0 ]; then
  echo "  ALL CHECKS PASSED"
  exit 0
else
  echo "  $ISSUES ISSUE(S) FOUND"
  exit 1
fi
