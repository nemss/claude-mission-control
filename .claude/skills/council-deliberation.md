---
name: council-deliberation
description: Structured two-agent debate — Explorer argues FOR, Challenger argues AGAINST. Overseer synthesizes.
---

# Council Deliberation

A structured debate between two agents to make better decisions.

## When to Use

- Architectural decisions with significant trade-offs
- Technology or library choices
- Approach selection when multiple valid options exist
- Any decision where groupthink could lead to a bad outcome

## How It Works

### 1. Overseer Frames the Question

Define clearly:
- The proposal being debated
- The context and constraints
- What a good answer looks like

### 2. Spawn Explorer (argues FOR)

```
Agent(subagent_type="council-explorer", prompt="Proposal: [description]. Argue FOR this proposal. Find supporting evidence, benefits, successful precedents. Be thorough and specific. Read the codebase for relevant context.")
```

Explorer delivers: structured argument with evidence.

### 3. Spawn Challenger (argues AGAINST)

```
Agent(subagent_type="council-challenger", prompt="Proposal: [description]. Explorer's argument: [paste Explorer's output]. Argue AGAINST this proposal. Find risks, alternatives, failure modes. Challenge every assumption. Be specific.")
```

Challenger delivers: counter-arguments, risks, alternatives.

### 4. Overseer Synthesizes

Read both arguments. Decide:
- If Explorer is clearly right → proceed with proposal
- If Challenger raised valid risks → modify the proposal to address them
- If Challenger's alternative is better → pivot
- If unclear → escalate to user with both arguments

### 5. Log the Decision

Append to `decisions.jsonl`:
```json
{"ts":"...","agent":"overseer","type":"council","summary":"Decision: [what was decided]","detail":"Explorer argued: [key point]. Challenger argued: [key point]. Resolution: [why this was chosen]"}
```

## Rules

- Explorer and Challenger must not communicate directly
- Each agent argues independently based on evidence
- The Overseer is the sole decision-maker
- The debate is a tool for better decisions, not a requirement for every choice
