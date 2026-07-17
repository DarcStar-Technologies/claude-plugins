#!/usr/bin/env bash
# discover-plugins.sh — the DISCOVERY step for dep-doctor's picker when no target plugin
# is given. Resolves the marketplace root (nearest ancestor with
# .claude-plugin/marketplace.json), lists each `plugins/<dir>` that has a valid
# plugin.json, and emits a JSON array of {name, path, description} with an ABSOLUTE path
# so the command can use it regardless of its own working directory. Scoped to plugins/
# only — never templates/.
#
# Usage: discover-plugins.sh [search-root]   (default: .)
#
# Exits 2 with no output when no marketplace ancestor is found, so the caller can fall
# back to a free-text prompt. Prints `[]` (exit 0) when there are no plugins.
set -euo pipefail

die() {
  printf 'discover-plugins: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

root_arg="${1:-.}"

# Nearest ancestor that is a marketplace (tests the filesystem root too).
find_marketplace() {
  local d
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  while [[ -n "$d" ]]; do
    [[ -f "$d/.claude-plugin/marketplace.json" ]] && {
      printf '%s' "$d"
      return 0
    }
    [[ "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
  return 1
}

root="$(find_marketplace "$root_arg")" || exit 2 # no marketplace -> caller falls back
[[ -d "$root/plugins" ]] || {
  printf '[]\n'
  exit 0
}

# Collect one tab-separated row per plugin, then assemble the JSON in a single final jq
# (one jq per manifest to validate+extract, instead of re-serializing the array each time).
entries=()
while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  manifest="$dir/.claude-plugin/plugin.json"
  [[ -f "$manifest" ]] || continue
  # Validate + extract name and description in one jq; an unparseable/non-object manifest
  # fails here and is skipped.
  line="$(jq -r 'select(type == "object") | [.name // "", .description // ""] | @tsv' "$manifest" 2>/dev/null)" || continue
  name="${line%%$'\t'*}"
  [[ -n "$name" ]] || continue
  desc="${line#*$'\t'}"
  entries+=("$(printf '%s\t%s\t%s' "$name" "$desc" "$dir")")
done < <(find "$root/plugins" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

[[ "${#entries[@]}" -gt 0 ]] || {
  printf '[]\n'
  exit 0
}
printf '%s\n' "${entries[@]}" |
  jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {name: .[0], path: .[2], description: .[1]})'
