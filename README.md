# Mission Control — AI Agent Orchestration System

A reusable multi-agent orchestration system for Claude Code. Coordinates specialized AI agents through shared filesystem-based memory.

## Quick Start

1. **Enable agent teams** (experimental feature):
   Already configured in `.claude/settings.json` with:
   ```json
   { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
   ```

2. **Start orchestrating**:
   ```
   /orchestrate [describe your task]
   ```
   The Overseer will break it down and delegate to the right agents.

3. **Or use agents directly**:
   ```
   @builder implement the login form
   @researcher analyze the auth API options
   @oracle validate the latest changes
   ```

## Agent Roles

| Agent | Role | What it does | What it doesn't do |
|-------|------|--------------|--------------------|
| **Overseer** | Coordinator | Breaks down tasks, delegates, tracks progress | Write code |
| **Builder** | Implementation | Writes code, tests, makes commits | Make architectural decisions alone |
| **Researcher** | Analysis | Explores codebase, APIs, documentation | Modify any files |
| **Writer** | Documentation | Creates and updates all documentation | Touch code files |
| **Oracle** | Quality Gate | Validates deliverables, issues PASS/FAIL | Fix issues (only reports them) |

## Memory Layer

All agents coordinate through a shared filesystem at `.claude/memory/shared/`:

```
.claude/memory/shared/
  decisions.jsonl    # Append-only log of all agent decisions
  context.md         # Current project state (updated by Overseer)
  findings/          # Research outputs from Researcher
  content/           # Documentation drafts from Writer
```

### decisions.jsonl format

```json
{"ts":"2025-01-15T10:30:00Z","agent":"builder","type":"implementation","summary":"Added auth middleware","detail":"..."}
```

Types: `delegation`, `implementation`, `research`, `documentation`, `verdict`, `blocker`

## Hooks

Two automated hooks run during agent team work:

- **TaskCompleted** (`validate-task.sh`): Checks for unstaged changes, runs tests if available. Blocks completion on failure.
- **TeammateIdle** (`on-idle.sh`): Suggests pending work from context.md or unresolved FAIL verdicts.

## Customization

### Add a new agent role

1. Create `.claude/agents/your-agent.md` with frontmatter:
   ```yaml
   ---
   name: your-agent
   description: What this agent does
   tools: Read, Grep, Glob
   ---
   ```
2. Define what it DOES and DOES NOT do in the markdown body
3. Specify how it reads/writes shared memory
4. Update `.claude/docs/AGENT_ROLES.md` with the new role

### Modify memory format

Edit the JSONL schema convention in `CLAUDE.md` and update all agent instructions to match.

### Add validation logic

Edit `.claude/hooks/validate-task.sh` to add project-specific checks (linting, type checking, etc.).

### Change conventions

Edit `.claude/docs/CONVENTIONS.md` for project-specific code style, naming, and commit rules.

## Project Structure

```
.
├── CLAUDE.md                          # Main agent configuration
├── README.md                          # This file
└── .claude/
    ├── settings.json                  # Permissions, hooks, env vars
    ├── agents/
    │   ├── overseer.md                # Coordinator agent
    │   ├── builder.md                 # Implementation agent
    │   ├── researcher.md              # Research agent
    │   ├── writer.md                  # Documentation agent
    │   └── oracle.md                  # Quality gate agent
    ├── docs/
    │   ├── CONVENTIONS.md             # Code style and commit rules
    │   ├── ARCHITECTURE_GUIDE.md      # System architecture
    │   └── AGENT_ROLES.md             # Agent role reference
    ├── hooks/
    │   ├── validate-task.sh           # TaskCompleted hook
    │   └── on-idle.sh                 # TeammateIdle hook
    └── memory/
        └── shared/
            ├── decisions.jsonl        # Decision log
            ├── context.md             # Current context
            ├── findings/              # Research outputs
            └── content/               # Documentation drafts
```
