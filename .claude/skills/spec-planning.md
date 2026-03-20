---
name: spec-planning
description: 4-step spec system — agents design before they build. Requirements → UX Research → Technical Design → Task Breakdown.
---

# Spec Planning System

Agents design before they build. No vibe coding.

## Step 1: Requirements

**Agent:** Researcher (+ user input)
**Output:** `.claude/memory/shared/findings/spec-requirements-[feature].md`

Gather:
- User stories: "As a [role], I want [action], so that [benefit]"
- Edge cases: what could go wrong, boundary conditions
- Constraints: performance, security, compatibility requirements
- Non-goals: what this feature explicitly does NOT do

Ask the user to confirm requirements before proceeding.

## Step 2: UX Research

**Agent:** Researcher
**Output:** `.claude/memory/shared/findings/spec-ux-research-[feature].md`

Research:
- How competitors solve this problem
- Existing conventions and patterns in the codebase
- API design patterns (if applicable)
- User expectations based on similar features

Deliver: summary of approaches with pros/cons.

## Step 3: Technical Design

**Agent:** Researcher (read-only exploration)
**Output:** `.claude/memory/shared/findings/spec-technical-design-[feature].md`

Design:
- Data model / schema changes
- API endpoints or interfaces
- Component structure
- Integration points with existing code
- Dependencies needed (if any)

Reference existing code: file paths, function names, patterns to follow.

## Step 4: Task Breakdown

**Agent:** Overseer
**Output:** Task files in `.claude/memory/shared/queue/`

Break the technical design into ordered, atomic tasks:
1. Each task is independently deliverable
2. Each has clear acceptance criteria
3. Tasks are ordered by dependency
4. Each references the relevant spec documents

Create queue files following the kanban task format.

## After Spec Planning

The queue should contain all tasks needed to implement the feature.
Builder picks them up in order. Oracle validates each one.
The spec documents in `findings/` serve as the source of truth throughout.
