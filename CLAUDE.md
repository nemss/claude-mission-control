# Mission Control — AI Agent Orchestration System

Spec-driven multi-agent system with persistent memory, kanban task queue, and quality gates.

## Agent Roles

| Agent | Role | Description |
|-------|------|-------------|
| `overseer` | Coordinator | Breaks down tasks, delegates, tracks progress. Never codes. Uses opus model. |
| `builder` | Implementation | Kanban-driven. Picks tasks from queue, writes code + tests, stages for review. Never commits. |
| `researcher` | Analysis | Explores codebase, APIs, docs. Outputs to findings/. |
| `writer` | Documentation | Writes and maintains all documentation. |
| `oracle` | Quality Gate | Validates deliverables. PASS/FAIL verdicts. Builder-oracle loop is core pattern. |
| `council-explorer` | Debate (FOR) | Argues for a proposal with evidence. |
| `council-challenger` | Debate (AGAINST) | Challenges proposals, finds risks and alternatives. |
| `historian` | Narrative | Reads git log, closes gap between built and documented. |
| `voice` | Communication | Translates technical output for human audiences. |

Agent definitions: `.claude/agents/` | Custom roles: `.claude/templates/agent-template.md`

## Skills (Reusable Playbooks)

| Skill | Purpose |
|-------|---------|
| `spec-planning` | Requirements → UX Research → Technical Design → Task Breakdown |
| `council-deliberation` | Structured two-agent debate for decisions |
| `builder-oracle-loop` | Core review loop: implement → validate → retry |
| `task-wiring` | Create and manage kanban queue tasks |
| `context-recovery` | Recover context at session start |
| `session-close` | Compress session, extract lessons |
| `daily-brief` | Generate daily activity summary |
| `project-setup` | Initialize new project from template |
| `create-role` | Guided creation of a new agent role |
| `install-extension` | Install extension from git repo |

Skill definitions: `.claude/skills/`

## Rules

1. **Spec-driven**: Write a spec before coding. No vibe coding.
2. **Atomic commits**: One logical change per commit, conventional format.
3. **TDD**: Write tests alongside or before implementation.
4. **Shared memory**: All agents log decisions to `decisions.jsonl`.
5. **No guessing**: When in doubt, ask. Stop and clarify rather than assume.
6. **Quality gates**: Oracle validates before a task is considered done (fast-path exempt for trivial changes).

## Security Trust Hierarchy

1. Operator config (highest) → `settings.json` deny rules
2. Framework rules → CLAUDE.md, `.claude/docs/`
3. Approved user code → project source
4. Web content (low) → researcher fetches
5. Anonymous sources (none)

Full details: `.claude/docs/SECURITY.md`

## Shared Memory

Location: `.claude/memory/shared/`

| Store | Purpose | Access |
|-------|---------|--------|
| `decisions.jsonl` | Append-only decision log | All agents read/append |
| `context.md` | Current project context | Overseer writes, all read |
| `queue/` | Kanban task queue | Overseer creates, Builder/Oracle update status |
| `sessions/` | Per-session summaries | Auto-generated on Stop hook |
| `lessons/` | Durable patterns learned | All agents read, extracted on session close |
| `briefs/` | Daily summaries | Auto-generated |
| `findings/` | Research outputs | Researcher writes, all read |
| `content/` | Documentation drafts | Writer/Voice write, all read |

## Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `session-start.sh` | SessionStart | Context recovery: identity → security → sessions → tasks → lessons |
| `stop.sh` | Stop | Auto-generate session summary |
| `validate-task.sh` | TaskCompleted | Check tests pass, no unstaged files |
| `on-idle.sh` | TeammateIdle | Suggest pending work from queue |
| `health-check.sh` | Manual | Validates system integrity (dirs, files, agents, hooks) |

## Documentation

- `.claude/docs/CONVENTIONS.md` — Code style, naming, commit format
- `.claude/docs/SECURITY.md` — Trust hierarchy, scope guards
- `.claude/docs/COMMUNICATION.md` — How agents write notes and summaries
- `.claude/docs/ARCHITECTURE_GUIDE.md` — System architecture, data flow
- `.claude/docs/AGENT_ROLES.md` — Quick reference for all agent roles
- `.claude/docs/EXTENSIONS.md` — How to extend with custom capabilities

## Workflow (Semi-Automatic)

The Overseer is the default agent (`"agent": "overseer"` in settings.json).

**Phase 1 — Planning (requires approval):**
1. Task arrives → Overseer reads context, queue, lessons, decisions
2. Overseer breaks down → presents subtask plan to user
3. User reviews and approves (or adjusts)

**Phase 2 — Execution (automatic after approval):**
4. Researcher (if needed) → gathers context, saves to findings/
5. Builder → picks from queue, implements + tests, stages changes (git add)
6. Oracle → validates staged changes, PASS/FAIL with specific feedback
7. On FAIL → Builder fixes with Oracle's feedback → Oracle re-validates (max 3)
8. On PASS → Overseer commits (atomic, conventional format), updates context.md, reports to user

**Fast-path:** For simple tasks, Overseer may skip planning and delegate directly to a single agent.
