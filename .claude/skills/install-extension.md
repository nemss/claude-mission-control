---
name: install-extension
description: Install a Mission Control extension from a git repository
---

# Install Extension

## Extension Structure

An extension is a git repo containing:
```
my-extension/
  agents/          # Additional agent roles (.md files)
  skills/          # Additional skills (.md files)
  hooks/           # Additional hook scripts (.sh files)
  docs/            # Extension documentation
  install.sh       # Installation script
  README.md        # Extension description
```

## Installation Steps

### 1. Clone the Extension

```bash
git clone [repo-url] /tmp/extension-install
```

### 2. Review Contents

Before installing, review:
- Agent definitions — do they follow security standards?
- Hook scripts — do they do anything destructive?
- Skills — are they compatible with existing skills?

### 3. Copy Files

```bash
# Agents
cp /tmp/extension-install/agents/*.md .claude/agents/

# Skills
cp /tmp/extension-install/skills/*.md .claude/skills/

# Hooks (review carefully!)
cp /tmp/extension-install/hooks/*.sh .claude/hooks/
chmod +x .claude/hooks/*.sh

# Docs
cp /tmp/extension-install/docs/*.md .claude/docs/
```

### 4. Update Settings

If the extension requires hooks, add them to `.claude/settings.json`.
If the extension requires permissions, add them to the allow list.

### 5. Update Documentation

Add the new agents to AGENT_ROLES.md.
Note the extension in CLAUDE.md if it changes the workflow.

### 6. Clean Up

```bash
rm -rf /tmp/extension-install
```

## Creating an Extension

See `.claude/templates/agent-template.md` for the agent file format.
Follow `.claude/docs/SECURITY.md` for trust boundaries.
Each extension should be self-contained and not modify core files.
