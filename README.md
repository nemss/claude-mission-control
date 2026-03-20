# Mission Control — AI Agent Orchestration System

A multi-agent orchestration system for Claude Code. Specialized agents coordinate through persistent filesystem-based memory with kanban task queues and quality gates.

**Core principle:** Memory is permanent, agents are not. The memory isn't in the agent — it's in the system. Replace any agent, lose nothing.

## Why Mission Control?

Stock Claude Code is a single agent with no memory between sessions. That works for small tasks. It breaks down on real projects.

| Problem | Stock Claude Code | Mission Control |
|---------|-------------------|-----------------|
| **Context loss** | Every session starts blank. You re-explain the project each time. | Persistent shared memory. Agents recover full context on start. |
| **No coordination** | One agent does everything — planning, coding, reviewing, documenting. | Specialized agents with clear boundaries. Overseer delegates, Builder codes, Oracle reviews. |
| **No quality gates** | You are the only reviewer. Mistakes ship if you miss them. | Oracle validates every deliverable. PASS/FAIL with specific feedback and automatic retries. |
| **No task management** | Work lives in your head or in ad-hoc prompts. | Kanban queue with status tracking. Tasks persist across sessions. |
| **Lost decisions** | Why was this choice made? No record. | Append-only decision log. Every agent logs what it did and why. |
| **No learned patterns** | Same mistakes repeat across sessions. | Lessons system. The swarm records what works and what to avoid. |

The result: you give direction once, and a team of agents executes with structure, memory, and accountability.

## Quick Start

1. **Enable agent teams** (already configured in `.claude/settings.json`):
   ```json
   { "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
   ```

2. **Start orchestrating**:
   ```
   @overseer [describe your task]
   ```
   The Overseer breaks it down, presents a plan, and after approval runs the pipeline automatically.

3. **Or use agents directly**:
   ```
   @builder pick the next task from the queue
   @researcher analyze the auth API options
   @oracle validate the latest changes
   ```

## Agent Roles

| Agent | Role | What it does |
|-------|------|-------------|
| **Overseer** | Coordinator | Breaks down tasks, manages queue, delegates. Never codes. |
| **Builder** | Implementation | Kanban-driven. Picks tasks, writes code + tests, commits. |
| **Researcher** | Analysis | Explores codebase, APIs, docs. Read-only. |
| **Writer** | Documentation | Creates and updates all documentation. |
| **Oracle** | Quality Gate | Validates deliverables. PASS/FAIL with specific feedback. |
| **Council** | Debate | Explorer (FOR) + Challenger (AGAINST) for better decisions. |
| **Historian** | Narrative | Reads git log, closes gap between built and documented. |
| **Voice** | Communication | Translates technical output for human audiences. |

## Core Workflow

```
YOU → OVERSEER → BUILDER → ORACLE
                    ↑         │
                    └─ FAIL ──┘ (retry with specific feedback)
                       PASS → done
```

1. You give direction → Overseer plans (you approve)
2. Builder picks from queue → implements → sends to review
3. Oracle validates → PASS or FAIL with feedback
4. On FAIL → Builder fixes → Oracle re-validates (max 3 retries)
5. Overseer summarizes and reports

## Memory Layer

Every agent wakes up empty. But the system remembers everything.

```
.claude/memory/shared/
  decisions.jsonl    # Append-only log of all agent activity
  context.md         # Current project state (Overseer maintains)
  queue/             # Kanban task queue with status tracking
  sessions/          # Per-session compressed summaries
  lessons/           # Durable patterns the swarm has learned
  briefs/            # Daily activity summaries
  findings/          # Research outputs from Researcher
  content/           # Documentation drafts from Writer/Voice
```

### Context Recovery

On every session start, the system recovers context automatically:
**Identity → Security → Recent Sessions → Active Tasks → Lessons → Context**

### Lessons — The Swarm Learns

Agents record durable patterns: what works, what to avoid. Searchable before every run. The swarm gets smarter about its own failure modes over time.

