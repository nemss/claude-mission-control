# Mission Control System Analysis — Comprehensive Review

## Summary

Mission Control is a well-structured agent orchestration framework with strong foundational concepts (persistent memory, kanban queue, builder-oracle loop). However, it has significant practical gaps that would frustrate real-world usage: the Oracle cannot actually update task files despite instructions telling it to, the system has no cancellation or rollback mechanism, the memory system will degrade as projects grow, and several agents (Historian, Voice) lack enough specificity to be useful without heavy user hand-holding. The documentation is thorough but repetitive across files, and some features (extensions, council) are scaffolded but untested.

## Sources

- Every file in the repository was read for this analysis
- Files are referenced with paths relative to project root throughout

## Findings

### 1. Practical Usability Gaps

**1a. Oracle Cannot Write Files — But Is Told To**

This is the single most critical design flaw. The Oracle agent definition (`.claude/agents/oracle.md`, line 6) declares `disallowedTools: Write, Edit`. But the same file at line 19 says:

> 6. **Update task file** — status to `done` (PASS) or `todo` (FAIL) + write Oracle Feedback

And again at line 40: "Update the task file frontmatter: `status: done`"

The file does acknowledge this contradiction at lines 70-72 in a section titled "Important: Oracle Cannot Write Files" — but this means the Oracle's own core loop (lines 14-20) describes a workflow it literally cannot execute. The mitigation ("Overseer must do this on Oracle's behalf") is buried and not integrated into the Overseer's instructions. The Overseer's agent definition (`.claude/agents/overseer.md`) describes at line 87 spawning Oracle and expecting it to "update status to 'done'" — which it cannot do.

In the `builder-oracle-loop.md` skill, lines 77-79 clarify that the Overseer should update the file after Oracle reports, but this contradicts what the Oracle's own core loop says. An agent reading its own definition will try to write and fail silently or with a tool error.

**1b. No Way to Cancel or Abort Mid-Flight**

There is no cancellation mechanism anywhere. Once the Overseer starts the builder-oracle loop, the user cannot:
- Cancel a specific task
- Abort the entire pipeline
- Deprioritize a task that is in-progress
- Remove a task from the queue gracefully

The only option is to close the session entirely, which is not surfaced anywhere as a workflow.

**1c. No Conflict Resolution for Concurrent Edits**

The Overseer can spawn multiple Builders in parallel (`.claude/agents/overseer.md`, lines 71-74). But there is no mechanism for handling:
- Two Builders editing the same file
- Git merge conflicts between parallel commits
- Race conditions on `decisions.jsonl` (two agents appending simultaneously)
- Queue file status races (two agents reading the same `todo` task)

The system assumes independence but provides no guard rails when assumptions break.

**1d. Context.md Is a Single-Writer Bottleneck with No Structure**

`context.md` is the only shared memory file tracked in git (per `.gitignore`, line 19). It uses placeholder text and a free-form structure that will become stale fast. There is no schema enforcement, no timestamp on last update, and the template placeholders (`[What we're working on]`) will persist across sessions because the Stop hook (`stop.sh`) does not update `context.md` — only the session-close skill describes that behavior, but that skill is not wired to any hook.

**1e. No Onboarding Path for a Real Project**

The README says to copy the `.claude/` directory into your project and customize. But:
- `settings.json` has Node.js-specific permissions (`npm test`, `npm run lint`, `npx tsc`). A Python, Go, or Rust project would need to rewrite these entirely.
- The `validate-task.sh` hook only checks `package.json` for test scripts. Non-Node projects get no test validation.
- CONVENTIONS.md assumes JavaScript/TypeScript naming patterns.
- There is no script or tool to adapt the system to a different tech stack.

### 2. Missing Error Handling

**2a. Hook Scripts Fail Silently on Missing Globs**

In `session-start.sh` (line 52), the grep command searches `"$SHARED_DIR/queue/"*.md`. If the queue directory exists but contains only `.gitkeep` (the initial state), this glob expands to a literal `*.md` on some shells, and grep will fail. The `|| true` suppresses the error, but the result is unpredictable behavior.

