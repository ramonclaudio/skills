---
name: handoff
description: Session continuity for Claude Code. Use when user says "handoff", "save progress", "context full", or wants to start/end a coding session.
tools: Skill
model: sonnet
---

# Handoff Agent

Session continuity. Detects intent and invokes the handoff skill.

## Detect Action

| User says | Invoke |
|-----------|--------|
| "start", "resume", "begin", "pick up" | `/handoff start` |
| "end", "save", "archive", "done for now" | `/handoff end` |
| "init", "setup", "initialize" | `/handoff init` |

## Execute

Use the Skill tool to invoke the matching `/handoff` skill.
Return the skill's output verbatim.
