# Mission Control — AI Agent Orchestration System

Spec-driven multi-agent system for coordinating AI teammates through shared memory.

## Agent Roles

| Agent | Role | Description |
|-------|------|-------------|
| `overseer` | Coordinator | Breaks down tasks, delegates, tracks progress. Never codes. |
| `builder` | Implementation | Writes code and tests. Follows CONVENTIONS.md. |
| `researcher` | Analysis | Explores codebase, APIs, docs. Read-only, outputs to findings/. |
| `writer` | Documentation | Writes and maintains all documentation. |
| `oracle` | Quality Gate | Validates deliverables. Issues PASS/FAIL verdicts. |

Agent definitions: `.claude/agents/`

## Commands

- `/orchestrate` — Start the Overseer to coordinate a complex task
- `/delegate` — Have the Overseer assign subtasks to teammates
- `/spec` — Write a specification before implementation
- `/commit` — Create an atomic conventional commit
- `/start` — Initialize a new task with context

## Rules

1. **Spec-driven**: Write a spec before coding. No vibe coding.
2. **Atomic commits**: One logical change per commit, conventional format.
3. **TDD**: Write tests alongside or before implementation.
4. **Shared memory**: All agents log decisions to `decisions.jsonl`.
5. **No guessing**: When in doubt, ask. Stop and clarify rather than assume.
6. **Quality gates**: Oracle validates before a task is considered done.

## Shared Memory

Location: `.claude/memory/shared/`

| File | Purpose | Access |
|------|---------|--------|
| `decisions.jsonl` | Append-only decision log | All agents read/append |
| `context.md` | Current project context | Overseer writes, all read |
| `findings/` | Research outputs | Researcher writes, all read |
| `content/` | Documentation drafts | Writer writes, all read |

Entry format for decisions.jsonl:
```json
{"ts":"ISO-8601","agent":"name","type":"category","summary":"one-line","detail":"full context"}
```

## Hooks

- **TaskCompleted**: Validates deliverables (tests pass, no unstaged files)
- **TeammateIdle**: Suggests next work from context.md or unresolved FAILs

## Documentation

- `.claude/docs/CONVENTIONS.md` — Code style, naming, commit format
- `.claude/docs/ARCHITECTURE_GUIDE.md` — System architecture, data flow
- `.claude/docs/AGENT_ROLES.md` — Quick reference for all agent roles

## Workflow

1. Task arrives → Overseer reads context and decisions
2. Overseer breaks down → delegates to appropriate agents
3. Agents work → log to shared memory
4. Oracle validates → PASS/FAIL verdict
5. On FAIL → Builder fixes, Oracle re-validates
6. On PASS → Overseer updates context, reports to user
