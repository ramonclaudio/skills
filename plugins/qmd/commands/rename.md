---
description: Rename a QMD collection
allowed-tools: Bash(qmd collection rename*)
argument-hint: <old-name> <new-name>
---

Run `qmd collection rename $ARGUMENTS`. Expects two arguments: `<old-name> <new-name>`.

Report the old and new `qmd://` URIs. Warn the user if any scripts or contexts reference the old collection name.
