# Architecture Guide

## Overview

Mission Control is an AI agent orchestration system built on Claude Code. It coordinates specialized agents through a shared filesystem-based memory layer with persistent context across sessions.

## System Architecture

```
User
  │
  ▼
┌─────────────────────────────────────────────────┐
│                   OVERSEER                       │
│  Full picture · Routes tasks · Never executes    │
│  Uses most capable model (opus)                  │
└──────┬──────┬──────┬──────┬──────┬──────────────┘
       │      │      │      │      │
       ▼      ▼      ▼      ▼      ▼
   Builder  Oracle  Researcher  Writer  Council
   (code)   (QA)    (analysis)  (docs)  (debate)
       │      │      │          │
       ▼      ▼      ▼          ▼
┌─────────────────────────────────────────────────┐
│            SHARED MEMORY (filesystem)            │
│  queue/ · decisions.jsonl · context.md           │
│  sessions/ · lessons/ · briefs/ · findings/      │
└─────────────────────────────────────────────────┘
```

## Core Flow

```
YOU → OVERSEER → BUILDER → ORACLE
                    ↑         │
                    └─ FAIL ──┘ (retry with feedback)
                       PASS → done
```

1. **User** gives direction
2. **Overseer** breaks into tasks, creates queue items, waits for approval
3. **Builder** picks task, implements, sends to review
4. **Oracle** validates, PASS or FAIL with specific feedback
5. On FAIL → Builder fixes → Oracle re-validates (max 3 retries)
6. **Overseer** summarizes outcome, updates context

## Memory Layer

### Persistent (survives sessions)

| Store | Format | Purpose |
|-------|--------|---------|
| `decisions.jsonl` | Append-only JSONL | All agent decisions and verdicts |
| `context.md` | Markdown | Current project state (Overseer maintains) |
| `queue/` | Markdown files | Kanban task queue with status tracking |
| `sessions/` | Markdown files | Per-session compressed summaries |
| `lessons/` | JSON files | Durable patterns the swarm has learned |
| `briefs/` | Markdown files | Daily activity summaries |
| `findings/` | Markdown files | Research outputs |
| `content/` | Markdown files | Documentation drafts |

### Context Recovery Pattern

Every session starts with context recovery (via SessionStart hook):
```
Identity → Security → Recent Sessions → Active Tasks → Lessons → Context
```

Agents wake up empty but recover full context in seconds.

### Key Principle

**Memory is permanent, agents are not.** The memory isn't in the agent — it's in the system. Replace any agent, lose nothing.

## Task Queue (Kanban)

```
todo → in-progress → review → done
                  ↗          ↘
            blocked      todo (bounced by Oracle)
```

Each task file contains: instructions, acceptance criteria, handoff state, manager notes, oracle feedback.

## Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `session-start.sh` | SessionStart | Context recovery sequence |
| `stop.sh` | Stop | Auto-generate session summary |
| `validate-task.sh` | TaskCompleted | Check tests, unstaged files |
| `on-idle.sh` | TeammateIdle | Suggest pending work from queue |
| `health-check.sh` | Manual | Validates system integrity (dirs, files, agents, hooks) |

### Hook Failure Recovery

When a hook exits with code 2 (block):
- **TaskCompleted**: Task stays in current status. Feedback sent to the agent via stderr. Agent should fix the issue and retry.
- **TeammateIdle**: Agent receives the suggestion and keeps working instead of going idle.

When a hook exits with a non-zero code other than 2, the hook is treated as errored and the action proceeds as if the hook didn't exist. Check hook scripts for syntax errors if this happens.

## Skills (Reusable Playbooks)

| Skill | Purpose |
|-------|---------|
| `spec-planning` | 4-step spec: Requirements → Research → Design → Breakdown |
| `council-deliberation` | Structured two-agent debate |
| `builder-oracle-loop` | Core review loop pattern |
| `task-wiring` | Create and manage queue tasks |
| `context-recovery` | Recover context at session start |
| `session-close` | Compress session, extract lessons |
| `daily-brief` | Generate daily activity summary |
| `project-setup` | Initialize new project from template |
| `create-role` | Create a new agent role |
| `install-extension` | Install extension from git repo |

## Extensions

Core handles memory, roles, tasks, coordination. Extensions snap in specialized capabilities:
- Each extension is a separate git repo
- Contains agents, skills, hooks, docs
- Install by copying into `.claude/`
- See `.claude/docs/EXTENSIONS.md`

## Security Trust Hierarchy

| Level | Source | Trust |
|-------|--------|-------|
| 1 | Operator config (`settings.json`) | Highest |
| 2 | Framework rules (CLAUDE.md, docs) | High |
| 3 | Approved user code | Medium |
| 4 | Web content | Low |
| 5 | Anonymous sources | None |

See `.claude/docs/SECURITY.md` for full details.