## Skills (Reusable Playbooks)

| Skill | Purpose |
|-------|---------|
| **spec-planning** | 4-step spec: Requirements → UX Research → Technical Design → Task Breakdown |
| **council-deliberation** | Structured two-agent debate for decisions with trade-offs |
| **builder-oracle-loop** | Core review loop: implement → validate → retry |
| **task-wiring** | Create and manage kanban queue tasks |
| **context-recovery** | Recover full context at session start |
| **session-close** | Compress session into summary, extract lessons |

## Customization

### Add a new agent role

Use the `create-role` skill or manually:
1. Copy `.claude/templates/agent-template.md` to `.claude/agents/your-agent.md`
2. Define tools, boundaries, and memory access
3. Update `.claude/docs/AGENT_ROLES.md`

### Install an extension

Extensions are git repos with agents, skills, hooks. Use the `install-extension` skill or:
1. Clone the extension repo
2. Copy its files into `.claude/`
3. Update settings if needed

See `.claude/docs/EXTENSIONS.md` for details.

### Change conventions

Edit `.claude/docs/CONVENTIONS.md` for project-specific rules.

## Project Structure

```
.
├── CLAUDE.md                              # Main agent configuration
├── README.md                              # This file
└── .claude/
    ├── settings.json                      # Permissions, hooks, env vars
    ├── agents/
    │   ├── overseer.md                    # Coordinator
    │   ├── builder.md                     # Implementation
    │   ├── researcher.md                  # Analysis
    │   ├── writer.md                      # Documentation
    │   ├── oracle.md                      # Quality gate
    │   ├── council-explorer.md            # Debate: argues FOR
    │   ├── council-challenger.md          # Debate: argues AGAINST
    │   ├── historian.md                   # Narrative from git/decisions
    │   └── voice.md                       # Human communication
    ├── skills/
    │   ├── spec-planning.md               # 4-step spec system
    │   ├── council-deliberation.md        # Two-agent debate
    │   ├── builder-oracle-loop.md         # Core review loop
    │   ├── task-wiring.md                 # Kanban task management
    │   ├── context-recovery.md            # Session start recovery
    │   ├── session-close.md               # Session end compression
    │   ├── daily-brief.md                 # Daily summary generation
    │   ├── project-setup.md               # New project initialization
    │   ├── create-role.md                 # New agent role creation
    │   └── install-extension.md           # Extension installation
    ├── docs/
    │   ├── CONVENTIONS.md                 # Code style and commit rules
    │   ├── SECURITY.md                    # Trust hierarchy and scope guards
    │   ├── COMMUNICATION.md               # Agent communication standards
    │   ├── ARCHITECTURE_GUIDE.md          # System architecture
    │   ├── AGENT_ROLES.md                 # Agent role reference
    │   └── EXTENSIONS.md                  # Extension system docs
    ├── hooks/
    │   ├── session-start.sh               # Context recovery on start
    │   ├── stop.sh                        # Session summary on stop
    │   ├── validate-task.sh               # Task completion validation
    │   └── on-idle.sh                     # Idle work suggestion
    ├── templates/
    │   └── agent-template.md              # Boilerplate for new agents
    ├── extensions/                         # Installed extensions
    └── memory/
        └── shared/
            ├── decisions.jsonl            # Decision log
            ├── context.md                 # Current context
            ├── queue/                     # Task queue
            ├── sessions/                  # Session summaries
            ├── lessons/                   # Learned patterns
            ├── briefs/                    # Daily briefs
            ├── findings/                  # Research outputs
            └── content/                   # Documentation drafts
```

## Engineering Standards

Agents follow the same standards a real team would:
- **Security**: Trust hierarchy, scope guards, data handling — `.claude/docs/SECURITY.md`
- **Code**: Naming, structure, commit format — `.claude/docs/CONVENTIONS.md`
- **Communication**: Notes, summaries, handoff messages — `.claude/docs/COMMUNICATION.md`
