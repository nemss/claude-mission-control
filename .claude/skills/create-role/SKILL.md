---
name: create-role
description: Guided creation of a new agent role from template
---

# Create a New Agent Role

## Step 1: Define the Role

Answer these questions:
1. **Name**: lowercase, hyphenated (e.g., `data-analyst`)
2. **Description**: one-line summary of what this agent does
3. **Purpose**: what problem does this role solve?

## Step 2: Set Tool Boundaries

Choose which tools this agent can use:
- `Read, Grep, Glob` — read-only exploration
- `Read, Write, Edit, Grep, Glob` — can modify files
- `Read, Grep, Glob, Bash` — can run shell commands
- `WebSearch, WebFetch` — can access the web
- `Agent` — can spawn sub-agents

Set `disallowedTools` for any tools that must be explicitly blocked.

## Step 3: Create the Agent File

Copy `.claude/templates/agent-template.md` to `.claude/agents/[name].md`.

Fill in:
- YAML frontmatter (name, description, tools, disallowedTools)
- What the agent DOES (3-5 concrete actions)
- What it DOES NOT do (constraints and boundaries)
- Shared memory access pattern (what it reads/writes)
- Workflow (step-by-step process)

## Step 4: Update Documentation

Add the new role to `.claude/docs/AGENT_ROLES.md`:
- Add row to the Role Matrix table
- Add entry to "When to Use Each Agent" table
- Add any new decision log entry types

## Step 5: Test

Invoke the new agent with a simple task to verify:
```
@your-agent-name [simple task description]
```

Check that it stays within its defined boundaries.
