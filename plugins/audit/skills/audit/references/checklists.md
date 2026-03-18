# Audit Checklists

Each agent receives one section below as its audit scope.

---

## Architecture, Design & Clarity

ARCHITECTURE - flag if found:
1. COUPLING: Circular imports. Modules that know too much about each other's internals.
2. ABSTRACTION ROT: Interfaces that add indirection without value. Wrapper classes that just pass through. 'Manager' classes that manage nothing.
3. GOD FILES: Files >300 lines doing too many things. Functions >50 lines.
4. DEAD CODE: Exported functions nobody imports. Unused variables. Commented-out code. Stale feature flags. Run `${CLAUDE_SKILL_DIR}/scripts/count-dead-exports.sh` for deterministic dead export detection.
5. STRUCTURE: Files in wrong directories. No clear module boundaries. Flat directory with 50 files.

CLARITY - flag if found:
6. NESTED TERNARIES: Ternary inside ternary. Use switch/if-else instead. No exceptions.
7. DENSE ONE-LINERS: Single lines doing 3+ chained operations. If you read it twice, it's too dense.
8. CLEVER OVER CLEAR: Bitwise tricks in non-perf code. Regex where string methods work. Reduce where for-loop is clearer. 5-level destructuring.
9. IMPLICIT BEHAVIOR: !!value, +string, comma operators, assignment in conditions, short-circuit for side effects.
10. NAMING: Variables named 'data', 'result', 'temp'. Functions that don't describe what they do. Misleading names.
11. WALL OF CODE: Functions with no visual grouping. 30 sequential lines with no breaks. Missing early returns that would flatten nesting.

---

## Bugs & Logic Errors

1. NULL/UNDEFINED: Accessing properties on potentially null values without checks. Optional chaining missing where needed.
2. RACE CONDITIONS: Async operations that can interleave. State updates that don't account for concurrent access.
3. ERROR HANDLING: Try/catch that swallows errors. Missing error handling on I/O. Catch blocks that log and continue when they should throw.
4. TYPE SAFETY: 'as any' casts. Type assertions that lie. Runtime type mismatches the compiler can't catch.
5. LOGIC ERRORS: Off-by-one. Wrong comparison operators. Inverted boolean logic. Short-circuit skipping side effects.
6. EDGE CASES: Empty arrays not handled. Zero/negative values not checked. Unicode/encoding issues. Timezone bugs.

---

## Security, Dependencies & Performance

SECURITY:
1. INJECTION: SQL injection, XSS, command injection, path traversal. Unsanitized user input reaching dangerous sinks.
2. AUTH/AUTHZ: Missing auth checks. Broken authorization. Hardcoded secrets. Tokens in URLs.
3. EXPOSURE: Sensitive data in logs. Error messages leaking internals. Debug endpoints in production. .env in git.
4. CRYPTO: Weak hashing for passwords. Missing CSRF tokens. Insecure random generation.

DEPENDENCIES:
5. BLOAT: Deps replaceable with 5 lines of code. Multiple libs doing the same thing.
6. ABANDONED: Deps with no updates in 12+ months.
7. MISCONFIGURATION: Wrong TS strict settings. Missing security headers. Overly permissive CORS.

PERFORMANCE:
8. N+1: Database calls inside loops. Sequential awaits that could be parallel. Fetching data you already have.
9. MEMORY: Large arrays never released. Event listeners not cleaned up. Subscriptions not unsubscribed.
10. RENDERING: Components re-rendering every state change. Missing memoization. Inline object/function creation in render paths.
11. BLOCKING: Sync file I/O. CPU work on main thread. Missing pagination on large datasets.
12. BUNDLE: Importing entire libraries for one function. Wrong dynamic/static import choice.

---

## Convention Compliance

For each rule in CLAUDE.md (and any directory-scoped CLAUDE.md files):
1. Check if the rule is actually followed across all relevant files
2. Flag violations with exact file:line references
3. Note rules that are outdated or contradictory

Also check for:
- Inconsistent patterns (some files do X, others do Y, no clear reason)
- README claims that don't match reality
- Package.json scripts that are broken or misleading

Quote the exact rule being violated. Only flag clear violations - skip ambiguous rules.
