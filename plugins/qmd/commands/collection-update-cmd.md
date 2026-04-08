---
description: Set or change the pre-update shell command for an existing qmd collection (e.g. git pull --ff-only).
allowed-tools: Bash(qmd collection update-cmd*)
argument-hint: <name> '<command>'
---

Run `qmd collection update-cmd $ARGUMENTS` (alias: `qmd collection set-update`).

The command is stored in the collection's `update:` field in `${XDG_CONFIG_HOME:-~/.config}/qmd/index.yml` and runs before every `qmd update` for that collection. The most common use case is `git pull --ff-only`, but it accepts any shell command.

The `/qmd:add` SKILL writes this once at clone time. Use `/qmd:collection-update-cmd` later when:

- A repo's branch policy changes (`pull --ff-only` → `pull --rebase --ff-only`)
- You want a stash dance: `'git stash && git pull --rebase --ff-only && git stash pop'`
- You want to skip the pull entirely (call with no command argument to clear it)

Examples:

```bash
qmd collection update-cmd next.js 'git -C ~/Developer/refs/next.js pull --ff-only'
qmd collection update-cmd myrepo 'git stash && git pull --rebase --ff-only && git stash pop'
qmd collection update-cmd notes ''   # clear (no pull, just re-index)
```

If `qmd update` runs and the command exits non-zero, **the entire `qmd update` aborts immediately** (subsequent collections are skipped). Test the command on its own before setting it.
