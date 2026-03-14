# Team Composition Patterns

Pick the pattern that matches the work. Adapt as needed; these are starting points, not prescriptions.

**Cost:** Agent teams use 3-10x more tokens than a single session (roughly 7x in plan mode). Each teammate has its own context window (1M tokens with Opus 4.6 on Max/Team/Enterprise), and total usage scales with the number of active teammates. Use Sonnet for teammates when possible. Keep spawn prompts focused. Clean up teams when done. The overhead is justified when parallelism provides a clear benefit. For routine tasks, a single session is cheaper and faster.

**Team sizing:** Start with 3-5 teammates for most workflows. Target 5-6 tasks per teammate. Beyond 5 teammates, coordination overhead dominates and diminishing returns kick in. Three focused teammates often outperform five scattered ones.

## When NOT to use teams

Use a single session or subagents instead when:
- **Sequential work**: steps must happen in order, no parallelism possible
- **Same-file edits**: multiple changes to one file cause overwrites
- **High dependency**: most tasks block on each other, teammates wait more than they work
- **Small scope**: fewer than 3 files, obvious change

## Teams vs subagents

| | Subagents | Agent teams |
|--|-----------|-------------|
| **Context** | Own window; results return to caller | Own window; fully independent |
| **Communication** | Report back to main agent only | Message each other directly |
| **Coordination** | Main agent manages all work | Shared task list, self-coordination |
| **Best for** | Focused tasks where only the result matters | Complex work requiring discussion and collaboration |
| **Cost** | Lower: results summarized to main context | Higher: each teammate is a separate instance |

Use subagents (`Agent` without `team_name`) when you need quick, focused workers that report back. Use teams (`TeamCreate` + `Agent` with `team_name`) when workers need to share findings, challenge each other, and coordinate independently via `SendMessage`.

---

## Parallel Builders

**When:** New feature spanning multiple modules with clean boundaries.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Decompose, assign, review |
| builder-{module} | sonnet | Implement one module end-to-end |
| test-writer | sonnet | Write tests after builders finish |

**Task flow:** Interface tasks (unblocked) → builder tasks (blocked by interfaces) → test tasks (blocked by builders).

**Example:**
```
Create a team to build the notification system.
- builder-api: owns src/api/notifications/
- builder-ui: owns src/components/notifications/
- builder-data: owns src/db/notifications/
- test-writer: owns tests/notifications/ (blocked by all builders)
```

---

## Review Panel

**When:** Code review, security audit, PR review.

A single reviewer gravitates toward one type of issue at a time. Splitting review criteria into independent domains means security, performance, and test coverage all get thorough attention simultaneously. Each reviewer applies a distinct lens so they don't overlap.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Synthesize findings |
| reviewer-{lens} | opus/sonnet | Review through one lens |

**Task flow:** All reviewers work in parallel (no dependencies). Each works from the same code but applies a different filter. Lead collects and synthesizes across all reviewers.

**Example:**
```
Review PR #142 with three reviewers:
- reviewer-security (opus): auth, injection, data exposure
- reviewer-perf (sonnet): N+1, memory, bundle size
- reviewer-tests (sonnet): coverage gaps, edge cases, assertion quality
```

---

## Research Team

**When:** Evaluating options, investigating architecture, exploring a problem space.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Frame questions, synthesize |
| researcher-{angle} | sonnet | Explore one angle in depth |

**Task flow:** Researchers work in parallel. Lead synthesizes findings, may spawn follow-up researchers.

---

## Research and Implement

**When:** Any task where you need to understand before acting. Upgrade migrations, codebase modernization, doc syncs, dependency audits. The most common team pattern.

**One-liner:** "Use /teams to scour the codebase and docs, then implement."

| Role | Agent Type | Model | Does |
|------|-----------|-------|------|
| codebase-scout | Explore | sonnet | Read every file systematically, directory by directory. Report structure, imports, patterns, issues. EDIT: NONE / READ: entire codebase. |
| docs-researcher | Explore | sonnet | Search /qmd collections with keyword + semantic + hybrid queries. Read full docs for anything scoring above threshold. Report findings with doc paths and relevant excerpts. EDIT: NONE / READ: QMD collections. |
| Lead | orchestrator | opus | Gather findings from scout and researcher. Synthesize into action plan. Spawn fixer with explicit numbered fix list. |
| fixer | general-purpose | opus | Get numbered fix list from lead with explicit EDIT paths for every file. Apply fixes, run validation (lint, typecheck, test, build). Report results. |

