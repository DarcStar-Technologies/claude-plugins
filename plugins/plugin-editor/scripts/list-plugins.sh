#!/usr/bin/env bash
# list-plugins.sh — discover the plugins in a marketplace repo, for the
# /edit-plugin picker when no target directory is given. Walks up from
# [search-root] to the nearest ancestor marketplace (a `.claude-plugin/
# marketplace.json`), then emits a JSON array of {name, path, description} for each
# `plugins/<dir>` that has a plugin.json.
#
# Usage: list-plugins.sh [search-root]   (default: .)
#
# Exits non-zero with no output when there is no marketplace ancestor, so the
# caller can fall back to a free-text prompt. Prints `[]` (exit 0) when the
# marketplace has a plugins/ dir but no valid plugins. Scoped to plugins/ only —
# never templates/.
set -euo pipefail

die() {
  printf 'list-plugins: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

root_arg="${1:-.}"

# Nearest ancestor that is a marketplace (has .claude-plugin/marketplace.json).
find_marketplace() {
  local d
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  while [[ -n "$d" && "$d" != "/" ]]; do
    [[ -f "$d/.claude-plugin/marketplace.json" ]] && {
      printf '%s' "$d"
      return 0
    }
    d="$(dirname "$d")"
  done
  return 1
}

root="$(find_marketplace "$root_arg")" || exit 2 # no marketplace -> caller falls back
[[ -d "$root/plugins" ]] || {
  printf '[]\n'
  exit 0
}

out='[]'
while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  manifest="$dir/.claude-plugin/plugin.json"
  [[ -f "$manifest" ]] || continue
  jq empty "$manifest" 2>/dev/null || continue # skip an unparseable manifest, don't abort the whole listing
  name="$(jq -r '.name // empty' "$manifest")"
  [[ -n "$name" ]] || continue
  desc="$(jq -r '.description // ""' "$manifest")"
  out="$(jq --arg n "$name" --arg p "plugins/$(basename "$dir")" --arg d "$desc" \
    '. += [{name: $n, path: $p, description: $d}]' <<<"$out")"
done < <(find "$root/plugins" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

printf '%s\n' "$out"
