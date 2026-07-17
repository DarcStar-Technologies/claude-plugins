#!/usr/bin/env bash
# discover-targets.sh — the DISCOVERY step for /scaffold-retarget. When the command
# isn't given a target plugin, it runs this to list retargetable plugins and emits
# JSON for its AskUserQuestion picker.
#
# A plugin is retargetable only if it records scaffold provenance
# (.claude-plugin/scaffold.json with a template + templateVersion) — there is nothing
# to retarget without it. This is the key difference from the generic template picker:
# candidates lacking scaffold.json are filtered out.
#
# Usage: discover-targets.sh [search-root]   (default: .)
#
# Exits 2 with no output when no marketplace root is found (caller falls back to a
# free-text prompt); prints `[]` (exit 0) when the marketplace has no retargetable
# plugin. Each emitted `path` is ABSOLUTE.
set -euo pipefail

die() {
  printf 'discover-targets: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

root_arg="${1:-.}"

# Nearest ancestor holding a marketplace manifest (tests the filesystem root too).
find_root() {
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

root="$(find_root "$root_arg")" || exit 2 # no marketplace -> caller falls back
[[ -d "$root/plugins" ]] || {
  printf '[]\n'
  exit 0
}

entries=()
while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  # Retargetable == has scaffold provenance with a template recorded.
  scaffold="$dir/.claude-plugin/scaffold.json"
  [[ -f "$scaffold" ]] || continue
  jq -e '.template // empty | length > 0' "$scaffold" >/dev/null 2>&1 || continue
  manifest="$dir/.claude-plugin/plugin.json"
  [[ -f "$manifest" ]] || continue
  line="$(jq -r '[.name // "", .description // ""] | @tsv' "$manifest" 2>/dev/null)" || continue
  name="${line%%$'\t'*}"
  desc="${line#*$'\t'}"
  [[ -n "$name" ]] || continue
  # Annotate the description with the current template + version so the picker is useful.
  tmpl="$(jq -r '.template // "?"' "$scaffold")"
  tver="$(jq -r '.templateVersion // "?"' "$scaffold")"
  desc="[$tmpl v$tver] $desc"
  entries+=("$(printf '%s\t%s\t%s' "$name" "$desc" "$dir")")
done < <(find "$root/plugins" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

[[ "${#entries[@]}" -gt 0 ]] || {
  printf '[]\n'
  exit 0
}
printf '%s\n' "${entries[@]}" |
  jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {name: .[0], path: .[2], description: .[1]})'
