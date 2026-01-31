# Audit Plugin

Brutally honest codebase audit with parallel agents. Finds bugs, architectural rot, and dead weight.

## Usage

```bash
/audit:run                # Full audit with fixes applied
/audit:run --dry-run      # Report only, no modifications
/audit:run --recent       # Scope to files changed in last 20 commits
/audit:run src/           # Scope to specific path
```

## How It Works

Launches 4 parallel agents, each focused on a different audit dimension:

| Agent | Model | Focus |
|-------|-------|-------|
| Architecture, Design & Clarity | opus | Coupling, dead code, god files, nested ternaries, naming, readability |
| Bugs & Logic Errors | opus | Null access, race conditions, type safety, edge cases |
| Security, Dependencies & Performance | sonnet | Injection, auth, bloated deps, N+1 queries, memory leaks |
| Convention Compliance | sonnet | CLAUDE.md rule violations, inconsistent patterns |

After all agents report, a validation pass confirms CRITICAL and HIGH findings (removes false positives). Findings are ranked and applied unless `--dry-run` is set.

## Output

```
## Audit Report

**Codebase:** my-app
**Files analyzed:** 47
**Findings:** 12 (2 critical, 5 high, 5 medium)

### CRITICAL
1. ...

### HIGH
1. ...

### MEDIUM
1. ...

### What's Actually Good
- ...
```

## Requirements

- `git`

## Version

1.0.0
