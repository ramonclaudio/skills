# Sweep Agent Prompts

Agent prompts for the 3 Phase 2 sweep agents and the Phase 4 fix agent.

## Agent 1: Duplicates & Dead Code

Launch a background Explore agent (opus) to scan for duplicated code blocks (>10 lines similar) and dead/unused exports (exported but never imported). Run `${CLAUDE_SKILL_DIR}/scripts/find-unused-exports.sh` for deterministic dead export detection. Output: `[SEVERITY] category | file:line | description | fix`

Severity: HIGH = exact duplicates >20 lines or exported-but-never-imported public API. MEDIUM = similar blocks >10 lines or unused internal exports.

Skip test files for dead export analysis. Skip files in `node_modules`, `dist`, `build`.

## Agent 2: Deps, TODOs & File Size

Launch a background Explore agent (opus) to scan for unused dependencies (in `package.json`, not devDependencies), stale TODOs/FIXMEs without issue links, and bloated files (>300 lines). Output: `[SEVERITY] category | file:line | description | fix`

Severity: HIGH = unused dep that adds >1MB or is a security risk. MEDIUM = any other unused dep, TODO >6 months old, file >500 lines. LOW = TODO without issue link, file >300 lines.

Skip `node_modules`, `dist`, `build`.

## Agent 3: Naming & Consistency

Launch a background Explore agent (opus) to scan for naming inconsistencies (mixed camelCase/snake_case, inconsistent file naming, boolean prefix drift, import alias mismatches) and mixed patterns (async/await vs .then(), class vs functional components). Output: `[SEVERITY] category | file:line | description | fix`

Severity: MEDIUM = naming inconsistency in public API. LOW = internal naming inconsistency or style drift.

Only flag clear inconsistencies, not style preferences. Skip `node_modules`, `dist`, `build`.

## Phase 4: Fix Agent

Launched for each HIGH finding when not in `--dry-run` mode.

Launch a background general-purpose agent (opus) to apply the fix with Edit. Read first, apply, verify surrounding code. Report APPLIED or SKIPPED.
