---
description: Set the pre-update shell command for a collection
allowed-tools:
  - Bash(qmd collection update-cmd*)
argument-hint: <name> '<command>'
---

Run `qmd collection update-cmd $ARGUMENTS`.

Attaches a shell command that runs before every `qmd update` for this collection. Replaces direct editing of `~/.config/qmd/index.yml`.

The command is stored in the collection's `update` field in `${XDG_CONFIG_HOME:-~/.config}/qmd/index.yml`.

Example:
```bash
qmd collection update-cmd next.js 'git -C ~/Developer/refs/next.js pull --ff-only'
qmd collection update-cmd myrepo 'git stash && git pull --rebase --ff-only && git stash pop'
```
