# Polish Workflow: Phases 2-5

## Phase 2: Deep Analysis (ultrathink)

**Guards:**
- If discovery finds **0 files**, report "No source files found" and stop.
- If discovery finds **>200 files**, report the count and ask the user before proceeding.
- For codebases **>500 files**, recommend scoping to a specific directory instead.

For EVERY file discovered, read its contents and analyze with extended thinking:

**Polish Criteria** - Flag a file if it has ANY of:
1. **Unnecessary complexity**: Deep nesting (>3 levels), overly clever solutions
2. **Redundant code**: Duplicate logic, unused variables/imports, dead code
3. **Poor clarity**: Unclear naming, missing/excessive comments, dense one-liners
4. **Anti-patterns**: Nested ternaries, callback hell, god functions (>50 lines)
5. **Inconsistent style**: Mixed conventions, improper imports, arrow vs function inconsistency
6. **Over-abstraction**: Premature optimization, unnecessary indirection

**Scoring**: Rate each file 0-10 on polish potential (10 = most needs work)

## Phase 3: Create Work Queue

Use TaskCreate to create a prioritized list of files needing polish (score >= 5).

Format each task:
```
TaskCreate(
  subject: "Polish {filepath}",
  description: "Score: {N}/10 | Reason: {brief reason}",
  activeForm: "Polishing {filename}"
)
```

## Phase 4: Parallel Polish

For EACH file in the queue, launch a background agent:

```
Agent(
  subagent_type="general-purpose",
  model="sonnet",
  run_in_background=true,
  prompt="Polish the file at {filepath}.

  Use only Read, Edit, Glob, and Grep tools. Do NOT use Bash or spawn sub-agents.

  Read the file first, then apply these refinements:
  - Reduce nesting and complexity
  - Eliminate redundant code
  - Improve naming clarity
  - Remove nested ternaries (use switch/if-else)
  - Follow project conventions
  - Choose clarity over brevity

  Preserve ALL functionality. Use Edit tool for changes.
  Report: [changes made] or [no changes needed]"
)
```

**Concurrency**: Launch up to 5 agents simultaneously. Poll with TaskGet, launch more as slots free up.

## Phase 5: Verification & Report

After all agents complete:
1. TaskUpdate each task to `completed`
2. Summarize total files analyzed, files polished, key changes made
3. List any files that couldn't be polished and why

## Constraints

- NEVER change functionality - only improve how code is written
- All original features and behaviors must remain intact
- Skip generated files, vendored code, and config files
- If uncertain about a change, skip it
