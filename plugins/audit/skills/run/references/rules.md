# Audit Rules

## Finding Format

All agents use this format for every finding:

```
- Severity: CRITICAL / HIGH / MEDIUM
- File: {path}:{line_numbers}
- Problem: {1 sentence}
- Fix: {exact change}
```

Only flag real issues. If it works and is readable, move on.

## Severity Definitions

| Severity | Bugs | Architecture | Performance | Security |
|----------|------|-------------|-------------|----------|
| CRITICAL | Will crash at runtime | - | User-facing lag | Exploitable vulnerability |
| HIGH | Wrong behavior | Actively harmful structure | Measurable waste | Data exposure risk |
| MEDIUM | Edge case | Suboptimal but functional | Suboptimal | Theoretical risk |

## False Positives (DO NOT flag)

- Code that works correctly but you'd write differently
- Style preferences without functional impact
- Pre-existing issues outside the audit scope
- Things a linter will catch (don't run the linter to verify)
- Generic code quality concerns not backed by a specific rule or bug
- Micro-optimizations for code that runs once
- Files under 10 lines (config stubs, barrel exports) unless they have clear bugs
- Theoretical risks requiring unlikely attack vectors

## Constraints

- NEVER modify test files, generated files, vendored code, or lockfiles
- NEVER change functionality - only fix bugs, remove dead code, and improve what exists
- If uncertain about a fix, report only (don't apply)
- Every finding must have an actionable fix, not a vague suggestion
- Respect CLAUDE.md conventions - the project's rules are law

## Report Format

```
## Audit Report

**Codebase:** {repo name}
**Files analyzed:** {count}
**Findings:** {count} ({critical} critical, {high} high, {medium} medium)

### CRITICAL

{numbered list of critical findings with file:line, problem, and fix}

### HIGH

{numbered list}

### MEDIUM

{numbered list}

### What's Actually Good

{brief notes on things done well - be genuine, not patronizing}
```
