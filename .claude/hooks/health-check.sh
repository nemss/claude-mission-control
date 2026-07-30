#!/usr/bin/env bash
set -euo pipefail

# Health check — validates Mission Control system integrity.
# Run manually: bash .claude/hooks/health-check.sh
# Exit 0 = healthy, Exit 1 = issues found.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
SHARED_DIR="$CLAUDE_DIR/memory/shared"
ISSUES=0
WARNINGS=0

check() {
  local label="$1" condition="$2"
  if eval "$condition"; then
    echo "  PASS  $label"
  else
    echo "  FAIL  $label"
    ISSUES=$((ISSUES + 1))
  fi
}

fail() {
  echo "  FAIL  $1"
  ISSUES=$((ISSUES + 1))
}

# WARN never changes the exit code — only FAIL does.
warn() {
  echo "  WARN  $1"
  WARNINGS=$((WARNINGS + 1))
}

# Read a frontmatter value: fm_value <file> <key>. Empty if absent or no frontmatter.
fm_value() {
  awk -v key="^$2:" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && /^---[[:space:]]*$/ { exit }
    NR > 1 && $0 ~ key { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }
  ' "$1"
}

# All skills Mission Control ships with.
KNOWN_SKILLS="builder-oracle-loop context-recovery council-deliberation create-role daily-brief
install-extension project-setup session-close spec-planning task-wiring"

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
echo "--- Agent Frontmatter ---"
for agent_file in "$CLAUDE_DIR"/agents/*.md; do
  [ -f "$agent_file" ] || continue
  AGENT_STEM=$(basename "$agent_file" .md)
  if [ "$(head -1 "$agent_file")" != "---" ]; then
    fail "$AGENT_STEM.md: no YAML frontmatter (must open with ---)"
    continue
  fi
  AGENT_NAME=$(fm_value "$agent_file" name)
  AGENT_DESC=$(fm_value "$agent_file" description)
  if [ -z "$AGENT_NAME" ]; then
    fail "$AGENT_STEM.md: frontmatter missing name:"
  elif [ "$AGENT_NAME" != "$AGENT_STEM" ]; then
    fail "$AGENT_STEM.md: name '$AGENT_NAME' does not match filename"
  elif [ -z "$AGENT_DESC" ]; then
    fail "$AGENT_STEM.md: frontmatter missing description:"
  else
    echo "  PASS  $AGENT_STEM.md frontmatter"
  fi
done

echo ""
echo "--- Skills Structure ---"
# Claude Code only loads .claude/skills/<name>/SKILL.md — a flat .md is a silent outage.
FLAT_SKILLS=$(find "$CLAUDE_DIR/skills" -maxdepth 1 -type f -name '*.md' 2>/dev/null || true)
if [ -n "$FLAT_SKILLS" ]; then
  while IFS= read -r flat; do
    [ -n "$flat" ] || continue
    fail "flat skill file (must be <name>/SKILL.md): $(basename "$flat")"
  done <<< "$FLAT_SKILLS"
else
  echo "  PASS  no flat .md files directly in skills/"
fi

for skill_dir in "$CLAUDE_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  SKILL_NAME=$(basename "$skill_dir")
  check "$SKILL_NAME/SKILL.md exists" "[ -f '${skill_dir}SKILL.md' ]"
done

for skill in $KNOWN_SKILLS; do
  check "known skill present: $skill" "[ -f '$CLAUDE_DIR/skills/$skill/SKILL.md' ]"
done

echo ""
echo "--- Skill Frontmatter ---"
for skill_dir in "$CLAUDE_DIR"/skills/*/; do
  [ -d "$skill_dir" ] || continue
  SKILL_NAME=$(basename "$skill_dir")
  SKILL_FILE="${skill_dir}SKILL.md"
  [ -f "$SKILL_FILE" ] || continue
  if [ "$(head -1 "$SKILL_FILE")" != "---" ]; then
    fail "$SKILL_NAME/SKILL.md: no YAML frontmatter (must open with ---)"
    continue
  fi
  FM_NAME=$(fm_value "$SKILL_FILE" name)
  FM_DESC=$(fm_value "$SKILL_FILE" description)
  if [ -z "$FM_NAME" ]; then
    fail "$SKILL_NAME/SKILL.md: frontmatter missing name:"
  elif [ "$FM_NAME" != "$SKILL_NAME" ]; then
    fail "$SKILL_NAME/SKILL.md: name '$FM_NAME' does not match directory"
  elif [ -z "$FM_DESC" ]; then
    fail "$SKILL_NAME/SKILL.md: frontmatter missing description:"
  else
    echo "  PASS  $SKILL_NAME/SKILL.md frontmatter"
  fi
done

echo ""
echo "--- Hooks (executable) ---"
for hook in session-start.sh stop.sh validate-task.sh on-idle.sh health-check.sh; do
  check "$hook" "[ -x '$CLAUDE_DIR/hooks/$hook' ]"
done

echo ""
echo "--- Hook Registration ---"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
REGISTERED_HOOKS=$(grep -o '\.claude/hooks/[A-Za-z0-9._-]*\.sh' "$SETTINGS_FILE" 2>/dev/null \
  | sed 's|.*/||' | sort -u || true)
if [ -z "$REGISTERED_HOOKS" ]; then
  fail "settings.json registers no hooks"
else
  while IFS= read -r hook; do
    [ -n "$hook" ] || continue
    if [ ! -f "$CLAUDE_DIR/hooks/$hook" ]; then
      fail "$hook is registered in settings.json but missing on disk"
    elif [ ! -x "$CLAUDE_DIR/hooks/$hook" ]; then
      fail "$hook is registered in settings.json but not executable"
    else
      echo "  PASS  $hook registered and runnable"
    fi
  done <<< "$REGISTERED_HOOKS"
