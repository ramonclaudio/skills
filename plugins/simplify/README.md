# Simplify Plugin

Codebases accumulate cruft. Nested ternaries, god functions, dead imports. Cleaning it up file by file is tedious. This runs parallel agents across the whole codebase and only touches what actually needs work.

## Usage

```bash
/simplify:simplify             # Analyze and apply simplifications
/simplify:simplify --dry-run   # Report only, no modifications
```

## How It Works

1. Globs all source files in the codebase
2. Reads every file, scores 0-10 on simplification potential
3. Creates tasks for files scoring 5+
4. Launches up to 5 background agents (sonnet) simultaneously, each simplifying one file
5. Summarizes files analyzed, simplified, and what changed

<details open>
<summary>What It Looks For</summary>

| Criteria | Examples |
|:---|:---|
| Unnecessary complexity | Deep nesting (>3 levels), overly clever solutions |
| Redundant code | Duplicate logic, unused variables/imports, dead code |
| Poor clarity | Unclear naming, dense one-liners |
| Anti-patterns | Nested ternaries, callback hell, god functions (>50 lines) |
| Inconsistent style | Mixed conventions, arrow vs function inconsistency |
| Over-abstraction | Premature optimization, unnecessary indirection |

</details>

> [!CAUTION]
> Never changes functionality. Only improves how code is written. Skips generated files, vendored code, and config files. Uncertain changes are skipped.

---

> [!IMPORTANT]
> Requires `git`.
