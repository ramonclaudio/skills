# Audit Plugin

I wanted a second opinion on my code that doesn't sugarcoat anything. This runs 4 parallel agents, each focused on a different audit dimension, then validates findings to cut false positives.

Finds bugs, architectural rot, and dead weight.

## Usage

```bash
/audit:audit                # Full audit with fixes applied
/audit:audit --dry-run      # Report only, no modifications
/audit:audit --recent       # Scope to files changed in last 20 commits
/audit:audit src/           # Scope to specific path
```

## How It Works

Launches 4 parallel agents, each focused on a different audit dimension:

| Agent | Model | Focus |
|:---|:---|:---|
| Architecture, Design & Clarity | opus | Coupling, dead code, god files, nested ternaries, naming, readability |
| Bugs & Logic Errors | opus | Null access, race conditions, type safety, edge cases |
| Security, Dependencies & Performance | sonnet | Injection, auth, bloated deps, N+1 queries, memory leaks |
| Convention Compliance | sonnet | CLAUDE.md rule violations, inconsistent patterns |

> [!TIP]
> Use `--dry-run` to preview findings before any modifications are applied.

After all agents report, a validation pass confirms CRITICAL and HIGH findings (removes false positives). Findings are ranked and applied unless `--dry-run` is set.

<details>
<summary>Output</summary>

```markdown
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

</details>

---

> [!IMPORTANT]
> Requires `git`.
