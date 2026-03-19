# Architecture Guide

## Overview

Mission Control is an AI agent orchestration system built on Claude Code's subagent and agent teams features. It coordinates multiple specialized agents through a shared filesystem-based memory layer.

## System Architecture

```
User
  │
  ▼
┌─────────────┐
│   Overseer   │ ◄── Coordinator (never codes)
└──────┬──────┘
       │ delegates
       ├──────────────┬──────────────┬──────────────┐
       ▼              ▼              ▼              ▼
┌───────────┐ ┌────────────┐ ┌───────────┐ ┌───────────┐
│  Builder   │ │ Researcher │ │  Writer    │ │  Oracle   │
│ (code)     │ │ (analysis) │ │ (docs)     │ │ (quality) │
└─────┬─────┘ └─────┬──────┘ └─────┬─────┘ └─────┬─────┘
      │              │              │              │
      ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────┐
│              Shared Memory Layer (filesystem)            │
│  decisions.jsonl │ context.md │ findings/ │ content/     │
└─────────────────────────────────────────────────────────┘
```

## Data Flow

1. **User → Overseer**: Task arrives with requirements
2. **Overseer → Shared Memory**: Reads `decisions.jsonl` and `context.md` for context
3. **Overseer → Teammates**: Delegates scoped subtasks with acceptance criteria
4. **Teammates → Shared Memory**: Log decisions, findings, content as they work
5. **Oracle → Shared Memory**: Reads deliverables, issues PASS/FAIL verdicts
6. **Hooks → Shared Memory**: Automated validation on task completion

## Memory Layer Design

### decisions.jsonl (append-only log)

Central record of all agent activity. Each line is a JSON object:

```json
{"ts":"2025-01-15T10:30:00Z","agent":"builder","type":"implementation","summary":"Added auth middleware","detail":"Created JWT validation middleware in src/middleware/auth.ts"}
```

Fields:
- `ts` — ISO-8601 timestamp
- `agent` — which agent wrote this entry
- `type` — category: `delegation`, `implementation`, `research`, `documentation`, `verdict`, `blocker`
- `summary` — one-line description
- `detail` — full context

### context.md (overwritable)

Living document maintained by the Overseer. Provides quick orientation for any agent:
- Active goal
- Key recent decisions
- Current blockers
- Next steps

### findings/ (research outputs)

Structured markdown files from the Researcher. Named by topic slug (e.g., `api-auth-options.md`).

### content/ (documentation drafts)

Markdown files from the Writer. Staging area before content is placed in its final location.

## Hooks

### TaskCompleted (validate-task.sh)

Fires when any teammate marks a task complete:
1. Checks for unstaged changes (potential forgotten files)
2. Runs tests if a test script exists
3. Logs PASS/FAIL verdict to `decisions.jsonl`
4. Exit 2 blocks completion with feedback

### TeammateIdle (on-idle.sh)

Fires when a teammate finishes and goes idle:
1. Checks `context.md` for pending next steps
2. Checks `decisions.jsonl` for unresolved FAIL verdicts
3. Exit 2 sends suggestion to keep working

## Agent Teams Activation

Agent teams require the experimental flag:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

This is configured in `.claude/settings.json`.
