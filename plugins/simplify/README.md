# Simplify Plugin

Codebases accumulate cruft. Nested ternaries, god functions, dead imports. Cleaning it up file by file is tedious. This runs parallel agents across the whole codebase and only touches what actually needs work.

## Usage

```bash
/simplify:run             # Analyze and apply simplifications
/simplify:run --dry-run   # Report only, no modifications
```

## How It Works

1. **Discovery**: Globs all source files in the codebase
2. **Analysis**: Reads every file and scores 0-10 on simplification potential
3. **Work Queue**: Creates tasks for files scoring 5+
4. **Parallel Simplification**: Launches up to 5 background agents (sonnet) simultaneously, each simplifying one file
5. **Report**: Summarizes files analyzed, simplified, and key changes

## What It Looks For

| Criteria | Examples |
|----------|---------|
| Unnecessary complexity | Deep nesting (>3 levels), overly clever solutions |
| Redundant code | Duplicate logic, unused variables/imports, dead code |
| Poor clarity | Unclear naming, dense one-liners |
| Anti-patterns | Nested ternaries, callback hell, god functions (>50 lines) |
| Inconsistent style | Mixed conventions, arrow vs function inconsistency |
| Over-abstraction | Premature optimization, unnecessary indirection |

## Constraints

- Never changes functionality. Only improves how code is written.
- Skips generated files, vendored code, and config files
- Uncertain changes are skipped

## Requirements

- `git`

## Version

1.0.0
