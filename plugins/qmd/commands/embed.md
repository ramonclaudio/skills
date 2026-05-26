---
description: Generate or refresh vector embeddings for indexed documents. Long running.
allowed-tools:
  - Bash(qmd embed*)
  - Bash(qmd status*)
argument-hint: [-f|--force] [-c collection] [--chunk-strategy auto|regex] [--max-docs-per-batch N] [--max-batch-mb N]
---

Run `qmd embed $ARGUMENTS`. Defaults to incremental (only embeds hashes without vectors).

Useful flags:
- `-f` / `--force`: clear all vectors and re-embed everything (after model change, dimension mismatch, or strategy switch).
- `-c <name>`: scope to one collection (embeds only its pending hashes). `-c <name> --force` clears and rebuilds only that collection's vectors and preserves hashes shared with sibling collections. Added in qmd 2.5.0.
- `--chunk-strategy auto`: AST-aware chunking for code files (`.ts/.tsx/.js/.jsx/.mts/.cts/.mjs/.cjs/.py/.go/.rs`). Recommended for code-heavy collections so chunks land on function/class boundaries instead of mid-statement.
- `--max-docs-per-batch N` / `--max-batch-mb N`: bound peak memory on huge collections (defaults: 64 docs / 64 MB, whichever is hit first).

After embedding, run `qmd status` and confirm zero pending embeds. First run downloads ~300 MB embedding model; pre-download all 3 models (~2 GB) with `/qmd:pull`.

Embeddings are safe to interrupt and resume — the next run picks up from where it stopped.
