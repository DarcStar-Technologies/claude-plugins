#!/usr/bin/env bash
# Every plugin must be self-documenting: require CONTEXT.md, CHANGELOG.md and
# README.md in each plugin directory (including the _template reference).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

errors=0
required=(CONTEXT.md CHANGELOG.md README.md)

while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  name="$(basename "$dir")"
  for f in "${required[@]}"; do
    if [[ ! -f "$dir/$f" ]]; then
      err "$name: missing $f"
      errors=$((errors + 1))
    fi
  done
done < <(list_plugin_dirs --all)

[[ "$errors" -eq 0 ]] || die "$errors documentation problem(s) found"
info "plugin docs OK"