fi

# health-check.sh is run manually, never wired to an event — every other hook should be.
for hook_file in "$CLAUDE_DIR"/hooks/*.sh; do
  [ -f "$hook_file" ] || continue
  HOOK_BASE=$(basename "$hook_file")
  if [ "$HOOK_BASE" = "health-check.sh" ]; then
    continue
  fi
  if ! echo "$REGISTERED_HOOKS" | grep -qx "$HOOK_BASE"; then
    warn "$HOOK_BASE is not referenced by settings.json — orphaned"
  fi
done

echo ""
echo "--- Settings Validation ---"
check "settings.json valid JSON" "python3 -m json.tool '$SETTINGS_FILE' > /dev/null 2>&1 || jq . '$SETTINGS_FILE' > /dev/null 2>&1"

echo ""
echo "--- decisions.jsonl ---"
if [ -f "$SHARED_DIR/decisions.jsonl" ] && [ -s "$SHARED_DIR/decisions.jsonl" ]; then
  LINES=$(wc -l < "$SHARED_DIR/decisions.jsonl" | tr -d ' ')
  echo "  INFO  $LINES entries"
  if [ "$LINES" -gt 500 ]; then
    warn "decisions.jsonl has $LINES entries — consider running rotation"
  fi
else
  echo "  INFO  empty or missing (normal for fresh setup)"
fi

echo ""
echo "--- Lessons Format ---"
# Canonical format: one JSON object per file, named L-NNN.json (.claude/docs/COMMUNICATION.md).
LESSON_FILES=$(find "$SHARED_DIR/lessons" -maxdepth 1 -type f 2>/dev/null || true)
LESSON_COUNT=0
if [ -n "$LESSON_FILES" ]; then
  while IFS= read -r lesson_file; do
    [ -n "$lesson_file" ] || continue
    LESSON_BASE=$(basename "$lesson_file")
    # README.md documents the format; .gitkeep keeps the directory in git.
    case "$LESSON_BASE" in README.md|.gitkeep) continue ;; esac
    LESSON_COUNT=$((LESSON_COUNT + 1))
    if ! echo "$LESSON_BASE" | grep -qE '^L-[0-9]{3}\.json$'; then
      fail "$LESSON_BASE is not named L-NNN.json"
    elif ! (python3 -m json.tool "$lesson_file" > /dev/null 2>&1 || jq . "$lesson_file" > /dev/null 2>&1); then
      fail "$LESSON_BASE is not valid JSON"
    else
      echo "  PASS  $LESSON_BASE"
    fi
  done <<< "$LESSON_FILES"
fi
if [ "$LESSON_COUNT" -eq 0 ]; then
  echo "  INFO  no lessons recorded yet"
fi

echo ""
echo "--- Queue Status ---"
QUEUE_FILES=$(find "$SHARED_DIR/queue" -name "*.md" 2>/dev/null || true)
if [ -n "$QUEUE_FILES" ]; then
  # `|| true`: grep exits 1 when a status has no matches, which pipefail would treat as fatal.
  TODO=$(echo "$QUEUE_FILES" | xargs grep -l 'status: todo' 2>/dev/null | wc -l | tr -d ' ' || true)
  IN_PROGRESS=$(echo "$QUEUE_FILES" | xargs grep -l 'status: in-progress' 2>/dev/null | wc -l | tr -d ' ' || true)
  REVIEW=$(echo "$QUEUE_FILES" | xargs grep -l 'status: review' 2>/dev/null | wc -l | tr -d ' ' || true)
  BLOCKED=$(echo "$QUEUE_FILES" | xargs grep -l 'status: blocked' 2>/dev/null | wc -l | tr -d ' ' || true)
else
  TODO=0; IN_PROGRESS=0; REVIEW=0; BLOCKED=0
fi
echo "  INFO  todo=$TODO  in-progress=$IN_PROGRESS  review=$REVIEW  blocked=$BLOCKED"

echo ""
echo "--- Queue Counter ---"
COUNTER_FILE="$SHARED_DIR/queue/.counter"
COUNTER=""
if [ ! -f "$COUNTER_FILE" ]; then
  fail ".counter is missing"
else
  COUNTER=$(tr -d ' \t\n\r' < "$COUNTER_FILE")
  if [ -z "$COUNTER" ]; then
    fail ".counter is empty — expected a non-negative integer"
    COUNTER=""
  elif ! echo "$COUNTER" | grep -qE '^[0-9]+$'; then
    fail ".counter is '$COUNTER' — expected a non-negative integer"
    COUNTER=""
  else
    echo "  PASS  .counter = $COUNTER"
  fi
fi

# Drift: a task ID above the counter means the next allocation reuses an existing ID.
# 10# forces base 10 so zero-padded IDs aren't read as octal.
if [ -n "$COUNTER" ] && [ -n "$QUEUE_FILES" ]; then
  while IFS= read -r task_file; do
    [ -n "$task_file" ] || continue
    TASK_ID=$(fm_value "$task_file" id)
    echo "$TASK_ID" | grep -qE '^[0-9]+$' || continue
    if [ "$((10#$TASK_ID))" -gt "$((10#$COUNTER))" ]; then
      warn "$(basename "$task_file") has id $TASK_ID > .counter $COUNTER — ID reuse risk"
    fi
  done <<< "$QUEUE_FILES"
fi

echo ""
echo "==========================="
if [ "$WARNINGS" -gt 0 ]; then
  echo "  $WARNINGS WARNING(S)"
fi
if [ "$ISSUES" -eq 0 ]; then
  echo "  ALL CHECKS PASSED"
  exit 0
else
  echo "  $ISSUES ISSUE(S) FOUND"
  exit 1
fi
