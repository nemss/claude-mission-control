# Agent Roles — Quick Reference

## Role Matrix

| Agent | Role | Codes? | Reads | Writes |
|-------|------|--------|-------|--------|
| **Overseer** | Coordinator | No | `decisions.jsonl`, `context.md`, `findings/` | `context.md`, `decisions.jsonl` |
| **Builder** | Implementation | Yes | `decisions.jsonl`, `findings/`, `CONVENTIONS.md` | Code, tests, `decisions.jsonl` |
| **Researcher** | Analysis | No | Codebase, docs, web, `decisions.jsonl` | `findings/*.md`, `decisions.jsonl` |
| **Writer** | Documentation | No | `decisions.jsonl`, `findings/`, `content/`, existing docs | `content/*.md`, project docs, `decisions.jsonl` |
| **Oracle** | Quality Gate | No | Everything | `decisions.jsonl` (verdicts only) |

## When to Use Each Agent

| Situation | Agent |
|-----------|-------|
| New task arrives | **Overseer** — breaks it down, delegates |
| Need to understand something in the codebase | **Researcher** — explores and documents findings |
| Time to write code | **Builder** — implements with tests |
| Documentation needs updating | **Writer** — writes/updates docs |
| Need to validate a deliverable | **Oracle** — runs checks, issues verdict |
| Something is blocked | **Overseer** — escalates to user |

## Decision Log Entry Types

| Type | Written By | Meaning |
|------|-----------|---------|
| `delegation` | Overseer | Task assigned to a teammate |
| `implementation` | Builder | Code change completed |
| `research` | Researcher | Finding documented |
| `documentation` | Writer | Doc written/updated |
| `verdict` | Oracle, Hooks | PASS/FAIL quality check |
| `blocker` | Any agent | Work is blocked, needs resolution |
