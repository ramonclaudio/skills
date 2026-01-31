#!/bin/bash
# Zero-config project bootstrap.
# Creates minimal .handoff/ with auto-detected project info.
# Called by session-start.sh when no .handoff/ exists in a git repo.
# Must complete in <2s — heavy scanning deferred to END phase.

source "$(dirname "$0")/state.sh"

DIR="${CLAUDE_PROJECT_DIR:-.}"

git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

mkdir -p "$DIR/.handoff/sessions"

# Quick project detection
NAME=$(jq -r '.name // empty' "$DIR/package.json" 2>/dev/null)
[ -z "$NAME" ] && NAME=$(grep -m1 '^name' "$DIR/pyproject.toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/')
[ -z "$NAME" ] && NAME=$(grep -m1 '^name' "$DIR/Cargo.toml" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/')
[ -z "$NAME" ] && [ -f "$DIR/go.mod" ] && NAME=$(head -1 "$DIR/go.mod" | awk '{print $2}' | sed 's|.*/||')
NAME="${NAME:-$(basename "$DIR")}"

DESC=$(jq -r '.description // empty' "$DIR/package.json" 2>/dev/null)

# Runtime from lockfile
RUNTIME=""
[ -f "$DIR/bun.lockb" ] || [ -f "$DIR/bun.lock" ] && RUNTIME="bun"
[ -z "$RUNTIME" ] && [ -f "$DIR/pnpm-lock.yaml" ] && RUNTIME="pnpm"
[ -z "$RUNTIME" ] && [ -f "$DIR/yarn.lock" ] && RUNTIME="yarn"
[ -z "$RUNTIME" ] && [ -f "$DIR/package-lock.json" ] && RUNTIME="npm"
[ -z "$RUNTIME" ] && [ -f "$DIR/Cargo.toml" ] && RUNTIME="cargo"
[ -z "$RUNTIME" ] && [ -f "$DIR/go.mod" ] && RUNTIME="go"
[ -z "$RUNTIME" ] && [ -f "$DIR/uv.lock" ] && RUNTIME="uv"
[ -z "$RUNTIME" ] && [ -f "$DIR/pyproject.toml" ] && RUNTIME="uv"

REMOTE=$(git -C "$DIR" remote get-url origin 2>/dev/null || echo "—")

# Build invocation table
INVOKE=""
case "$RUNTIME" in
  bun)  INVOKE="| Dev | \`bun run dev\` | Start dev server |
| Test | \`bun test\` | Run tests |
| Build | \`bun run build\` | Production build |" ;;
  npm)  INVOKE="| Dev | \`npm run dev\` | Start dev server |
| Test | \`npm test\` | Run tests |
| Build | \`npm run build\` | Production build |" ;;
  pnpm) INVOKE="| Dev | \`pnpm dev\` | Start dev server |
| Test | \`pnpm test\` | Run tests |
| Build | \`pnpm build\` | Production build |" ;;
  cargo) INVOKE="| Build | \`cargo build\` | Build project |
| Test | \`cargo test\` | Run tests |
| Run | \`cargo run\` | Run project |" ;;
  go)   INVOKE="| Build | \`go build\` | Build project |
| Test | \`go test ./...\` | Run tests |" ;;
  uv)   INVOKE="| Run | \`uv run python\` | Run with deps |
| Test | \`uv run pytest\` | Run tests |" ;;
esac

cat > "$DIR/.handoff/CONTEXT.md" <<EOF
# ${NAME}

> ${DESC:-Project}

## Links

| Resource | URL |
|----------|-----|
| Repository | ${REMOTE} |
| Local | ${DIR} |

## Stack

<!-- CURATED: Edit manually -->
| Layer | Tech | Version |
|-------|------|---------|
| Runtime | ${RUNTIME:-unknown} | |

## Structure

<!-- AUTO: Regenerated on END -->

## Invocation

<!-- AUTO: Regenerated on END -->
$(if [ -n "$INVOKE" ]; then
echo "| Method | Command | Purpose |"
echo "|--------|---------|---------|"
echo "$INVOKE"
fi)

## Patterns

<!-- CURATED: Edit manually -->

## What Never Works

<!-- CURATED: Edit manually -->
| Problem | Solution |
|---------|----------|
EOF

# Reinitialize STATE_DIR after mkdir
STATE_DIR="$DIR/.handoff"
CTX_FILE="$STATE_DIR/.context-state"
JSON_FILE="$STATE_DIR/state.json"
state_init
state_to_markdown

# Add handoff ref to CLAUDE.md if it exists
if [ -f "$DIR/CLAUDE.md" ]; then
  if ! grep -q "Compact Instructions" "$DIR/CLAUDE.md" 2>/dev/null; then
    printf '\n<!-- Compact Instructions -->\n<!-- Handoff: see .handoff/HANDOFF.md for session state -->\n' >> "$DIR/CLAUDE.md"
  fi
fi

echo "AUTO-INIT: Bootstrapped .handoff/ for ${NAME} (${RUNTIME:-unknown}). Run /handoff:run init for thorough setup."
