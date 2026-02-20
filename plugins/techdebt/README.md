# Tech Debt Plugin

Lightweight end-of-session sweep. Run it at the end of every session to find and kill accumulated tech debt before it compounds.

Fast and targeted — not a full audit.

## Usage

```bash
/techdebt                # Full sweep with fixes applied
/techdebt --dry-run      # Report only, no modifications
/techdebt src/           # Scope to specific path
```

<details>
<summary>Fully-qualified syntax</summary>

If another plugin has a conflicting skill name, use the full `plugin:skill` form:

```bash
/techdebt:techdebt [--dry-run] [path]
```

</details>

## What It Finds

| Category | What | Severity |
|:---|:---|:---|
| Duplicated code | Blocks >10 lines of similarity across files | HIGH/MEDIUM |
| Dead exports | Exported symbols with zero imports | HIGH/MEDIUM |
| Unused dependencies | package.json deps not imported anywhere | HIGH/MEDIUM |
| Stale TODOs | TODO/FIXME/HACK with no linked issue | LOW/MEDIUM |
| Bloated files | Source files >300 lines | LOW/MEDIUM |
| Naming drift | Inconsistent conventions in same codebase | LOW/MEDIUM |

## Output

```markdown
## Tech Debt Sweep

**Scope:** full codebase
**Files scanned:** 47

### Duplicated Code
- [HIGH] `src/api/users.ts:45` — 25-line block duplicated from `src/api/teams.ts:82`. **Fix:** Extract to shared `buildQuery()` in `src/api/shared.ts`.

### Unused Dependencies
- [MEDIUM] `package.json` — `lodash` not imported anywhere. **Fix:** Remove from dependencies.

### Stale TODOs
- [LOW] `src/utils.ts:12` — `// TODO: refactor this` (no issue linked). **Fix:** Create issue or remove.

---
**Total:** 3 findings (1 high, 1 medium, 1 low)
```

---

> [!TIP]
> Pair with `/audit` for deep analysis. Use `/techdebt` for quick daily hygiene.
