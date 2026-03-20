# Agent Roles — Quick Reference

## Role Matrix

| Agent | Role | Codes? | Reads | Writes |
|-------|------|--------|-------|--------|
| **Overseer** | Coordinator | No | everything | `context.md`, `queue/`, `decisions.jsonl` |
| **Builder** | Implementation | Yes | `decisions.jsonl`, `findings/`, `lessons/`, `CONVENTIONS.md` | Code, tests, `queue/` status, `decisions.jsonl` |
| **Researcher** | Analysis | No | Codebase, docs, web, `decisions.jsonl` | `findings/*.md`, `decisions.jsonl` |
| **Writer** | Documentation | No | `decisions.jsonl`, `findings/`, `content/`, existing docs | `content/*.md`, project docs, `decisions.jsonl` |
| **Oracle** | Quality Gate | No | Everything | `decisions.jsonl` (verdicts), `queue/` status |
| **Council Explorer** | Debate (FOR) | No | Codebase, docs, web | Output to Overseer only |
| **Council Challenger** | Debate (AGAINST) | No | Codebase, docs, web, Explorer's argument | Output to Overseer only |
| **Historian** | Narrative | No | Git log, `decisions.jsonl`, `sessions/` | Output to Overseer/Writer |
| **Voice** | Communication | No | `decisions.jsonl`, `sessions/`, `briefs/` | `content/*.md`, project docs |

## When to Use Each Agent

| Situation | Agent |
|-----------|-------|
| New task arrives | **Overseer** — breaks it down, creates queue tasks |
| Need to understand something | **Researcher** — explores and documents findings |
| Time to write code | **Builder** — picks from queue, implements with tests |
| Documentation needs updating | **Writer** — writes/updates docs |
| Need to validate a deliverable | **Oracle** — runs checks, issues PASS/FAIL |
| Architectural decision with trade-offs | **Council** — Explorer + Challenger debate |
| What happened recently? | **Historian** — reads git log, produces narrative |
| Need human-friendly summary | **Voice** — translates technical output |
| Something is blocked | **Overseer** — escalates to user |

## Decision Log Entry Types

| Type | Written By | Meaning |
|------|-----------|---------|
| `delegation` | Overseer | Task assigned to a teammate |
| `implementation` | Builder | Code change completed |
| `research` | Researcher | Finding documented |
| `documentation` | Writer | Doc written/updated |
| `verdict` | Oracle, Hooks | PASS/FAIL quality check |
| `council` | Overseer | Council deliberation result |
| `blocker` | Any agent | Work is blocked, needs resolution |

## Core Patterns

### Builder-Oracle Loop
The core productivity pattern. Builder implements → Oracle validates → PASS (done) or FAIL (retry with feedback). Max 3 retries before escalation.

### Council Deliberation
For decisions with trade-offs. Explorer argues FOR → Challenger argues AGAINST → Overseer synthesizes.

### Spec Planning
Before building: Requirements → UX Research → Technical Design → Task Breakdown. Uses Researcher + Overseer.
