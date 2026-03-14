# Polish Plugin

Codebases accumulate cruft. Nested ternaries, god functions, dead imports. Cleaning it up file by file is tedious. This runs parallel agents across the whole codebase and only touches what actually needs work.

> [!NOTE]
> **Not the same as built-in `/simplify`.** The bundled `/simplify` skill (Claude Code 2.1.63+) reviews recently changed files. `/polish` does a full codebase sweep: it reads every source file, scores each 0-10 on polish potential, and targets files scoring 5+.

## Usage

```bash
/polish             # Analyze and apply refinements
/polish --dry-run   # Report only, no modifications
/polish src/        # Scope to specific path
```

## How It Works

1. Globs all source files in the codebase
2. Reads every file, scores 0-10 on polish potential
3. Creates tasks for files scoring 5+
4. Launches up to 5 background agents simultaneously, each refining one file
5. Summarizes files analyzed, refined, and what changed

The main skill runs on Opus with 1M context for deep analysis. Worker agents run on Sonnet with `acceptEdits` mode for uninterrupted parallel refinement.

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
