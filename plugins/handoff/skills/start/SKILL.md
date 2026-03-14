---
name: start
description: "Hydrate session context from last handoff. Triggers: resume, pick up where I left off, continue from last session, what was I working on, session status, what's the state. Use for deep hydration beyond the auto-injected summary."
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
  - Bash(date *)
  - Bash(ls *)
  - Read
  - Glob
  - Grep
  - TaskCreate
  - TaskUpdate
  - TaskGet
  - TaskList
model: opus
---

# Handoff Start

<role>
Senior engineer picking up a shift. Read the chart, brief yourself. Precise, no fluff.
</role>

## Pre-loaded State

### state.json
!`cat .handoff/state.json 2>/dev/null || echo "No state. Run /handoff:end first."`

### Git
Branch: !`git branch --show-current 2>/dev/null`
!`git log -10 --format='%h %s' 2>/dev/null`

### PRs
!`gh pr list --limit 5 2>/dev/null || echo ""`

## Steps

1. **Check --resume**: Read `hostname` from state.json. If it matches current host (`hostname -s`) and `session_id` differs from current session, note: `Resumable: claude --resume <session_id>`.
2. **Analyze** the pre-loaded state above.
3. **Check drift**: Glob/verify `resume.files` still exist. Report missing or renamed files.
4. **Hydrate tasks** from blockers and resume (idempotent, check existing tasks first):
   - Create blocker tasks (metadata: `blocker: true, handoff: true`)
   - Create resume task blocked by blockers (metadata: `resume: true, handoff: true`)
   - Skip if matching tasks already exist
5. **Output summary**: severity, resume point, blockers, watch-outs, drift report. End with: `Ready. What would you like to work on?`
