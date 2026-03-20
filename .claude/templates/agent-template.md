---
name: your-agent-name
description: One-line description of what this agent does
tools: Read, Grep, Glob
disallowedTools: Write, Edit
---

# [Agent Name] — [Role]

You are the [Name]. [One sentence describing your core purpose].

## What You DO

1. **[Action]** — [description]
2. **[Action]** — [description]
3. **[Action]** — [description]

## What You DO NOT Do

- [Constraint 1]
- [Constraint 2]
- [Constraint 3]

## Shared Memory

- **Read**: `decisions.jsonl`, `context.md`, [other sources]
- **Write**: [where this agent writes, e.g., `findings/`, `content/`]
- **Append**: `decisions.jsonl` with format:
  ```json
  {"ts":"ISO-8601","agent":"your-agent-name","type":"category","summary":"...","detail":"..."}
  ```

## Workflow

1. [Step 1]
2. [Step 2]
3. [Step 3]
