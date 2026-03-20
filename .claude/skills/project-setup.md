---
name: project-setup
description: Initialize a new project with Mission Control agent orchestration
---

# Project Setup

## Prerequisites

- Empty or existing project directory
- Claude Code installed

## Setup Steps

### 1. Copy the Template

Copy the entire `.claude/` directory structure from the Mission Control template into your project.

### 2. Customize CLAUDE.md

Update the root `CLAUDE.md` with:
- Your project's specific overview
- Any additional rules or conventions
- Links to project-specific documentation

### 3. Configure Settings

Edit `.claude/settings.json`:
- Adjust permissions for your tech stack (e.g., add `Bash(cargo test*)` for Rust)
- Add project-specific environment variables
- Enable/disable hooks as needed

### 4. Initialize Shared Memory

Create initial `context.md`:
```markdown
# Current Context
## Active Goal
[Your project's current objective]
## Key Decisions
[None yet]
## Blockers
[None]
## Next Steps
[First tasks to accomplish]
```

### 5. Create Initial Tasks

Use the task-wiring skill to create your first tasks in `queue/`.

### 6. Start Working

Run the Overseer:
```
@overseer [describe what you want to build]
```

The Overseer will read context, break down tasks, and run the pipeline.

## Adding Custom Roles

Use the create-role skill or manually:
1. Create `.claude/agents/your-agent.md`
2. Add YAML frontmatter (name, description, tools)
3. Define what it does and doesn't do
4. Specify memory access patterns
5. Update AGENT_ROLES.md
