# Sweep Agent Prompts

Agent prompts for the 3 Phase 2 sweep agents and the Phase 4 fix agent.

## Agent 1: Duplicates & Dead Code (sonnet)

```
Agent(
  description="Scan duplicates and dead code",
  subagent_type="Explore",
  run_in_background=true,
  prompt="Tech debt scan: duplicates and dead code.

  FILES: {file_list}

  CHECK:
  1. DUPLICATED CODE: Find blocks of >10 lines that are substantially similar across files. Read files and compare. Report both locations.
  2. DEAD/UNUSED EXPORTS: For each `export` in source files, grep for imports of that symbol across the codebase. If zero imports found (and it's not an entrypoint/index file), flag it.

  OUTPUT FORMAT (one per finding, no other text):
  [SEVERITY] category | file:line | description | fix

  Severity: HIGH = exact duplicates >20 lines or exported-but-never-imported public API. MEDIUM = similar blocks >10 lines or unused internal exports.

  Be fast. Skip test files for dead export analysis. Skip files in node_modules, dist, build."
)
```

## Agent 2: Deps, TODOs & File Size (sonnet)

```
Agent(
  description="Scan deps, TODOs, file size",
  subagent_type="Explore",
  run_in_background=true,
  prompt="Tech debt scan: dependencies, TODOs, and file size.

  FILES: {file_list}

  CHECK:
  1. UNUSED DEPS: Read package.json dependencies (not devDependencies). For each dep, grep the codebase for import/require of that package name. Flag deps with zero matches.
  2. STALE TODOs: Grep for TODO, FIXME, HACK, XXX, @todo. Flag any that do NOT contain a linked issue (no URL, no #123 pattern, no JIRA-style KEY-123). Report file:line and the TODO text.
  3. BLOATED FILES: Check line counts. Flag any source file >300 lines. Report exact line count.

  OUTPUT FORMAT (one per finding, no other text):
  [SEVERITY] category | file:line | description | fix

  Severity: HIGH = unused dep that adds >1MB or is a security risk. MEDIUM = any other unused dep, TODO >6 months old, file >500 lines. LOW = TODO without issue link, file >300 lines.

  Be fast. Skip node_modules, dist, build."
)
```

## Agent 3: Naming & Consistency (sonnet)

```
Agent(
  description="Scan naming consistency",
  subagent_type="Explore",
  run_in_background=true,
  prompt="Tech debt scan: naming and consistency.

  FILES: {file_list}

  CHECK:
  1. INCONSISTENT NAMING: Check for mixed conventions in the same codebase:
     - camelCase vs snake_case in same language
     - Inconsistent file naming (kebab-case vs camelCase vs PascalCase for same file type)
     - Boolean variables not prefixed with is/has/should/can when siblings are
     - Inconsistent import aliasing patterns
  2. MIXED PATTERNS: Different approaches to the same problem in the same codebase (e.g., some files use async/await, others use .then() for the same patterns; some use class components, others functional).

  OUTPUT FORMAT (one per finding, no other text):
  [SEVERITY] category | file:line | description | fix

  Severity: MEDIUM = naming inconsistency in public API. LOW = internal naming inconsistency or style drift.

  Be fast. Only flag clear inconsistencies, not style preferences. Skip node_modules, dist, build."
)
```

## Phase 4: Fix Agent (sonnet)

Launched for each HIGH finding when not in `--dry-run` mode.

```
Agent(
  description="Apply tech debt fix",
  subagent_type="general-purpose",
  model="sonnet",
  run_in_background=true,
  prompt="Apply this fix. Use the Edit tool.

  FILE: {file_path}
  PROBLEM: {description}
  FIX: {exact_fix}

  Read first. Apply. Verify surrounding code.
  Report: APPLIED or SKIPPED (reason)."
)
```