Similarly, `on-idle.sh` line 12 uses the same pattern. In both cases, the scripts handle the "no files" case via `|| true`, but the actual glob expansion differs between bash versions and whether `nullglob` is set.

**2b. Stop Hook Generates Summaries Only from Today's Decisions**

`stop.sh` (line 21) filters decisions by `TODAY=$(date -u +%Y-%m-%d)` and does a simple grep. If a session spans midnight UTC, decisions from the early part of the session are lost from the summary. There is no session ID to correlate decisions to a specific session — the system relies on date matching.

**2c. decisions.jsonl Has No Corruption Protection**

Multiple agents append to the same JSONL file. There is no file locking, no atomic write guarantee, and no validation that entries are valid JSON. If two agents append at the same instant, lines can interleave and corrupt the file. Once corrupted, every agent that reads it (which is all of them) gets garbage.

**2d. No Validation of Task File Frontmatter**

Task files use YAML frontmatter for status tracking. There is no validation that:
- Status values are from the allowed set (todo, in-progress, review, done, blocked)
- Required fields (id, status, assignee) exist
- IDs are unique
- Priority values are valid

Agents could write malformed frontmatter and break the queue system.

**2e. validate-task.sh Checks Unstaged Files Globally, Not Per-Task**

The TaskCompleted hook (line 31) runs `git diff --name-only` which checks ALL unstaged files in the repo. If a user has unrelated unstaged changes (e.g., local config edits, a file they are working on manually), every task completion will fail validation. There is no way to scope the check to files relevant to the specific task.

### 3. Agent Instruction Quality

**3a. Researcher Has disallowedTools: Write, Edit — But Must Save Findings**

The Researcher agent definition (`.claude/agents/researcher.md`, line 6) declares `disallowedTools: Write, Edit`. But its core purpose (line 5, line 48) is to "Deliver findings as structured markdown in `.claude/memory/shared/findings/`" and "Save findings to: `.claude/memory/shared/findings/[topic-slug].md`".

This is exactly the same contradiction as the Oracle. The Researcher cannot write its own findings files. This means the Researcher is functionally useless as a standalone agent — it can only report findings verbally to the Overseer, who would then have to transcribe them. The entire findings/ directory system is broken for its intended use case.

**3b. Historian and Voice Lack Actionable Workflows**

The Historian (`.claude/agents/historian.md`) says to "Deliver findings to the Overseer or Writer" but has `disallowedTools: Write, Edit`. It cannot write to any file. Its output format shows structured markdown but provides no mechanism to persist it. The agent can only deliver its analysis as text in its response to whoever spawned it.

The Voice agent (`.claude/agents/voice.md`) says to "Write to `.claude/memory/shared/content/`" and does have Write tool access. But its instructions give no concrete trigger for when it should be invoked. There is no skill or workflow that includes Voice in the pipeline.

**3c. Builder Instructions Say "No Documentation" but Context Requires It**

Builder (`.claude/agents/builder.md`, line 74) says "Modify documentation (Writer's job)". But if the Builder creates a new API endpoint or module, code comments and inline documentation are part of the code. The line between "code" and "documentation" is not defined. A Builder that adds a function without a docstring is arguably correct per its instructions, but that degrades code quality.

**3d. Overseer Has Duplicate Step Numbers**

In `.claude/agents/overseer.md`, there are two sections labeled "### Step 3" (lines 93 and 95). Step 3 first appears as "Run the builder-oracle loop" and then "Update context". This is a copy-paste error that could confuse the agent about which step it is on.

### 4. Workflow Holes

**4a. No "Small Task" Path**

Every task goes through the full pipeline: Overseer breaks down, creates queue files, spawns Builder, spawns Oracle. For a one-line fix or a quick config change, this is massive overhead. There is no fast-path for trivial tasks. A user asking "fix the typo in line 5 of README.md" would trigger the entire orchestration machinery.

