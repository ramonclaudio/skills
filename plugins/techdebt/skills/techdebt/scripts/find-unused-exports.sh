#!/usr/bin/env bash
# Find exported symbols never imported elsewhere. Outputs: file:line symbol
set -uo pipefail

root="${1:-.}"

find "$root" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
  -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/_generated/*" \
  -not -path "*/build/*" -not -path "*/.next/*" -not -name "*.min.*" -not -name "*.d.ts" \
  2>/dev/null | sort | while IFS= read -r file; do

  # Skip barrel files
  case "${file##*/}" in
    index.ts|index.tsx|index.js|index.jsx) continue ;;
  esac

  grep -n "export" "$file" 2>/dev/null | while IFS=: read -r lineno line; do
    # Skip re-exports
    [[ "$line" == *from[[:space:]]*[\'\"]* ]] && continue

    symbols=()

    if [[ "$line" =~ ^[[:space:]]*export[[:space:]]+(default[[:space:]]+)?(const|let|var|function|class|type|interface|enum)[[:space:]]+([a-zA-Z_\$][a-zA-Z0-9_\$]*) ]]; then
      symbols+=("${BASH_REMATCH[3]}")
    elif [[ "$line" =~ ^[[:space:]]*export[[:space:]]*\{([^}]+)\} ]]; then
      IFS=',' read -ra parts <<< "${BASH_REMATCH[1]}"
      for part in "${parts[@]}"; do
        part="${part#"${part%%[![:space:]]*}"}"  # trim leading
        part="${part%"${part##*[![:space:]]}"}"  # trim trailing
        if [[ "$part" =~ [[:space:]]as[[:space:]]+([a-zA-Z_\$][a-zA-Z0-9_\$]*) ]]; then
          symbols+=("${BASH_REMATCH[1]}")
        elif [[ -n "$part" ]]; then
          symbols+=("$part")
        fi
      done
    else
      continue
    fi

    for sym in "${symbols[@]}"; do
      refs=$(grep -rl --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
        --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=_generated --exclude-dir=build \
        -w "$sym" "$root" 2>/dev/null | grep -vc "^${file}$" || true)
      [[ "$refs" -eq 0 ]] && echo "$file:$lineno $sym"
    done
  done
done
