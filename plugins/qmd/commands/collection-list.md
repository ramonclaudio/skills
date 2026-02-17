---
description: List all QMD collections with metadata
allowed-tools:
  - Bash(qmd collection list*)
---

Run `qmd collection list`.

Shows all collections with metadata: name, path, glob pattern, file count, and last updated timestamp.

Differs from `qmd ls` (which shows an `ls -l` style file listing). Both read from YAML + database — they differ in output format, not data source.
