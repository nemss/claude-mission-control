# Extensions

Mission Control is extensible. The core handles memory, roles, tasks, and coordination. Extensions snap in specialized capabilities without touching core.

## Architecture

```
Core (Mission Control)
  Memory, Roles, Tasks, Hooks
       │
       ├── Extension: Monitoring
       │   Health checks, alerts, dashboards
       │   Uses: roles + tasks
       │
       ├── Extension: Content Pipeline
       │   Blog posts, social, newsletters
       │   Uses: skills + tasks
       │
       ├── Extension: Domain Workflows
       │   Custom roles for any industry
       │   Uses: roles + skills
       │
       └── Your Extension
           Any specialized capability
           Separate repo, portable
```

## Extension Format

An extension is a git repository containing any combination of:

| Directory | Contains | Installed To |
|-----------|----------|-------------|
| `agents/` | Agent role definitions (.md) | `.claude/agents/` |
| `skills/` | Reusable playbooks (.md) | `.claude/skills/` |
| `hooks/` | Hook scripts (.sh) | `.claude/hooks/` |
| `docs/` | Documentation (.md) | `.claude/docs/` |

## Installing

Use the `install-extension` skill or manually copy files.

## Creating

1. Create a new git repo
2. Add agents, skills, hooks, or docs as needed
3. Follow the agent template in `.claude/templates/agent-template.md`
4. Follow security standards in `.claude/docs/SECURITY.md`
5. Add a README explaining what the extension does

## Principles

- Extensions must not modify core files
- Extensions must follow the security trust hierarchy
- Each extension should be independently useful
- Extensions are portable — shareable across projects