**4b. No Dependency Between Tasks**

The task file format has no `depends_on` field. The Overseer is told to "classify tasks" as independent or dependent (`.claude/agents/overseer.md`, lines 69-73), but this classification lives only in the Overseer's reasoning — not in the task files. If a session ends and resumes, the dependency information is lost. The next Overseer invocation has no way to know that task 003 depends on task 002.

**4c. No Rollback When Oracle FAILs Permanently**

After 3 failed attempts, the builder-oracle-loop skill says to set status to `blocked` and escalate. But the code changes from those 3 attempts are still committed. There is no mechanism to:
- Revert the failed commits
- Identify which commits belong to the failed task
- Clean up partial implementations

The user is left with broken commits in their git history.

**4d. Builder Commits Before Oracle Reviews**

The Builder's workflow (`.claude/agents/builder.md`, line 19) says: "Commit — atomic conventional commit" then "Update task file — set status: review". This means the code is committed to the branch BEFORE Oracle validates it. If Oracle FAILs, the bad commit is already in history. This design means the git log accumulates fix-up commits for every retry cycle.

**4e. No Way to Route Non-Builder Tasks**

The queue system assumes `assignee: builder` for all implementation tasks. But what if the Overseer creates a research task or a documentation task? The `on-idle.sh` hook checks for `status: todo` without filtering by assignee. A Builder could pick up a task meant for the Writer. The task-wiring skill mentions only Builder as a consumer.

### 5. Memory System Gaps

**5a. decisions.jsonl Will Grow Without Bound**

There is no rotation, archival, or cleanup of the decisions log. On a real project with active use, this file will grow to thousands of lines within weeks. Every session start reads the last 10 lines (session-start.sh, line 85), but agents are also instructed to read the full file for context. As it grows, this becomes a performance and context-window problem.

**5b. Lessons Have No Search Mechanism**

The context-recovery skill (line 35) says "Read all files in `.claude/memory/shared/lessons/`". As lessons accumulate, this becomes a flood of information. There is no tagging, categorization, or search mechanism. The system tells agents to "pay special attention to critical severity lessons" but offers no way to filter by severity without reading every file.

**5c. Session Summaries Pile Up with No Pruning**

The session-start hook reads the last 3 sessions. The session-close skill creates new ones. There is no pruning. Over months of use, the sessions directory accumulates indefinitely. While only 3 are read, the disk usage grows and `ls -t` becomes slower (though this is minor).

**5d. Queue Files Are Deleted on PASS — No Audit Trail in the Queue**

The Overseer instructions (line 91) say "delete the task file from queue (history is in decisions.jsonl and git log)". But since queue files are gitignored, deleting them removes them permanently. The only record is in decisions.jsonl, which is also gitignored. If decisions.jsonl is lost or corrupted, there is zero record of completed tasks.

**5e. findings/ Is Gitignored — Research Is Ephemeral**

All files in `findings/*.md` are gitignored (`.gitignore`, line 8). This means research outputs do not persist across git clones. If a developer clones the repo on a new machine, all findings are gone. The README claims "memory is permanent, agents are not" but findings are not permanent at all — they are local to the machine.

The same applies to lessons, sessions, briefs, content, and queue files. Only `context.md` survives a git clone. The "permanent memory" claim is only true within a single machine's filesystem.

### 6. Over-Engineered Elements

**6a. Nine Agents for What Could Be Three**

The core workflow uses Overseer, Builder, and Oracle. Researcher is useful but broken (cannot write). Writer, Historian, Voice, and the two Council agents are specialized to the point of being rarely useful. In practice, most users will only ever use 3 agents and the rest add cognitive overhead (more docs to maintain, more roles to understand, more potential for confusion about who does what).

**6b. Extension System with Zero Extensions**

The extension system (EXTENSIONS.md, install-extension skill) is scaffolded but there are no actual extensions. The install process is a manual `cp` command. There is no registry, no versioning, no conflict detection, no uninstall mechanism. This is speculative architecture — building infrastructure for a future that may never arrive.