**Task flow:** Scout and researcher work in parallel (read-only) -> lead synthesizes -> fixer implements.

**Key:** Research teammates are always read-only. Only the fixer edits. Lead never implements directly.

**Example:**
```
Upgrade Expo SDK from 55 to 56.
- codebase-scout (explore): read all source files, map every SDK 55 API usage
- docs-researcher (explore): search /qmd expo collection for SDK 56 migration guides, breaking changes
- fixer: apply migration changes from the synthesized fix list
```

---

## Adversarial Debug

**When:** Root cause unknown, multiple plausible theories.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Frame hypotheses, judge evidence |
| investigator-{theory} | sonnet | Gather evidence, attempt to disprove other theories |

**Task flow:** Investigators work in parallel. Each tries to prove their theory AND disprove others. The theory that survives scrutiny is likely correct.

Sequential debugging anchors on the first plausible explanation. Parallel adversarial investigation resists that bias.

---

## Cross-Layer

**When:** Changes spanning frontend, backend, database, tests.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Define interfaces between layers |
| data | sonnet | Schema, migrations, queries |
| backend | sonnet | API routes, business logic |
| frontend | sonnet | UI components, client state |
| tests | sonnet | Integration and e2e |

**Task flow:**
```
data ──→ backend ──→ frontend
                         ↓
                      tests (also blocked by backend)
```

Lead defines the interface contracts first. Each layer teammate works within those contracts.

---

## Verification

**When:** Output quality matters and you want a dedicated check pass.

| Role | Model | Does |
|------|-------|------|
| Lead | opus | Coordinate builders and verifier |
| builder-{area} | sonnet | Implement assigned work |
| verifier | opus | Check completed work against criteria |

**Task flow:** Builder tasks (parallel) -> verification tasks (blocked by builders).

The verifier gets concrete criteria in its spawn prompt. Generic instructions like "check quality" produce vague results. Be specific:

```
You are verifier, responsible for validating all completed work.

You MUST run the complete test suite before marking any verification
task as passed. Check:
- All tests pass (no skips, no flakes)
- No type errors (tsc --noEmit)
- No lint violations
- Changed files match the acceptance criteria in each task description

If any check fails, message the responsible builder with the failure
and mark the verification task as blocked. Do not pass incomplete work.
```

Minimal context transfer succeeds where broad instructions fail. The verifier only needs to know what "correct" looks like, not how to build it.

---

## Batch Processing

`/batch` is a bundled Claude Code skill that spawns agents in isolated git worktrees for repetitive changes across many files. Each agent gets its own worktree, makes its change, and the results are merged. Use `/batch` instead of agent teams when:

- The same change applies to many files (migrations, renames, pattern updates)
- Each unit of work is independent and needs no inter-agent communication
- You want automatic worktree isolation without manual setup

For work that requires discussion, coordination, or shared findings, use agent teams instead.

---

## Use Case Examples

### Parallel code review

A single reviewer gravitates toward one type of issue at a time. Split review criteria into independent domains so security, performance, and test coverage each get thorough attention:

```
Create an agent team to review PR #142. Spawn three reviewers:
- One focused on security implications
- One checking performance impact
- One validating test coverage
Have them each review and report findings.
```

### Competing hypotheses

Sequential debugging anchors on the first plausible explanation. Parallel adversarial investigation resists that bias. Make teammates explicitly challenge each other:

```
Users report the app exits after one message instead of staying connected.
Spawn 5 agent teammates to investigate different hypotheses. Have them talk to
each other to try to disprove each other's theories, like a scientific
debate. Update the findings doc with whatever consensus emerges.
```

---

## Anti-patterns

| Don't | Why | Do instead |
|-------|-----|------------|
| >5 teammates | Coordination dominates. O(n^2) messaging. | Merge roles. Use subagents for subtasks within a teammate. |
| Overlapping file ownership | Merge conflicts, lost work, silent overwrites | One owner per file. No exceptions. |
| No task graph | Teammates duplicate work or skip work | Always create tasks with dependencies before spawning |
| Vague spawn prompts | Teammates waste tokens exploring the codebase | Include specific file paths, acceptance criteria, and exclusions |
| Lead implements | Teammates sit idle while lead does the work | Use `--delegate` mode. The lead coordinates. |
| No plan approval on risky work | Teammates make irreversible changes | Use `--plan-approval` for schema, API, and infrastructure changes |
| Team for trivial work | Overhead exceeds benefit | If < 3 files change, just do it |