**6c. Daily Brief Skill with No Trigger**

The `daily-brief` skill exists but is not wired to any hook or automatic trigger. It says to generate "at the start of a new day's first session" but the session-start hook does not call it. It would only run if a user or agent explicitly invoked it, which means it will almost never run.

**6d. Trust Hierarchy Documentation for a Local-Only System**

The security trust hierarchy (5 levels with web content and anonymous sources) is thorough documentation for what is essentially a local CLI tool running on a developer's machine. The practical attack surface is minimal — the user is running Claude Code locally. The security docs are not wrong, but they add complexity without matching real risk.

### 7. Under-Engineered Elements

**7a. No Task ID Generation Logic**

The Overseer is told to "Find the next ID by counting existing files in queue/" (`.claude/agents/overseer.md`, line 65). Since completed tasks are deleted, counting existing files will reuse IDs. Task 001 is completed and deleted; later, a new task is created and gets ID 001 again. This breaks any reference to task IDs in decisions.jsonl.

**7b. No Schema for Any Data Format**

The system uses YAML frontmatter, JSONL, and markdown, but none of these have formal schemas. There is no validation tool, no linting, no type checking. Everything relies on agents following the format correctly, which they will not always do — especially under retry pressure.

**7c. No Health Check or Diagnostic**

There is no way to verify the system is working correctly. No command to check:
- Are all required directories present?
- Is decisions.jsonl valid JSON?
- Are there orphaned tasks (in-progress but no active session)?
- Are hooks executable?
- Is the settings.json valid?

The session-start hook creates missing directories, but that is the extent of self-repair.

**7d. No Guidance on Context Window Management**

The system aggressively loads context on session start (security rules, 3 sessions, all active tasks, 10 lessons, full context.md, 10 decisions). For a project with many active tasks and lessons, this could consume a significant portion of the agent's context window before the user even asks a question. There is no budgeting, prioritization, or truncation strategy.

**7e. The Overseer Cannot Actually Run Tests or Lint**

The Overseer's settings.json permissions include `Bash(npm test*)` and `Bash(npm run lint*)`, but the agent definition says "Never codes" and "What You DO NOT Do: Run tests or builds directly." The permissions allow it, but the instructions forbid it. This contradiction means the Overseer might or might not run tests depending on which instruction it prioritizes.

## Recommendations

1. **Fix the Oracle/Researcher write contradiction immediately.** Either give them Write access scoped to their output directories, or explicitly redesign the workflow so the Overseer transcribes their output. The current state guarantees confusion.

2. **Add a fast-path for simple tasks.** Not everything needs the full pipeline. A `/quick` command or a task flag that skips queue files and Oracle validation would make the system practical for daily use.

3. **Add a `depends_on` field to task files** and have the Overseer populate it during planning. This makes dependency information persist across sessions.

4. **Implement decisions.jsonl rotation.** Archive entries older than N days to a `decisions-archive/` directory. Keep the active file small.

5. **Reconsider gitignoring all memory files.** At minimum, `lessons/` and `findings/` should be tracked in git. These represent durable project knowledge. Session summaries and queue files can remain local.

6. **Add a diagnostic/health-check script.** A simple `bash .claude/hooks/health-check.sh` that validates directory structure, file formats, and hook permissions.

7. **Consolidate or retire low-value agents.** Historian and Voice could be skills rather than full agents. The Council pair is interesting but should be marked as optional/advanced rather than core.

8. **Fix the Builder-before-Oracle commit ordering.** Either have Builder stage but not commit (letting Oracle validate before commit), or accept the fix-up commit pattern and document it explicitly.

9. **Make the system tech-stack-agnostic.** The hooks, settings, and conventions are Node.js-specific. Add a `stack` config variable and conditional logic in hooks, or provide template settings for common stacks.

10. **Wire the daily-brief and session-close skills to hooks or make them explicit commands.** Unwired skills are dead code.
